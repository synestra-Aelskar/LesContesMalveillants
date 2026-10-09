"""Base de contenu commune des Contes Malveillants.

La source de verite est ``database/entries`` : une definition Lua par entree.
Les fichiers ``Atelier.lua`` des addons ne sont que des artefacts reconstruits.

Commandes principales :

    lcm-db.cmd import     # importe cumulativement les brouillons du WTF
    lcm-db.cmd build      # reconstruit les deux fichiers distribuables
    lcm-db.cmd sync       # import + build
    lcm-db.cmd status

Le parseur inclus ne depend d'aucun module externe. Il lit le sous-ensemble Lua
utilise par les SavedVariables de WoW : tables, chaines, nombres et booleens.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import defaultdict
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[1]
DATABASE = PROJECT / "database"
ENTRIES = DATABASE / "entries"
TOMBSTONES = DATABASE / "tombstones"


def addons_directory() -> Path:
    """Trouve l'installation WoW, sans lier la base a une seule machine."""
    configured = os.environ.get("LCM_ADDONS", "").strip()
    if configured:
        return Path(configured).expanduser().resolve()
    if (PROJECT / "LesContesMalveillants").is_dir():
        return PROJECT
    return PROJECT.parent


ADDONS = addons_directory()
PLAYER_OUTPUT = ADDONS / "LesContesMalveillants" / "Data" / "Genere" / "Atelier.lua"
MJ_OUTPUT = ADDONS / "LesContesMalveillants_MJ" / "Genere" / "Atelier_MJ.lua"

FAMILIES = {
    "objets": "Objets",
    "traits": "Traits",
    "races": "Races",
    "etats": "Etats",
    "apprentissages": "Apprentissages",
    "sacs": "Sacs",
    "ressources": "Ressources",
    "devises": "Devises",
    "informations": "Informations",
    "listes": "Listes",
    "connaissances": "Connaissances",
    "resolutions": "Resolutions",
    "calculateurs": "Calculateurs",
    "pnj": "PNJ",
    "jeux": "Forge",
    "points": "Points",
}
REGISTRY_TO_FAMILY = {registry: family for family, registry in FAMILIES.items()}
RESERVED_MJ = {"pnj", "jeux", "points"}
SAFE_ID = re.compile(r"^[A-Za-z0-9_.-]+$")


class LuaError(ValueError):
    pass


