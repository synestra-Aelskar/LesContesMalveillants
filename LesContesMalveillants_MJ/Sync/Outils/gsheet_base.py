"""Synchronise la base de contenu LCM avec un Google Sheet prive aux MJ.

Installation : python -m pip install google-auth requests
Le Sheet doit etre partage en edition avec l'adresse du compte de service.
Les joueurs recoivent les definitions publiques par leur addon et par le ping
des MJ ; ils ne se connectent jamais directement au Sheet.
"""

from __future__ import annotations

import argparse
import base64
import gzip
import hashlib
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from urllib.parse import quote
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "database"))
import lcm_db  # noqa: E402

STATE = ROOT / "database" / ".gsheet_state.json"
FEUILLES_FILE = ROOT / "Outils" / "feuilles_lcm.json"
HEADERS = ["Famille", "ID", "Nom", "Description", "MJ", "Statut", "Definition Lua"]
BACKUP_TAB = "Archives"
BACKUP_HEADERS = ["Instantane", "Fichier", "SHA256", "Fragment", "Fragments", "Gzip Base64"]
STATE_HEADERS = ["Compte", "Royaume", "Personnage", "Chemin", "Type", "Valeur", "Sauvegarde"]
REGLAGES_HEADERS = ["Chemin", "Valeur"]
ACTIVE = "ACTIF"
DELETED = "SUPPRIME"


def validate_tool_extensions(family: str, identifier: str, definition: dict) -> None:
    """Valide outils et prérequis de coffre dans leurs familles existantes."""
    if family == "objets" and definition.get("categorie") == "outil":
        bonus = definition.get("bonus") or {}
        if not isinstance(bonus, dict):
            raise ValueError(f"bonus d'outil invalides : {identifier}")
        for field in bonus:
            if str(field).startswith("metier:") and not str(field)[len("metier:"):]:
                raise ValueError(f"metier d'outil vide : {identifier}")
    if family == "points" and definition.get("nature") == "coffre":
        coffre = definition.get("coffre") or {}
        tools = coffre.get("outils") or {}
        if not isinstance(tools, dict):
            raise ValueError(f"liste d'outils invalide : {identifier}")
        for index, tool in enumerate(tools.values(), 1):
            if not isinstance(tool, dict):
                raise ValueError(f"prerequis d'outil invalide : {identifier} #{index}")
            exact = bool(str(tool.get("entree") or "").strip())
            by_type = bool(str(tool.get("typeOutil") or "").strip())
            if exact == by_type:
                raise ValueError(f"prerequis d'outil ambigu : {identifier} #{index}")


def sheet_bool(value: object) -> bool:
    if value is True:
        return True
    if value is False:
        return False
    text = str(value).strip().upper()
    if text in ("TRUE", "VRAI", "1"):
        return True
    if text in ("FALSE", "FAUX", "0", ""):
        return False
    raise ValueError(f"MJ doit valoir TRUE ou FALSE : {value!r}")


def canonical(row: list[object]) -> list[object]:
    values = (row + [""] * len(HEADERS))[: len(HEADERS)]
    family, identifier, label, description, mj, status, lua = values
    family, identifier = str(family).strip(), str(identifier).strip()
    if family not in lcm_db.FAMILIES:
        raise ValueError(f"famille inconnue : {family!r}")
    lcm_db.safe_id(identifier)
    status = str(status or ACTIVE).strip().upper()
    if status not in (ACTIVE, DELETED):
        raise ValueError(f"statut invalide pour {family}/{identifier} : {status}")
    definition = lcm_db.LuaParser(str(lua)).value() if str(lua).strip() else {}
    if not isinstance(definition, dict):
        raise ValueError(f"definition invalide : {family}/{identifier}")
    if status == ACTIVE and not definition:
        raise ValueError(f"definition vide : {family}/{identifier}")
    if definition and str(definition.get("id", "")) != identifier:
        raise ValueError(f"ID different dans la definition : {family}/{identifier}")
    if definition:
        validate_tool_extensions(family, identifier, definition)
        # Les colonnes lisibles priment sur les memes champs dans le Lua.
        definition["label"] = str(label)
        definition["description"] = str(description)
    mj = sheet_bool(mj)
    if definition:
        mandatory_mj = family in lcm_db.RESERVED_MJ or (
            family == "resolutions" and str(definition.get("categorie", "")) == "mj"
        )
        if mandatory_mj and not mj:
            raise ValueError(f"{family}/{identifier} doit rester MJ = TRUE")
        if mj and not mandatory_mj:
            definition["distributionMJ"] = True
        else:
            definition.pop("distributionMJ", None)
    return [family, identifier, str(label), str(description), mj, status,
            lcm_db.lua_value(definition) if definition else ""]


