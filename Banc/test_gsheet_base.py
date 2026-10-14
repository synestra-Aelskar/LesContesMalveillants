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


class GoogleSheetBaseTest(unittest.TestCase):
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
            with patch.object(gsheet, "ROOT", root):
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