class LuaParser:
    """Petit lecteur de valeurs Lua, suffisant pour les SavedVariables."""

    def __init__(self, source: str, position: int = 0):
        self.source = source
        self.position = position

    def error(self, message: str) -> LuaError:
        line = self.source.count("\n", 0, self.position) + 1
        return LuaError(f"{message} (ligne {line})")

    def skip(self) -> None:
        while self.position < len(self.source):
            if self.source[self.position].isspace():
                self.position += 1
                continue
            if self.source.startswith("--", self.position):
                end = self.source.find("\n", self.position + 2)
                self.position = len(self.source) if end < 0 else end + 1
                continue
            break

    def peek(self, token: str) -> bool:
        self.skip()
        return self.source.startswith(token, self.position)

    def take(self, token: str) -> None:
        self.skip()
        if not self.source.startswith(token, self.position):
            raise self.error(f"« {token} » attendu")
        self.position += len(token)

    def identifier(self) -> str:
        self.skip()
        match = re.match(r"[A-Za-z_][A-Za-z0-9_]*", self.source[self.position :])
        if not match:
            raise self.error("identifiant attendu")
        self.position += len(match.group(0))
        return match.group(0)

    def string(self) -> str:
        self.skip()
        quote = self.source[self.position]
        if quote not in "\"'":
            raise self.error("chaine attendue")
        self.position += 1
        out: list[str] = []
        escapes = {"a": "\a", "b": "\b", "f": "\f", "n": "\n", "r": "\r", "t": "\t", "v": "\v"}
        while self.position < len(self.source):
            char = self.source[self.position]
            self.position += 1
            if char == quote:
                return "".join(out)
            if char != "\\":
                out.append(char)
                continue
            if self.position >= len(self.source):
                raise self.error("echappement incomplet")
            escaped = self.source[self.position]
            self.position += 1
            if escaped in escapes:
                out.append(escapes[escaped])
            elif escaped in "\\\"'":
                out.append(escaped)
            elif escaped == "z":
                while self.position < len(self.source) and self.source[self.position].isspace():
                    self.position += 1
            elif escaped.isdigit():
                digits = escaped
                while len(digits) < 3 and self.position < len(self.source) and self.source[self.position].isdigit():
                    digits += self.source[self.position]
                    self.position += 1
                out.append(chr(int(digits, 10)))
            elif escaped == "\n":
                out.append("\n")
            else:
                out.append(escaped)
        raise self.error("chaine non terminee")

    def number(self):
        self.skip()
        match = re.match(
            r"[-+]?(?:0[xX][0-9A-Fa-f]+|(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)",
            self.source[self.position :],
        )
        if not match:
            raise self.error("nombre attendu")
        raw = match.group(0)
        self.position += len(raw)
        if re.match(r"[-+]?0[xX]", raw):
            sign = -1 if raw.startswith("-") else 1
            return sign * int(raw.lstrip("+-"), 16)
        value = float(raw) if any(c in raw for c in ".eE") else int(raw)
        return int(value) if isinstance(value, float) and value.is_integer() else value

    def value(self):
        self.skip()
        if self.position >= len(self.source):
            raise self.error("valeur attendue")
        char = self.source[self.position]
        if char == "{":
            return self.table()
        if char in "\"'":
            return self.string()
        if char.isdigit() or char in "+-.":
            return self.number()
        word = self.identifier()
        if word == "true":
            return True
        if word == "false":
            return False
        if word == "nil":
            return None
        raise self.error(f"valeur Lua inconnue : {word}")

    def table(self) -> dict:
        self.take("{")
        result: dict = {}
        array_index = 1
        while True:
            self.skip()
            if self.peek("}"):
                self.take("}")
                return result

            if self.peek("["):
                self.take("[")
                key = self.value()
                self.take("]")
                self.take("=")
                value = self.value()
            else:
                saved = self.position
                try:
                    key_candidate = self.identifier()
                    if self.peek("="):
                        self.take("=")
                        key, value = key_candidate, self.value()
                    else:
                        self.position = saved
                        key, value = array_index, self.value()
                        array_index += 1
                except LuaError:
                    self.position = saved
                    key, value = array_index, self.value()
                    array_index += 1
            if value is not None:
                result[key] = value
            self.skip()
            if self.peek(","):
                self.take(",")
            elif self.peek(";"):
                self.take(";")
            elif not self.peek("}"):
                raise self.error("virgule ou fin de table attendue")


def parse_assignments(source: str) -> dict:
    parser = LuaParser(source)
    values = {}
    while True:
        parser.skip()
        if parser.position >= len(source):
            return values
        name = parser.identifier()
        parser.take("=")
        values[name] = parser.value()


def parse_return_table(source: str) -> dict:
    match = re.search(r"\breturn\b", source)
    if not match:
        raise LuaError("fichier d'entree sans return")
    value = LuaParser(source, match.end()).value()
    if not isinstance(value, dict):
        raise LuaError("l'entree ne retourne pas une table")
    return value


def lua_string(value: str) -> str:
    replacements = {
        "\\": "\\\\",
        '"': '\\"',
        "\r": "\\r",
        "\n": "\\n",
        "\t": "\\t",
    }
    return '"' + "".join(replacements.get(c, c) for c in value) + '"'


