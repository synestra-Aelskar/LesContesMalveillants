"""Les points poses (coffres, filons, vendeurs) dans la base commune, sans reseau.

21 octobre 2026 : ils passent par la meme file d'envoi que le contenu
(LCM_MJ_DB.brouillons.poses), restent cote MJ, et deux versions d'un meme
point se departagent par leur rang au lieu d'arreter la synchronisation.
"""

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "Outils"))
import gsheet_base as db  # noqa: E402

spec = importlib.util.spec_from_file_location("gsheet_auto_poses", ROOT / "Outils" / "gsheet_auto.py")
auto = importlib.util.module_from_spec(spec)
spec.loader.exec_module(auto)


def pose(identifier: str, epoque: int = 0, version: int = 1, auteur: str = "Reika-Apertus",
         quantite: int = 1, statut: str = db.ACTIVE) -> list[object]:
    definition = {"id": identifier, "label": identifier, "nature": "coffre", "auteur": auteur,
                  "epoque": epoque, "version": version,
                  "donnees": {"def": "coffre_temoin", "x": 1, "y": 2, "z": 0,
                              "objets": {1: {"entree": "objets/or", "quantite": quantite}}}}
    return db.canonical(["poses", identifier, identifier, "", True, statut,
                         db.lcm_db.lua_value(definition)])


class MemorySheet:
    def __init__(self, rows):
        self.rows = rows
        self.tab = None

    def select(self, tab):
        self.tab = tab

    def values(self):
        return [db.HEADERS] + self.rows


