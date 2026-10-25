"""Tests du pont de la base Sheets vers la base du depot.

Le pont recopie dans un seul sens. Ce qui compte ici n'est pas qu'il copie,
c'est ce qu'il refuse de faire : une entree presente dans le depot et absente
du classeur reste en place, parce que seule une pierre tombale dit une
suppression voulue. Un pont qui nettoie tout seul ferait maigrir le depot en
silence, et c'est deja arrive autrement.
"""

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "Outils" / "pont_base.py"
spec = importlib.util.spec_from_file_location("pont_base", SCRIPT)
pont = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pont)


def ecrire_entree(base: Path, side: str, family: str, ident: str, label: str = "Témoin") -> Path:
    chemin = base / "entries" / side / family / f"{ident}.lua"
    chemin.parent.mkdir(parents=True, exist_ok=True)
    tete = json.dumps({"family": family, "id": ident, "registry": family.title(), "side": side})
    chemin.write_text(
        f"-- lcm-db: {tete}\nreturn {{\n    id = \"{ident}\",\n    label = \"{label}\",\n}}\n",
        encoding="utf-8",
        newline="\n",
    )
    return chemin


def ecrire_pierre(base: Path, family: str, ident: str, crlf: bool = False) -> Path:
    chemin = base / "tombstones" / family / f"{ident}.delete"
    chemin.parent.mkdir(parents=True, exist_ok=True)
    fin = "\r\n" if crlf else "\n"
    chemin.write_bytes(f"{family}/{ident}{fin}".encode("utf-8"))
    return chemin


class PontBaseTest(unittest.TestCase):
    def setUp(self):
        self.dossier = tempfile.TemporaryDirectory()
        racine = Path(self.dossier.name)
        self.depot = racine / "depot"
        self.sheets = racine / "sheets"
        for base in (self.depot, self.sheets):
            (base / "entries").mkdir(parents=True)
            (base / "tombstones").mkdir(parents=True)

    def tearDown(self):
        self.dossier.cleanup()

    def test_ajoute_modifie_et_laisse_les_orphelins(self):
        ecrire_entree(self.sheets, "player", "objets", "neuf")
        ecrire_entree(self.depot, "player", "objets", "connu", label="Avant")
        ecrire_entree(self.sheets, "player", "objets", "connu", label="Apres")
        orphelin = ecrire_entree(self.depot, "player", "objets", "seul_au_depot")

        plan = pont.comparer(self.depot, self.sheets)
        self.assertEqual([cle for cle, _ in plan["ajouts"]], [("objets", "neuf")])
        self.assertEqual([cle for cle, _ in plan["modifies"]], [("objets", "connu")])
        self.assertEqual([cle for cle, _ in plan["orphelins"]], [("objets", "seul_au_depot")])

        pont.appliquer(plan, self.depot, self.sheets)
        copie = self.depot / "entries" / "player" / "objets" / "neuf.lua"
        self.assertEqual(copie.read_bytes(), (self.sheets / "entries" / "player" / "objets" / "neuf.lua").read_bytes())
        self.assertIn("Apres", (self.depot / "entries" / "player" / "objets" / "connu.lua").read_text(encoding="utf-8"))
        self.assertTrue(orphelin.exists(), "le pont ne supprime jamais une entree que le classeur ignore")

        # Une seconde passe ne doit plus rien trouver a faire.
        encore = pont.comparer(self.depot, self.sheets)
        self.assertEqual(encore["ajouts"], [])
        self.assertEqual(encore["modifies"], [])

    def test_une_pierre_tombale_voyage_en_lf_et_se_nomme(self):
        ecrire_entree(self.depot, "player", "objets", "a_retirer")
        ecrire_entree(self.sheets, "player", "objets", "a_retirer")
        ecrire_pierre(self.sheets, "objets", "a_retirer", crlf=True)
        ecrire_pierre(self.sheets, "objets", "deja_parti", crlf=True)

        plan = pont.comparer(self.depot, self.sheets)
        presences = {cle: present for cle, _, present in plan["suppressions"]}
        self.assertTrue(presences[("objets", "a_retirer")], "elle retire du contenu encore publie")
        self.assertFalse(presences[("objets", "deja_parti")], "celle-la ne retire rien de plus")

        pont.appliquer(plan, self.depot, self.sheets)
        copie = self.depot / "tombstones" / "objets" / "a_retirer.delete"
        self.assertNotIn(b"\r", copie.read_bytes(), "le depot declare les .delete en eol=lf")
        self.assertEqual(copie.read_text(encoding="utf-8"), "objets/a_retirer\n")

    def test_un_changement_de_cote_ne_laisse_pas_de_double(self):
        ancienne = ecrire_entree(self.depot, "player", "points", "bascule")
        ecrire_entree(self.sheets, "mj", "points", "bascule")

        plan = pont.comparer(self.depot, self.sheets)
        self.assertEqual([cle for cle, _, _ in plan["deplaces"]], [("points", "bascule")])

        pont.appliquer(plan, self.depot, self.sheets)
        self.assertFalse(ancienne.exists(), "la copie de l'ancien cote ferait une entree en double")
        self.assertTrue((self.depot / "entries" / "mj" / "points" / "bascule.lua").exists())
        # `lire_entrees` refuse les doublons : si l'ancienne subsistait, elle
        # leverait ici plutot que de laisser la reconstruction echouer plus tard.
        self.assertEqual(len(pont.lire_entrees(self.depot)), 1)


if __name__ == "__main__":
    unittest.main()
