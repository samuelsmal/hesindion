import copy
import json
import os
import subprocess
import sys
import tempfile
import unittest

from amend_export import amend, init_build

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

    def test_bool_attack_at(self):
        b = build()
        b["pets"]["Kupperus"]["values"]["attacks"][0]["at"] = True
        errors = amend(export(), b)
        self.assertTrue(any("attack Tritt" in m and "at must be an integer" in m for m in errors), errors)

    def test_bool_in_tricks(self):
        b = build()
        b["pets"]["Kupperus"]["values"]["tricks"] = ["Aus", False]
        errors = amend(export(), b)
        self.assertTrue(any("values.tricks item False is not a string" in m for m in errors), errors)

    def test_comments_stay_out_of_the_block(self):
        b = build()
        b["comment"] = "the build"
        b["pets"]["Kupperus"]["purchases"][1]["comment"] = "KO +2"
        b["pets"]["Kupperus"]["values"]["comment"] = "lep: 121 + 16 bought"
        e = export()
        self.assertEqual(amend(e, b), [])
        self.assertNotIn("comment", json.dumps(e["hesindion"]))

    def test_float_be(self):
        b = build()
        b["pets"]["Kupperus"]["values"]["be"] = 0.5
        errors = amend(export(), b)
        self.assertTrue(any("values.be" in m for m in errors), errors)

    def test_scalar_advantages(self):
        b = build()
        b["pets"]["Kupperus"]["values"]["advantages"] = "Geduldig"
        errors = amend(export(), b)
        self.assertTrue(any("values.advantages" in m for m in errors), errors)

    def test_bool_vw(self):
        b = build()
        b["pets"]["Kupperus"]["values"]["vw"] = True
        errors = amend(export(), b)
        self.assertTrue(any("values.vw" in m for m in errors), errors)

    def test_rs_and_be_are_optional(self):
        # vw/rs/be are optional per the schema and CompanionData.Values (Int?);
        # expected_fields() already skips a None one. Omitting them is not an error.
        b = build()
        del b["pets"]["Kupperus"]["values"]["rs"]
        del b["pets"]["Kupperus"]["values"]["be"]
        self.assertEqual(amend(export(), b), [])

    def test_non_int_ap_total(self):
        b = build()
        b["pets"]["Kupperus"]["ap"]["total"] = True
        errors = amend(export(), b)
        self.assertTrue(any("ap.total" in m and "integer" in m for m in errors), errors)

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


class OptionalPartsTests(unittest.TestCase):
    """Only what the export itself holds is needed; every other part of a build is optional."""

    def minimal(self):
        return {"schemaVersion": 1, "pets": {"Kupperus": {"values": {"vw": 14}}}}

    def test_minimal_build_injects_a_complete_block(self):
        e = export()
        self.assertEqual(amend(e, self.minimal()), [])
        pet = e["hesindion"]["pets"]["PET_1"]
        self.assertEqual(pet["ap"], {"total": 336, "spent": 336})  # from the export's totalAp/spentAp
        self.assertEqual(pet["purchases"], [])
        self.assertEqual([a["name"] for a in pet["values"]["attacks"]], ["Tritt", "Niederreiten"])
        self.assertEqual(pet["values"]["vw"], 14)
        for key in ("advantages", "abilities", "training", "tricks"):
            self.assertEqual(pet["values"][key], [])

    def test_minimal_build_without_export_ap(self):
        e = export()
        del e["pets"]["PET_1"]["totalAp"], e["pets"]["PET_1"]["spentAp"]
        self.assertEqual(amend(e, self.minimal()), [])
        self.assertEqual(e["hesindion"]["pets"]["PET_1"]["ap"], {"total": 0, "spent": 0})

    def test_fix_leaves_ap_alone_without_ap_in_build(self):
        e = export()
        del e["pets"]["PET_1"]["totalAp"]
        self.assertEqual(amend(e, self.minimal(), fix=True), [])
        self.assertNotIn("totalAp", e["pets"]["PET_1"])

    def test_purchases_without_ap_total(self):
        b = build()
        del b["pets"]["Kupperus"]["ap"]
        e = export()
        self.assertEqual(amend(e, b), [])
        self.assertEqual(e["hesindion"]["pets"]["PET_1"]["ap"], {"total": 336, "spent": 336})

    def test_ap_total_without_purchases(self):
        b = self.minimal()
        b["pets"]["Kupperus"]["ap"] = {"total": 336}
        e = export()
        self.assertEqual(amend(e, b), [])
        self.assertEqual(e["hesindion"]["pets"]["PET_1"]["ap"], {"total": 336, "spent": 336})

    def test_stated_ap_is_still_checked_against_the_export(self):
        b = self.minimal()
        b["pets"]["Kupperus"]["ap"] = {"total": 330}
        errors = amend(export(), b)
        self.assertTrue(any("totalAp is 336, build says 330" in m for m in errors), errors)

    def test_stated_values_are_still_checked(self):
        b = self.minimal()
        b["pets"]["Kupperus"]["values"]["attributes"] = {"kk": 27}
        errors = amend(export(), b)
        self.assertTrue(any("str is 28, build says 27" in m for m in errors), errors)


