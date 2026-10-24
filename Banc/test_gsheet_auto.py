"""Tests sans reseau de la synchronisation automatique MJ."""

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path
from threading import Event
from types import SimpleNamespace
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "Outils"))
import gsheet_base as db  # noqa: E402

spec = importlib.util.spec_from_file_location("gsheet_auto", ROOT / "Outils" / "gsheet_auto.py")
auto = importlib.util.module_from_spec(spec)
spec.loader.exec_module(auto)


class MemorySheet:
    def __init__(self, rows):
        self.rows = rows
        self.tab = None

    def select(self, tab):
        self.tab = tab

    def values(self):
        return [db.HEADERS] + self.rows


class AutoSyncTest(unittest.TestCase):
    def test_listener_reacts_to_saved_variables_only(self):
        changed = Event()
        listener = auto.SavedVariablesListener(changed)
        listener.on_any_event(SimpleNamespace(is_directory=False, src_path="autre.txt"))
        self.assertFalse(changed.is_set())
        listener.on_any_event(SimpleNamespace(is_directory=False,
                                              src_path="LesContesMalveillants_MJ.lua"))
        self.assertTrue(changed.is_set())

    def test_reload_detects_only_new_draft(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "Banc") as directory:
            file = Path(directory) / "LesContesMalveillants_MJ.lua"
            file.write_text('LCM_MJ_DB = { brouillons = { traits = { ancien = '
                            '{ id = "ancien", label = "Ancien" } } } }\n', encoding="utf-8")
            # Depuis le 15 octobre 2026, tout ce qui n'est pas encore PUBLIE
            # part (`pending_rows`) : « ancien » l'a ete, « tente » non.
            snap = auto.snapshot(file)
            before = auto.record(snap, {"traits/ancien": db.digest(snap["drafts"]["traits/ancien"])})
            file.write_text('LCM_MJ_DB = { brouillons = { traits = { ancien = '
                            '{ id = "ancien", label = "Ancien" }, tente = '
                            '{ id = "tente", label = "Tente" } } } }\n', encoding="utf-8")
            drafts, masks = auto.pending_rows(before, auto.snapshot(file))
            self.assertEqual(set(drafts), {"traits/tente"})
            self.assertEqual(masks, set())

    def test_remote_change_blocks_overwrite(self):
        old = auto.draft_row("traits", {"id": "temoin", "label": "Ancien"})
        remote = auto.draft_row("traits", {"id": "temoin", "label": "Binome"})
        edited = auto.draft_row("traits", {"id": "temoin", "label": "Local"})
        sheet = MemorySheet([remote])
        with patch.object(db, "load_state", return_value={"traits/temoin": db.digest(old)}), \
             patch.object(db, "local_rows", return_value={"traits/temoin": old}):
            with self.assertRaisesRegex(ValueError, "conflit"):
                auto.stage_changes(sheet, "sheet", {"traits/temoin": edited}, set())
        self.assertEqual(sheet.rows, [remote])

    def test_un_nombre_ecrit_en_texte_nest_pas_un_conflit(self):
        # Meme contenu, deux ecritures : le cout saisi en jeu arrive en texte
        # (« 2 »), la feuille le rend en nombre. L'empreinte differe, donc le
        # service criait au conflit et la file d'envoi du MJ ne se vidait plus.
        texte = auto.draft_row("traits", {"id": "temoin", "label": "Temoin", "cout": "2"})
        nombre = auto.draft_row("traits", {"id": "temoin", "label": "Temoin", "cout": 2})
        self.assertNotEqual(db.digest(texte), db.digest(nombre))

        # Rien a renvoyer : le brouillon n'a pas bouge depuis le dernier
        # passage, et la ligne locale dit deja la meme chose.
        self.assertEqual(
            auto.stale_rows({"drafts": {"traits/temoin": db.digest(texte)}},
                            {"traits/temoin": texte}, {"traits/temoin": nombre}),
            set())

        # Et rien ne part vers la feuille, sans conflit ni ecriture inutile.
        sheet = MemorySheet([nombre])
        with patch.object(db, "load_state", return_value={"traits/temoin": db.digest(nombre)}), \
             patch.object(db, "local_rows", return_value={"traits/temoin": nombre}):
            self.assertEqual(
                auto.stage_changes(sheet, "sheet", {"traits/temoin": texte}, set()), [])
        self.assertEqual(sheet.rows, [nombre])

        # Un cout qui change VRAIMENT repart, lui.
        trois = auto.draft_row("traits", {"id": "temoin", "label": "Temoin", "cout": 3})
        self.assertEqual(
            auto.stale_rows({"drafts": {"traits/temoin": db.digest(trois)}},
                            {"traits/temoin": trois}, {"traits/temoin": nombre}),
            {"traits/temoin"})

    def test_cleanup_removes_only_published_drafts(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "Banc") as directory:
            root = Path(directory)
            file = root / "WTF" / "Account" / "COMPTE" / "SavedVariables" / "LesContesMalveillants_MJ.lua"
            file.parent.mkdir(parents=True)
            file.write_text('LCM_MJ_DB = { autre = 42, brouillons = { traits = { '
                            'publie = { id = "publie", label = "Publie" }, '
                            'prive = { id = "prive", label = "Prive" } } } }\n', encoding="utf-8")
            snap = auto.snapshot(file)
            published = {"traits/publie": db.digest(snap["drafts"]["traits/publie"])}
            with patch.object(db, "ROOT", root):
                self.assertEqual(auto.clear_published(file, published), 1)
            after = auto.snapshot(file)
            self.assertEqual(set(after["drafts"]), {"traits/prive"})
            self.assertEqual(db.lcm_db.parse_assignments(file.read_text(encoding="utf-8"))["LCM_MJ_DB"]["autre"], 42)


if __name__ == "__main__":
    unittest.main()
