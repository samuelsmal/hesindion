# Companion Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give animal companions a checked, structured data block inside the Optolith export. A local tool writes the block, Hesindion imports it, and a re-import without the block asks whether to keep the previous companion data.

**Architecture:**
- **Python tool** (`scripts/companions/`, PyYAML only). It reads a hand-written `<export>.companions.yaml`, prices every purchase with the Kat C column, checks the export against the build, and writes a `hesindion` block into the export JSON.
- **Import.** The Swift importer decodes that block into new optional `Pet` properties.
- **Re-import.** It gets a pre-flight (`companionConflicts`) and a `keepingCompanionDataFor:` parameter, and `HeroListView` asks through a `DSAModal`.

**Tech Stack:** Python 3 + PyYAML + unittest; Swift 6 / SwiftUI / SwiftData, Swift Testing, XCUITest.

**Spec:** `docs/plans/2026-09-24-companion-data-design.md`

## Global Constraints

- Work only in the worktree `/Users/SamuelvonBaussnern/proj/50_priv/Hesindion/companion-data`, branch `feat/companion-data`. Never commit to `main`.
- **Kat C:** a step to value v costs `3` for v ≤ 12, else `3 × (v − 11)`. The nth bought LeP costs the step to n.
- **Export write:** `json.dumps(obj, ensure_ascii=False, separators=(",", ":"))`. The Boronmir sample round-trips byte-identical this way (verified). Keep key order and add `hesindion` as the last root key.
- **Optolith pet fields are strings** (`"cou": "15"`). When `--fix` writes them, it writes strings.
- **The canonical attack line** is `Name: AT <at> TP <tp> RW <rw>`, and the app's regex reads it: `([A-ZÄÖÜa-zäöüß]+):\s*AT\s+(\d+)\s+TP\s+(\d+W\d+(?:[+-]\d+)?)\s+RW\s+(kurz|mittel|lang)`.
- **The block schema version is `1`.** `values` in the block always carries `attacks`, `advantages`, `abilities`, `training` and `tricks` (lists, possibly empty).
- **"Keep previous" copies only:** `defense`, `armor`, `encumbrance`, `advantages`, `abilities`, `training`, `tricks`, `purchases`, `apTotal`, `apSpent`, `attacks`. Everything else comes from the new export.
- **UI:**
  - No `.alert` for the new question. Use `DSAModal`/`DSAModalButton`, added via `.overlay`.
  - All strings go in `Strings.swift`, en + de.
  - List pets through `petsInOrder`.
- **Tests:**
  - Run one xcodebuild target at a time (AGENTS.md).
  - `Hesindion/Resources/UITestHero.json` must stay byte-identical, because snapshot tests depend on it.

**User decisions (already made):**
- "Purchases + final values": the tool checks costs and sums and does not compute final values.
- "Only the added data": keep-previous restores only the fields the block adds.
- The companion file is a YAML next to the export. The block lives under the `hesindion` key.
- Work happens in a new worktree branched from `review/neobrutalism-swiftui-audit` (done: `../companion-data`).
- The spec in `docs/plans/2026-09-24-companion-data-design.md` is approved ("lgtm").

**Deviation from spec §7, recorded in Task 9:** there is no `PendingImport` object. Unsaved SwiftData models would have to survive while the modal waits. Instead:
- `companionConflicts(in:context:)` runs first.
- `importHero(from:context:keepingCompanionDataFor:)` imports afterwards.

Behaviour is identical. Spec §6's "chips" become `FieldRow`s, which is the section's existing idiom.

---

## File map

| File | Responsibility |
|---|---|
| `scripts/companions/companions.py` | Kat C prices, purchase normalisation (new) |
| `scripts/companions/amend_export.py` | checks, `--fix`, block injection, CLI (new) |
| `scripts/companions/test_companions.py`, `test_amend_export.py` | unittest (new) |
| `specs/data/companion-block.schema.json` | JSON Schema of the block (new, documentation + contract) |
| `docs/sample_heros/Boronmir Siebenfeld von Greifenfurt (2026-09-24).companions.yaml` | Kupperus's build (new) |
| `docs/sample_heros/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json` | fixed + block (new file in branch) |
| `Hesindion/Resources/UITestHeroCompanions.json` | UI fixture: UITestHero + block (new) |
| `Hesindion/Models/Pet.swift` | new properties, `PetPurchase`, `adoptCompanionData`, `hasMightyBlow` |
| `Hesindion/Services/CompanionData.swift` | decoding the block (new) |
| `Hesindion/Services/OptolithImportService.swift` | reads the block, conflicts, keep |
| `Hesindion/Views/HeroListView.swift` | the re-import question |
| `Hesindion/Views/HeroDetailView.swift` | shows the companion data |
| `Hesindion/Views/CombatAttackViews.swift` | Mächtiger Schlag via `hasMightyBlow` |
| `Hesindion/UITestSeed.swift` | fixture and re-import launch arguments |
| `Hesindion/Theme/Strings.swift` | strings |
| `HesindionTests/CompanionImportTests.swift` | unit tests (new) |
| `HesindionUITests/CompanionReimportFlowTests.swift` | UI test (new) |
| `Makefile`, `AGENTS.md`, `CHANGELOG.md`, `docs/adr/0015-companion-data-in-optolith-export.md` | tooling + docs |

---

### Task 1: Kat C pricing and purchase normalisation

**Goal:** `scripts/companions/companions.py` prices and normalises every purchase kind in spec §3, with unit tests.

**Files:**
- Create: `scripts/companions/companions.py`
- Test: `scripts/companions/test_companions.py`

**Acceptance Criteria:**
- [ ] `raise_cost(7, 14) == 30`, `raise_cost(17, 19) == 45`, `raise_cost(25, 26) == 45`, `lep_cost(16) == 78`
- [ ] `normalise` returns `{kind, name, ap}` for advantage/training/trick/ability, `{kind:"raise", target, from, to, ap}`, and `{kind:"buy", target:"lep", count, ap}`
- [ ] An explicit wrong `ap` on a raise raises `BuildError` with the message `raise vw 7→14 costs 30 AP, file says 25`
- [ ] Unknown targets, `to <= from`, and unknown purchase shapes raise `BuildError`

**Verify:** `python3 -m unittest discover -s scripts/companions -p 'test_*.py' -v` → all OK

**Steps:**

- [ ] **Step 1: Write the failing tests** in `scripts/companions/test_companions.py`:

```python
import unittest

from companions import BuildError, kat_c_step, lep_cost, normalise, raise_cost


class KatCTests(unittest.TestCase):
    def test_steps(self):
        self.assertEqual([kat_c_step(v) for v in (1, 12, 13, 18, 25, 26)], [3, 3, 6, 21, 42, 45])

    def test_raise_cost(self):
        self.assertEqual(raise_cost(7, 14), 30)
        self.assertEqual(raise_cost(17, 19), 45)
        self.assertEqual(raise_cost(3, 8), 15)
        self.assertEqual(raise_cost(25, 26), 45)

    def test_lep_cost(self):
        self.assertEqual(lep_cost(12), 36)
        self.assertEqual(lep_cost(16), 78)


class NormaliseTests(unittest.TestCase):
    def test_named(self):
        self.assertEqual(normalise({"advantage": "Geduldig", "ap": 5}),
                         {"kind": "advantage", "name": "Geduldig", "ap": 5})
        self.assertEqual(normalise({"trick": "Komm", "ap": 3})["kind"], "trick")

    def test_named_needs_ap(self):
        with self.assertRaisesRegex(BuildError, "Geduldig"):
            normalise({"advantage": "Geduldig"})

    def test_raise(self):
        self.assertEqual(normalise({"raise": "vw", "from": 7, "to": 14}),
                         {"kind": "raise", "target": "vw", "from": 7, "to": 14, "ap": 30})
        self.assertEqual(normalise({"raise": "talent:Willenskraft", "from": 3, "to": 8})["ap"], 15)

    def test_raise_wrong_ap(self):
        with self.assertRaisesRegex(BuildError, "raise vw 7→14 costs 30 AP, file says 25"):
            normalise({"raise": "vw", "from": 7, "to": 14, "ap": 25})

    def test_raise_bad(self):
        for bad in ({"raise": "lp", "from": 1, "to": 2},
                    {"raise": "vw", "from": 5, "to": 5},
                    {"raise": "talent:", "from": 1, "to": 2}):
            with self.assertRaises(BuildError):
                normalise(bad)

    def test_buy_lep(self):
        self.assertEqual(normalise({"buy": "lep", "count": 16}),
                         {"kind": "buy", "target": "lep", "count": 16, "ap": 78})

    def test_unknown(self):
        with self.assertRaises(BuildError):
            normalise({"spell": "Balsam"})


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to watch them fail.** `python3 -m unittest discover -s scripts/companions -p 'test_*.py' -v` should give `ModuleNotFoundError: companions`.

- [ ] **Step 3: Implement** `scripts/companions/companions.py`:

```python
"""Companion builds: the Kat C price list and the purchase normaliser.

Animal companions raise attributes, talents, LE, AT and VW in column C
(Kodex des Schwertes p. 153); the column is the Regelwerk's Kostentabelle,
which ends at 25 and is continued here by its own linear rule.
See docs/plans/2026-09-24-companion-data-design.md §3.
"""