def lua_value(value, indent: int = 0) -> str:
    margin = "    " * indent
    if value is None:
        return "nil"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, (int, float)):
        return str(int(value)) if isinstance(value, float) and value.is_integer() else str(value)
    if isinstance(value, str):
        return lua_string(value)
    if not isinstance(value, dict):
        raise TypeError(f"valeur impossible a serialiser : {type(value).__name__}")

    integer_keys = sorted(k for k in value if isinstance(k, int))
    string_keys = sorted(k for k in value if isinstance(k, str))
    sequential = not string_keys and integer_keys == list(range(1, len(integer_keys) + 1))
    if sequential and all(not isinstance(value[k], dict) for k in integer_keys):
        return "{ " + ", ".join(lua_value(value[k], indent + 1) for k in integer_keys) + " }"

    lines = []
    if sequential:
        for key in integer_keys:
            lines.append("    " * (indent + 1) + lua_value(value[key], indent + 1) + ",")
    else:
        for key in integer_keys:
            lines.append(
                "    " * (indent + 1) + f"[{key}] = " + lua_value(value[key], indent + 1) + ","
            )
        for key in string_keys:
            rendered_key = key if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", key) else f"[{lua_string(key)}]"
            lines.append(
                "    " * (indent + 1) + rendered_key + " = " + lua_value(value[key], indent + 1) + ","
            )
    if not lines:
        return "{}"
    return "{\n" + "\n".join(lines) + "\n" + margin + "}"


def side_for(family: str, definition: dict) -> str:
    if family in RESERVED_MJ:
        return "mj"
    if family == "resolutions" and str(definition.get("categorie", "")) == "mj":
        return "mj"
    return "player"


def safe_id(identifier) -> str:
    identifier = str(identifier or "")
    if not SAFE_ID.match(identifier):
        raise ValueError(f"identifiant de contenu non sur : {identifier!r}")
    return identifier


def metadata(family: str, registry: str, side: str, identifier: str) -> str:
    data = {"family": family, "id": identifier, "registry": registry, "side": side}
    return "-- lcm-db: " + json.dumps(data, ensure_ascii=False, sort_keys=True) + "\n"


def entry_path(family: str, side: str, identifier: str) -> Path:
    return ENTRIES / side / family / f"{safe_id(identifier)}.lua"


def tombstone_path(family: str, identifier: str) -> Path:
    return TOMBSTONES / family / f"{safe_id(identifier)}.delete"


def write_entry(family: str, definition: dict, raw_table: str | None = None) -> Path:
    if family not in FAMILIES:
        raise ValueError(f"famille inconnue : {family}")
    identifier = safe_id(definition.get("id"))
    registry = FAMILIES[family]
    side = side_for(family, definition)
    path = entry_path(family, side, identifier)
    path.parent.mkdir(parents=True, exist_ok=True)
    table = raw_table.strip() if raw_table else lua_value(definition)
    text = metadata(family, registry, side, identifier) + "return " + table + "\n"
    path.write_text(text, encoding="utf-8", newline="\n")
    return path


CALLS = re.compile(
    r"^LCM\.(?P<registry>\w+)\.Add\((?P<table>\{[\s\S]*?^\})\)\s*$"
    r"|^LCM\.Publier\(LCM\.(?P<pregistry>\w+),\s*(?P<ptable>\{[\s\S]*?^\})\)\s*$",
    re.MULTILINE,
)


def seed_file(path: Path, force: bool) -> tuple[int, int]:
    source = path.read_text(encoding="utf-8")
    written = skipped = 0
    for match in CALLS.finditer(source):
        registry = match.group("registry") or match.group("pregistry")
        table_source = match.group("table") or match.group("ptable")
        family = REGISTRY_TO_FAMILY.get(registry)
        if not family:
            raise ValueError(f"registre inconnu dans {path}: {registry}")
        definition = LuaParser(table_source).value()
        identifier = safe_id(definition.get("id"))
        destination = entry_path(family, side_for(family, definition), identifier)
        if destination.exists() and not force:
            skipped += 1
            continue
        write_entry(family, definition, table_source)
        written += 1
    return written, skipped


def newest_saved_variables() -> Path:
    configured = os.environ.get("LCM_RETAIL", "").strip()
    if configured:
        retail = Path(configured).expanduser().resolve()
    elif ADDONS.name.lower() == "addons" and ADDONS.parent.name.lower() == "interface":
        retail = ADDONS.parent.parent
    else:
        raise FileNotFoundError(
            "installation WoW introuvable : configure LCM_ADDONS vers Interface/AddOns"
        )
    candidates = list((retail / "WTF" / "Account").glob("*/SavedVariables/LesContesMalveillants_MJ.lua"))
    if not candidates:
        raise FileNotFoundError("SavedVariables LesContesMalveillants_MJ.lua introuvable")
    return max(candidates, key=lambda p: p.stat().st_mtime)