class InitTests(unittest.TestCase):
    def test_init_build_passes_the_check(self):
        e = export()
        b = init_build(e)
        self.assertEqual(amend(copy.deepcopy(e), b), [])
        values = b["pets"]["Kupperus"]["values"]
        self.assertEqual(values["attributes"]["kk"], 28)
        self.assertEqual((values["lep"], values["ini"], values["gs"]), (137, "15+1W6", 15))
        self.assertEqual(values["talents"], {"Kraftakt": 8, "Willenskraft": 8})
        self.assertEqual(values["attacks"][0], {"name": "Tritt", "at": 19, "tp": "1W6+8", "rw": "mittel"})
        self.assertNotIn("purchases", b["pets"]["Kupperus"])

    def test_init_adds_the_main_attack_missing_from_notes(self):
        e = export()
        e["pets"]["PET_1"].update({"notes": "Kampfverhalten: ruhig.", "reach": "Mittel"})
        b = init_build(e)
        self.assertEqual(b["pets"]["Kupperus"]["values"]["attacks"],
                         [{"name": "Niederreiten", "at": 19, "tp": "2W6+7", "rw": "mittel"}])

    def test_init_boronmir_sample_passes_the_check(self):
        sample = os.path.join(HERE, "..", "..", "specs", "heroes",
                              "Boronmir Siebenfeld von Greifenfurt.json")
        with open(sample, encoding="utf-8") as f:
            e = json.load(f)
        self.assertEqual(amend(copy.deepcopy(e), init_build(e)), [])


class CliTests(unittest.TestCase):
    def run_cli(self, *args):
        return subprocess.run([sys.executable, os.path.join(HERE, "amend_export.py"), *args],
                              capture_output=True, text=True)

    def write(self, directory, e, b):
        path = os.path.join(directory, "Held.json")
        with open(path, "w", encoding="utf-8") as f:
            f.write(json.dumps(e, ensure_ascii=False, separators=(",", ":")))
        with open(os.path.join(directory, "Held.companions.json"), "w", encoding="utf-8") as f:
            json.dump(b, f, ensure_ascii=False, indent=2)
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

    def test_init_writes_a_build_file_once(self):
        with tempfile.TemporaryDirectory() as d:
            path = self.write(d, export(), build())
            os.remove(os.path.join(d, "Held.companions.json"))
            before = open(path, encoding="utf-8").read()
            result = self.run_cli(path, "--init")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(open(path, encoding="utf-8").read(), before)  # the export is untouched
            with open(os.path.join(d, "Held.companions.json"), encoding="utf-8") as f:
                self.assertIn("Kupperus", json.load(f)["pets"])
            self.assertEqual(self.run_cli(path, "--check").returncode, 0)
            again = self.run_cli(path, "--init")
            self.assertEqual(again.returncode, 1)
            self.assertIn("already exists", again.stderr)

    def test_boronmir_sample_is_consistent(self):
        sample = os.path.join(HERE, "..", "..", "specs", "heroes",
                              "Boronmir Siebenfeld von Greifenfurt (2026-09-24).json")
        result = self.run_cli(sample, "--check")
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
