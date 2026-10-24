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
import math
import os
import sys
import time
from datetime import datetime
from decimal import Decimal, InvalidOperation
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

# La colonne Famille d'un point pose dit CE qui est pose (« Vendeur »,
# « Coffre »), pas le nom de la famille : c'est ce que le MJ cherche en
# filtrant. Le nom n'est qu'un affichage — la nature fait foi dans le Lua, et
# a la lecture tous ces noms redeviennent « poses ». Une suppression n'a plus
# de Lua, donc plus de nature : elle s'affiche « Point posé ».
NATURES_POSES = {"coffre": "Coffre", "ressource": "Récolte", "vendeur": "Vendeur"}
POSE_SANS_NATURE = "Point posé"
FAMILLES_AFFICHEES = {nom: "poses" for nom in [*NATURES_POSES.values(), POSE_SANS_NATURE]}
# L'onglet des points poses a une colonne de plus : le personnage qui a pose le
# point, pour filtrer les placements de chacun. Comme la Famille affichee, elle
# n'est qu'une lecture du Lua (`posePar`, a defaut l'arbitre) et s'ignore a la
# relecture. Elle vient APRES la colonne Lua, masquee : a l'ecran, elle suit
# Statut, et aucune colonne existante ne change de place.
CREATEUR = "Créateur"

# Les trois conteneurs d'etats de la fenetre Sante, dans l'ordre de
# Core/Etats.lua. Un type d'etat (famille `listes`, liste `type_etats`) designe
# l'un d'eux, et rien d'autre.
CONTENEURS_ETATS = ("etat", "maladie", "intangible")


def validate_tool_extensions(family: str, identifier: str, definition: dict) -> None:
    """Garde les nouveaux outils dans les familles existantes du Sheet.

    Un outil est un objet, son type une entree de listes, et le prerequis
    correspondant vit dans un point coffre : aucune nouvelle feuille/famille
    n'est necessaire. Refuser ici une cible ambigue evite de la publier depuis
    le Sheet puis de la voir echouer au chargement de l'addon.
    """
    if family == "objets" and definition.get("categorie") == "outil":
        bonus = definition.get("bonus") or {}
        if not isinstance(bonus, dict):
            raise ValueError(f"bonus d'outil invalides : {identifier}")
        for field in bonus:
            if str(field).startswith("metier:") and not str(field)[len("metier:"):]:
                raise ValueError(f"metier d'outil vide : {identifier}")
        # Un outil contenant (Core/Contenants.lua, 23 octobre 2026) : la meme
        # regle que l'addon, pour ne pas publier ce qu'il refuserait.
        contenant = definition.get("contenant")
        if contenant is not None:
            if not isinstance(contenant, dict):
                raise ValueError(f"contenant illisible : {identifier}")
            def entier(cle: str) -> int:
                valeur = contenant.get(cle)
                # Les champs saisis en jeu restent parfois du texte dans les
                # brouillons. Contenants.Lire les accepte via tonumber : lire
                # la meme valeur ici, sans modifier la definition sauvegardee.
                if isinstance(valeur, str):
                    try:
                        valeur = float(valeur.strip())
                    except ValueError:
                        raise ValueError(f"{cle} du contenant illisible : {identifier}") from None
                if isinstance(valeur, float) and not math.isfinite(valeur):
                    raise ValueError(f"{cle} du contenant illisible : {identifier}")
                if isinstance(valeur, bool) or not isinstance(valeur, (int, float)) or valeur != int(valeur) or valeur < 1:
                    raise ValueError(f"{cle} du contenant illisible : {identifier}")
                return int(valeur)
            if entier("retrait") > entier("taille"):
                raise ValueError(f"un usage retire plus que le contenant ne tient : {identifier}")
    elif family == "objets" and definition.get("contenant") is not None:
        raise ValueError(f"seul un outil peut etre un contenant : {identifier}")
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
    if family == "listes" and definition.get("liste") == "type_etats":
        # Un type d'etat dit OU l'etat se range (Core/Contenus.lua, 24 octobre
        # 2026). L'addon refuse autre chose au CHARGEMENT, par error() : un
        # conteneur faux publie depuis le Sheet n'abime pas une entree, il
        # empeche l'addon de se charger — chez tout le monde. Il ne passe donc
        # pas le service.
        conteneur = str(definition.get("conteneur") or "").strip()
        if conteneur not in CONTENEURS_ETATS:
            raise ValueError(f"conteneur d'un type d'etat illisible : {identifier}")


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
    family = FAMILLES_AFFICHEES.get(family, family)
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