ATTRIBUTES = ("mu", "kl", "in", "ch", "ff", "ge", "ko", "kk")
NAMED_KINDS = ("advantage", "training", "trick", "ability")


class BuildError(ValueError):
    pass


def kat_c_step(value):
    """AP for raising a value to `value` (from value - 1) in column C."""
    return 3 if value <= 12 else 3 * (value - 11)


def raise_cost(start, end):
    return sum(kat_c_step(v) for v in range(start + 1, end + 1))


def lep_cost(count):
    """The nth bought LeP costs what raising a value to n costs."""
    return sum(kat_c_step(n) for n in range(1, count + 1))


def _valid_target(target):
    if target in ATTRIBUTES or target in ("vw", "at"):
        return True
    return target.startswith("talent:") and len(target) > len("talent:")


def normalise(purchase):
    """One YAML purchase -> the block's {kind, name|target, ap, ...}."""
    for kind in NAMED_KINDS:
        if kind in purchase:
            ap = purchase.get("ap")
            if not isinstance(ap, int) or ap < 0:
                raise BuildError(f"{kind} {purchase[kind]}: needs a non-negative integer ap")
            return {"kind": kind, "name": str(purchase[kind]), "ap": ap}
    if "raise" in purchase:
        target = str(purchase["raise"])
        start, end = purchase.get("from"), purchase.get("to")
        if not _valid_target(target):
            raise BuildError(f"raise {target}: unknown target")
        if not (isinstance(start, int) and isinstance(end, int) and end > start):
            raise BuildError(f"raise {target}: needs integers from < to")
        ap = raise_cost(start, end)
        if "ap" in purchase and purchase["ap"] != ap:
            raise BuildError(f"raise {target} {start}→{end} costs {ap} AP, file says {purchase['ap']}")
        return {"kind": "raise", "target": target, "from": start, "to": end, "ap": ap}
    if purchase.get("buy") == "lep":
        count = purchase.get("count")
        if not isinstance(count, int) or count < 1:
            raise BuildError("buy lep: needs a positive integer count")
        ap = lep_cost(count)
        if "ap" in purchase and purchase["ap"] != ap:
            raise BuildError(f"buy lep ×{count} costs {ap} AP, file says {purchase['ap']}")
        return {"kind": "buy", "target": "lep", "count": count, "ap": ap}
    raise BuildError(f"unknown purchase {purchase!r}")
```

- [ ] **Step 4: Run the tests again.** They should all pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/companions/companions.py scripts/companions/test_companions.py
git commit -m "feat(companions): price companion purchases with the Kat C column"
```

---

### Task 2: Export checks, `--fix`, block injection and the CLI

**Goal:** `scripts/companions/amend_export.py` implements spec §5. It checks a companion YAML against an Optolith export, optionally fixes the export's own pet fields, writes the `hesindion` block, and adds the Makefile targets and the JSON Schema.

**Files:**
- Create: `scripts/companions/amend_export.py`, `scripts/companions/test_amend_export.py`, `specs/data/companion-block.schema.json`
- Modify: `Makefile` (after the `test-rules-db` target, ~line 127)

**Acceptance Criteria:**
- [ ] `amend(export, companions, fix=False)` returns `[]` and adds `export["hesindion"]` for a consistent build. The block's purchases carry their prices and `ap.spent` equals the sum.
- [ ] Each of these gives one error string naming the pet and field:
  - an unmatched pet name
  - Σ purchases ≠ `ap.total`
  - `totalAp`/`spentAp` ≠ `ap.total`
  - bought LeP > KO
  - a bad attack (`tp`/`rw`)
  - an attribute, `lp`, `ini`, `mov`, `at` or `dp` mismatch
  - a talent mismatch
  - an unreadable notes attack (`Biss: AT 156TP`)
  - `pa`/`pro` ≠ `vw`/`rs`
- [ ] With `fix=True`, the export's `cou…str`, `lp`, `ini`, `mov`, `at`, `dp`, `pa`, `pro`, `totalAp`, `spentAp`, the talents string and the notes attack lines are set from the build, and the same checks then pass. Non-attack prose in `notes` survives.
- [ ] The CLI exits 1 and leaves the file untouched on any error. `--check` never writes. Output is compact, `ensure_ascii=False`.
- [ ] `make test-companions` runs the tests, and `make companions HERO=…` runs the tool.

**Verify:** `make test-companions` → all OK

**Steps:**

- [ ] **Step 1: Write the failing tests** in `scripts/companions/test_amend_export.py`:

```python
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


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to watch them fail.** `python3 -m unittest discover -s scripts/companions -p 'test_*.py' -v` should give `ModuleNotFoundError: amend_export`.

- [ ] **Step 3: Implement** `scripts/companions/amend_export.py`:

```python
#!/usr/bin/env python3
"""Check a companion build against its Optolith export and inject it.

    amend_export.py <export.json> [--companions X.yaml] [--out Y.json] [--check] [--fix]

Reads <export>.companions.yaml by default. Writes the `hesindion` block
(docs/plans/2026-09-24-companion-data-design.md §4) only when every check
passes; --fix first sets the export's own pet fields from the build.
"""
import argparse
import json
import os
import re
import sys

import yaml

from companions import BuildError, normalise

EXPORT_ATTRIBUTES = {"mu": "cou", "kl": "sgc", "in": "int", "ch": "cha",
                     "ff": "dex", "ge": "agi", "ko": "con", "kk": "str"}
VALUE_LISTS = ("attacks", "advantages", "abilities", "training", "tricks")
TP = re.compile(r"\d+W\d+(?:[+-]\d+)?")
RW = ("kurz", "mittel", "lang")
# The app's parsePetAttacks regex, verbatim.
ATTACK_LINE = re.compile(
    r"([A-ZÄÖÜa-zäöüß]+):\s*AT\s+(\d+)\s+TP\s+(\d+W\d+(?:[+-]\d+)?)\s+RW\s+(kurz|mittel|lang)")


def canonical_attack(attack):
    return f"{attack['name']}: AT {attack['at']} TP {attack['tp']} RW {attack['rw']}"


def parse_talents(text):
    """'Kraftakt 8, Klettern (…)' -> [(part, name or None, value or None)]."""
    parts = []
    for part in text.split(","):
        m = re.fullmatch(r"\s*(.+?)\s+(\d+)\s*", part)
        parts.append((part.strip(), m.group(1), int(m.group(2))) if m else (part.strip(), None, None))
    return parts


def main_attack(pet, values):
    return next((a for a in values["attacks"] if a["name"] == pet.get("attack")), None)


def expected_fields(values, ap_total):
    """Export field -> expected string, for the fields present in the build."""
    fields = {EXPORT_ATTRIBUTES[k]: str(v) for k, v in values.get("attributes", {}).items()}
    for export_key, value_key in (("lp", "lep"), ("ini", "ini"), ("mov", "gs"), ("pa", "vw"), ("pro", "rs")):
        if values.get(value_key) is not None:
            fields[export_key] = str(values[value_key])
    fields["totalAp"] = fields["spentAp"] = str(ap_total)
    return fields


def check_attacks(name, values):
    errors = []
    for attack in values["attacks"]:
        label = f"{name}: attack {attack.get('name')}"
        if not isinstance(attack.get("at"), int):
            errors.append(f"{label}: at must be an integer")
        if not TP.fullmatch(str(attack.get("tp", ""))):
            errors.append(f"{label}: tp {attack.get('tp')!r} is not like 1W6+3")
        if attack.get("rw") not in RW:
            errors.append(f"{label}: rw {attack.get('rw')!r} is not one of kurz, mittel, lang")
    return errors