def import_drafts(saved: Path, apply_deletions: bool = False) -> tuple[int, int, int]:
    root = parse_assignments(saved.read_text(encoding="utf-8")).get("LCM_MJ_DB", {})
    drafts = root.get("brouillons", {}) if isinstance(root, dict) else {}
    imported = unchanged = deleted = 0
    for family, definitions in drafts.items():
        if family not in FAMILIES or not isinstance(definitions, dict):
            continue
        for _, definition in definitions.items():
            if not isinstance(definition, dict):
                continue
            identifier = safe_id(definition.get("id"))
            side = side_for(family, definition)
            destination = entry_path(family, side, identifier)
            new_text = metadata(family, FAMILIES[family], side, identifier) + "return " + lua_value(definition) + "\n"
            if destination.exists() and destination.read_text(encoding="utf-8") == new_text:
                unchanged += 1
            else:
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_text(new_text, encoding="utf-8", newline="\n")
                imported += 1
            tombstone = tombstone_path(family, identifier)
            if tombstone.exists():
                tombstone.unlink()

    if apply_deletions:
        masks = root.get("masques", {}) if isinstance(root, dict) else {}
        for family, identifiers in masks.items():
            if family not in FAMILIES or not isinstance(identifiers, dict):
                continue
            for identifier, active in identifiers.items():
                if not active:
                    continue
                identifier = safe_id(identifier)
                marker = tombstone_path(family, identifier)
                marker.parent.mkdir(parents=True, exist_ok=True)
                marker.write_text(f"{family}/{identifier}\n", encoding="utf-8", newline="\n")
                deleted += 1
    return imported, unchanged, deleted


def read_entry(path: Path) -> tuple[dict, dict, str]:
    source = path.read_text(encoding="utf-8")
    first, _, rest = source.partition("\n")
    if not first.startswith("-- lcm-db: "):
        raise ValueError(f"metadonnees absentes : {path}")
    meta = json.loads(first[len("-- lcm-db: ") :])
    definition = parse_return_table(rest)
    if str(definition.get("id", "")) != str(meta.get("id", "")):
        raise ValueError(f"id du fichier different de son contenu : {path}")
    return meta, definition, rest[rest.find("return") + len("return") :].strip()


HEADER = """-- ============================================================================
--  FICHIER GENERE — NE PAS MODIFIER A LA MAIN
-- ============================================================================
--  Construit depuis la base commune `necronicon/database/entries`.
--  Une archive d'addon est un livrable ; elle n'est jamais la source de verite.
-- ============================================================================

{prefix}

"""


def build() -> dict[str, int]:
    grouped: dict[str, dict[str, list[tuple[str, str, str]]]] = {
        "player": defaultdict(list),
        "mj": defaultdict(list),
    }
    seen = set()
    for path in sorted(ENTRIES.glob("*/*/*.lua")):
        meta, definition, table_source = read_entry(path)
        family = str(meta["family"])
        identifier = str(meta["id"])
        registry = str(meta["registry"])
        side = str(meta["side"])
        if family not in FAMILIES or FAMILIES[family] != registry or side not in grouped:
            raise ValueError(f"metadonnees invalides : {path}")
        key = family, identifier
        if key in seen:
            raise ValueError(f"entree en double : {family}/{identifier}")
        seen.add(key)
        if tombstone_path(family, identifier).exists():
            continue
        expected_side = side_for(family, definition)
        if side != expected_side:
            raise ValueError(f"mauvais cote pour {family}/{identifier}: {side}, attendu {expected_side}")
        grouped[side][family].append((identifier, registry, table_source))

    counts = {}
    targets = {
        "player": (PLAYER_OUTPUT, "local _, LCM = ..."),
        "mj": (MJ_OUTPUT, "local LCM = _G.LCM\nif not LCM then return end"),
    }
    for side, (target, prefix) in targets.items():
        chunks = [HEADER.format(prefix=prefix)]
        total = 0
        for family in sorted(grouped[side]):
            entries = sorted(grouped[side][family], key=lambda item: item[0])
            chunks.append(f"-- ----- {family} ({len(entries)}) " + "-" * max(0, 56 - len(family)) + "\n")
            for _, registry, table_source in entries:
                chunks.append(f"LCM.Publier(LCM.{registry}, {table_source})\n\n")
            total += len(entries)
        if total == 0:
            chunks.append("-- Aucune entree.\n")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("".join(chunks).rstrip() + "\n", encoding="utf-8", newline="\n")
        counts[side] = total
    return counts


