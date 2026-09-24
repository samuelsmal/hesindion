import copy
import json
import os
import subprocess
import sys
import tempfile
import unittest

from amend_export import amend

HERE = os.path.dirname(__file__)


def export():
    return {
        "name": "Held",
        "pets": {"PET_1": {
            "name": "Kupperus", "attack": "Niederreiten", "dp": "2W6+7",
            "talents": "Klettern (keine Probe erlaubt), Kraftakt 8, Willenskraft 8",
            "notes": "Tritt: AT 19 TP 1W6+8 RW mittel; Niederreiten: AT 19 TP 2W6+7 RW mittel; Kampfverhalten: ruhig.",
            "totalAp": "336", "spentAp": "336",
            "cou": "15", "sgc": "10", "int": "12", "cha": "12", "dex": "8", "agi": "15", "con": "26", "str": "28",
            "lp": "137", "ini": "15+1W6", "mov": "15", "at": "19",
        }},
    }


def build():
    return {"schemaVersion": 1, "pets": {"Kupperus": {
        "breed": "svellttaler-kaltblut",
        "ap": {"total": 336},
        "purchases": [
            {"advantage": "Geduldig", "ap": 5}, {"advantage": "Ausdauernd", "ap": 15},
            {"advantage": "Heldenwuchs", "ap": 15}, {"advantage": "Zähes Tier", "ap": 12},
            {"advantage": "Schnell", "ap": 8}, {"advantage": "Stark", "ap": 15},
            {"advantage": "Tapfer", "ap": 15}, {"advantage": "Sprungsicher", "ap": 5},
            {"advantage": "Loyal", "ap": 10}, {"training": "Kampftier", "ap": 17},
            {"trick": "Komm", "ap": 3},
            {"raise": "vw", "from": 7, "to": 14}, {"raise": "at", "from": 17, "to": 19},
            {"buy": "lep", "count": 16},
            {"raise": "talent:Willenskraft", "from": 3, "to": 8},
            {"raise": "talent:Selbstbeherrschung", "from": 4, "to": 8},
            {"raise": "talent:Körperbeherrschung", "from": 4, "to": 8},
            {"raise": "talent:Sinnesschärfe", "from": 4, "to": 8},
            {"raise": "talent:Einschüchtern", "from": 6, "to": 10},
        ],
        "values": {
            "attributes": {"mu": 15, "kl": 10, "in": 12, "ch": 12, "ff": 8, "ge": 15, "ko": 26, "kk": 28},
            "lep": 137, "ini": "15+1W6", "gs": 15, "vw": 14, "rs": 0, "be": 0,
            "attacks": [
                {"name": "Tritt", "at": 19, "tp": "1W6+8", "rw": "mittel"},
                {"name": "Niederreiten", "at": 19, "tp": "2W6+7", "rw": "mittel"},
            ],
            "talents": {"Kraftakt": 8, "Willenskraft": 8},
            "advantages": ["Ruhiges Temperament", "Geduldig"],
            "abilities": ["Mächtiger Schlag"],
            "training": ["Reittier", "Kampftier"],
            "tricks": ["Aus", "Fass I", "Fass II", "Komm"],
        },
    }}}