def check_export(name, pet, values, ap_total):
    errors = []
    for key, expected in expected_fields(values, ap_total).items():
        if key in ("pa", "pro", "totalAp", "spentAp") and key not in pet:
            continue
        if str(pet.get(key)) != expected:
            errors.append(f"{name}: {key} is {pet.get(key)}, build says {expected}")
    attack = main_attack(pet, values)
    if attack is None:
        errors.append(f"{name}: attack {pet.get('attack')!r} is not in values.attacks")
    else:
        if str(pet.get("at")) != str(attack["at"]):
            errors.append(f"{name}: at is {pet.get('at')}, build says {attack['at']}")
        if pet.get("dp") != attack["tp"]:
            errors.append(f"{name}: dp is {pet.get('dp')}, build says {attack['tp']}")
    talents = values.get("talents", {})
    seen = set()
    for _, talent, value in parse_talents(pet.get("talents", "")):
        if talent is None:
            continue
        seen.add(talent)
        if talent not in talents:
            errors.append(f"{name}: talent {talent} {value} is not in values.talents")
        elif talents[talent] != value:
            errors.append(f"{name}: talent {talent} is {value}, build says {talents[talent]}")
    for talent in sorted(set(talents) - seen):
        errors.append(f"{name}: talent {talent} is missing from the export")
    found = {m.group(1): m for m in ATTACK_LINE.finditer(pet.get("notes", ""))}
    for attack in values["attacks"]:
        m = found.get(attack["name"])
        if m is None:
            errors.append(f"{name}: notes: attack {attack['name']} unreadable, "
                          f"expected '{canonical_attack(attack)}'")
        elif (int(m.group(2)), m.group(3), m.group(4)) != (attack["at"], attack["tp"], attack["rw"]):
            errors.append(f"{name}: notes: '{m.group(0)}', build says '{canonical_attack(attack)}'")
    return errors


def fix_export(pet, values, ap_total):
    for key, expected in expected_fields(values, ap_total).items():
        pet[key] = expected
    attack = main_attack(pet, values)
    if attack is not None:
        pet["at"], pet["dp"] = str(attack["at"]), attack["tp"]
    talents = values.get("talents", {})
    parts, seen = [], set()
    for part, talent, _ in parse_talents(pet.get("talents", "")):
        if talent in talents:
            seen.add(talent)
            parts.append(f"{talent} {talents[talent]}")
        elif part:
            parts.append(part)
    parts += [f"{t} {v}" for t, v in talents.items() if t not in seen]
    pet["talents"] = ", ".join(parts)
    notes = pet.get("notes", "")
    for attack in values["attacks"]:
        loose = re.compile(re.escape(attack["name"]) + r":\s*AT.*?RW\s+[A-Za-z]+", re.S)
        if loose.search(notes):
            notes = loose.sub(lambda _: canonical_attack(attack), notes, count=1)
        else:
            notes = f"{canonical_attack(attack)}; {notes}" if notes else canonical_attack(attack)
    pet["notes"] = notes


