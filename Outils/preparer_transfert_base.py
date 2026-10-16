"""Construit le paquet portable de la base LCM depuis database/entries."""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "database"))
import lcm_db  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "Transfert_Base_LCM"
CONTENT = PACKAGE / "Contenu"


def main() -> None:
    if PACKAGE.exists():
        shutil.rmtree(PACKAGE)
    CONTENT.mkdir(parents=True)

    entries = []
    for path in sorted((ROOT / "database" / "entries").glob("*/*/*.lua")):
        meta, definition, table = lcm_db.read_entry(path)
        family = meta["family"]
        identifier = meta["id"]
        if lcm_db.tombstone_path(family, identifier).exists():
            continue
        entries.append((family, identifier, table))

    lines = [
        "-- Import LCM : contenu partage, sans donnees de personnage.\n",
        "LCM_MJ_DB = type(LCM_MJ_DB) == 'table' and LCM_MJ_DB or {}\n",
        "LCM_MJ_DB.brouillons = type(LCM_MJ_DB.brouillons) == 'table' and LCM_MJ_DB.brouillons or {}\n",
        "LCM_MJ_DB.masques = type(LCM_MJ_DB.masques) == 'table' and LCM_MJ_DB.masques or {}\n",
    ]
    for family, identifier, table in entries:
        family_lua = lcm_db.lua_string(family)
        id_lua = lcm_db.lua_string(identifier)
        lines.extend(
            [
                f"LCM_MJ_DB.brouillons[{family_lua}] = type(LCM_MJ_DB.brouillons[{family_lua}]) == 'table' and LCM_MJ_DB.brouillons[{family_lua}] or {{}}\n",
                f"LCM_MJ_DB.brouillons[{family_lua}][{id_lua}] = {table}\n",
                f"if type(LCM_MJ_DB.masques[{family_lua}]) == 'table' then LCM_MJ_DB.masques[{family_lua}][{id_lua}] = nil end\n",
            ]
        )
    (PACKAGE / "Import_Brouillons.lua").write_text("".join(lines), encoding="utf-8", newline="\n")

    for addon, subfolder in (
        ("LesContesMalveillants", Path("Data") / "Genere"),
        ("LesContesMalveillants_MJ", Path("Genere")),
    ):
        source = ROOT / addon / subfolder
        target = CONTENT / addon / subfolder
        target.mkdir(parents=True)
        for file in source.glob("*.lua"):
            shutil.copy2(file, target / file.name)

    shutil.copytree(ROOT / "database" / "entries", PACKAGE / "Source" / "entries")
    if (ROOT / "database" / "reglages").exists():
        shutil.copytree(ROOT / "database" / "reglages", PACKAGE / "Source" / "reglages")
    if (ROOT / "database" / "tombstones").exists():
        shutil.copytree(ROOT / "database" / "tombstones", PACKAGE / "Source" / "tombstones")
    for name in ("Installer la base.bat", "Installer la base.ps1", "LISEZ-MOI.txt"):
        shutil.copy2(ROOT / "Outils" / "transfert_base" / name, PACKAGE / name)
    (PACKAGE / "Manifest.json").write_text(
        json.dumps({"definitions": len(entries), "familles": {f: sum(1 for e in entries if e[0] == f) for f in sorted({e[0] for e in entries})}}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Paquet cree : {PACKAGE} ({len(entries)} definitions)")


if __name__ == "__main__":
    main()