class PosesTest(unittest.TestCase):
    def test_famille_reservee_au_mj(self):
        self.assertEqual(db.lcm_db.FAMILIES["poses"], "Poses")
        self.assertIn("poses", db.lcm_db.RESERVED_MJ)
        self.assertEqual(db.feuilles()["poses"], {"titre": "Poses", "familles": ["poses"]})
        # Une ligne qui pretend etre pour les joueurs est refusee : un coffre
        # cache se lirait dans les fichiers de l'addon joueur.
        with self.assertRaisesRegex(ValueError, "doit rester MJ"):
            db.canonical(["poses", "c1", "c1", "", False, db.ACTIVE, '{ id = "c1" }'])

    def test_le_fichier_genere_les_publie_cote_mj_seulement(self):
        with tempfile.TemporaryDirectory() as dossier:
            racine = Path(dossier)
            entrees, tombes = racine / "entries", racine / "tombstones"
            joueur, mj = racine / "Atelier.lua", racine / "Atelier_MJ.lua"
            with patch.object(db.lcm_db, "ENTRIES", entrees), \
                 patch.object(db.lcm_db, "TOMBSTONES", tombes), \
                 patch.object(db.lcm_db, "PLAYER_OUTPUT", joueur), \
                 patch.object(db.lcm_db, "MJ_OUTPUT", mj), \
                 patch.object(db.lcm_db, "lire_reglages", return_value=[]):
                definition = db.lcm_db.LuaParser(pose("c1")[6]).value()
                chemin = db.lcm_db.write_entry("poses", definition)
                self.assertEqual(chemin.parent.parent.name, "mj")
                db.lcm_db.build()
                self.assertIn("LCM.Publier(LCM.Poses,", mj.read_text(encoding="utf-8"))
                self.assertNotIn("Poses", joueur.read_text(encoding="utf-8"))

    def test_la_file_d_envoi_les_emporte(self):
        with tempfile.TemporaryDirectory() as dossier:
            fichier = Path(dossier) / "LesContesMalveillants_MJ.lua"
            fichier.write_text(
                'LCM_MJ_DB = { brouillons = { poses = { c1 = { id = "c1", label = "c1", '
                'nature = "coffre", auteur = "Reika-Apertus", epoque = 0, version = 2, '
                'donnees = { def = "coffre_temoin" } } } }, masques = { poses = { c2 = true } } }\n',
                encoding="utf-8")
            snap = auto.snapshot(fichier)
            self.assertIn("poses/c1", snap["drafts"])
            self.assertTrue(snap["drafts"]["poses/c1"][4])
            self.assertEqual(snap["masks"], ["poses/c2"])

    def test_le_plus_recent_l_emporte(self):
        self.assertTrue(db.pose_plus_recente(pose("c", version=3), pose("c", version=2)))
        self.assertFalse(db.pose_plus_recente(pose("c", version=2), pose("c", version=3)))
        # Une reprise de garde (epoque) passe avant le nombre de gestes.
        self.assertTrue(db.pose_plus_recente(pose("c", epoque=1, version=0),
                                             pose("c", epoque=0, version=9)))
        # A rang egal, le plus petit nom : la meme regle que l'addon.
        self.assertTrue(db.pose_plus_recente(pose("c", auteur="Abel-Apertus"),
                                             pose("c", auteur="Zed-Apertus")))
        # Une suppression l'emporte toujours.
        self.assertTrue(db.pose_plus_recente(pose("c", statut=db.DELETED), pose("c", version=9)))
        self.assertFalse(db.pose_plus_recente(pose("c", version=9), pose("c", statut=db.DELETED)))

    def test_deux_versions_ne_bloquent_pas_l_envoi(self):
        ancienne = pose("c1", version=1)
        distante = pose("c1", version=5, quantite=3)
        plus_recente = pose("c1", version=6, quantite=4)
        plus_vieille = pose("c1", version=2, quantite=9)
        sheet = MemorySheet([distante])
        with patch.object(db, "load_state", return_value={"poses/c1": db.digest(ancienne)}), \
             patch.object(db, "local_rows", return_value={"poses/c1": ancienne}):
            self.assertEqual(auto.stage_changes(sheet, "sheet", {"poses/c1": plus_recente}, set()),
                             [plus_recente])
            self.assertEqual(auto.stage_changes(sheet, "sheet", {"poses/c1": plus_vieille}, set()), [])

    def test_la_colonne_famille_dit_ce_qui_est_pose(self):
        # 21 octobre 2026 : « poses » ne disait rien au MJ qui filtre le Sheet.
        # La colonne affiche la nature ; tous ces noms se relisent « poses ».
        coffre = pose("c1")
        self.assertEqual(db.vers_sheet(coffre)[0], "Coffre")
        self.assertEqual(db.canonical(db.vers_sheet(coffre)), coffre)
        vendeur = db.lcm_db.LuaParser(coffre[6]).value()
        vendeur["nature"] = "vendeur"
        ligne = db.canonical(["Vendeur", "c1", "c1", "", True, db.ACTIVE,
                              db.lcm_db.lua_value(vendeur)])
        self.assertEqual(ligne[0], "poses")
        supprime = db.canonical(["poses", "c2", "", "", True, db.DELETED, ""])
        self.assertEqual(db.vers_sheet(supprime)[0], "Point posé")
        # Les autres familles ne bougent pas.
        self.assertEqual(db.famille_affichee(["objets", "o"] + [""] * 5), "objets")
        self.assertEqual(len(db.vers_sheet(["objets", "o"] + [""] * 5)), len(db.HEADERS))

    def test_la_colonne_createur_dit_qui_a_pose(self):
        # Le poseur, sans son royaume ; a defaut (point d'avant posePar),
        # l'arbitre. Une colonne d'affichage : la relecture l'ignore.
        coffre = pose("c1")
        self.assertEqual(db.vers_sheet(coffre)[7], "Reika")
        definition = db.lcm_db.LuaParser(coffre[6]).value()
        definition["donnees"]["posePar"] = "Moon-Apertus"
        posee = db.canonical(["poses", "c1", "c1", "", True, db.ACTIVE,
                              db.lcm_db.lua_value(definition)])
        self.assertEqual(db.createur(posee), "Moon")
        self.assertEqual(db.canonical(db.vers_sheet(posee)), posee)
        self.assertEqual(db.en_tetes("Poses"), db.HEADERS + ["Créateur"])
        self.assertEqual(db.en_tetes("Objets"), db.HEADERS)

    def test_un_onglet_poses_trop_etroit_s_elargit(self):
        envois = []

        class Classeur(db.Sheets):
            def __init__(self):
                self._lus, self._onglets, self._prets = {"Poses": [db.HEADERS]}, {"Poses": 7}, set()
                self.tab, self._perime = "Poses", False

            def request(self, method, suffix, body=None):
                envois.append((suffix, body))
                return {}

        Classeur().prepare()
        lots = [b["requests"] for s, b in envois if s == ":batchUpdate"]
        # L'elargissement part seul, AVANT la mise en forme qui vise la colonne H.
        self.assertEqual(lots[0], [{"appendDimension": {"sheetId": 7, "dimension": "COLUMNS",
                                                        "length": 1}}])
        self.assertEqual(envois[-1][1]["values"], [db.HEADERS + ["Créateur"]])
        self.assertIn("A1%3AH1", envois[-1][0])

    def test_un_ancien_poses_se_renomme_sans_changer_de_contenu(self):
        coffre = pose("c1")
        ecrit = []

        preparee = []

        class Feuille(MemorySheet):
            def prepare(self):
                preparee.append(self.tab)

            def write(self, debut, lignes):
                ecrit.append((debut, lignes))

        feuille = Feuille([coffre, db.vers_sheet(pose("c2"))])
        feuille.tab = "Poses"
        with patch.object(db, "local_rows", return_value={"poses/c1": coffre,
                                                          "poses/c2": pose("c2")}), \
             patch.object(db, "load_state", return_value={}), \
             patch.object(db, "save_state"), \
             patch.object(db.lcm_db, "build"):
            db.synchronise(feuille, "sheet", "poses", {"poses"}, prepare=False, verbose=False)
        # Seule la ligne restee « poses » est reecrite, avec son nom affiche.
        self.assertEqual(ecrit, [(2, [db.vers_sheet(coffre)])])
        # Le service passe sans preparer l'onglet : un en-tete « Créateur »
        # absent le fait preparer quand meme, sinon la colonne resterait sans
        # titre (constate le 21 octobre 2026).
        self.assertEqual(preparee, ["Poses"])

    def test_un_onglet_absent_est_cree_puis_relu(self):
        appels = []

        class Classeur(db.Sheets):
            def __init__(self):
                # Ce que le classeur a vraiment ; `_onglets` n'en est que le cache.
                self.existants = {"Objets": 1}
                self._lus, self._onglets, self.tab = {}, None, None

            def request(self, method, suffix, body=None):
                appels.append(suffix)
                if "batchGet" in suffix and "Poses" not in self.existants:
                    raise RuntimeError("Google Sheets (400) : Unable to parse range: 'Poses'!A:G")
                return {"valueRanges": [{"values": [db.HEADERS]}, {"values": [db.HEADERS]}]}

            def _onglet(self, titre):
                if self._onglets is None:
                    self._onglets = dict(self.existants)
                return self._onglets.get(titre)

            def prepare(self):
                self.existants[self.tab] = 2
                self._onglets[self.tab] = 2

        classeur = Classeur()
        classeur.precharger(["Objets", "Poses"])
        self.assertIn("Poses", classeur.existants)
        self.assertEqual(sum("batchGet" in a for a in appels), 2)
        self.assertEqual(classeur._lus["Poses"], [db.HEADERS])


if __name__ == "__main__":
    unittest.main()