def amend(export, companions, fix=False):
    """Check every companion; on success add export['hesindion']. Returns errors."""
    errors, block = [], {}
    by_name = {}
    for key, pet in export.get("pets", {}).items():
        by_name.setdefault(pet.get("name"), []).append(key)
    for name, build in companions.get("pets", {}).items():
        keys = by_name.get(name, [])
        if len(keys) != 1:
            errors.append(f"{name}: no pet named {name!r} in the export" if not keys
                          else f"{name}: {len(keys)} pets share this name in the export")
            continue
        pet = export["pets"][keys[0]]
        values = dict(build.get("values", {}))
        for key in VALUE_LISTS:
            values.setdefault(key, [])
        ap_total = build.get("ap", {}).get("total")
        purchases = []
        for purchase in build.get("purchases", []):
            try:
                purchases.append(normalise(purchase))
            except BuildError as error:
                errors.append(f"{name}: {error}")
        spent = sum(p["ap"] for p in purchases)
        if spent != ap_total:
            errors.append(f"{name}: purchases sum to {spent} AP, ap.total is {ap_total}")
        ko = values.get("attributes", {}).get("ko")
        bought = sum(p["count"] for p in purchases if p["kind"] == "buy")
        if ko is not None and bought > ko:
            errors.append(f"{name}: bought LeP {bought} exceed KO {ko}")
        errors += check_attacks(name, values)
        if fix:
            fix_export(pet, values, ap_total)
        errors += check_export(name, pet, values, ap_total)
        block[keys[0]] = {"name": name, "breed": build.get("breed"),
                          "ap": {"total": ap_total, "spent": spent},
                          "purchases": purchases, "values": values}
    if not errors:
        export.pop("hesindion", None)
        export["hesindion"] = {"schemaVersion": 1, "pets": block}
    return errors


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("export")
    parser.add_argument("--companions")
    parser.add_argument("--out")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--fix", action="store_true")
    args = parser.parse_args(argv)
    companions_path = args.companions or os.path.splitext(args.export)[0] + ".companions.yaml"
    with open(args.export, encoding="utf-8") as f:
        export = json.load(f)
    with open(companions_path, encoding="utf-8") as f:
        companions = yaml.safe_load(f)
    errors = amend(export, companions, fix=args.fix)
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        return 1
    if not args.check:
        with open(args.out or args.export, "w", encoding="utf-8") as f:
            f.write(json.dumps(export, ensure_ascii=False, separators=(",", ":")))
    print(f"ok: {len(companions.get('pets', {}))} companion(s)"
          + ("" if args.check else f" written to {args.out or args.export}"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Write `specs/data/companion-block.schema.json`:**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "hesindion/companion-block.schema.json",
  "title": "Hesindion companion block (root key `hesindion` of an Optolith export)",
  "description": "Written by scripts/companions/amend_export.py; read by CompanionData.parse. See docs/plans/2026-09-24-companion-data-design.md §4.",
  "type": "object",
  "required": ["schemaVersion", "pets"],
  "properties": {
    "schemaVersion": { "const": 1 },
    "pets": {
      "type": "object",
      "additionalProperties": {
        "type": "object",
        "required": ["name", "ap", "purchases", "values"],
        "properties": {
          "name": { "type": "string" },
          "breed": { "type": ["string", "null"] },
          "ap": {
            "type": "object", "required": ["total", "spent"],
            "properties": { "total": { "type": "integer" }, "spent": { "type": "integer" } }
          },
          "purchases": {
            "type": "array",
            "items": {
              "type": "object", "required": ["kind", "ap"],
              "properties": {
                "kind": { "enum": ["advantage", "training", "trick", "ability", "raise", "buy"] },
                "name": { "type": "string" },
                "target": { "type": "string" },
                "ap": { "type": "integer", "minimum": 0 },
                "from": { "type": "integer" },
                "to": { "type": "integer" },
                "count": { "type": "integer", "minimum": 1 }
              }
            }
          },
          "values": {
            "type": "object",
            "required": ["attacks", "advantages", "abilities", "training", "tricks"],
            "properties": {
              "attributes": { "type": "object", "additionalProperties": { "type": "integer" } },
              "lep": { "type": "integer" },
              "ini": { "type": "string" },
              "gs": { "type": "integer" },
              "vw": { "type": "integer" },
              "rs": { "type": "integer" },
              "be": { "type": "integer" },
              "talents": { "type": "object", "additionalProperties": { "type": "integer" } },
              "attacks": {
                "type": "array",
                "items": {
                  "type": "object", "required": ["name", "at", "tp", "rw"],
                  "properties": {
                    "name": { "type": "string" },
                    "at": { "type": "integer" },
                    "tp": { "type": "string", "pattern": "^\\d+W\\d+([+-]\\d+)?$" },
                    "rw": { "enum": ["kurz", "mittel", "lang"] }
                  }
                }
              },
              "advantages": { "type": "array", "items": { "type": "string" } },
              "abilities": { "type": "array", "items": { "type": "string" } },
              "training": { "type": "array", "items": { "type": "string" } },
              "tricks": { "type": "array", "items": { "type": "string" } }
            }
          }
        }
      }
    }
  }
}
```

- [ ] **Step 5: Add the Makefile targets** after `test-rules-db` (~line 127):

```make
# Companion builds (docs/plans/2026-09-24-companion-data-design.md): check
# <export>.companions.yaml against its Optolith export and inject the `hesindion`
# block. FIX=1 first sets the export's own pet fields from the build; CHECK=1
# validates without writing.
#   make companions HERO="docs/sample_heros/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json"
companions:
	python3 scripts/companions/amend_export.py '$(HERO)' $(if $(FIX),--fix,) $(if $(CHECK),--check,)

test-companions:
	python3 -m unittest discover -s scripts/companions -p 'test_*.py' -v
```

Add `companions test-companions` to the `.PHONY` line if the Makefile has one (`grep -n PHONY Makefile`).

- [ ] **Step 6: Run** `make test-companions`. Everything should be OK. If a test fails, fix the implementation, not the test, unless the test contradicts spec §5.

- [ ] **Step 7: Commit**

```bash
git add scripts/companions specs/data/companion-block.schema.json Makefile
git commit -m "feat(companions): check a companion build against its export and inject it"
```

---

### Task 3: Kupperus's build and the fixed sample exports

**Goal:** Write Kupperus's 336-AP build as YAML. Run the tool with `--fix` on the 2026-09-24 Boronmir export, and create the UI fixture `UITestHeroCompanions.json`.

**Files:**
- Create: `docs/sample_heros/Boronmir Siebenfeld von Greifenfurt (2026-09-24).companions.yaml`, `Hesindion/Resources/UITestHeroCompanions.json`
- Modify (add to git): `docs/sample_heros/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json`
- Test: `scripts/companions/test_amend_export.py` (golden test)

**Acceptance Criteria:**
- [ ] `make companions CHECK=1 HERO="docs/sample_heros/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json"` prints `ok: 1 companion(s)` after the fix.
- [ ] The sample's Kupperus now has Körperbeherrschung 8, `Biss: AT 16 TP 1W6+3 RW kurz`, `at` 19, `pa` 14, `pro` 0, and a `hesindion` block with `ap.spent` 336.
- [ ] `UITestHeroCompanions.json` is `UITestHero.json` plus the fix and the block. `UITestHero.json` is byte-identical to before (`git diff --quiet Hesindion/Resources/UITestHero.json`).
- [ ] The golden test checks the committed sample with `--check`.

**Verify:** `make test-companions && git diff --quiet Hesindion/Resources/UITestHero.json && echo unchanged` → all OK, then `unchanged`

**Steps:**

- [ ] **Step 1: Write the YAML** `docs/sample_heros/Boronmir Siebenfeld von Greifenfurt (2026-09-24).companions.yaml`:

```yaml
# Kupperus, Boronmir's Svellttaler Kaltblut — the build worked out on 2026-09-24.
# Check and inject: make companions HERO="docs/sample_heros/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json"
# Ruhiges Temperament and Reittier come with the breed (Aventurische Tiergefährten
# p. 45; Kodex des Schwertes p. 155) and cost nothing.
schemaVersion: 1
pets:
  Kupperus:
    breed: svellttaler-kaltblut
    base:
      attributes: { mu: 12, kl: 10, in: 12, ch: 12, ff: 8, ge: 15, ko: 24, kk: 25 }
      lep: 75
      ini: 14+1W6
      gs: 12
      vw: 7
      attacks:
        - { name: Tritt, at: 15, tp: 1W6+7, rw: mittel }
        - { name: Biss, at: 12, tp: 1W6+2, rw: kurz }
        - { name: Niederreiten, at: 15, tp: 2W6+6, rw: mittel }
      talents: { Einschüchtern: 2, Körperbeherrschung: 4, Kraftakt: 8, Schwimmen: 4,
                 Selbstbeherrschung: 4, Sinnesschärfe: 4, Verbergen: 2, Willenskraft: 3 }
      advantages: [Ruhiges Temperament]
      abilities: [Mächtiger Schlag]
      training: [Reittier]
    ap:
      total: 336
    purchases:
      - { advantage: Geduldig, ap: 5 }
      - { advantage: Ausdauernd, ap: 15 }       # KO +2
      - { advantage: Heldenwuchs, ap: 15 }      # LeP + KO
      - { advantage: Zähes Tier, ap: 12 }
      - { advantage: Schnell, ap: 8 }           # GS +25 %
      - { advantage: Stark, ap: 15 }            # KK +2
      - { advantage: Tapfer, ap: 15 }           # MU +2
      - { advantage: Sprungsicher, ap: 5 }
      - { advantage: Loyal, ap: 10 }
      - { training: Kampftier, ap: 17 }         # +1 MU +1 KK +2 AT +1 TP +20 % LeP, Einschüchtern +4
      - { trick: Komm, ap: 3 }
      - { raise: vw, from: 7, to: 14 }
      - { raise: at, from: 17, to: 19 }
      - { buy: lep, count: 16 }
      - { raise: "talent:Willenskraft", from: 3, to: 8 }
      - { raise: "talent:Selbstbeherrschung", from: 4, to: 8 }
      - { raise: "talent:Körperbeherrschung", from: 4, to: 8 }
      - { raise: "talent:Sinnesschärfe", from: 4, to: 8 }
      - { raise: "talent:Einschüchtern", from: 6, to: 10 }
    values:
      attributes: { mu: 15, kl: 10, in: 12, ch: 12, ff: 8, ge: 15, ko: 26, kk: 28 }
      lep: 137        # (75 + 26 Heldenwuchs) × 1.2 Kampftier = 121, + 16 bought
      ini: 15+1W6     # (MU 15 + GE 15) / 2 — GM ruling
      gs: 15
      vw: 14
      rs: 0
      be: 0
      attacks:
        - { name: Tritt, at: 19, tp: 1W6+8, rw: mittel }
        - { name: Biss, at: 16, tp: 1W6+3, rw: kurz }
        - { name: Niederreiten, at: 19, tp: 2W6+7, rw: mittel }
      talents: { Einschüchtern: 10, Körperbeherrschung: 8, Kraftakt: 8, Schwimmen: 4,
                 Selbstbeherrschung: 8, Sinnesschärfe: 8, Verbergen: 2, Willenskraft: 8 }
      advantages: [Ruhiges Temperament, Geduldig, Ausdauernd, Heldenwuchs, Zähes Tier,
                   Schnell, Stark, Tapfer, Sprungsicher, Loyal]
      abilities: [Mächtiger Schlag]
      training: [Reittier, Kampftier]
      tricks: [Aus, Fass I, Fass II, Komm]
```

- [ ] **Step 2: Confirm the check catches the known errors.** Run `make companions CHECK=1 HERO="docs/sample_heros/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json"`. It should exit 1 and report at least `talent Körperbeherrschung is 4, build says 8`, `at is 18, build says 19` and `notes: attack Biss unreadable`.

- [ ] **Step 3: Fix and inject.** Run `make companions FIX=1 HERO="docs/sample_heros/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json"`, then the `CHECK=1` command again. It should print `ok: 1 companion(s)`. Inspect the result with:

```bash
python3 -c "
import json; d=json.load(open('docs/sample_heros/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json'))
p=d['pets']['PET_1']; print(p['talents']); print(p['notes'][:140]); print(p['at'], p['pa'], p['pro'])
print(d['hesindion']['pets']['PET_1']['ap'])"
```

The output should show `Körperbeherrschung 8`, `Biss: AT 16 TP 1W6+3 RW kurz`, `19 14 0`, and `{'total': 336, 'spent': 336}`.

- [ ] **Step 4: Build the UI fixture.** It uses the stripped UITestHero, whose Kupperus has the old values, so `--fix` brings them up to the build:

```bash
python3 scripts/companions/amend_export.py Hesindion/Resources/UITestHero.json \
  --companions "docs/sample_heros/Boronmir Siebenfeld von Greifenfurt (2026-09-24).companions.yaml" \
  --fix --out Hesindion/Resources/UITestHeroCompanions.json
git diff --quiet Hesindion/Resources/UITestHero.json && echo unchanged
```

The output should be `ok: …` and `unchanged`. (`Hesindion/Resources` is a synchronized group, so the new file is bundled automatically.)

- [ ] **Step 5: Add the golden test** to `scripts/companions/test_amend_export.py`, inside `CliTests`:

```python
    def test_boronmir_sample_is_consistent(self):
        sample = os.path.join(HERE, "..", "..", "docs", "sample_heros",
                              "Boronmir Siebenfeld von Greifenfurt (2026-09-24).json")
        result = self.run_cli(sample, "--check")
        self.assertEqual(result.returncode, 0, result.stderr)
```

- [ ] **Step 6: Run the Verify command.**

- [ ] **Step 7: Commit**

```bash
git add "docs/sample_heros/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json" \
        "docs/sample_heros/Boronmir Siebenfeld von Greifenfurt (2026-09-24).companions.yaml" \
        Hesindion/Resources/UITestHeroCompanions.json scripts/companions/test_amend_export.py
git commit -m "docs(sample): Kupperus's 336-AP build, fixed and injected into the Boronmir export"
```

---

### Task 4: Pet companion properties and block decoding on import

**Goal:** `Pet` holds the companion data, and `OptolithImportService.parsePets` fills it from the `hesindion` block, taking the attacks from the block instead of the notes regex.

**Files:**
- Modify: `Hesindion/Models/Pet.swift`
- Create: `Hesindion/Services/CompanionData.swift`
- Modify: `Hesindion/Services/OptolithImportService.swift:130-132` (parse call), `:738-793` (`parsePets`)
- Test: `HesindionTests/CompanionImportTests.swift` (new)

**Acceptance Criteria:**
- [ ] Importing the 2026-09-24 sample gives Kupperus these values:
  - `defense == 14`, `armor == 0`, `encumbrance == 0`
  - `apTotal == 336`, `apSpent == 336`
  - `training == ["Reittier", "Kampftier"]`, `tricks.count == 4`, `advantages.count == 10`, `abilities == ["Mächtiger Schlag"]`
  - `purchases.count == 19`
  - three attacks, among them `Biss` with AT 16, `1W6+3`, `kurz`
- [ ] Importing the old sample (`Boronmir Siebenfeld von Greifenfurt.json`, no block) gives `hasCompanionData == false`, empty lists, and the regex attacks as before.
- [ ] If a block entry fails to decode, that pet imports as if it had no block, and the import does not throw.
- [ ] Existing `HeroImportTests` still pass.

**Verify:** `xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator -derivedDataPath build -destination 'platform=iOS Simulator,name=<IPAD_NAME from Makefile>' -parallel-testing-enabled NO test -only-testing:HesindionTests/CompanionImportTests -only-testing:HesindionTests/HeroImportTests` → `** TEST SUCCEEDED **` (the Makefile's `test-only` target from Task 6 wraps this; until then use the raw command with the Makefile's variables)

**Steps:**

- [ ] **Step 1: Write the failing tests** in `HesindionTests/CompanionImportTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
@testable import Hesindion

@MainActor
struct CompanionImportTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Hero.self, HeroStateEntry.self, PersonalData.self, Experience.self, Attributes.self,
            DerivedValues.self, Talent.self, CombatTechnique.self,
            MeleeWeapon.self, RangedWeapon.self, Armor.self, Shield.self,
            EquipmentItem.self, Money.self, Pet.self, Language.self,
            HeroSpell.self, LogEntry.self, Adventure.self, WeatherDay.self,
        ])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func sample(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/sample_heros/\(name)")
    }

    private var withBlock: URL { sample("Boronmir Siebenfeld von Greifenfurt (2026-09-24).json") }
    private var withoutBlock: URL { sample("Boronmir Siebenfeld von Greifenfurt.json") }

    private func kupperus(_ context: ModelContext) throws -> Pet {
        let hero = try #require(try context.fetch(FetchDescriptor<Hero>()).first)
        return try #require(hero.petsInOrder.first { $0.name == "Kupperus" })
    }

    @Test func importReadsCompanionBlock() throws {
        let context = ModelContext(try makeContainer())
        try OptolithImportService().importHero(from: withBlock, context: context)
        let pet = try kupperus(context)

        #expect(pet.hasCompanionData)
        #expect(pet.defense == 14)
        #expect(pet.armor == 0)
        #expect(pet.encumbrance == 0)
        #expect(pet.apTotal == 336)
        #expect(pet.apSpent == 336)
        #expect(pet.training == ["Reittier", "Kampftier"])
        #expect(pet.tricks == ["Aus", "Fass I", "Fass II", "Komm"])
        #expect(pet.advantages.count == 10)
        #expect(pet.abilities == ["Mächtiger Schlag"])
        #expect(pet.purchases.count == 19)
        #expect(pet.purchases.contains(PetPurchase(kind: "raise", target: "vw", ap: 30, from: 7, to: 14)))
        #expect(pet.attacks.map(\.name) == ["Tritt", "Biss", "Niederreiten"])
        #expect(pet.attacks[1] == PetAttack(name: "Biss", at: 16, damage: "1W6+3", reach: "kurz"))
        #expect(pet.hasMightyBlow)
    }

    @Test func importWithoutBlockKeepsTodaysParsing() throws {
        let context = ModelContext(try makeContainer())
        try OptolithImportService().importHero(from: withoutBlock, context: context)
        let pet = try kupperus(context)

        #expect(!pet.hasCompanionData)
        #expect(pet.defense == nil)
        #expect(pet.training.isEmpty)
        #expect(pet.attacks.map(\.name) == ["Tritt", "Biss", "Niederreiten"])
        #expect(pet.attacks.first?.at == 15)
        #expect(pet.hasMightyBlow)  // from `skills`, the fallback
    }

    @Test func undecodableBlockIsIgnoredForThatPet() throws {
        var root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: withBlock)) as? [String: Any])
        root["hesindion"] = ["schemaVersion": 1, "pets": ["PET_1": ["name": "Kupperus"]]]
        let data = try JSONSerialization.data(withJSONObject: root)
        let context = ModelContext(try makeContainer())

        try OptolithImportService().importHero(from: data, context: context)

        let pet = try kupperus(context)
        #expect(!pet.hasCompanionData)
        #expect(pet.attacks.count == 3)  // regex over the fixed notes
    }
}
```

- [ ] **Step 2: Run the tests to watch them fail.** They should fail to compile: `defense`, `PetPurchase` and `hasMightyBlow` are unknown.

- [ ] **Step 3: Extend `Hesindion/Models/Pet.swift`.** Add after `PetAttack`:

```swift
/// One entry of a companion's build, as `scripts/companions/amend_export.py`
/// writes it (docs/plans/2026-09-24-companion-data-design.md §4).
struct PetPurchase: Codable, Hashable {
    var kind: String
    var name: String?
    var target: String?
    var ap: Int
    var from: Int?
    var to: Int?
    var count: Int?
}
```

Add these stored properties after `specialSkills` (all defaulted, so migration is lightweight):

```swift
    // Companion data from the export's `hesindion` block. Optolith has no place
    // for it; nil / empty when the export was not amended.
    var defense: Int?
    var armor: Int?
    var encumbrance: Int?
    var advantages: [String] = []
    var abilities: [String] = []
    var training: [String] = []
    var tricks: [String] = []
    var purchases: [PetPurchase] = []
    var apTotal: Int?
    var apSpent: Int?

    var hasCompanionData: Bool { apTotal != nil }

    /// The block's ability list when there is one, the free-text `skills` otherwise.
    var hasMightyBlow: Bool {
        abilities.contains("Mächtiger Schlag") || specialSkills.contains("Mächtiger Schlag")
    }

    /// Re-import without the block, and the player chose to keep the last one:
    /// only what the block adds comes over, the export's own fields stay new.
    func adoptCompanionData(from old: Pet) {
        defense = old.defense
        armor = old.armor
        encumbrance = old.encumbrance
        advantages = old.advantages
        abilities = old.abilities
        training = old.training
        tricks = old.tricks
        purchases = old.purchases
        apTotal = old.apTotal
        apSpent = old.apSpent
        attacks = old.attacks
    }
