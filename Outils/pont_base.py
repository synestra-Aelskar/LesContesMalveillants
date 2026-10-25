"""Pont de la base Google Sheets vers la base du depot.

Deux bases de contenu vivent sur la machine d'un maitre du jeu :

* celle du **depot**, ``.publication/database``, que ``publier.ps1`` reconstruit
  et que les joueurs recoivent a l'installation ;
* celle du **veilleur Sheets**,
  ``AddOns/LesContesMalveillants_MJ/Sync/database``, que la tache planifiee
  remplit depuis le classeur partage entre les deux maitres du jeu.

Le veilleur importe les brouillons des SavedVariables **puis les vide**. Quand
``base.ps1 -Mode envoyer`` passe derriere, il ne trouve plus rien a importer et
conclut que la base du depot est a jour : le contenu de seance part donc dans le
classeur et n'entre jamais dans le depot. Ce script est le chainon manquant. Il
va dans un seul sens, du classeur vers le depot, et n'ecrit **jamais** dans le
classeur : la synchro a deux sens est le travail de ``gsheet_base.py sync``.

    pont_base.py              # apercu : ne touche a rien
    pont_base.py --appliquer  # recopie dans la base du depot

Ce qui n'existe que dans le depot est **signale, jamais supprime** : une entree
qui disparaitrait sans laisser de trace serait une perte silencieuse, et seule
une pierre tombale posee dans le classeur dit une suppression voulue.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[1]
CLONE = PROJECT / ".publication"
BASE_DEPOT = CLONE / "database"
MARQUE = "-- lcm-db:"


def dossier_addons(demande: str | None) -> Path:
    """Trouve le dossier AddOns sans lier le script a une seule machine."""
    if demande:
        return Path(demande).expanduser().resolve()
    configure = os.environ.get("LCM_ADDONS", "").strip()
    if configure:
        return Path(configure).expanduser().resolve()
    # `lcm.config.ps1` reste local : il porte les chemins de la machine. C'est
    # la seule source fiable quand le script est lance a la main.
    config = Path(__file__).resolve().parent / "lcm.config.ps1"
    if config.is_file():
        trouve = re.search(
            r"^\s*\$Global:LcmAddOns\s*=\s*'([^']+)'",
            config.read_text(encoding="utf-8-sig"),
            re.MULTILINE,
        )
        if trouve:
            return Path(trouve.group(1)).resolve()
    raise SystemExit("dossier AddOns introuvable : passe --addons ou renseigne LCM_ADDONS.")


def lire_tete(chemin: Path) -> dict[str, str]:
    """Lit les metadonnees de la premiere ligne d'une entree."""
    premiere = chemin.read_text(encoding="utf-8").split("\n", 1)[0].strip()
    if not premiere.startswith(MARQUE):
        raise ValueError(f"entree sans en-tete lcm-db : {chemin}")
    return json.loads(premiere[len(MARQUE):])


def lire_entrees(base: Path) -> dict[tuple[str, str], Path]:
    entrees: dict[tuple[str, str], Path] = {}
    for chemin in sorted((base / "entries").glob("*/*/*.lua")):
        tete = lire_tete(chemin)
        cle = (str(tete["family"]), str(tete["id"]))
        if cle in entrees:
            raise ValueError(f"entree en double : {cle[0]}/{cle[1]}")
        entrees[cle] = chemin
    return entrees


def lire_pierres(base: Path) -> dict[tuple[str, str], Path]:
    pierres: dict[tuple[str, str], Path] = {}
    for chemin in sorted((base / "tombstones").glob("*/*.delete")):
        pierres[(chemin.parent.name, chemin.stem)] = chemin
    return pierres