def key(row: list[object]) -> str:
    return f"{row[0]}/{row[1]}"


def digest(row: list[object]) -> str:
    payload = json.dumps(row, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def feuilles() -> dict[str, dict]:
    config = json.loads(FEUILLES_FILE.read_text(encoding="utf-8"))
    seen: set[str] = set()
    for name, item in config.items():
        if not name or not item.get("titre") or not isinstance(item.get("familles"), list):
            raise ValueError(f"configuration de feuille invalide : {name}")
        for family in item["familles"]:
            if family not in lcm_db.FAMILIES or family in seen:
                raise ValueError(f"famille absente ou en double : {family}")
            seen.add(family)
    if seen != set(lcm_db.FAMILIES):
        raise ValueError("familles non classees : " + ", ".join(sorted(set(lcm_db.FAMILIES) - seen)))
    return config


def local_rows(families: set[str] | None = None) -> dict[str, list[object]]:
    rows: dict[str, list[object]] = {}
    for path in sorted(lcm_db.ENTRIES.glob("*/*/*.lua")):
        meta, definition, _ = lcm_db.read_entry(path)
        family = str(meta["family"])
        if families is not None and family not in families:
            continue
        identifier = str(meta["id"])
        if family not in lcm_db.FAMILIES or lcm_db.FAMILIES[family] != meta["registry"]:
            raise ValueError(f"metadonnees invalides : {path}")
        side = lcm_db.side_for(family, definition)
        if side != meta["side"]:
            raise ValueError(f"cote incoherent : {path} (attendu {side})")
        status = DELETED if lcm_db.tombstone_path(family, identifier).exists() else ACTIVE
        row = canonical([family, identifier, definition.get("label", identifier),
                         definition.get("description", ""), side == "mj", status,
                         lcm_db.lua_value(definition)])
        if key(row) in rows:
            raise ValueError(f"entree en double : {key(row)}")
        rows[key(row)] = row
    for marker in sorted(lcm_db.TOMBSTONES.glob("*/*.delete")):
        family, identifier = marker.parent.name, marker.stem
        if families is not None and family not in families:
            continue
        if family not in lcm_db.FAMILIES:
            raise ValueError(f"famille de suppression inconnue : {marker}")
        identifier = lcm_db.safe_id(identifier)
        name = f"{family}/{identifier}"
        if name not in rows:
            rows[name] = canonical([family, identifier, "", "",
                                    family in lcm_db.RESERVED_MJ, DELETED, ""])
    return rows


def remote_rows(values: list[list[object]]) -> dict[str, tuple[int, list[object]]]:
    if not values or values[0][: len(HEADERS)] != HEADERS:
        raise ValueError("en-tetes du Sheet absents ou modifies")
    rows = {}
    for number, raw in enumerate(values[1:], 2):
        # Une case a cocher vide est renvoyee comme FALSE par Sheets.
        if not any(str(v).strip() for index, v in enumerate(raw) if index != 4):
            continue
        row = canonical(raw)
        if key(row) in rows:
            raise ValueError(f"doublon ligne {number} : {key(row)}")
        rows[key(row)] = (number, row)
    return rows


def state_path(classeur: str) -> Path:
    return STATE.with_name(f".gsheet_state_{classeur}.json")


def load_state(sheet_id: str, classeur: str) -> dict[str, str]:
    path = state_path(classeur)
    if not path.exists():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("sheet_id") != sheet_id:
        raise ValueError("cet ordinateur est lie a un autre Sheet ; verifier .gsheet_state.json")
    return data.get("hashes", {})


def save_state(sheet_id: str, classeur: str, rows: dict[str, list[object]]) -> None:
    data = {"sheet_id": sheet_id, "hashes": {k: digest(v) for k, v in sorted(rows.items())}}
    path = state_path(classeur)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


class Sheets:
    def __init__(self, credentials: Path, sheet_id: str, tab: str = "Jeu"):
        try:
            from google.oauth2 import service_account
            from google.auth.transport.requests import AuthorizedSession
        except ImportError as exc:
            raise RuntimeError("installer d'abord : python -m pip install google-auth requests") from exc
        scopes = ["https://www.googleapis.com/auth/spreadsheets"]
        auth = service_account.Credentials.from_service_account_file(str(credentials), scopes=scopes)
        self.session = AuthorizedSession(auth)
        self.base = f"https://sheets.googleapis.com/v4/spreadsheets/{sheet_id}"
        self.tab = tab

    def select(self, tab: str) -> None:
        self.tab = tab

    def request(self, method: str, suffix: str, body: dict | None = None) -> dict:
        response = self.session.request(method, self.base + suffix, json=body, timeout=30)
        if not response.ok:
            raise RuntimeError(f"Google Sheets ({response.status_code}) : {response.text[:500]}")
        return response.json() if response.content else {}

    def prepare(self) -> None:
        meta = self.request("GET", "?fields=sheets(properties(sheetId,title))")
        found = next((s["properties"]["sheetId"] for s in meta.get("sheets", [])
                      if s["properties"]["title"] == self.tab), None)
        if found is None:
            result = self.request("POST", ":batchUpdate", {"requests": [
                {"addSheet": {"properties": {"title": self.tab, "gridProperties": {
                    "rowCount": 2000, "columnCount": len(HEADERS), "frozenRowCount": 1}}}}
            ]})
            found = result["replies"][0]["addSheet"]["properties"]["sheetId"]
        requests = [
            {"updateSheetProperties": {"properties": {"sheetId": found,
                "gridProperties": {"frozenRowCount": 1}},
                "fields": "gridProperties.frozenRowCount"}},
            {"repeatCell": {"range": {"sheetId": found, "startRowIndex": 0,
                "endRowIndex": 1, "startColumnIndex": 0, "endColumnIndex": len(HEADERS)},
                "cell": {"userEnteredFormat": {"backgroundColor": {
                    "red": 0.11, "green": 0.17, "blue": 0.24},
                    "textFormat": {"bold": True, "foregroundColor": {
                        "red": 1, "green": 1, "blue": 1}}}},
                "fields": "userEnteredFormat"}},
            {"updateDimensionProperties": {"range": {"sheetId": found,
                "dimension": "COLUMNS", "startIndex": 0, "endIndex": 2},
                "properties": {"pixelSize": 160}, "fields": "pixelSize"}},
            {"updateDimensionProperties": {"range": {"sheetId": found,
                "dimension": "COLUMNS", "startIndex": 2, "endIndex": 4},
                "properties": {"pixelSize": 300}, "fields": "pixelSize"}},
            {"updateDimensionProperties": {"range": {"sheetId": found,
                "dimension": "COLUMNS", "startIndex": 4, "endIndex": 6},
                "properties": {"pixelSize": 105}, "fields": "pixelSize"}},
            {"updateDimensionProperties": {"range": {"sheetId": found,
                "dimension": "COLUMNS", "startIndex": 6, "endIndex": 7},
                "properties": {"pixelSize": 500, "hiddenByUser": True},
                "fields": "pixelSize,hiddenByUser"}},
            {"updateDimensionProperties": {"range": {"sheetId": found,
                "dimension": "ROWS", "startIndex": 1, "endIndex": 2000},
                "properties": {"pixelSize": 38}, "fields": "pixelSize"}},
            {"repeatCell": {"range": {"sheetId": found, "startRowIndex": 1,
                "startColumnIndex": 0, "endColumnIndex": len(HEADERS)},
                "cell": {"userEnteredFormat": {"verticalAlignment": "MIDDLE",
                    "wrapStrategy": "CLIP"}},
                "fields": "userEnteredFormat.verticalAlignment,userEnteredFormat.wrapStrategy"}},
            {"setBasicFilter": {"filter": {"range": {"sheetId": found,
                "startRowIndex": 0, "endColumnIndex": len(HEADERS)}}}},
            {"setDataValidation": {"range": {"sheetId": found,
                "startRowIndex": 1, "startColumnIndex": 4, "endColumnIndex": 5},
                "rule": {"condition": {"type": "BOOLEAN"}, "strict": True}}},
        ]
        self.request("POST", ":batchUpdate", {"requests": requests})
        current = self.values()
        if not current or not any(str(value).strip() for value in current[0]):
            self.write(1, [HEADERS])
        elif current[0][: len(HEADERS)] != HEADERS:
            raise ValueError(f"l'onglet {self.tab} existe avec d'autres en-tetes")

    def prepare_backups(self) -> None:
        meta = self.request("GET", "?fields=sheets(properties(sheetId,title))")
        found = next((s["properties"]["sheetId"] for s in meta.get("sheets", [])
                      if s["properties"]["title"] == BACKUP_TAB), None)
        if found is None:
            result = self.request("POST", ":batchUpdate", {"requests": [
                {"addSheet": {"properties": {"title": BACKUP_TAB,
                    "gridProperties": {"rowCount": 1000, "columnCount": len(BACKUP_HEADERS),
                                       "frozenRowCount": 1}}}}
            ]})
            found = result["replies"][0]["addSheet"]["properties"]["sheetId"]
        self.request("POST", ":batchUpdate", {"requests": [
            {"repeatCell": {"range": {"sheetId": found, "startRowIndex": 0,
                "endRowIndex": 1, "startColumnIndex": 0, "endColumnIndex": len(BACKUP_HEADERS)},
                "cell": {"userEnteredFormat": {"backgroundColor": {
                    "red": 0.11, "green": 0.17, "blue": 0.24},
                    "textFormat": {"bold": True, "foregroundColor": {
                        "red": 1, "green": 1, "blue": 1}}}},
                "fields": "userEnteredFormat"}},
            {"updateDimensionProperties": {"range": {"sheetId": found,
                "dimension": "COLUMNS", "startIndex": 0, "endIndex": 3},
                "properties": {"pixelSize": 280}, "fields": "pixelSize"}},
            {"updateDimensionProperties": {"range": {"sheetId": found,
                "dimension": "COLUMNS", "startIndex": 5, "endIndex": 6},
                "properties": {"pixelSize": 450}, "fields": "pixelSize"}},
        ]})
        encoded = quote(f"'{BACKUP_TAB}'!A1:F1", safe="")
        values = self.request("GET", f"/values/{encoded}").get("values", [])
        if not values:
            self.request("PUT", f"/values/{encoded}?valueInputOption=RAW",
                         {"range": f"'{BACKUP_TAB}'!A1:F1", "values": [BACKUP_HEADERS]})
        elif values[0] != BACKUP_HEADERS:
            raise ValueError(f"l'onglet {BACKUP_TAB} existe avec d'autres en-tetes")

    def values(self) -> list[list[object]]:
        region = quote(f"'{self.tab}'!A:G", safe="")
        return self.request("GET", f"/values/{region}?valueRenderOption=UNFORMATTED_VALUE").get("values", [])

    def write(self, start: int, rows: list[list[object]]) -> None:
        if not rows:
            return
        end = start + len(rows) - 1
        cell_range = f"'{self.tab}'!A{start}:G{end}"
        self.request("PUT", f"/values/{quote(cell_range, safe='')}?valueInputOption=RAW",
                     {"range": cell_range, "majorDimension": "ROWS", "values": rows})

    def append_backup(self, rows: list[list[object]]) -> None:
        region = quote(f"'{BACKUP_TAB}'!A:F", safe="")
        self.request("POST", f"/values/{region}:append?valueInputOption=RAW"
                     "&insertDataOption=INSERT_ROWS",
                     {"range": f"'{BACKUP_TAB}'!A:F", "majorDimension": "ROWS", "values": rows})

    def backup_values(self) -> list[list[object]]:
        region = quote(f"'{BACKUP_TAB}'!A:F", safe="")
        return self.request("GET", f"/values/{region}?valueRenderOption=UNFORMATTED_VALUE").get("values", [])

    def prepare_view(self, tab: str, headers: list[str]) -> None:
        meta = self.request("GET", "?fields=sheets(properties(sheetId,title))")
        found = next((s["properties"]["sheetId"] for s in meta.get("sheets", [])
                      if s["properties"]["title"] == tab), None)
        if found is None:
            result = self.request("POST", ":batchUpdate", {"requests": [
                {"addSheet": {"properties": {"title": tab, "gridProperties": {
                    "rowCount": 1000, "columnCount": len(headers), "frozenRowCount": 1}}}}
            ]})
            found = result["replies"][0]["addSheet"]["properties"]["sheetId"]
        self.request("POST", ":batchUpdate", {"requests": [
            {"repeatCell": {"range": {"sheetId": found, "startRowIndex": 0,
                "endRowIndex": 1, "startColumnIndex": 0, "endColumnIndex": len(headers)},
                "cell": {"userEnteredFormat": {"backgroundColor": {
                    "red": 0.11, "green": 0.17, "blue": 0.24},
                    "textFormat": {"bold": True, "foregroundColor": {
                        "red": 1, "green": 1, "blue": 1}}}},
                "fields": "userEnteredFormat"}},
            {"updateDimensionProperties": {"range": {"sheetId": found,
                "dimension": "COLUMNS", "startIndex": 0, "endIndex": len(headers)},
                "properties": {"pixelSize": 230}, "fields": "pixelSize"}},
        ]})
        region = quote(f"'{tab}'!A1:{chr(64 + len(headers))}1", safe="")
        current = self.request("GET", f"/values/{region}").get("values", [])
        if not current:
            self.request("PUT", f"/values/{region}?valueInputOption=RAW",
                         {"range": f"'{tab}'!A1:{chr(64 + len(headers))}1", "values": [headers]})
        elif current[0] != headers:
            raise ValueError(f"l'onglet {tab} existe avec d'autres en-tetes")

    def replace_view(self, tab: str, headers: list[str], rows: list[list[object]]) -> None:
        self.prepare_view(tab, headers)
        last = chr(64 + len(headers))
        region = quote(f"'{tab}'!A2:{last}", safe="")
        self.request("POST", f"/values/{region}:clear", {})
        if rows:
            end = len(rows) + 1
            target = f"'{tab}'!A2:{last}{end}"
            self.request("PUT", f"/values/{quote(target, safe='')}?valueInputOption=RAW",
                         {"range": target, "majorDimension": "ROWS", "values": rows})


def apply_remote(row: list[object], backup: Path) -> None:
    family, identifier, _, _, _, status, lua = row
    definition = lcm_db.LuaParser(lua).value() if lua else {}
    if status == DELETED:
        target = lcm_db.tombstone_path(family, identifier)
        if not target.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(f"{family}/{identifier}\n", encoding="utf-8")
        return
    target = lcm_db.entry_path(family, lcm_db.side_for(family, definition), identifier)
    other = lcm_db.entry_path(family, "player" if target.parent.parent.name == "mj" else "mj", identifier)
    for path in (target, other):
        if path.exists():
            archived = backup / path.relative_to(ROOT)
            archived.parent.mkdir(parents=True, exist_ok=True)
            archived.write_bytes(path.read_bytes())
    lcm_db.write_entry(family, definition)
    if other.exists():
        other.unlink()
    marker = lcm_db.tombstone_path(family, identifier)
    if marker.exists():
        archived = backup / marker.relative_to(ROOT)
        archived.parent.mkdir(parents=True, exist_ok=True)
        archived.write_bytes(marker.read_bytes())
        marker.unlink()


def synchronise(api: Sheets, sheet_id: str, classeur: str, families: set[str],
               prepare: bool = True, verbose: bool = True) -> None:
    if prepare:
        api.prepare()
    local = local_rows(families)
    remote = remote_rows(api.values())
    for identifier in remote:
        if identifier.split("/", 1)[0] not in families:
            raise ValueError(f"entree dans le mauvais classeur : {identifier}")
    baseline = load_state(sheet_id, classeur)
    pulls: list[list[object]] = []
    pushes: list[tuple[int, list[object]]] = []
    appends: list[list[object]] = []
    conflicts: list[str] = []
    for identifier in sorted(set(local) | set(remote)):
        here = local.get(identifier)
        there = remote.get(identifier)
        old = baseline.get(identifier)
        if here is None and there is not None:
            if old:
                conflicts.append(identifier + " (supprime localement)")
            else:
                pulls.append(there[1])
        elif there is None and here is not None:
            if old:
                conflicts.append(identifier + " (supprime du Sheet)")
            else:
                appends.append(here)
        elif here is not None and there is not None:
            local_hash, remote_hash = digest(here), digest(there[1])
            if local_hash == remote_hash:
                continue
            if old == local_hash:
                pulls.append(there[1])
            elif old == remote_hash:
                pushes.append((there[0], here))
            else:
                conflicts.append(identifier + " (deux versions differentes)")
    if conflicts:
        raise ValueError("synchronisation arretee, aucun changement applique :\n- "
                         + "\n- ".join(conflicts))
    backup = ROOT / "Sauvegardes_LCM" / datetime.now().strftime("%Y%m%d_%H%M%S")
    for row in pulls:
        apply_remote(row, backup)
    # Verifier toute la base avant d'envoyer les modifications locales.
    lcm_db.build()
    for number, row in pushes:
        api.write(number, [row])
    if appends:
        api.write(max([1] + [number for number, _ in remote.values()]) + 1, appends)
    save_state(sheet_id, classeur, local_rows(families))
    if verbose and (pulls or pushes or appends):
        print(f"{classeur} : {len(pulls)} recues, {len(pushes) + len(appends)} envoyees.")
    if pulls and verbose:
        print(f"Copies des anciens fichiers : {backup}")


def saved_files(retail: Path) -> list[Path]:
    account = retail / "WTF" / "Account"
    if not account.is_dir():
        raise FileNotFoundError(f"dossier WoW introuvable : {account}")
    names = {
        "LesContesMalveillants.lua", "LesContesMalveillants.lua.bak",
        "LesContesMalveillants_MJ.lua", "LesContesMalveillants_MJ.lua.bak",
    }
    return sorted(path for path in account.rglob("LesContesMalveillants*.lua*")
                  if path.is_file() and path.name in names
                  and "SavedVariables" in path.parts)


def flat_values(value: object, prefix: str = ""):
    if isinstance(value, dict):
        if not value:
            yield [prefix or "/", "table", "{}"]
        for key in sorted(value, key=lambda item: (str(type(item)), str(item))):
            escaped = str(key).replace("~", "~0").replace("/", "~1")
            yield from flat_values(value[key], prefix + "/" + escaped)
    elif isinstance(value, bool):
        yield [prefix or "/", "booleen", "TRUE" if value else "FALSE"]
    elif isinstance(value, (int, float)):
        yield [prefix or "/", "nombre", str(value)]
    else:
        yield [prefix or "/", "texte", str(value)]


def current_state_rows(retail: Path, files: list[Path]) -> dict[str, list[list[object]]]:
    result: dict[str, list[list[object]]] = {"Comptes": [], "Fiches": [], "Etat MJ": []}
    for file in files:
        if file.suffix != ".lua":
            continue
        parts = file.relative_to(retail).parts
        if len(parts) == 5 and parts[:2] == ("WTF", "Account"):
            account, realm, character = parts[2], "", ""
            tab, variable = (("Etat MJ", "LCM_MJ_DB") if file.name.endswith("_MJ.lua")
                             else ("Comptes", "LCM_DB"))
        elif len(parts) == 7 and parts[:2] == ("WTF", "Account"):
            account, realm, character = parts[2], parts[3], parts[4]
            tab, variable = "Fiches", "LCM_CharDB"
        else:
            continue
        timestamp = datetime.fromtimestamp(file.stat().st_mtime).astimezone().isoformat(timespec="seconds")
        try:
            root = lcm_db.parse_assignments(file.read_text(encoding="utf-8", errors="replace"))
            value = root.get(variable)
            if not isinstance(value, dict):
                raise ValueError(f"table {variable} absente")
            for path, typ, cell in flat_values(value):
                result[tab].append([account, realm, character, path, typ, cell, timestamp])
        except (ValueError, lcm_db.LuaError) as error:
            result[tab].append([account, realm, character, "/", "ERREUR",
                                str(error), timestamp])
    return result


def publish_state_views(api: Sheets, retail: Path, files: list[Path]) -> None:
    result = current_state_rows(retail, files)
    for tab, rows in result.items():
        api.replace_view(tab, STATE_HEADERS, rows)
    reglages = [[chemin, valeur] for chemin, valeur in lcm_db.lire_reglages()]
    api.replace_view("Reglages", REGLAGES_HEADERS, reglages)


def sauvegarder(api: Sheets, retail: Path) -> None:
    files = saved_files(retail)
    if not files:
        raise FileNotFoundError("aucune SavedVariables LCM trouvee")
    api.prepare_backups()
    stamp = datetime.now().astimezone().strftime("%Y%m%d_%H%M%S_%z")
    destination = ROOT / "Sauvegardes_LCM" / f"LCM_{stamp}.zip"
    destination.parent.mkdir(parents=True, exist_ok=True)
    rows: list[list[object]] = []
    manifest: dict[str, str] = {}
    with ZipFile(destination, "w", compression=ZIP_DEFLATED) as archive:
        for file in files:
            relative = file.relative_to(retail).as_posix()
            raw = file.read_bytes()
            archive.writestr(relative, raw)
            encoded = base64.b64encode(gzip.compress(raw, mtime=0)).decode("ascii")
            chunks = [encoded[i:i + 30000] for i in range(0, len(encoded), 30000)]
            signature = hashlib.sha256(raw).hexdigest()
            manifest[relative] = signature
            for index, chunk in enumerate(chunks, 1):
                rows.append([stamp, relative, signature, index, len(chunks), chunk])
    manifest_raw = json.dumps(manifest, ensure_ascii=False, sort_keys=True).encode("utf-8")
    rows.insert(0, [stamp, "__MANIFEST__", hashlib.sha256(manifest_raw).hexdigest(),
                    1, 1, base64.b64encode(gzip.compress(manifest_raw, mtime=0)).decode("ascii")])
    # Une copie locale complete existe avant le premier appel reseau.
    for index in range(0, len(rows), 100):
        api.append_backup(rows[index:index + 100])
    publish_state_views(api, retail, files)
    print(f"{len(files)} fichiers sauvegardes : {destination} ; {len(rows)} fragments dans le Sheet.")


def restaurer(api: Sheets, stamp: str, destination: Path) -> None:
    api.prepare_backups()
    entries: dict[str, list[list[object]]] = {}
    for row in api.backup_values()[1:]:
        if len(row) == len(BACKUP_HEADERS) and str(row[0]) == stamp:
            entries.setdefault(str(row[1]), []).append(row)
    if not entries:
        raise ValueError(f"instantane absent du Sheet : {stamp}")
    manifest_fragments = entries.pop("__MANIFEST__", None)
    if not manifest_fragments or len(manifest_fragments) != 1:
        raise ValueError("manifeste de sauvegarde absent ou incomplet")
    manifest_raw = gzip.decompress(base64.b64decode(str(manifest_fragments[0][5]), validate=True))
    if hashlib.sha256(manifest_raw).hexdigest() != str(manifest_fragments[0][2]):
        raise ValueError("empreinte du manifeste incorrecte")
    manifest = json.loads(manifest_raw)
    if set(entries) != set(manifest):
        raise ValueError("liste des fichiers de sauvegarde incomplete")
    root = destination.resolve()
    validated: list[tuple[Path, bytes]] = []
    for name, fragments in entries.items():
        relative = Path(name)
        if relative.is_absolute() or ".." in relative.parts or relative.parts[0] != "WTF":
            raise ValueError(f"chemin de sauvegarde invalide : {name}")
        count = int(fragments[0][4])
        if len(fragments) != count or sorted(int(f[3]) for f in fragments) != list(range(1, count + 1)):
            raise ValueError(f"fragments incomplets : {name}")
        fragments.sort(key=lambda f: int(f[3]))
        encoded = "".join(str(f[5]) for f in fragments)
        raw = gzip.decompress(base64.b64decode(encoded, validate=True))
        if hashlib.sha256(raw).hexdigest() != str(fragments[0][2]):
            raise ValueError(f"empreinte incorrecte : {name}")
        if hashlib.sha256(raw).hexdigest() != manifest[name]:
            raise ValueError(f"fichier different du manifeste : {name}")
        target = (root / relative).resolve()
        if not target.is_relative_to(root):
            raise ValueError(f"chemin hors destination : {name}")
        if target.exists():
            raise FileExistsError(f"ne remplace pas un fichier existant : {target}")
        validated.append((target, raw))
    for target, raw in validated:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)
    print(f"{len(entries)} fichiers restaures dans {root}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("commande", choices=("apercu", "initialiser", "sync", "sauvegarder", "restaurer"))
    parser.add_argument("--feuille", help="synchroniser une seule feuille de contenu")
    parser.add_argument("--sheet-id", help="identifiant dans l'URL du Google Sheet")
    parser.add_argument("--credentials", type=Path, help="JSON du compte de service Google")
    parser.add_argument("--retail", type=Path, help="dossier _retail_ de WoW")
    parser.add_argument("--instantane", help="identifiant d'une sauvegarde a restaurer")
    parser.add_argument("--destination", type=Path, help="dossier vide pour une restauration")
    args = parser.parse_args()
    plan = feuilles()
    if args.commande == "apercu":
        for name, item in plan.items():
            rows = local_rows(set(item["familles"]))
            print(f"{item['titre']} ({name}) : {len(rows)} entrees, "
                  f"{sum(r[4] for r in rows.values())} MJ")
        return
    if not args.sheet_id or not args.credentials:
        parser.error("la commande requiert --sheet-id et --credentials")
    api = Sheets(args.credentials, args.sheet_id)
    if args.commande in ("initialiser", "sync"):
        if args.feuille and (args.feuille not in plan or not plan[args.feuille]["familles"]):
            parser.error("--feuille doit designer une feuille de contenu")
        selected = [args.feuille] if args.feuille else [name for name in plan if plan[name]["familles"]]
        for name in selected:
            api.select(plan[name]["titre"])
            synchronise(api, args.sheet_id, name, set(plan[name]["familles"]))
        if args.commande == "initialiser":
            api.prepare_backups()
            api.replace_view("Reglages", REGLAGES_HEADERS,
                             [[chemin, valeur] for chemin, valeur in lcm_db.lire_reglages()])
            for tab in ("Comptes", "Fiches", "Etat MJ"):
                api.prepare_view(tab, STATE_HEADERS)
            print("Toutes les feuilles de contenu et de sauvegarde sont pretes.")
    elif args.commande == "sauvegarder":
        retail = args.retail or (Path(os.environ["LCM_RETAIL"]) if "LCM_RETAIL" in os.environ else None)
        if not retail:
            parser.error("sauvegarder requiert --retail ou LCM_RETAIL")
        sauvegarder(api, retail.resolve())
    else:
        if not args.instantane or not args.destination:
            parser.error("restaurer requiert --instantane et --destination")
        restaurer(api, args.instantane, args.destination)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, RuntimeError, lcm_db.LuaError) as error:
        print(f"ERREUR : {error}", file=sys.stderr)
        raise SystemExit(1) from error