```

- [ ] **Step 4: Create `Hesindion/Services/CompanionData.swift`:**

```swift
import Foundation

/// One pet's entry in the `hesindion` block that `scripts/companions/amend_export.py`
/// writes into an Optolith export (docs/plans/2026-09-24-companion-data-design.md §4;
/// schema: specs/data/companion-block.schema.json). Optolith ignores the key, so a
/// fresh Optolith export does not have it.
struct CompanionData: Decodable {
    struct AP: Decodable {
        var total: Int
        var spent: Int
    }

    struct Attack: Decodable {
        var name: String
        var at: Int
        var tp: String
        var rw: String
    }

    struct Values: Decodable {
        var vw: Int?
        var rs: Int?
        var be: Int?
        var attacks: [Attack]
        var advantages: [String]
        var abilities: [String]
        var training: [String]
        var tricks: [String]
    }

    var name: String
    var ap: AP
    var purchases: [PetPurchase]
    var values: Values

    /// Entries by pet key. An entry that does not decode is left out — the pet then
    /// imports as if the export had not been amended.
    static func parse(root: [String: Any]) -> [String: CompanionData] {
        guard let block = root["hesindion"] as? [String: Any],
              let pets = block["pets"] as? [String: Any] else { return [:] }
        var result: [String: CompanionData] = [:]
        for (key, value) in pets {
            do {
                let data = try JSONSerialization.data(withJSONObject: value)
                result[key] = try JSONDecoder().decode(CompanionData.self, from: data)
            } catch {
                print("OptolithImport: companion data for \(key) does not decode, ignored: \(error)")
            }
        }
        return result
    }

    func apply(to pet: Pet) {
        pet.defense = values.vw
        pet.armor = values.rs
        pet.encumbrance = values.be
        pet.advantages = values.advantages
        pet.abilities = values.abilities
        pet.training = values.training
        pet.tricks = values.tricks
        pet.purchases = purchases
        pet.apTotal = ap.total
        pet.apSpent = ap.spent
        pet.attacks = values.attacks.map { PetAttack(name: $0.name, at: $0.at, damage: $0.tp, reach: $0.rw) }
    }
}
```

- [ ] **Step 5: Wire it into `OptolithImportService.swift`.**
  - At the pets parse (~line 131), change the call:

```swift
        // Parse pets
        let petsJSON = root["pets"] as? [String: Any] ?? [:]
        let pets = parsePets(petsJSON, companions: CompanionData.parse(root: root))
```

  - Change `parsePets` to accept and apply the block. The signature and the end of the closure become:

```swift
    private func parsePets(_ json: [String: Any], companions: [String: CompanionData]) -> [Pet] {
        json.compactMap { key, value -> Pet? in
            // … unchanged body up to the Pet(…) initialiser …
            let result = Pet(
                // … unchanged arguments …
            )
            companions[key]?.apply(to: result)
            return result
        }
    }