# Ce qui ne fait pas une modification : l'arbitrage de seance.
#
# `epoque` monte a chaque reprise de garde d'un objet pose et `version` a
# chaque geste ; ensemble, elles tranchent entre deux copies chez deux maitres
# du jeu (MJ/Coffres.lua). Elles montent donc toutes seules pendant qu'on joue,
# et les 42 poses de la campagne revenaient « modifiees » a chaque passage du
# pont sans qu'un mot de leur contenu ait change (constate le 25 octobre 2026 :
# epoque 29 -> 35, et rien d'autre). Un pont qui annonce quarante-deux
# ecritures pour rien finit par ne plus se lire.
#
# La description vide ne compte que pour les POSES, ou le classeur l'ajoute par
# defaut a des entrees qui n'en ont pas. Ailleurs, vider une description est un
# geste, et il doit se voir.
ARBITRAGE = re.compile(r'^[ \t]*(?:epoque|version)[ \t]*=[ \t]*\d+,?[ \t]*\r?\n', re.MULTILINE)
DESCRIPTION_VIDE = re.compile(r'^[ \t]*description[ \t]*=[ \t]*""[ \t]*,?[ \t]*\r?\n', re.MULTILINE)


def sans_arbitrage(chemin: Path, famille: str) -> str:
    texte = ARBITRAGE.sub("", chemin.read_text(encoding="utf-8"))
    if famille == "poses":
        texte = DESCRIPTION_VIDE.sub("", texte)
    return texte


def etiquette(base: Path, cle: tuple[str, str], entrees: dict[tuple[str, str], Path]) -> str:
    """Le nom lisible d'une entree, pour que l'apercu se lise sans les ids."""
    chemin = entrees.get(cle)
    if chemin is None:
        return f"{cle[0]}/{cle[1]}"
    trouve = re.search(r'^\s*label\s*=\s*"((?:[^"\\]|\\.)*)"', chemin.read_text(encoding="utf-8"), re.MULTILINE)
    nom = trouve.group(1).replace('\\"', '"') if trouve else cle[1]
    return f"{cle[0]} / {nom}"


def comparer(depot: Path, sheets: Path) -> dict[str, list]:
    entreesDepot = lire_entrees(depot)
    entreesSheets = lire_entrees(sheets)
    pierresDepot = lire_pierres(depot)
    pierresSheets = lire_pierres(sheets)

    plan: dict[str, list] = {
        "ajouts": [],
        "modifies": [],
        "deplaces": [],
        "suppressions": [],
        "orphelins": [],
        "arbitrage": [],
    }

    for cle, source in entreesSheets.items():
        cible = entreesDepot.get(cle)
        if cible is None:
            plan["ajouts"].append((cle, source))
        elif cible.parent.parent.name != source.parent.parent.name:
            # L'entree a change de cote (joueur <-> MJ). La laisser aux deux
            # endroits ferait echouer la reconstruction sur une entree en double.
            plan["deplaces"].append((cle, source, cible))
        elif cible.read_bytes() != source.read_bytes():
            if sans_arbitrage(cible, cle[0]) == sans_arbitrage(source, cle[0]):
                plan["arbitrage"].append((cle, source))
            else:
                plan["modifies"].append((cle, source))

    for cle, source in pierresSheets.items():
        if cle not in pierresDepot:
            plan["suppressions"].append((cle, source, cle in entreesDepot))

    for cle in entreesDepot:
        if cle not in entreesSheets:
            plan["orphelins"].append((cle, entreesDepot[cle]))

    return plan


def copier(source: Path, depuis: Path, vers: Path) -> Path:
    cible = vers / source.relative_to(depuis)
    cible.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, cible)
    return cible


def copier_pierre(source: Path, depuis: Path, vers: Path) -> Path:
    """Recopie une pierre tombale en fins de ligne LF.

    Le veilleur les ecrit en CRLF ; le depot les declare `eol=lf`. Un octet-a-
    octet laisserait Git les reecrire a la premiere occasion, et chaque passage
    du pont salirait la copie de travail pour rien.
    """
    cible = vers / source.relative_to(depuis)
    cible.parent.mkdir(parents=True, exist_ok=True)
    cible.write_text(source.read_text(encoding="utf-8").replace("\r\n", "\n"), encoding="utf-8", newline="\n")
    return cible


