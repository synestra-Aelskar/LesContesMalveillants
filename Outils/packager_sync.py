"""Copie le surveillant et sa base dans le dossier de l'addon MJ.

Le dossier Sync est distribue avec LesContesMalveillants_MJ seulement. La cle
Google, les etats locaux et les sauvegardes WoW n'y sont jamais copies.
"""

from pathlib import Path
from shutil import copy2, copytree


ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "LesContesMalveillants_MJ" / "Sync"


def main() -> None:
    if TARGET.exists():
        raise SystemExit(f"{TARGET} existe deja ; son etat local est preserve.")
    (TARGET / "Outils").mkdir(parents=True)
    (TARGET / "database").mkdir()
    for name in ("gsheet_auto.py", "gsheet_base.py", "feuilles_lcm.json",
                 "installer_sync.ps1"):
        copy2(ROOT / "Outils" / name, TARGET / "Outils" / name)
    copy2(ROOT / "database" / "lcm_db.py", TARGET / "database" / "lcm_db.py")
    for name in ("entries", "reglages", "tombstones"):
        source = ROOT / "database" / name
        if source.is_dir():
            copytree(source, TARGET / "database" / name,
                     ignore=lambda _, names: {n for n in names
                                               if n.startswith(".") or n == "__pycache__"})
    print(f"Programme MJ pret dans {TARGET}")


if __name__ == "__main__":
    main()
