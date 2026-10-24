"""Tests hors reseau du stockage Google Sheets LCM."""

import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "Outils" / "gsheet_base.py"
spec = importlib.util.spec_from_file_location("gsheet_base", SCRIPT)
gsheet = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gsheet)


class MemorySheet:
    def __init__(self):
        self.rows = [gsheet.BACKUP_HEADERS]
        self.views = {}

    def prepare_backups(self):
        pass

    def append_backup(self, rows):
        self.rows.extend(rows)

    def backup_values(self):
        return self.rows

    def replace_view(self, tab, headers, rows):
        self.views[tab] = (headers, rows)

    # Les vues changees partent d'un coup depuis le travail sur le quota.
    def replace_views(self, vues):
        for tab, (headers, rows) in vues.items():
            self.replace_view(tab, headers, rows)


class GoogleSheetBaseTest(unittest.TestCase):
    def test_tools_and_chest_tool_types_round_trip(self):
        # La reference est Outils/ ; la copie deployee dans Sync/ n'est plus
        # suivie dans le depot (Outils/packager_sync.py la refait).
        packaged_script = SCRIPT
        packaged_spec = importlib.util.spec_from_file_location("gsheet_base_packaged", packaged_script)
        packaged = importlib.util.module_from_spec(packaged_spec)
        packaged_spec.loader.exec_module(packaged)
        definitions = [
            ("listes", "serrurerie", '{ id = "serrurerie", liste = "outils" }'),
            ("objets", "crochet", '{ id = "crochet", categorie = "outil", '
             'type = "serrurerie", bonus = { ["metier:mineur"] = 2 } }'),
            ("points", "coffre", '{ id = "coffre", nature = "coffre", '
             'coffre = { outils = { { typeOutil = "serrurerie", '
             'expertise = "crochetage", quantite = 1 } } } }'),
        ]
        for implementation in (gsheet, packaged):
            for family, identifier, lua in definitions:
                with self.subTest(script=implementation.__name__, family=family):
                    row = implementation.canonical([family, identifier, identifier, "", family == "points",
                                                    implementation.ACTIVE, lua])
                    parsed = implementation.lcm_db.LuaParser(row[6]).value()
                    self.assertEqual(parsed["id"], identifier)
                    self.assertEqual(implementation.canonical(row), row)
        with self.assertRaisesRegex(ValueError, "ambigu"):
            gsheet.canonical(["points", "coffre", "Coffre", "", True, gsheet.ACTIVE,
                              '{ id = "coffre", nature = "coffre", coffre = { outils = '
                              '{ { entree = "objets/crochet", typeOutil = "serrurerie" } } } }'])

    def test_nouvelles_familles_et_contenants(self):
        # 22-23 octobre 2026 : lanternes, cristaux et consommables entrent dans
        # la base, chacun dans son onglet. Absents, ils ne quittaient jamais la
        # file d'envoi du MJ.
        plan = gsheet.feuilles()
        for famille, titre in (("consommables", "Consommables"), ("lanternes", "Lanternes"),
                               ("cristaux", "Cristaux")):
            self.assertIn(famille, gsheet.lcm_db.FAMILIES)
            self.assertEqual(plan[famille], {"titre": titre, "familles": [famille]})
            self.assertNotIn(famille, gsheet.lcm_db.RESERVED_MJ)
        # Un consommable par criteres, avec l'etat qu'il pose et son passe.
        conso = ('{ id = "soupe", type = "t_soupe", bonus = { ["rend:fatigue"] = 2, resi_vent = 5 }, '
                 'etatApplique = { conteneur = "maladie", nom = "Repus", rounds = 3 }, '
                 'transfertDe = { "ressources/soupe" } }')
        row = gsheet.canonical(["consommables", "soupe", "Soupe", "", False, gsheet.ACTIVE, conso])
        parsed = gsheet.lcm_db.LuaParser(row[6]).value()
        self.assertEqual(parsed["etatApplique"]["conteneur"], "maladie")
        self.assertEqual(gsheet.canonical(row), row)
        # Un outil contenant passe ; un contenant faux ne se publie pas.
        gourde = ('{ id = "gourde", categorie = "outil", contenant = { taille = 100, retrait = 20, '
                  'types = { "t_boisson" }, entrees = { "consommables/eau" }, depart = "consommables/eau" } }')
        gsheet.canonical(["objets", "gourde", "Gourde", "", False, gsheet.ACTIVE, gourde])
        with self.assertRaisesRegex(ValueError, "plus que le contenant"):
            gsheet.canonical(["objets", "g2", "G2", "", False, gsheet.ACTIVE,
                              '{ id = "g2", categorie = "outil", contenant = { taille = 1, retrait = 5 } }'])
        with self.assertRaisesRegex(ValueError, "seul un outil"):
            gsheet.canonical(["objets", "e", "E", "", False, gsheet.ACTIVE,
                              '{ id = "e", categorie = "arme", contenant = { taille = 1, retrait = 1 } }'])

    def test_un_type_detat_designe_un_conteneur_connu(self):
        # 24 octobre 2026 : le conteneur d'un etat se lit sur son TYPE, une
        # entree de « Liste-Type-Etats ». L'addon refuse autre chose au
        # chargement, par error() : publie depuis le Sheet, un conteneur faux
        # ne gate pas une entree, il empeche l'addon de se charger chez tout
        # le monde.
        for conteneur in gsheet.CONTENEURS_ETATS:
            row = gsheet.canonical(["listes", "t_" + conteneur, "Type", "", False, gsheet.ACTIVE,
                                    '{ id = "t_%s", liste = "type_etats", conteneur = "%s" }'
                                    % (conteneur, conteneur)])
            self.assertEqual(gsheet.canonical(row), row)
        for faux in ('{ id = "t_faux", liste = "type_etats", conteneur = "armes" }',
                     '{ id = "t_faux", liste = "type_etats", conteneur = "" }',
                     # Le champ laisse vide : c'est le cas qui arrive.
                     '{ id = "t_faux", liste = "type_etats" }'):
            with self.assertRaisesRegex(ValueError, "conteneur d'un type d'etat"):
                gsheet.canonical(["listes", "t_faux", "Type", "", False, gsheet.ACTIVE, faux])
        # Une autre liste ne connait pas ce champ et n'a pas a le porter.
        gsheet.canonical(["listes", "t_epee", "Epees", "", False, gsheet.ACTIVE,
                          '{ id = "t_epee", liste = "armes" }'])

    def test_un_nombre_saisi_en_texte_vaut_le_nombre(self):
        # Un champ saisi en jeu reste parfois du texte dans le brouillon :
        # « 100 » plutot que 100. Le jeu le lit par tonumber, le service doit
        # le lire pareil — sinon une gourde parfaitement valable est refusee,
        # et deux ecritures du MEME contenu passent pour un conflit.
        texte = ('{ id = "gourde", categorie = "outil", contenant = { taille = "100", '
                 'retrait = "20", types = { "t_boisson" } } }')
        gsheet.canonical(["objets", "gourde", "Gourde", "", False, gsheet.ACTIVE, texte])
        with self.assertRaisesRegex(ValueError, "contenant illisible"):
            gsheet.canonical(["objets", "g3", "G3", "", False, gsheet.ACTIVE,
                              '{ id = "g3", categorie = "outil", contenant = '
                              '{ taille = "beaucoup", retrait = 1 } }'])

        nombre = ['objets', 'gourde', 'Gourde', '', False, gsheet.ACTIVE,
                  '{ id = "gourde", taille = 3, bonus = { force = 2 } }']
        comme_texte = ['objets', 'gourde', 'Gourde', '', False, gsheet.ACTIVE,
                       '{ id = "gourde", taille = "3", bonus = { force = "2" } }']
        self.assertTrue(gsheet.equivalent_rows(nombre, comme_texte))
        # L'empreinte, elle, ne bouge pas : la changer invaliderait les bases
        # de comparaison deja ecrites.
        self.assertNotEqual(gsheet.digest(nombre), gsheet.digest(comme_texte))
        # Une vraie difference reste une difference, et un texte n'est jamais
        # converti la ou on attend du texte.
        autre = ['objets', 'gourde', 'Gourde', '', False, gsheet.ACTIVE,
                 '{ id = "gourde", taille = 4, bonus = { force = 2 } }']
        self.assertFalse(gsheet.equivalent_rows(nombre, autre))
        mot = ['objets', 'gourde', 'Gourde', '', False, gsheet.ACTIVE,
               '{ id = "gourde", taille = 3, bonus = { force = 2 }, nom = "3" }']
        chiffre = ['objets', 'gourde', 'Gourde', '', False, gsheet.ACTIVE,
                   '{ id = "gourde", taille = 3, bonus = { force = 2 }, nom = 3 }']
        self.assertFalse(gsheet.equivalent_rows(mot, chiffre))

    def test_tabs_cover_each_family_once(self):
        plan = gsheet.feuilles()
        self.assertEqual(len(plan), len(gsheet.lcm_db.FAMILIES) + 5)
        self.assertEqual(len({item["titre"] for item in plan.values()}), len(plan))
        self.assertEqual(plan["sauvegardes"]["titre"], "Archives")
        assigned = [family for item in plan.values() for family in item["familles"]]
        self.assertEqual(len(assigned), len(set(assigned)))
        self.assertEqual(set(assigned), set(gsheet.lcm_db.FAMILIES))

    def test_mj_routing_and_mandatory_mj(self):
        row = gsheet.canonical(["traits", "temoin", "Temoin", "", True,
                                "ACTIF", '{ id = "temoin" }'])
        definition = gsheet.lcm_db.LuaParser(row[6]).value()
        self.assertEqual(gsheet.lcm_db.side_for("traits", definition), "mj")
        with self.assertRaisesRegex(ValueError, "doit rester MJ"):
            gsheet.canonical(["pnj", "temoin", "Temoin", "", False,
                              "ACTIF", '{ id = "temoin" }'])

    def test_empty_checkbox_rows_are_ignored(self):
        self.assertEqual(gsheet.remote_rows([gsheet.HEADERS, [],
                                             ["", "", "", "", False]]), {})

    def test_saved_variables_round_trip_and_checksum(self):
        with tempfile.TemporaryDirectory(dir=SCRIPT.parents[1] / "Banc") as directory:
            root = Path(directory)
            retail = root / "_retail_"
            file = retail / "WTF" / "Account" / "COMPTE" / "Royaume" / "Perso" / "SavedVariables" / "LesContesMalveillants.lua"
            file.parent.mkdir(parents=True)
            original = b"LCM_CharDB = { fiche = { nom = 'Temoin' } }\r\n"
            file.write_bytes(original)
            sheet = MemorySheet()
            # Ce qui a deja ete envoye se note a part : isole ici, sinon le test
            # ecrit dans celui du vrai service et une archive « deja partie »
            # ne repart pas.
            with patch.object(gsheet, "ROOT", root),                  patch.object(gsheet, "ECRITURES", root / "ecritures.json"):
                gsheet.sauvegarder(sheet, retail)
                self.assertEqual(sheet.views["Fiches"][1][0][3:6],
                                 ["/fiche/nom", "texte", "Temoin"])
                stamp = sheet.rows[1][0]
                target = root / "restauration"
                gsheet.restaurer(sheet, stamp, target)
                self.assertEqual((target / file.relative_to(retail)).read_bytes(), original)
                with self.assertRaises(FileExistsError):
                    gsheet.restaurer(sheet, stamp, target)
                sheet.rows[2][2] = "0" * 64
                with self.assertRaisesRegex(ValueError, "empreinte incorrecte"):
                    gsheet.restaurer(sheet, stamp, root / "corrompu")


if __name__ == "__main__":
    unittest.main()
