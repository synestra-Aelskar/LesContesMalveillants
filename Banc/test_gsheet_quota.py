"""Tests sans reseau du quota Google du service MJ (17 octobre 2026).

Le service tombait sur « Read requests per minute per user » : il relisait
dix-huit onglets un par un a chaque releve, et renvoyait tout ce qu'il avait,
change ou non. On verifie ici qu'il ne lit que si le classeur a change, qu'il
n'ecrit que ce qui a change, qu'il attend avant le plafond, et qu'un refus
pour quota se retente au lieu d'abandonner le passage a moitie fait.

Vise la copie EMBARQUEE (LesContesMalveillants_MJ/Sync), celle que le service
fait tourner.
"""

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.parse import unquote


# Le service de reference vit dans Outils/ ; LesContesMalveillants_MJ/Sync
# n'en est qu'une copie deployee (Outils/packager_sync.py).
OUTILS = Path(__file__).resolve().parents[1] / "Outils"
sys.path.insert(0, str(OUTILS))
spec = importlib.util.spec_from_file_location("gsheet_base_sync", OUTILS / "gsheet_base.py")
db = importlib.util.module_from_spec(spec)
spec.loader.exec_module(db)


class Reponse:
    def __init__(self, status=200, data=None, headers=None):
        self.status_code = status
        self.ok = 200 <= status < 300
        self._data = data if data is not None else {}
        self.content = json.dumps(self._data).encode("utf-8")
        self.text = self.content.decode("utf-8")
        self.headers = headers or {}

    def json(self):
        return self._data


class Session:
    """Repond selon l'adresse ; garde chaque appel pour qu'on les compte."""

    def __init__(self):
        self.appels = []
        self.version = "1"
        self.drive_en_panne = False
        self.refus = []          # statuts a rendre d'abord, dans l'ordre
        self.onglets = {}

    def request(self, method, url, json=None, timeout=None):
        url = unquote(url)
        self.appels.append((method, url))
        if self.refus:
            return Reponse(self.refus.pop(0), {"error": {"message": "quota"}})
        if "/drive/v3/files/" in url:
            if self.drive_en_panne:
                return Reponse(403, {"error": {"message": "Drive API desactivee"}})
            return Reponse(200, {"version": self.version})
        if json and any("addSheet" in r for r in json.get("requests", [])):
            titre = json["requests"][0]["addSheet"]["properties"]["title"]
            self.onglets.setdefault(titre, [])
            return Reponse(200, {"replies": [{"addSheet": {"properties": {
                "sheetId": len(self.onglets), "title": titre}}}]})
        if "values:batchGet" in url:
            return Reponse(200, {"valueRanges": [{"values": [db.HEADERS]}
                                                 for _ in url.split("ranges=")[1:]]})
        if "fields=sheets" in url:
            return Reponse(200, {"sheets": [{"properties": {"title": titre, "sheetId": i}}
                                            for i, titre in enumerate(self.onglets)]})
        if method == "GET" and "A1:" in url:
            for titre, entetes in self.onglets.items():
                if titre in url:
                    return Reponse(200, {"values": [entetes] if entetes else []})
            return Reponse(200, {"values": []})
        return Reponse(200, {})

    def compter(self, *morceaux, method=None):
        return sum(1 for m, url in self.appels
                   if (method is None or m == method) and all(x in url for x in morceaux))

    def lectures_sheet(self):
        return sum(1 for m, url in self.appels if m == "GET" and "sheets.googleapis.com" in url)


class Horloge:
    def __init__(self):
        self.t = 1000.0
        self.pauses = []

    def __call__(self):
        return self.t

    def dormir(self, secondes):
        self.pauses.append(secondes)
        self.t += secondes


def api(session=None, horloge=None, limite=40):
    horloge = horloge or Horloge()
    return db.Sheets(Path("cle.json"), "classeur", session=session or Session(),
                     quota=db.Quota(limite, horloge, horloge.dormir),
                     dormir=horloge.dormir, journal=lambda message: None)


class QuotaTests(unittest.TestCase):
    def test_on_attend_avant_le_plafond(self):
        horloge = Horloge()
        quota = db.Quota(3, horloge, horloge.dormir)
        for _ in range(3):
            self.assertEqual(quota.attendre("lecture"), 0)
        self.assertGreater(quota.attendre("lecture"), 59)
        self.assertEqual(len(horloge.pauses), 1)
        # Les ecritures ont leur propre compte.
        self.assertEqual(quota.attendre("ecriture"), 0)

    def test_un_refus_pour_quota_se_retente(self):
        session, horloge = Session(), Horloge()
        session.refus = [429, 429]
        sheets = api(session, horloge)
        sheets.select("Traits")
        sheets.write(2, [["traits", "x"]])
        self.assertEqual(session.compter("values/", method="PUT"), 3)
        self.assertGreaterEqual(min(horloge.pauses), 60, "moins d'une minute retombe dans le quota")

    def test_une_erreur_serveur_ne_rejoue_pas_une_ecriture(self):
        session = Session()
        session.refus = [500]
        sheets = api(session)
        with self.assertRaises(RuntimeError):
            sheets.append_backup([["a"]])
        self.assertEqual(session.compter(":append"), 1)

    def test_le_quota_epuise_finit_par_le_dire(self):
        session = Session()
        session.refus = [429] * db.Sheets.ESSAIS
        with self.assertRaises(RuntimeError) as erreur:
            api(session).values()
        self.assertIn("429", str(erreur.exception))