def status() -> tuple[dict[str, int], int]:
    counts = defaultdict(int)
    for path in ENTRIES.glob("*/*/*.lua"):
        meta, _, _ = read_entry(path)
        counts[str(meta["family"])] += 1
    tombstones = sum(1 for _ in TOMBSTONES.glob("*/*.delete"))
    return dict(sorted(counts.items())), tombstones


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Base commune des Contes Malveillants")
    sub = parser.add_subparsers(dest="command", required=True)
    seed = sub.add_parser("seed", help="migre les Atelier.lua actuels vers la base source")
    seed.add_argument("--force", action="store_true", help="remplace les fichiers source existants")
    imp = sub.add_parser("import", help="importe cumulativement les brouillons du WTF")
    imp.add_argument("--saved", type=Path, help="SavedVariables a lire")
    imp.add_argument("--apply-deletions", action="store_true", help="transforme les masques en suppressions partagees")
    sync = sub.add_parser("sync", help="importe les brouillons puis reconstruit les addons")
    sync.add_argument("--saved", type=Path, help="SavedVariables a lire")
    sync.add_argument("--apply-deletions", action="store_true")
    sub.add_parser("build", help="reconstruit les fichiers distribuables")
    sub.add_parser("status", help="compte les entrees de la base commune")
    delete = sub.add_parser("delete", help="enregistre explicitement une suppression partagee")
    delete.add_argument("family", choices=sorted(FAMILIES))
    delete.add_argument("id")
    restore = sub.add_parser("restore", help="annule une suppression partagee")
    restore.add_argument("family", choices=sorted(FAMILIES))
    restore.add_argument("id")
    args = parser.parse_args(argv)

    try:
        if args.command == "seed":
            player = seed_file(PLAYER_OUTPUT, args.force)
            mj = seed_file(MJ_OUTPUT, args.force)
            print(f"Migration initiale : {player[0] + mj[0]} ecrite(s), {player[1] + mj[1]} conservee(s).")
        elif args.command in {"import", "sync"}:
            saved = args.saved or newest_saved_variables()
            imported, unchanged, deleted = import_drafts(saved, args.apply_deletions)
            print(f"Brouillons : {imported} importe(s), {unchanged} inchange(s), {deleted} suppression(s).")
            print(f"Source : {saved}")
            if args.command == "sync":
                counts = build()
                print(f"Addons reconstruits : {counts['player']} joueur, {counts['mj']} MJ.")
        elif args.command == "build":
            counts = build()
            print(f"Addons reconstruits : {counts['player']} joueur, {counts['mj']} MJ.")
        elif args.command == "status":
            counts, deleted = status()
            for family, count in counts.items():
                print(f"{family:18} {count}")
            print(f"{'suppressions':18} {deleted}")
        elif args.command == "delete":
            identifier = safe_id(args.id)
            marker = tombstone_path(args.family, identifier)
            marker.parent.mkdir(parents=True, exist_ok=True)
            marker.write_text(f"{args.family}/{identifier}\n", encoding="utf-8", newline="\n")
            print(f"Suppression partagee enregistree : {args.family}/{identifier}")
            print("Lance `lcm-db.cmd build` pour actualiser les addons.")
        elif args.command == "restore":
            marker = tombstone_path(args.family, safe_id(args.id))
            if marker.exists():
                marker.unlink()
                print(f"Suppression annulee : {args.family}/{args.id}")
            else:
                print(f"Aucune suppression pour {args.family}/{args.id}")
        return 0
    except Exception as error:
        print(f"ERREUR : {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