def _definition(row: list[object]) -> dict:
    lua = str(row[6] or "").strip()
    definition = lcm_db.LuaParser(lua).value() if lua else {}
    return definition if isinstance(definition, dict) else {}


def famille_affichee(row: list[object]) -> str:
    if row[0] != "poses":
        return str(row[0])
    return NATURES_POSES.get(str(_definition(row).get("nature") or ""), POSE_SANS_NATURE)


def createur(row: list[object]) -> str:
    """Le personnage qui a pose ce point, sans son royaume."""
    definition = _definition(row)
    donnees = definition.get("donnees")
    pose_par = donnees.get("posePar") if isinstance(donnees, dict) else None
    return str(pose_par or definition.get("auteur") or "").split("-", 1)[0]


def vers_sheet(row: list[object]) -> list[object]:
    """Une ligne canonique telle qu'elle s'ecrit dans le Sheet."""
    ligne = [famille_affichee(row)] + list(row[1:])
    if row[0] == "poses":
        ligne.append(createur(row))
    return ligne


def onglet_poses() -> str:
    return next(item["titre"] for item in feuilles().values() if "poses" in item["familles"])


def en_tetes(tab: str) -> list[str]:
    """Les en-tetes de cet onglet de contenu."""
    return HEADERS + [CREATEUR] if tab == onglet_poses() else HEADERS