class LectureTests(unittest.TestCase):
    ONGLETS = ["Objets", "Traits", "Races"]

    def test_tous_les_onglets_en_une_lecture(self):
        session = Session()
        sheets = api(session)
        self.assertTrue(sheets.actualiser(self.ONGLETS))
        self.assertEqual(session.lectures_sheet(), 1)
        for titre in self.ONGLETS:
            sheets.select(titre)
            self.assertEqual(sheets.values(), [db.HEADERS])
        self.assertEqual(session.lectures_sheet(), 1)

    def test_classeur_inchange_pas_de_lecture(self):
        session = Session()
        sheets = api(session)
        sheets.actualiser(self.ONGLETS)
        self.assertFalse(sheets.actualiser(self.ONGLETS))
        self.assertFalse(sheets.actualiser(self.ONGLETS))
        self.assertEqual(session.lectures_sheet(), 1)
        self.assertEqual(session.compter("/drive/v3/files/"), 3)

    def test_classeur_modifie_on_relit(self):
        session = Session()
        sheets = api(session)
        sheets.actualiser(self.ONGLETS)
        session.version = "2"     # l'autre MJ, ou une saisie a la main
        self.assertTrue(sheets.actualiser(self.ONGLETS))
        self.assertEqual(session.lectures_sheet(), 2)

    def test_notre_ecriture_fait_relire(self):
        session = Session()
        sheets = api(session)
        sheets.actualiser(self.ONGLETS)
        sheets.select("Traits")
        sheets.write(2, [["traits", "x"]])
        self.assertTrue(sheets.actualiser(self.ONGLETS))

    def test_sans_drive_on_lit_a_chaque_fois(self):
        session = Session()
        session.drive_en_panne = True
        sheets = api(session)
        sheets.actualiser(self.ONGLETS)
        self.assertTrue(sheets.actualiser(self.ONGLETS))
        self.assertEqual(session.lectures_sheet(), 2)


class EcritureTests(unittest.TestCase):
    def setUp(self):
        self.dossier = tempfile.TemporaryDirectory()
        racine = Path(self.dossier.name)
        (racine / "Outils").mkdir()
        self.retail = racine / "retail"
        sv = self.retail / "WTF" / "Account" / "COMPTE" / "SavedVariables"
        sv.mkdir(parents=True)
        self.fichier = sv / "LesContesMalveillants_MJ.lua"
        self.fichier.write_text('LCM_MJ_DB = {\n["version"] = 2,\n}\n', encoding="utf-8")
        self.patches = [patch.object(db, "ROOT", racine),
                        patch.object(db, "ECRITURES", racine / "Outils" / ".gsheet_ecritures.json"),
                        patch.object(db.lcm_db, "lire_reglages", lambda: [])]
        for p in self.patches:
            p.start()
        self.racine = racine

    def tearDown(self):
        for p in self.patches:
            p.stop()
        self.dossier.cleanup()

    def zips(self):
        return sorted((self.racine / "Sauvegardes_LCM").glob("LCM_*.zip"))

    def test_archive_identique_ne_part_pas(self):
        session = Session()
        sheets = api(session)
        db.sauvegarder(sheets, self.retail)
        self.assertEqual(session.compter(":append"), 1)
        self.assertEqual(len(self.zips()), 1)
        vues = session.compter("values:batchUpdate")
        appels = len(session.appels)

        db.sauvegarder(sheets, self.retail)
        self.assertEqual(len(session.appels), appels, "rien n'a change : aucun appel")
        self.assertEqual(len(self.zips()), 1)

        self.fichier.write_text('LCM_MJ_DB = {\n["version"] = 3,\n}\n', encoding="utf-8")
        db.sauvegarder(sheets, self.retail)
        self.assertEqual(session.compter(":append"), 2)
        self.assertEqual(len(self.zips()), 2)
        self.assertEqual(session.compter("values:batchUpdate"), vues + 1,
                         "seule la vue qui a change est reecrite")

    def test_archive_locale_avant_le_reseau(self):
        session = Session()
        session.refus = [400]     # le Sheet refuse tout de suite
        with self.assertRaises(RuntimeError):
            db.sauvegarder(api(session), self.retail)
        self.assertEqual(len(self.zips()), 1, "la copie locale existe malgre l'echec")
        # Et l'envoi rate n'est pas note comme fait : il repart.
        session2 = Session()
        db.sauvegarder(api(session2), self.retail)
        self.assertEqual(session2.compter(":append"), 1)
        self.assertEqual(len(self.zips()), 1)

    def test_mise_en_forme_seulement_a_la_creation(self):
        session = Session()
        session.onglets = {db.BACKUP_TAB: db.BACKUP_HEADERS}
        sheets = api(session)
        sheets.prepare_backups()
        sheets.prepare_backups()
        self.assertEqual(session.compter(":batchUpdate", method="POST"), 0)
        self.assertEqual(session.compter("A1:F1", method="GET"), 1)


if __name__ == "__main__":
    unittest.main()