class AmendTests(unittest.TestCase):
    def assertOneError(self, errors, fragment):
        self.assertEqual(len(errors), 1, errors)
        self.assertIn(fragment, errors[0])
        self.assertIn("Kupperus", errors[0])

    def test_consistent_build_injects_block(self):
        e = export()
        self.assertEqual(amend(e, build()), [])
        pet = e["hesindion"]["pets"]["PET_1"]
        self.assertEqual(e["hesindion"]["schemaVersion"], 1)
        self.assertEqual(pet["ap"], {"total": 336, "spent": 336})
        self.assertIn({"kind": "raise", "target": "vw", "from": 7, "to": 14, "ap": 30}, pet["purchases"])
        self.assertEqual(pet["values"]["vw"], 14)
        self.assertEqual(list(e)[-1], "hesindion")

    def test_values_lists_default_to_empty(self):
        b = build()
        del b["pets"]["Kupperus"]["values"]["tricks"]
        e = export()
        amend(e, b)
        self.assertEqual(e["hesindion"]["pets"]["PET_1"]["values"]["tricks"], [])

    def test_unmatched_pet(self):
        b = build()
        b["pets"]["Kuperus"] = b["pets"].pop("Kupperus")
        errors = amend(export(), b)
        self.assertEqual(len(errors), 1, errors)
        self.assertIn("no pet named 'Kuperus'", errors[0])

    def test_sum_mismatch(self):
        b = build()
        b["pets"]["Kupperus"]["ap"]["total"] = 330
        errors = amend(export(), b)  # also totalAp/spentAp, which disagree with 330 too
        self.assertIn("Kupperus: purchases sum to 336 AP, ap.total is 330", errors[0])

    def test_export_ap_mismatch(self):
        e = export()
        e["pets"]["PET_1"]["spentAp"] = "312"
        self.assertOneError(amend(e, build()), "spentAp")

    def test_lep_over_ko(self):
        b = build()
        purchases = b["pets"]["Kupperus"]["purchases"]
        purchases[purchases.index({"buy": "lep", "count": 16})] = {"buy": "lep", "count": 27}
        errors = amend(export(), b)
        self.assertTrue(any("bought LeP 27 exceed KO 26" in m for m in errors), errors)

    def test_bad_attack(self):
        b = build()
        b["pets"]["Kupperus"]["values"]["attacks"][0]["rw"] = "Mittel"
        errors = amend(export(), b)
        self.assertTrue(any("attack Tritt" in m and "rw" in m for m in errors), errors)

    def test_attribute_mismatch(self):
        e = export()
        e["pets"]["PET_1"]["str"] = "27"
        self.assertOneError(amend(e, build()), "str is 27, build says 28")

    def test_main_attack_mismatch(self):
        e = export()
        e["pets"]["PET_1"]["at"] = "18"
        self.assertOneError(amend(e, build()), "at is 18, build says 19")

    def test_talent_mismatch(self):
        e = export()
        e["pets"]["PET_1"]["talents"] = "Kraftakt 8, Willenskraft 3"
        self.assertOneError(amend(e, build()), "talent Willenskraft is 3, build says 8")

    def test_unreadable_notes_attack(self):
        e = export()
        e["pets"]["PET_1"]["notes"] = "Tritt: AT 196TP 1W6+8 RW mittel; Niederreiten: AT 19 TP 2W6+7 RW mittel"
        self.assertOneError(amend(e, build()), "notes: attack Tritt unreadable")

    def test_pa_mismatch(self):
        e = export()
        e["pets"]["PET_1"]["pa"] = "7"
        self.assertOneError(amend(e, build()), "pa is 7, build says 14")

    def test_fix_rewrites_export_fields(self):
        e = export()
        pet = e["pets"]["PET_1"]
        pet.update({"str": "27", "at": "18", "talents": "Klettern (keine Probe erlaubt), Kraftakt 8, Willenskraft 3",
                    "notes": "Tritt: AT 196TP 1W6+8 RW mittel; Niederreiten: AT 19 TP 2W6+7 RW mittel; Kampfverhalten: ruhig."})
        del pet["totalAp"]
        self.assertEqual(amend(e, build(), fix=True), [])
        self.assertEqual((pet["str"], pet["at"], pet["pa"], pet["pro"], pet["totalAp"]), ("28", "19", "14", "0", "336"))
        self.assertEqual(pet["talents"], "Klettern (keine Probe erlaubt), Kraftakt 8, Willenskraft 8")
        self.assertIn("Tritt: AT 19 TP 1W6+8 RW mittel", pet["notes"])
        self.assertIn("Kampfverhalten: ruhig.", pet["notes"])
        self.assertEqual(amend(copy.deepcopy(e), build()), [])


class CliTests(unittest.TestCase):
    def run_cli(self, *args):
        return subprocess.run([sys.executable, os.path.join(HERE, "amend_export.py"), *args],
                              capture_output=True, text=True)

    def write(self, directory, e, b):
        import yaml
        path = os.path.join(directory, "Held.json")
        with open(path, "w", encoding="utf-8") as f:
            f.write(json.dumps(e, ensure_ascii=False, separators=(",", ":")))
        with open(os.path.join(directory, "Held.companions.yaml"), "w", encoding="utf-8") as f:
            yaml.safe_dump(b, f, allow_unicode=True)
        return path

    def test_writes_compact_utf8(self):
        with tempfile.TemporaryDirectory() as d:
            path = self.write(d, export(), build())
            result = self.run_cli(path)
            self.assertEqual(result.returncode, 0, result.stderr)
            raw = open(path, encoding="utf-8").read()
            self.assertIn('"hesindion":{"schemaVersion":1', raw)
            self.assertIn("Mächtiger Schlag", raw)

    def test_error_leaves_file_untouched(self):
        with tempfile.TemporaryDirectory() as d:
            e = export()
            e["pets"]["PET_1"]["str"] = "27"
            path = self.write(d, e, build())
            before = open(path, encoding="utf-8").read()
            result = self.run_cli(path)
            self.assertEqual(result.returncode, 1)
            self.assertIn("str is 27, build says 28", result.stderr)
            self.assertEqual(open(path, encoding="utf-8").read(), before)

    def test_check_does_not_write(self):
        with tempfile.TemporaryDirectory() as d:
            path = self.write(d, export(), build())
            before = open(path, encoding="utf-8").read()
            self.assertEqual(self.run_cli(path, "--check").returncode, 0)
            self.assertEqual(open(path, encoding="utf-8").read(), before)

    def test_boronmir_sample_is_consistent(self):
        sample = os.path.join(HERE, "..", "..", "specs", "heroes",
                              "Boronmir Siebenfeld von Greifenfurt (2026-09-24).json")
        result = self.run_cli(sample, "--check")
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
