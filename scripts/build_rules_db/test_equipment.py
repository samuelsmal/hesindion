import sqlite3
import tempfile
import unittest
from pathlib import Path

import yaml

import build_db


DE_YAML = """
- id: ITEMTPL_19
  name: Rabenschnabel
  versions:
    - note: "geweiht (Boron); borongeweihte Waffen sind nur für Borongeweihte erwerbbar\\n"
    - advantage: "Statt mit der Hammerseite anzugreifen, kann der Held auch die Dornenspitze verwenden.<br>\\nZweite Zeile.\\n"
      disadvantage: "Nach einem bestätigten Patzer bei einer Attacke erhält der Träger zusätzlich 1 Stufe *Betäubung*.\\n"
- id: ITEMTPL_99
  name: Wagenrad
"""

UNIV_YAML = """
- id: ITEMTPL_19
  gr: 1
  special:
    combatTechnique: CT_5
    damageDiceNumber: 1
    damageDiceSides: 6
    damageFlat: 4
    at: 0
    pa: -1
    reach: 2
- id: ITEMTPL_99
  gr: 8
  special: {}
"""


class ImportEquipmentTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.source = Path(self.tmp.name)
        (self.source / "de-DE").mkdir()
        (self.source / "univ").mkdir()
        (self.source / "de-DE" / "Equipment.yaml").write_text(DE_YAML, encoding="utf-8")
        (self.source / "univ" / "Equipment.yaml").write_text(UNIV_YAML, encoding="utf-8")

        self.conn = sqlite3.connect(":memory:")
        build_db.create_schema(self.conn)

    def tearDown(self):
        self.conn.close()
        self.tmp.cleanup()

    def test_imports_the_rabenschnabel_row(self):
        count = build_db.import_equipment(self.conn, self.source)
        self.assertEqual(count, 1)

        row = self.conn.execute(
            """SELECT name, gr, combat_technique, damage, at, pa, reach, note, advantage, disadvantage
               FROM equipment WHERE id = 'ITEMTPL_19'"""
        ).fetchone()
        self.assertIsNotNone(row)
        name, gr, ct, damage, at, pa, reach, note, adv, dis = row
        self.assertEqual(name, "Rabenschnabel")
        self.assertEqual(gr, 1)
        self.assertEqual(ct, "CT_5")
        self.assertEqual(damage, "1W6+4")
        self.assertEqual(at, 0)
        self.assertEqual(pa, -1)
        self.assertEqual(reach, 2)
        self.assertTrue(note.startswith("geweiht (Boron)"))
        self.assertIn("Dornenspitze", adv)
        self.assertIn("\nZweite Zeile.", adv)
        self.assertIn("Betäubung", dis)
        # <br> is turned into a newline and the text is stripped.
        self.assertFalse(adv.endswith("\n"))
        self.assertFalse(adv.startswith(" "))

    def test_a_gr_8_item_is_not_imported(self):
        build_db.import_equipment(self.conn, self.source)
        row = self.conn.execute(
            "SELECT 1 FROM equipment WHERE id = 'ITEMTPL_99'"
        ).fetchone()
        self.assertIsNone(row)


if __name__ == "__main__":
    unittest.main()