def appliquer(plan: dict[str, list], depot: Path, sheets: Path) -> None:
    for _, source in plan["ajouts"] + plan["modifies"]:
        copier(source, sheets / "entries", depot / "entries")
    for _, source, ancienne in plan["deplaces"]:
        copier(source, sheets / "entries", depot / "entries")
        ancienne.unlink()
    for _, source, _ in plan["suppressions"]:
        copier_pierre(source, sheets / "tombstones", depot / "tombstones")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Reporte la base Sheets dans la base du depot")
    parser.add_argument("--appliquer", action="store_true", help="ecrit dans la base du depot (sinon : apercu)")
    parser.add_argument("--addons", help="dossier Interface/AddOns")
    parser.add_argument("--details", action="store_true", help="nomme chaque entree concernee")
    args = parser.parse_args(argv)

    if not BASE_DEPOT.is_dir():
        raise SystemExit(f"base du depot introuvable : {BASE_DEPOT}")
    sheets = dossier_addons(args.addons) / "LesContesMalveillants_MJ" / "Sync" / "database"
    if not sheets.is_dir():
        raise SystemExit(f"base du veilleur Sheets introuvable : {sheets}")

    plan = comparer(BASE_DEPOT, sheets)
    entreesSheets = lire_entrees(sheets)
    entreesDepot = lire_entrees(BASE_DEPOT)

    print(f"Base du depot  : {BASE_DEPOT}")
    print(f"Base du Sheets : {sheets}")
    print()
    print(f"{'ajouts':14} {len(plan['ajouts'])}")
    print(f"{'modifies':14} {len(plan['modifies'])}")
    print(f"{'changent de cote':14} {len(plan['deplaces'])}")
    print(f"{'suppressions':14} {len(plan['suppressions'])}")
    print(f"{'orphelins':14} {len(plan['orphelins'])}")
    if plan["arbitrage"]:
        print(f"{'arbitrage seul':14} {len(plan['arbitrage'])}  (epoque/version montee en seance : rien a reporter)")

    # Une pierre tombale qui vise une entree encore presente dans le depot
    # RETIRE du contenu publie. C'est le seul effet du pont qui fait maigrir le
    # depot : il se nomme toujours, meme sans --details.
    retires = [cle for cle, _, present in plan["suppressions"] if present]
    if retires:
        print()
        print(f"Retirees du contenu publie ({len(retires)}) :")
        for cle in retires:
            print(f"  - {etiquette(BASE_DEPOT, cle, entreesDepot)}")

    if plan["orphelins"]:
        print()
        print("Present dans le depot et absent du classeur (laisse en place) :")
        for cle, _ in plan["orphelins"]:
            print(f"  - {etiquette(BASE_DEPOT, cle, entreesDepot)}")

    if args.details:
        for titre, cles in (
            ("Ajouts", [cle for cle, _ in plan["ajouts"]]),
            ("Modifies", [cle for cle, _ in plan["modifies"]]),
            ("Changent de cote", [cle for cle, _, _ in plan["deplaces"]]),
            ("Arbitrage seul", [cle for cle, _ in plan["arbitrage"]]),
        ):
            if not cles:
                continue
            print()
            print(f"{titre} ({len(cles)}) :")
            for cle in cles:
                print(f"  - {etiquette(sheets, cle, entreesSheets)}")

    total = sum(len(plan[cle]) for cle in ("ajouts", "modifies", "deplaces", "suppressions"))
    print()
    if total == 0:
        print("La base du depot est a jour : rien a reporter.")
        return 0
    if not args.appliquer:
        print(f"Apercu seulement : {total} ecriture(s) en attente. Relance avec --appliquer.")
        return 0

    appliquer(plan, BASE_DEPOT, sheets)
    print(f"{total} ecriture(s) dans la base du depot.")
    print("Reste a faire : « Base - Envoyer.bat » puis « Publier.bat ».")
    return 0


if __name__ == "__main__":
    sys.exit(main())
