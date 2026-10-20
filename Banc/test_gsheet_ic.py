"""Les IC suivent les objets existants, sans feuille ni acces reseau en plus."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('gsheet_ic_test', ROOT / 'Outils/gsheet_base.py')
db = importlib.util.module_from_spec(spec)
spec.loader.exec_module(db)


class ICTest(unittest.TestCase):
    def test_roundtrip(self):
        for category in ('arme', 'equipement', 'accessoire', 'outil'):
            for properties in ({}, {1: {'id': 'ancienne', 'version': 1, 'cout': 2,
                    'nom': 'Propriété retirée', 'description': 'À conserver',
                    'frequence': {'type': 'combat', 'nombre': 1},
                    'duree': {'type': 'tours', 'nombre': 2}, 'parametres': {'bonus': 1}}}):
                d = {'id': 'ic_temoin', 'label': 'IC témoin', 'description': '',
                     'categorie': category, 'forge': 'jeu/rare', 'bonus': {'vue': 1},
                     'ic': {'version': 1, 'palier': 'bleu', 'convertis': 3, 'proprietes': properties}}
                row = db.canonical(['objets', d['id'], d['label'], '', False, db.ACTIVE, db.lcm_db.lua_value(d)])
                self.assertEqual(db.lcm_db.LuaParser(row[6]).value(), d)
                self.assertEqual(db.canonical(row), row)
                self.assertFalse(row[4])

    def test_old_item(self):
        d = {'id': 'ancien', 'label': 'Ancien', 'description': '', 'categorie': 'arme'}
        row = db.canonical(['objets', d['id'], d['label'], '', False, db.ACTIVE, db.lcm_db.lua_value(d)])
        self.assertEqual(db.lcm_db.LuaParser(row[6]).value(), d)


if __name__ == '__main__':
    unittest.main()