def digest(row: list[object]) -> str:
    payload = json.dumps(row, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def equivalent_rows(a: list[object], b: list[object]) -> bool:
    """Compare les champs numeriques connus, sans reecrire le contenu.

    Les empreintes historiques restent inchangees : changer digest invaliderait
    les bases de comparaison existantes. Ni les textes ni les identifiants ne
    sont convertis, et une valeur differente reste un vrai conflit.
    """
    if a == b:
        return True
    if a[:6] != b[:6]:
        return False
    family = a[0]

    def numeric(path):
        if family in {"objets", "traits", "races"} and len(path) == 2 and path[0] == "bonus":
            return True
        if family == "objets":
            return path == ("taille",) or path in {( "etat", k) for k in ("courant", "max", "version")} or path in {("contenant", "taille"), ("contenant", "retrait")}
        if family == "traits":
            return path == ("cout",)
        if family == "listes":
            return path == ("maxEquipe",)
        if family == "cristaux":
            return path == ("duree",)
        if family == "pnj":
            return len(path) == 2 and path[0] in {"valeurs", "metiersNiveaux"}
        if family == "jeux":
            return len(path) == 3 and ((path[0] == "champs" and path[2] in {"base", "cout", "min", "max"}) or (path[0] == "raretes" and path[2] in {"points", "coutTrait"}))
        return False

    def equal(x, y, path=()):
        if isinstance(x, dict) and isinstance(y, dict):
            for key in set(x) | set(y):
                if key not in x or key not in y:
                    # Ces deux collections vides sont ajoutees au PNJ en jeu.
                    if family == "pnj" and not path and key in {"apprentissages", "etats"} and (x[key] if key in x else y[key]) == {}:
                        continue
                    return False
                if not equal(x[key], y[key], path + (key,)):
                    return False
            return True
        if type(x) is type(y) and x == y:
            return True
        if numeric(path) and type(x) in (int, float, str) and type(y) in (int, float, str):
            try:
                nx, ny = Decimal(str(x)), Decimal(str(y))
                return nx.is_finite() and ny.is_finite() and nx == ny
            except InvalidOperation:
                return False
        return False

    return equal(lcm_db.LuaParser(a[6]).value(), lcm_db.LuaParser(b[6]).value())


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


def onglets_contenu() -> list[str]:
    """Les onglets qui portent du contenu, lus d'un coup a chaque passage."""
    return [item["titre"] for item in feuilles().values() if item["familles"]]


def remote_rows(values: list[list[object]],
                perimees: set[str] | None = None) -> dict[str, tuple[int, list[object]]]:
    """`perimees`, si on le donne, recoit les lignes dont les colonnes
    d'affichage (Famille, Créateur) ne disent pas ce qu'elles devraient — un
    « poses » d'avant l'affichage par nature, un créateur absent : le contenu
    est le meme, seul l'affichage est a reecrire."""
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
        if perimees is not None and (
                str(raw[0]).strip() != famille_affichee(row)
                or (row[0] == "poses"
                    and str(raw[7] if len(raw) > 7 else "").strip() != createur(row))):
            perimees.add(key(row))
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


class Quota:
    """Ce que Google accorde : 60 lectures et 60 ecritures par minute et par
    compte de service — partages entre les MJ qui utilisent la meme cle.

    On compte ce qu'on a envoye dans la derniere minute, et on ATTEND avant
    le plafond plutot que de se faire refuser : un passage interrompu au
    milieu a deja publie une partie de ses entrees et pas l'autre. Le passage
    suivant le rattrape, mais c'est la que se logent les conflits (17 octobre
    2026 : cinquante-trois refus en une soiree, plus rien de publie apres
    18:10). La marge laisse de la place a l'autre MJ.
    """

    FENETRE = 60.0

    def __init__(self, limite: int = 40, horloge=time.monotonic, dormir=time.sleep):
        self.limite = limite
        self.horloge = horloge
        self.dormir = dormir
        self.envois: dict[str, list[float]] = {"lecture": [], "ecriture": []}

    def attendre(self, sorte: str) -> float:
        envois = self.envois[sorte]
        attente = 0.0
        while True:
            maintenant = self.horloge()
            while envois and maintenant - envois[0] >= self.FENETRE:
                envois.pop(0)
            if len(envois) < self.limite:
                envois.append(maintenant)
                return attente
            pause = self.FENETRE - (maintenant - envois[0]) + 0.5
            attente += pause
            self.dormir(pause)


class Sheets:
    # Un refus pour quota n'a rien ecrit : on peut toujours le retenter. Une
    # erreur du serveur, si : une ligne d'archive ajoutee deux fois rendrait
    # l'instantane impossible a restaurer. On ne retente donc que les lectures.
    ESSAIS = 6

    def __init__(self, credentials: Path, sheet_id: str, tab: str = "Jeu",
                 session=None, quota: Quota | None = None, dormir=time.sleep, journal=None):
        if session is None:
            try:
                from google.oauth2 import service_account
                from google.auth.transport.requests import AuthorizedSession
            except ImportError as exc:
                raise RuntimeError("installer d'abord : python -m pip install google-auth requests") from exc
            # Drive en lecture des seules metadonnees : de quoi savoir si le
            # classeur a change sans le lire (`version_classeur`).
            scopes = ["https://www.googleapis.com/auth/spreadsheets",
                      "https://www.googleapis.com/auth/drive.metadata.readonly"]
            auth = service_account.Credentials.from_service_account_file(str(credentials), scopes=scopes)
            session = AuthorizedSession(auth)
        self.session = session
        self.sheet_id = sheet_id
        self.base = f"https://sheets.googleapis.com/v4/spreadsheets/{sheet_id}"
        self.tab = tab
        self.quota = quota or Quota()
        self.dormir = dormir
        self.journal = journal or (lambda message: print(message, flush=True))
        # La forme du classeur ne change pas en cours de route : on la verifie
        # une fois par lancement du service, pas a chaque releve.
        self._onglets: dict[str, int] | None = None
        self._prets: set[str] = set()
        # Les onglets lus d'un coup (`precharger`). Ils restent valables tant
        # que le classeur ne change pas : `actualiser` ne les relit qu'alors.
        self._lus: dict[str, list[list[object]]] = {}
        self._version_lue: str | None = None
        self._perime = True
        self._drive_signale = False

    def select(self, tab: str) -> None:
        self.tab = tab

    def request(self, method: str, suffix: str, body: dict | None = None) -> dict:
        sorte = "lecture" if method == "GET" else "ecriture"
        for essai in range(1, self.ESSAIS + 1):
            self.quota.attendre(sorte)
            response = self.session.request(method, self.base + suffix, json=body, timeout=30)
            if response.ok:
                return response.json() if response.content else {}
            reessayable = response.status_code == 429 or (
                sorte == "lecture" and response.status_code >= 500)
            if not reessayable or essai == self.ESSAIS:
                raise RuntimeError(f"Google Sheets ({response.status_code}) : "
                                   + self._raison(response))
            pause = self._pause(response, essai)
            self.journal(f"Google Sheets ({response.status_code}) : pause de {pause:.0f} s "
                         f"avant de reprendre (essai {essai + 1}/{self.ESSAIS}) ; rien n'est perdu.")
            self.dormir(pause)
        raise AssertionError("inaccessible")

    @staticmethod
    def _raison(response) -> str:
        # Une ligne, pas cinq cents caracteres de JSON a chaque refus.
        try:
            return str(response.json()["error"]["message"])[:300]
        except (ValueError, KeyError, TypeError):
            return response.text[:300]

    @staticmethod
    def _pause(response, essai: int) -> float:
        # Le quota se compte a la minute : moins d'une minute retombe dedans.
        attendu = 0.0
        try:
            attendu = float(response.headers.get("Retry-After") or 0)
        except (TypeError, ValueError, AttributeError):
            attendu = 0.0
        return max(attendu, min(300.0, 65.0 * essai))

    def _onglet(self, titre: str) -> int | None:
        if self._onglets is None:
            meta = self.request("GET", "?fields=sheets(properties(sheetId,title))")
            self._onglets = {s["properties"]["title"]: s["properties"]["sheetId"]
                             for s in meta.get("sheets", [])}
        return self._onglets.get(titre)

    def _creer_onglet(self, titre: str, colonnes: int, lignes: int) -> int:
        result = self.request("POST", ":batchUpdate", {"requests": [
            {"addSheet": {"properties": {"title": titre, "gridProperties": {
                "rowCount": lignes, "columnCount": colonnes, "frozenRowCount": 1}}}}
        ]})
        found = result["replies"][0]["addSheet"]["properties"]["sheetId"]
        if self._onglets is not None:
            self._onglets[titre] = found
        return found

    def prepare(self) -> None:
        if ("contenu", self.tab) in self._prets:
            return
        headers = en_tetes(self.tab)
        found = self._onglet(self.tab)
        if found is None:
            found = self._creer_onglet(self.tab, len(headers), 2000)
        current = self.values()
        if not current or not any(str(value).strip() for value in current[0]):
            current = []
        elif current[0][: len(HEADERS)] != HEADERS:
            raise ValueError(f"l'onglet {self.tab} existe avec d'autres en-tetes")
        # Un onglet cree avant sa colonne en plus n'a pas la place de l'ecrire :
        # on l'elargit une fois, avant toute mise en forme qui la viserait.
        manque = len(headers) - len(current[0]) if current else 0
        if manque > 0:
            self.request("POST", ":batchUpdate", {"requests": [{"appendDimension": {
                "sheetId": found, "dimension": "COLUMNS", "length": manque}}]})
        requests = [
            {"updateSheetProperties": {"properties": {"sheetId": found,
                "gridProperties": {"frozenRowCount": 1}},
                "fields": "gridProperties.frozenRowCount"}},
            {"repeatCell": {"range": {"sheetId": found, "startRowIndex": 0,
                "endRowIndex": 1, "startColumnIndex": 0, "endColumnIndex": len(headers)},
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
            *([{"updateDimensionProperties": {"range": {"sheetId": found,
                "dimension": "COLUMNS", "startIndex": len(HEADERS), "endIndex": len(headers)},
                "properties": {"pixelSize": 160}, "fields": "pixelSize"}}]
              if len(headers) > len(HEADERS) else []),
            {"updateDimensionProperties": {"range": {"sheetId": found,
                "dimension": "ROWS", "startIndex": 1, "endIndex": 2000},
                "properties": {"pixelSize": 38}, "fields": "pixelSize"}},
            {"repeatCell": {"range": {"sheetId": found, "startRowIndex": 1,
                "startColumnIndex": 0, "endColumnIndex": len(headers)},
                "cell": {"userEnteredFormat": {"verticalAlignment": "MIDDLE",
                    "wrapStrategy": "CLIP"}},
                "fields": "userEnteredFormat.verticalAlignment,userEnteredFormat.wrapStrategy"}},
            {"setBasicFilter": {"filter": {"range": {"sheetId": found,
                "startRowIndex": 0, "endColumnIndex": len(headers)}}}},
            {"setDataValidation": {"range": {"sheetId": found,
                "startRowIndex": 1, "startColumnIndex": 4, "endColumnIndex": 5},
                "rule": {"condition": {"type": "BOOLEAN"}, "strict": True}}},
        ]
        self.request("POST", ":batchUpdate", {"requests": requests})
        if not current or current[0][: len(headers)] != headers:
            self.write(1, [headers])
        self._prets.add(("contenu", self.tab))

    def prepare_backups(self) -> None:
        if ("archives", BACKUP_TAB) in self._prets:
            return
        found = self._onglet(BACKUP_TAB)
        # La mise en forme ne part qu'a la creation : la renvoyer a chaque
        # passage, c'etait une ecriture pour rien.
        if found is None:
            found = self._creer_onglet(BACKUP_TAB, len(BACKUP_HEADERS), 1000)
            self._mettre_en_forme_archives(found)
        encoded = quote(f"'{BACKUP_TAB}'!A1:F1", safe="")
        values = self.request("GET", f"/values/{encoded}").get("values", [])
        if not values:
            self.request("PUT", f"/values/{encoded}?valueInputOption=RAW",
                         {"range": f"'{BACKUP_TAB}'!A1:F1", "values": [BACKUP_HEADERS]})
        elif values[0] != BACKUP_HEADERS:
            raise ValueError(f"l'onglet {BACKUP_TAB} existe avec d'autres en-tetes")
        self._prets.add(("archives", BACKUP_TAB))

    def _mettre_en_forme_archives(self, found: int) -> None:
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

    def precharger(self, tabs: list[str]) -> None:
        """Lit tous ces onglets en UNE requete. Un passage en lisait dix-huit,
        un par un, a chaque releve : c'est ce qui epuisait le quota."""
        tabs = [tab for tab in dict.fromkeys(tabs) if tab not in self._lus]
        if not tabs:
            return
        ranges = "&".join("ranges=" + quote(f"'{tab}'!A:H", safe="") for tab in tabs)
        try:
            result = self.request("GET", f"/values:batchGet?{ranges}&valueRenderOption=UNFORMATTED_VALUE")
        except RuntimeError as erreur:
            # Un onglet de contenu tout neuf (« Poses », 21 octobre 2026)
            # n'existe pas encore dans le classeur : la lecture groupee
            # echouait en entier, et le passage avec elle. On le cree, et on
            # relit une fois. Rien de plus dans le cas ordinaire : le quota
            # compte chaque requete.
            if "(400)" not in str(erreur) or not self._creer_manquants(tabs):
                raise
            result = self.request("GET", f"/values:batchGet?{ranges}&valueRenderOption=UNFORMATTED_VALUE")
        found = result.get("valueRanges", [])
        if len(found) != len(tabs):
            raise RuntimeError(f"lecture groupee incomplete : {len(found)} onglet(s) sur {len(tabs)}")
        for tab, item in zip(tabs, found):
            self._lus[tab] = item.get("values", [])

    def _creer_manquants(self, tabs: list[str]) -> bool:
        """Cree les onglets de contenu absents. Rend vrai s'il en a cree."""
        self._onglets = None
        crees = False
        courant = self.tab
        for tab in tabs:
            if self._onglet(tab) is None:
                self.tab = tab
                self.prepare()
                crees = True
        self.tab = courant
        return crees

    def oublier(self) -> None:
        self._lus.clear()
        self._perime = True

    def version_classeur(self) -> str | None:
        """Le numero de version du classeur, tel que Drive le tient : il
        avance a CHAQUE modification, y compris une saisie a la main dans le
        Sheet. Drive a son propre quota, bien plus large que celui des
        lectures du Sheet. None si Drive ne repond pas : on lit alors, comme
        avant — mieux vaut une lecture de trop qu'un changement manque."""
        url = (f"https://www.googleapis.com/drive/v3/files/{self.sheet_id}"
               "?fields=version&supportsAllDrives=true")
        try:
            response = self.session.request("GET", url, timeout=30)
        except Exception as error:  # reseau coupe, jeton refuse...
            raison = str(error)
        else:
            if response.ok:
                try:
                    return str(response.json().get("version") or "") or None
                except ValueError:
                    return None
            raison = f"Drive ({response.status_code}) : {self._raison(response)}"
        if not self._drive_signale:
            self._drive_signale = True
            self.journal("Version du classeur illisible, le Sheet sera relu a chaque releve : " + raison)
        return None

    def actualiser(self, tabs: list[str]) -> bool:
        """Relit ces onglets SEULEMENT si le classeur a change depuis la
        derniere lecture, ou si l'on y a ecrit soi-meme. Rend vrai s'il a lu.

        La version est prise AVANT la lecture : un changement survenu entre
        les deux fera relire au releve suivant, il ne passera pas inapercu."""
        version = self.version_classeur()
        complet = all(tab in self._lus for tab in tabs)
        if (complet and not self._perime and version is not None
                and version == self._version_lue):
            return False
        self._lus.clear()
        self.precharger(tabs)
        self._version_lue = version
        self._perime = False
        return True

    def values(self) -> list[list[object]]:
        if self.tab in self._lus:
            return self._lus[self.tab]
        region = quote(f"'{self.tab}'!A:H", safe="")
        return self.request("GET", f"/values/{region}?valueRenderOption=UNFORMATTED_VALUE").get("values", [])

    def write(self, start: int, rows: list[list[object]]) -> None:
        if not rows:
            return
        # Notre propre ecriture change le classeur : relire au prochain releve.
        self._lus.pop(self.tab, None)
        self._perime = True
        end = start + len(rows) - 1
        last = chr(64 + max(len(row) for row in rows))
        cell_range = f"'{self.tab}'!A{start}:{last}{end}"
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
        if ("vue", tab) in self._prets:
            return
        found = self._onglet(tab)
        if found is None:
            found = self._creer_onglet(tab, len(headers), 1000)
            self._mettre_en_forme_vue(found, headers)
        region = quote(f"'{tab}'!A1:{chr(64 + len(headers))}1", safe="")
        current = self.request("GET", f"/values/{region}").get("values", [])
        if not current:
            self.request("PUT", f"/values/{region}?valueInputOption=RAW",
                         {"range": f"'{tab}'!A1:{chr(64 + len(headers))}1", "values": [headers]})
        elif current[0] != headers:
            raise ValueError(f"l'onglet {tab} existe avec d'autres en-tetes")
        self._prets.add(("vue", tab))

    def _mettre_en_forme_vue(self, found: int, headers: list[str]) -> None:
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

    def replace_view(self, tab: str, headers: list[str], rows: list[list[object]]) -> None:
        self.replace_views({tab: (headers, rows)})

    def replace_views(self, vues: dict[str, tuple[list[str], list[list[object]]]]) -> None:
        """Vide et reecrit plusieurs vues en deux requetes, au lieu de deux
        par vue."""
        for tab, (headers, _) in vues.items():
            self.prepare_view(tab, headers)
        effacer, ecrire = [], []
        for tab, (headers, rows) in vues.items():
            last = chr(64 + len(headers))
            effacer.append(f"'{tab}'!A2:{last}")
            if rows:
                ecrire.append({"range": f"'{tab}'!A2:{last}{len(rows) + 1}",
                               "majorDimension": "ROWS", "values": rows})
        self.request("POST", "/values:batchClear", {"ranges": effacer})
        if ecrire:
            self.request("POST", "/values:batchUpdate",
                         {"valueInputOption": "RAW", "data": ecrire})


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


# ===== Les points poses ======================================================
# Un point pose change a chaque geste, et deux MJ peuvent en avoir chacun une
# copie (la garde, MJ/Coffres.lua). Deux versions differentes ne sont donc pas
# un conflit a trancher a la main, qui arreterait toute la synchronisation :
# la plus recente l'emporte, selon la MEME regle que l'addon — l'epoque d'abord
# (une reprise de garde), puis la version (un geste), puis le plus petit nom.
# Une suppression l'emporte toujours : un point retire ne doit pas revenir.

def rang_pose(row: list[object]) -> tuple[int, int, str]:
    lua = str(row[6] or "").strip()
    definition = lcm_db.LuaParser(lua).value() if lua else {}
    def entier(valeur: object) -> int:
        try:
            return int(float(valeur))
        except (TypeError, ValueError):
            return 0
    return (entier(definition.get("epoque")), entier(definition.get("version")),
            str(definition.get("auteur") or ""))


def pose_plus_recente(a: list[object], b: list[object]) -> bool:
    """`a` doit-elle l'emporter sur `b` ?"""
    if a[5] == DELETED or b[5] == DELETED:
        return a[5] == DELETED and b[5] != DELETED
    ea, va, na = rang_pose(a)
    eb, vb, nb = rang_pose(b)
    if ea != eb:
        return ea > eb
    if va != vb:
        return va > vb
    return na < nb


def synchronise(api: Sheets, sheet_id: str, classeur: str, families: set[str],
               prepare: bool = True, verbose: bool = True) -> None:
    if prepare:
        api.prepare()
    local = local_rows(families)
    perimees: set[str] = set()
    values = api.values()
    # Le service ne prepare pas l'onglet a chaque passage (prepare=False) : une
    # colonne en plus arrivee apres coup n'aurait jamais son en-tete. On le
    # constate ici, et on prepare une fois (21 octobre 2026).
    headers = en_tetes(api.tab) if api.tab else HEADERS
    if values and values[0][: len(headers)] != headers:
        getattr(api, "_prets", set()).discard(("contenu", api.tab))
        api.prepare()
        values = api.values()
    remote = remote_rows(values, perimees)
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
            if local_hash == remote_hash or equivalent_rows(here, there[1]):
                continue
            if old == local_hash:
                pulls.append(there[1])
            elif old == remote_hash:
                pushes.append((there[0], here))
            elif identifier.startswith("poses/"):
                if pose_plus_recente(here, there[1]):
                    pushes.append((there[0], here))
                else:
                    pulls.append(there[1])
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
    # Une ligne dont seul le nom affiche a vieilli se reecrit telle quelle :
    # son contenu ne change pas, la comparaison ne l'aurait jamais renvoyee.
    ecrites = {number for number, _ in pushes}
    for identifier in sorted(perimees):
        number, row = remote[identifier]
        if number not in ecrites:
            pushes.append((number, row))
    for number, row in pushes:
        api.write(number, [vers_sheet(row)])
    if appends:
        api.write(max([1] + [number for number, _ in remote.values()]) + 1,
                  [vers_sheet(row) for row in appends])
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


# Ce qui a deja ete envoye au Sheet, pour ne pas le renvoyer tel quel : la
# derniere archive (son manifeste) et chaque vue (une empreinte de ses lignes).
# Perdre ce fichier ne coute qu'un envoi de trop, jamais une donnee.
ECRITURES = ROOT / "Outils" / ".gsheet_ecritures.json"


def lire_ecritures() -> dict:
    try:
        data = json.loads(ECRITURES.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def noter_ecritures(data: dict) -> None:
    temporary = ECRITURES.with_suffix(".tmp")
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
                         encoding="utf-8")
    temporary.replace(ECRITURES)


def empreinte_lignes(rows: list[list[object]]) -> str:
    return hashlib.sha256(json.dumps(rows, ensure_ascii=False, default=str).encode("utf-8")).hexdigest()


def publish_state_views(api: Sheets, retail: Path, files: list[Path]) -> int:
    """Reecrit les vues qui ont change, et elles seules. Rend leur nombre."""
    vues = {tab: (STATE_HEADERS, rows) for tab, rows in current_state_rows(retail, files).items()}
    vues["Reglages"] = (REGLAGES_HEADERS,
                        [[chemin, valeur] for chemin, valeur in lcm_db.lire_reglages()])
    ecritures = lire_ecritures()
    deja = ecritures.get("vues", {})
    changees = {tab: vue for tab, vue in vues.items() if deja.get(tab) != empreinte_lignes(vue[1])}
    if not changees:
        return 0
    api.replace_views(changees)
    ecritures = lire_ecritures()
    ecritures.setdefault("vues", {}).update(
        {tab: empreinte_lignes(vue[1]) for tab, vue in changees.items()})
    noter_ecritures(ecritures)
    return len(changees)


def sauvegarder(api: Sheets, retail: Path) -> None:
    """Archive les SavedVariables : en local D'ABORD, puis dans le Sheet.

    Une archive identique a la precedente ne part pas : ni nouveau zip, ni
    fragments dans le Sheet. Un envoi interrompu (quota, reseau) n'est pas
    note comme fait : le passage suivant renvoie l'archive entiere, sous un
    nouvel instantane — jamais un instantane a moitie complete.
    """
    files = saved_files(retail)
    if not files:
        raise FileNotFoundError("aucune SavedVariables LCM trouvee")
    contenus = [(file.relative_to(retail).as_posix(), file.read_bytes()) for file in files]
    manifest = {relative: hashlib.sha256(raw).hexdigest() for relative, raw in contenus}
    manifest_raw = json.dumps(manifest, ensure_ascii=False, sort_keys=True).encode("utf-8")
    signature_archive = hashlib.sha256(manifest_raw).hexdigest()
    ecritures = lire_ecritures()

    stamp = datetime.now().astimezone().strftime("%Y%m%d_%H%M%S_%z")
    if ecritures.get("archive_locale") != signature_archive:
        destination = ROOT / "Sauvegardes_LCM" / f"LCM_{stamp}.zip"
        # Deux archives dans la meme seconde : la seconde ECRASAIT la premiere.
        rang = 1
        while destination.exists():
            rang += 1
            destination = ROOT / "Sauvegardes_LCM" / f"LCM_{stamp}_{rang}.zip"
        destination.parent.mkdir(parents=True, exist_ok=True)
        with ZipFile(destination, "x", compression=ZIP_DEFLATED) as archive:
            for relative, raw in contenus:
                archive.writestr(relative, raw)
        ecritures["archive_locale"] = signature_archive
        noter_ecritures(ecritures)
        print(f"{len(files)} fichiers sauvegardes : {destination}")

    if ecritures.get("archive") != signature_archive:
        rows: list[list[object]] = [[stamp, "__MANIFEST__", signature_archive, 1, 1,
                                     base64.b64encode(gzip.compress(manifest_raw, mtime=0)).decode("ascii")]]
        for relative, raw in contenus:
            encoded = base64.b64encode(gzip.compress(raw, mtime=0)).decode("ascii")
            chunks = [encoded[i:i + 30000] for i in range(0, len(encoded), 30000)]
            for index, chunk in enumerate(chunks, 1):
                rows.append([stamp, relative, manifest[relative], index, len(chunks), chunk])
        api.prepare_backups()
        for index in range(0, len(rows), 100):
            api.append_backup(rows[index:index + 100])
        ecritures = lire_ecritures()
        ecritures["archive"] = signature_archive
        noter_ecritures(ecritures)
        print(f"{len(rows)} fragments d'archive dans le Sheet.")
    publish_state_views(api, retail, files)


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