```

  (Rename the existing `return Pet(` to `let result = Pet(`, keep every argument, and add the two lines after it.)

- [ ] **Step 6: Run the Verify command.** It should end with `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add Hesindion/Models/Pet.swift Hesindion/Services/CompanionData.swift \
        Hesindion/Services/OptolithImportService.swift HesindionTests/CompanionImportTests.swift
git commit -m "feat(import): read companion data from the export's hesindion block"
```

---

### Task 5: Re-import conflicts and keeping the previous companion data

**Goal:** The import service can report which stored companions would lose their data, and can import while keeping it for chosen pets.

**Files:**
- Modify: `Hesindion/Services/OptolithImportService.swift` (public API ~line 35-50, `importHero(from data:)`, `replaceHeroData` ~line 214-277)
- Test: `HesindionTests/CompanionImportTests.swift`

**Acceptance Criteria:**
- [ ] `companionConflicts(in:context:)` returns `["Kupperus"]` when the stored hero's Kupperus has companion data and the new file's Kupperus has no block.
- [ ] It returns `[]` when:
  - the new file has the block
  - the hero is not stored yet
  - the stored pet has no companion data
  - the new file has no pet of that name
- [ ] `importHero(from:context:keepingCompanionDataFor: ["Kupperus"])` leaves `defense == 14` and the block's attacks after re-importing the old sample, while `lifeEnergy` comes from the new file (75).
- [ ] Without `keepingCompanionDataFor`, the companion data is gone after re-import (`defense == nil`).
- [ ] `readData(from:)` reads a security-scoped URL and throws `fileReadFailed` on failure. `importHero(from url:)` still works.

**Verify:** the Task 4 xcodebuild command with `-only-testing:HesindionTests/CompanionImportTests -only-testing:HesindionTests/HeroImportTests` → `** TEST SUCCEEDED **`

**Steps:**

- [ ] **Step 1: Write the failing tests.** Append to `CompanionImportTests`:

```swift
    @Test func conflictWhenReimportLosesTheBlock() throws {
        let context = ModelContext(try makeContainer())
        let service = OptolithImportService()
        try service.importHero(from: withBlock, context: context)

        #expect(try service.companionConflicts(in: Data(contentsOf: withoutBlock), context: context) == ["Kupperus"])
        #expect(try service.companionConflicts(in: Data(contentsOf: withBlock), context: context).isEmpty)
    }

    @Test func noConflictForNewHeroOrPlainPet() throws {
        let context = ModelContext(try makeContainer())
        let service = OptolithImportService()
        #expect(try service.companionConflicts(in: Data(contentsOf: withoutBlock), context: context).isEmpty)

        try service.importHero(from: withoutBlock, context: context)
        #expect(try service.companionConflicts(in: Data(contentsOf: withoutBlock), context: context).isEmpty)
    }

    @Test func noConflictWhenPetIsGoneFromNewFile() throws {
        let context = ModelContext(try makeContainer())
        let service = OptolithImportService()
        try service.importHero(from: withBlock, context: context)
        var root = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: withoutBlock)) as? [String: Any])
        root["pets"] = [String: Any]()
        let data = try JSONSerialization.data(withJSONObject: root)

        #expect(try service.companionConflicts(in: data, context: context).isEmpty)
    }

    @Test func keepRestoresOnlyTheAddedFields() throws {
        let context = ModelContext(try makeContainer())
        let service = OptolithImportService()
        try service.importHero(from: withBlock, context: context)

        try service.importHero(from: Data(contentsOf: withoutBlock), context: context,
                               keepingCompanionDataFor: ["Kupperus"])

        let pet = try kupperus(context)
        #expect(pet.defense == 14)
        #expect(pet.apTotal == 336)
        #expect(pet.training == ["Reittier", "Kampftier"])
        #expect(pet.attacks[1] == PetAttack(name: "Biss", at: 16, damage: "1W6+3", reach: "kurz"))
        #expect(pet.lifeEnergy == 75)          // Optolith field: from the new file
        #expect(pet.attributes.kk == 25)
    }

    @Test func discardDropsTheAddedFields() throws {
        let context = ModelContext(try makeContainer())
        let service = OptolithImportService()
        try service.importHero(from: withBlock, context: context)

        try service.importHero(from: withoutBlock, context: context)

        let pet = try kupperus(context)
        #expect(!pet.hasCompanionData)
        #expect(pet.defense == nil)
        #expect(pet.attacks.first?.at == 15)
    }
```

- [ ] **Step 2: Run the tests to watch them fail.** They should fail to compile: `companionConflicts` and `keepingCompanionDataFor:` are unknown.

- [ ] **Step 3: Implement the API.** In `OptolithImportService.swift`, replace the `// MARK: - Public API` section's two `importHero` functions' headers as follows, and keep the body of the data variant:

```swift
    func readData(from url: URL) throws -> Data {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw OptolithImportError.fileReadFailed
        }
    }

    func importHero(from url: URL, context: ModelContext, keepingCompanionDataFor keep: Set<String> = []) throws {
        try importHero(from: try readData(from: url), context: context, keepingCompanionDataFor: keep)
    }

    /// Stored companions that have Hesindion companion data while their namesake in
    /// `data` has none — a re-import of a plain Optolith export that would drop it.
    /// Names in `petsInOrder` order; empty for a hero that is not stored yet.
    func companionConflicts(in data: Data, context: ModelContext) throws -> [String] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let heroName = root["name"] as? String else { return [] }
        let descriptor = FetchDescriptor<Hero>(predicate: #Predicate { $0.name == heroName })
        guard let hero = try context.fetch(descriptor).first else { return [] }
        let newPets = root["pets"] as? [String: Any] ?? [:]
        let companions = CompanionData.parse(root: root)
        return hero.petsInOrder.filter(\.hasCompanionData).map(\.name).filter { name in
            let keys = newPets.compactMap { key, value in
                (value as? [String: Any])?["name"] as? String == name ? key : nil
            }
            return !keys.isEmpty && keys.allSatisfy { companions[$0] == nil }
        }
    }

    func importHero(from data: Data, context: ModelContext, keepingCompanionDataFor keep: Set<String> = []) throws {
```

  - In the data variant, pass `keep` to `replaceHeroData` (add the argument `keepingCompanionDataFor: keep` at the call ~line 153).
  - Add the parameter `keepingCompanionDataFor keep: Set<String>` to `replaceHeroData`'s signature, after `liturgies:`.
  - Replace the two pet lines in `replaceHeroData` with:

```swift
        for pet in pets where keep.contains(pet.name) && !pet.hasCompanionData {
            if let old = hero.pets.first(where: { $0.name == pet.name && $0.hasCompanionData }) {
                pet.adoptCompanionData(from: old)
            }
        }
        hero.pets.forEach { context.delete($0) }
        hero.pets = pets
```

- [ ] **Step 4: Run the Verify command.** It should end with `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Hesindion/Services/OptolithImportService.swift HesindionTests/CompanionImportTests.swift
git commit -m "feat(import): report and keep companion data a re-import would drop"
```

---

### Task 6: The re-import question in HeroListView

**Goal:** Importing a file that would drop companion data asks once per pet, in a `DSAModal`: keep previous, use export only, or cancel. A UI test drives it via new debug launch arguments.

**Files:**
- Modify: `Hesindion/Views/HeroListView.swift` (state ~line 19-25, body modifiers, `handleURL` ~line 301)
- Modify: `Hesindion/UITestSeed.swift` (fixture + re-import arguments, `populate` ~line 210)
- Modify: `Hesindion/Theme/Strings.swift` (en block near `"importHero"` ~line 157, de block ~line 927)
- Modify: `Makefile` (add `test-only`)
- Create: `HesindionUITests/CompanionReimportFlowTests.swift`

**Acceptance Criteria:**
- [ ] If `companionConflicts` is empty, the import runs at once, as today.
- [ ] Otherwise a `DSAModal` (identifier `companion.reimport.modal`) appears for each conflicting pet, with the title `"<Name>: Begleiterdaten fehlen"` / `"<Name>: companion data missing"`.
- [ ] It has three buttons:
  - `companion.reimport.keep` (filled)
  - `companion.reimport.discard` (unfilled)
  - `companion.reimport.cancel` (unfilled), which aborts without importing
- [ ] After the last answer, `importHero(from:context:keepingCompanionDataFor:)` runs with the kept names.
- [ ] `-uitest-seed-fixture <name>` picks the seeded fixture (default `UITestHero`). `-uitest-reimport <name>` makes `HeroListView` import that bundled fixture on appear.
- [ ] `make test-only ONLY=HesindionUITests/CompanionReimportFlowTests` passes. Seeding with `UITestHeroCompanions` and re-importing `UITestHero`, then tapping keep, shows `VW 14` for Kupperus.

**Verify:** `make test-only ONLY=HesindionUITests/CompanionReimportFlowTests` → `** TEST SUCCEEDED **`

**Steps:**

- [ ] **Step 1: Add the Makefile target** after `test-ui`:

```make
# Run one test class or method (no re-recording):
#   make test-only ONLY=HesindionUITests/CompanionReimportFlowTests
test-only: boot
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk $(SDK) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS Simulator,name=$(IPAD_NAME)' \
		$(NO_CLONE) \
		test -only-testing:$(ONLY)
```

