import json
import tempfile
import unittest
from pathlib import Path

from rulec import hero
from rulec.vocab import REPO

BORONMIR = REPO / "docs" / "sample_heros" / "Boronmir Siebenfeld von Greifenfurt (2026-09-24).json"


class FromOptolithTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.h = hero.from_optolith(BORONMIR)
        cls.facts = {f["name"]: f for f in cls.h["facts"]}

    def test_level_defaults_to_one_and_reads_tier(self):
        self.assertEqual(self.h["owned"]["ADV_54"], {"level": 1})
        self.assertEqual(self.h["owned"]["ADV_25"], {"level": 2})

    def test_sid_becomes_option(self):
        self.assertEqual(self.h["owned"]["DISADV_37"], {"level": 1, "option": 2})

    def test_sid2_becomes_option2(self):
        # SA_9 Fertigkeitsspezialisierung: the talent (`sid`) and its Anwendungsgebiet (`sid2`).
        d = {"id": "H", "attr": {"values": [{"id": "ATTR_1", "value": 12}]},
             "activatable": {"SA_9": [{"sid": "TAL_10", "sid2": 2}]}}
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "h.json"
            path.write_text(json.dumps(d), encoding="utf-8")
            h = hero.from_optolith(path)
        self.assertEqual(h["owned"]["SA_9"], {"level": 1, "option": "TAL_10", "option2": 2})

    def test_attributes_by_name(self):
        self.assertEqual(self.facts["attr.MU"], {"name": "attr.MU", "value": 14, "owner": "sheet"})
        self.assertEqual(self.facts["attr.KO"]["value"], 15)
        self.assertEqual(self.facts["attr.KK"]["value"], 14)

    def test_techniques_and_talents(self):
        self.assertEqual(self.facts["ktw.CT_5"], {"name": "ktw.CT_5", "value": 14, "owner": "sheet"})
        self.assertEqual(self.facts["fw.TAL_23"], {"name": "fw.TAL_23", "value": 9, "owner": "sheet"})

    def test_every_fact_is_owned_by_the_sheet(self):
        self.assertEqual({f["owner"] for f in self.h["facts"]}, {"sheet"})

    def test_empty_activatables_are_left_out(self):
        for rid in ("ADV_5", "ADV_75", "DISADV_5", "DISADV_28", "DISADV_40", "DISADV_55",
                    "SA_48", "SA_59", "SA_66", "SA_884"):
            self.assertNotIn(rid, self.h["owned"])


if __name__ == "__main__":
    unittest.main()
