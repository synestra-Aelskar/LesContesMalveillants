"""Configuration et conservation du contenu des livres, sans reseau."""
import importlib.util
import os
from pathlib import Path
import sys
import unittest

ROOT = Path(os.environ.get('LCM_TEST_ROOT', Path(__file__).resolve().parents[1]))
spec = importlib.util.spec_from_file_location('gsheet_livres_test', ROOT / 'Outils/gsheet_base.py')
db = importlib.util.module_from_spec(spec)
spec.loader.exec_module(db)


class LivresSheetsTest(unittest.TestCase):
    def test_category_is_registered_once(self):
        plan = db.feuilles()
        self.assertEqual(db.lcm_db.FAMILIES['livres'], 'Livres')
        self.assertEqual(plan['livres'], {'titre': 'Livres', 'familles': ['livres']})
        self.assertEqual(sum(item['familles'].count('livres') for item in plan.values()), 1)

    def test_book_and_note_keep_their_content(self):
        for format in ('livre', 'note'):
            with self.subTest(format=format):
                definition = {'id': 'livre_temoin', 'label': 'Chronique témoin',
                    'description': 'Texte de test local.', 'format': format, 'modele': 'herbier',
                    'pages': {1: {'titre': 'À l’aube', 'texte': 'Une ligne.\nUne autre.'},
                              2: {'titre': 'Épilogue', 'texte': 'Fin.'}},
                    'style': {'encre': '302317', 'fond': 'E5D3A3', 'alignement': 'LEFT'}}
                if format == 'livre':
                    definition['couverture'] = {'titre': 'Chronique', 'texte': 'Garde'}
                    definition['dos'] = {'titre': '', 'texte': 'Derniers mots'}
                row = db.canonical(['livres', definition['id'], definition['label'],
                    definition['description'], False, db.ACTIVE, db.lcm_db.lua_value(definition)])
                self.assertEqual(db.lcm_db.LuaParser(row[6]).value(), definition)
                self.assertEqual(db.canonical(row), row)
                self.assertFalse(row[4])


if __name__ == '__main__':
    unittest.main()