- [ ] **Step 2: Write the failing UI test** `HesindionUITests/CompanionReimportFlowTests.swift`:

```swift
import XCTest

/// Re-importing a plain Optolith export over a hero whose companion carries
/// Hesindion companion data asks whether to keep it
/// (docs/plans/2026-09-24-companion-data-design.md §7).
final class CompanionReimportFlowTests: XCTestCase {

    @MainActor
    private func launchReimport() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [UITest.seedArgument, "debug", "load_default",
                               "-uitest-seed-fixture", "UITestHeroCompanions",
                               "-uitest-reimport", "UITestHero"]
        app.launch()
        return app
    }

    @MainActor
    func testKeepPreviousRetainsCompanionData() {
        let app = launchReimport()

        let keep = app.buttons["companion.reimport.keep"]
        XCTAssertTrue(keep.waitForExistence(timeout: UITest.timeout))
        XCTAssertTrue(app.staticTexts["Kupperus: Begleiterdaten fehlen"].exists)
        keep.tap()

        XCTAssertFalse(keep.waitForExistence(timeout: UITest.probeTimeout))
        let defense = app.staticTexts["pet.defense.Kupperus"]
        for _ in 0..<12 where !defense.exists { app.swipeUp() }
        XCTAssertTrue(defense.waitForExistence(timeout: UITest.timeout))
        XCTAssertEqual(defense.label, "14")
    }

    @MainActor
    func testDiscardDropsCompanionData() {
        let app = launchReimport()

        let discard = app.buttons["companion.reimport.discard"]
        XCTAssertTrue(discard.waitForExistence(timeout: UITest.timeout))
        discard.tap()

        XCTAssertFalse(discard.waitForExistence(timeout: UITest.probeTimeout))
        for _ in 0..<12 { app.swipeUp() }
        XCTAssertFalse(app.staticTexts["pet.defense.Kupperus"].exists)
    }
}
```

The test needs `pet.defense.Kupperus`, which Task 7 adds. Run it after Task 7. Here it only has to compile.

- [ ] **Step 3: Add the seed arguments** to `Hesindion/UITestSeed.swift`, next to the other `static let …Argument`s:

```swift
    /// `-uitest-seed-fixture UITestHeroCompanions` seeds from that bundled JSON
    /// instead of `UITestHero` — the companion re-import test needs a hero whose
    /// pet already carries the `hesindion` block.
    static let fixtureArgument = "-uitest-seed-fixture"

    /// `-uitest-reimport UITestHero` makes `HeroListView` import that bundled JSON
    /// on appear, through the same path as the file picker, so the re-import
    /// question can be driven without the system document browser.
    static let reimportArgument = "-uitest-reimport"

    private static func argument(after key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: key), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    static var reimportFixtureURL: URL? {
        guard isRequested, let name = argument(after: reimportArgument) else { return nil }
        return Bundle.main.url(forResource: name, withExtension: "json")
    }
```

  In `populate`, replace the resource lookup:

```swift
        let fixture = argument(after: fixtureArgument) ?? "UITestHero"
        guard let url = Bundle.main.url(forResource: fixture, withExtension: "json") else {
            fatalError("UITestSeed: \(fixture).json is missing from the app bundle")
        }
```

- [ ] **Step 4: Add the strings.** In the en block after `"selectHint"`:

```swift
        "companion.reimport.title":    "%@: companion data missing",
        "companion.reimport.message":  "This export has no Hesindion companion data (VW, attacks, advantages, training, tricks). The last import had it. Keep the previous values?",
        "companion.reimport.keep":     "Keep previous",
        "companion.reimport.discard":  "Use export only",
        "companion.reimport.cancel":   "Cancel import",
```

  In the de block after `"selectHint"`:

```swift
        "companion.reimport.title":    "%@: Begleiterdaten fehlen",
        "companion.reimport.message":  "Dieser Export enthält keine Hesindion-Begleiterdaten (VW, Angriffe, Vorteile, Ausbildung, Tricks). Der letzte Import hatte sie. Bisherige Werte behalten?",
        "companion.reimport.keep":     "Bisherige behalten",
        "companion.reimport.discard":  "Nur Export verwenden",
        "companion.reimport.cancel":   "Import abbrechen",
```

- [ ] **Step 5: Wire HeroListView.**
  - Add this state next to `importError`:

```swift
    /// A re-import waiting on the companion question: the file, the pets still to
    /// ask about (in `petsInOrder` order) and the ones already kept.
    private struct PendingReimport {
        let data: Data
        var remaining: [String]
        var keep: Set<String> = []
    }
    @State private var pendingReimport: PendingReimport?
```

  - Replace `handleURL`:

```swift
    private func handleURL(_ url: URL) {
        do {
            let service = OptolithImportService()
            let data = try service.readData(from: url)
            let conflicts = try service.companionConflicts(in: data, context: modelContext)
            if conflicts.isEmpty {
                try service.importHero(from: data, context: modelContext)
            } else {
                pendingReimport = PendingReimport(data: data, remaining: conflicts)
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func answerReimport(keep: Bool) {
        guard var pending = pendingReimport, let name = pending.remaining.first else { return }
        if keep { pending.keep.insert(name) }
        pending.remaining.removeFirst()
        guard pending.remaining.isEmpty else {
            pendingReimport = pending
            return
        }
        pendingReimport = nil
        do {
            try OptolithImportService().importHero(from: pending.data, context: modelContext,
                                                   keepingCompanionDataFor: pending.keep)
        } catch {
            showError(error.localizedDescription)
        }
    }
```

  - Add this after `.sheet(isPresented: $isShowingAdventureCreation) { … }` in `body`:

```swift
        .overlay {
            if let name = pendingReimport?.remaining.first {
                DSAModal(title: String(format: L("companion.reimport.title"), name),
                         accent: .groupEquipment) {
                    Text(L("companion.reimport.message"))
                        .font(.dsaBody(.subheadline))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DSAModalButton(title: L("companion.reimport.keep"), accent: .groupEquipment,
                                   identifier: "companion.reimport.keep") {
                        answerReimport(keep: true)
                    }
                    DSAModalButton(title: L("companion.reimport.discard"), accent: .groupEquipment,
                                   filled: false, identifier: "companion.reimport.discard") {
                        answerReimport(keep: false)
                    }
                    DSAModalButton(title: L("companion.reimport.cancel"), accent: .groupEquipment,
                                   filled: false, identifier: "companion.reimport.cancel") {
                        pendingReimport = nil
                    }
                }
                .accessibilityIdentifier("companion.reimport.modal")
            }
        }
```

  - In `.onAppear`, append:

```swift
            if let url = UITestSeed.reimportFixtureURL {
                handleURL(url)
            }
```

  `.groupEquipment` is the pets' accent in `petsSection`. If `DSAModal` needs to be a sibling in the root ZStack (AGENTS.md "Design"), check how `ContentWithNotesLayout` hosts its modal. If `HeroListView` is not the root, follow that pattern instead of `.overlay`, and keep the identifiers.

- [ ] **Step 6: Build.** Run `make build` (or the `test-only` command, which builds too). It should compile. The UI test runs after Task 7.

- [ ] **Step 7: Commit**

```bash
git add Hesindion/Views/HeroListView.swift Hesindion/UITestSeed.swift Hesindion/Theme/Strings.swift \
        Makefile HesindionUITests/CompanionReimportFlowTests.swift
git commit -m "feat(import): ask whether to keep companion data a re-import would drop"
```

---

### Task 7: Show companion data; Mächtiger Schlag from abilities

**Goal:** The hero detail's pets section shows VW/RS/BE, AP, advantages, abilities, training and tricks. Combat detects Mächtiger Schlag through `Pet.hasMightyBlow`.

**Files:**
- Modify: `Hesindion/Views/HeroDetailView.swift:1093-1156` (`petsSection`)
- Modify: `Hesindion/Views/CombatAttackViews.swift:183,231`
- Modify: `Hesindion/Theme/Strings.swift` (en + de)

**Acceptance Criteria:**
- [ ] For a pet with companion data, `petsSection` shows a block with `VW`, `RS`, `BE` and `AP` ("336 / 336"). The VW value `Text` has accessibility identifier `pet.defense.<name>`.
- [ ] Non-empty lists show as `FieldRow`s: `petAdvantages`, `petAbilities`, `petTraining`, `petTricks`.
- [ ] A pet without companion data renders exactly as before, so the existing snapshot tests pass unchanged.
- [ ] `CombatAttackViews` lines 183 and 231 use `mount.hasMightyBlow`.
- [ ] Both `CompanionReimportFlowTests` tests pass.

**Verify:** `make test-only ONLY=HesindionUITests/CompanionReimportFlowTests` → `** TEST SUCCEEDED **`, then `make test-ui` → `** TEST SUCCEEDED **` (snapshots unchanged)

**Steps:**

- [ ] **Step 1: Add the strings.** en:

```swift
        "petAdvantages":        "Advantages",
        "petAbilities":         "Abilities",
        "petTraining":          "Training",
        "petTricks":            "Tricks",
        "petBuild":             "Build",
```

  de:

```swift
        "petAdvantages":        "Vorteile",
        "petAbilities":         "Sonderfertigkeiten",
        "petTraining":          "Ausbildung",
        "petTricks":            "Tricks",
        "petBuild":             "Aufbau",
```

  First check `grep -n '"petAdvantages"\|"petBuild"' Hesindion/Theme/Strings.swift`. If a key exists, reuse it.

- [ ] **Step 2: Extend `petsSection`.** After the `SubfieldBlock(label: L("combat"), …)` and before `if !pet.talents.isEmpty`, insert:

```swift
                        if pet.hasCompanionData {
                            companionBlock(pet)
                        }
```

  Add this helper to the same view (next to `petsSection`):

```swift
    @ViewBuilder private func companionBlock(_ pet: Pet) -> some View {
        HStack(spacing: 16) {
            companionValue("VW", pet.defense, id: "pet.defense.\(pet.name)")
            companionValue("RS", pet.armor, id: "pet.armor.\(pet.name)")
            companionValue("BE", pet.encumbrance, id: "pet.encumbrance.\(pet.name)")
            Spacer()
            Text("\(pet.apSpent ?? 0) / \(pet.apTotal ?? 0) AP")
                .font(.dsaMono(.caption, emphasis: true))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("pet.ap.\(pet.name)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)

        if !pet.advantages.isEmpty {
            FieldRow(label: "petAdvantages", value: pet.advantages.joined(separator: ", "))
        }
        if !pet.abilities.isEmpty {
            FieldRow(label: "petAbilities", value: pet.abilities.joined(separator: ", "))
        }
        if !pet.training.isEmpty {
            FieldRow(label: "petTraining", value: pet.training.joined(separator: ", "))
        }
        if !pet.tricks.isEmpty {
            FieldRow(label: "petTricks", value: pet.tricks.joined(separator: ", "))
        }
    }

    private func companionValue(_ label: String, _ value: Int?, id: String) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.dsaBody(.caption)).foregroundStyle(.secondary)
            Text(value.map(String.init) ?? "–")
                .font(.dsaMono(.body, emphasis: true))
                .accessibilityIdentifier(id)
        }
    }
```

  If `SubfieldBlock` fits better visually (it is used for the attributes right above), use `SubfieldBlock(label: L("petBuild"), subfields: [("VW", …), ("RS", …), ("BE", …), ("AP", "336/336")])` instead. But first check whether `SubfieldBlock` can take an accessibility identifier per subfield (`grep -n 'struct SubfieldBlock' -A30 Hesindion/Views/*.swift`), because the UI test needs `pet.defense.<name>`. Keep the `HStack` if it cannot.

- [ ] **Step 3: Switch Mächtiger Schlag.** In `CombatAttackViews.swift`, replace both `mount.specialSkills.contains("Mächtiger Schlag")` (lines ~183 and ~231) with `mount.hasMightyBlow`. Leave line ~216's display of `specialSkills` as it is.

- [ ] **Step 4: Run the UI test.** `make test-only ONLY=HesindionUITests/CompanionReimportFlowTests` should end with `** TEST SUCCEEDED **`.

- [ ] **Step 5: Run the unit and snapshot suite.** `make test-ui` should end with `** TEST SUCCEEDED **`. If a snapshot of a hero detail fails, check whether it seeds a pet with companion data. Only `UITestHeroCompanions` has any, and no snapshot test uses it. So a failure means the no-data path changed: fix the view, and do not re-record.

- [ ] **Step 6: Commit**

```bash
git add Hesindion/Views/HeroDetailView.swift Hesindion/Views/CombatAttackViews.swift Hesindion/Theme/Strings.swift
git commit -m "feat(pets): show companion data; Mächtiger Schlag from the ability list"
```

---

### Task 8: Documentation

**Goal:** CHANGELOG, ADR 0015, AGENTS.md and the spec reflect the feature and the recorded deviations.

**Files:**
- Modify: `CHANGELOG.md` (`[Unreleased]`)
- Create: `docs/adr/0015-companion-data-in-optolith-export.md` (from `docs/adr/0000-template.md`)
- Modify: `AGENTS.md` (Build & Run target list, ~line 20-30)
- Modify: `docs/plans/2026-09-24-companion-data-design.md` (§6 display, §7 API)

**Acceptance Criteria:**
- [ ] CHANGELOG `[Unreleased]` has:
  - under **Added**: companion data block + `make companions` tool; import of VW/RS/BE, advantages, abilities, training, tricks, purchases, AP; the re-import question
  - under **Fixed**: a companion's attacks no longer depend on `notes` prose when the block is present
- [ ] ADR 0015 follows the template's headings. It records the decision (block under `hesindion` in the export, YAML source, tool checks and does not compute) and the alternatives rejected: in-app editing, a separate sidecar imported by the app, and Optolith's free-text fields.
- [ ] AGENTS.md lists `make companions`, `make test-companions` and `make test-only`.
- [ ] Spec §7 describes `companionConflicts` + `importHero(…keepingCompanionDataFor:)` in place of `PendingImport`. Spec §6 says FieldRows instead of chips.

**Verify:** `grep -c 'companions' CHANGELOG.md AGENTS.md && test -f docs/adr/0015-companion-data-in-optolith-export.md && grep -n 'companionConflicts' docs/plans/2026-09-24-companion-data-design.md` → non-zero counts, the file exists, and a match

**Steps:**

- [ ] **Step 1:** Read `docs/adr/0000-template.md` and `docs/adr/0014-rule-provenance-and-rule-sets.md`, then write ADR 0015 with the same headings. Status: Accepted, date 2026-09-24. Link the spec and plan.

- [ ] **Step 2:** Add the CHANGELOG entries at the top of `### Added`, and create `### Fixed` under `[Unreleased]` if it is missing:

```markdown
- Companion data: `make companions HERO=<export>` checks a hand-written `<export>.companions.yaml` (a companion's purchases priced in Kat C, AP sum, the export's own fields) and writes a `hesindion` block into the Optolith export; the import reads VW/RS/BE, advantages, abilities, training, tricks, purchases and AP from it and shows them on the hero's pets.
- Re-importing a plain Optolith export over a companion that had Hesindion companion data asks whether to keep the previous values (only the data the block adds; everything Optolith exports comes from the new file).
```

```markdown
- A companion's attacks come from the `hesindion` block when present, so a typo in the Optolith notes (`AT 156TP`) no longer drops an attack.
```

- [ ] **Step 3:** In AGENTS.md's make list, after `make test-rules-db`, add:

```
make companions HERO="<export.json>"  # Check <export>.companions.yaml and inject the hesindion block (FIX=1 rewrites the export's pet fields, CHECK=1 only checks)
make test-companions   # The companion tool's tests (Python unittest)
make test-only ONLY=<Target/Class>   # One test class or method
```

- [ ] **Step 4:** In the spec, make two edits:
  - Replace §7's first bullet list with the `companionConflicts(in:context:) -> [String]` / `importHero(from:context:keepingCompanionDataFor:)` description, plus one sentence on why: unsaved SwiftData models should not wait on a modal.
  - In §6, "as chips" → "as `FieldRow`s".

- [ ] **Step 5: Commit**

```bash
git add CHANGELOG.md AGENTS.md docs/adr/0015-companion-data-in-optolith-export.md docs/plans/2026-09-24-companion-data-design.md
git commit -m "docs: companion data — ADR 0015, changelog, make targets, spec as built"
```

---

### Task 9: Full verification

**Goal:** Run the whole suite once on the finished branch and confirm nothing regressed.

**Files:** none (fix-ups only, if a check fails)

**Acceptance Criteria:**
- [ ] `make test-companions` → OK
- [ ] `make test-ui` → `** TEST SUCCEEDED **` (unit + snapshot)
- [ ] `make test-only ONLY=HesindionUITests/CompanionReimportFlowTests` → `** TEST SUCCEEDED **`
- [ ] `make test-only ONLY=HesindionUITests/RabenschnabelFlowTests` → `** TEST SUCCEEDED **` (a mounted-combat flow still works with the unchanged fixture)
- [ ] `git status` is clean, and `git diff --quiet review/neobrutalism-swiftui-audit -- Hesindion/Resources/UITestHero.json` shows the fixture unchanged

**Verify:** each command above, run one at a time → the stated result

**Steps:**

- [ ] **Step 1:** Run each command in the list, one at a time, and capture the tail of each output.
- [ ] **Step 2:** For any failure, fix the cause in the task's files and commit it as `fix(companions): …`.
