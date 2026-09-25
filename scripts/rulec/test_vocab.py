import re
import unittest

from rulec import vocab

CAMEL = re.compile(r"^[a-z][a-zA-Z0-9]*(\.[a-zA-Z0-9]+)*\.?$")
SPEC_VERBS = {"add", "set", "multiply", "cap", "floor", "useLevel", "replace", "suppress",
              "forbid", "require", "limit", "offer", "ask", "tell", "provide", "derive",
              "check", "gain", "cost", "process", "item", "reroll"}


class VocabularyTests(unittest.TestCase):
    def setUp(self):
        self.v = vocab.load()

    def test_the_verbs_are_the_specs_22(self):
        self.assertEqual(set(self.v.verbs), SPEC_VERBS)

    def test_every_verb_has_a_phase_or_runs_on_the_action_layer(self):
        phases = set(self.v.raw["phases"]) | {"data", "player", "action"}
        for name, verb in self.v.verbs.items():
            self.assertIn(verb["phase"], phases, name)

    def test_every_field_type_is_declared(self):
        types = set(self.v.raw["fieldTypes"])
        for name, verb in self.v.verbs.items():
            for f, t in {**verb["fields"], **verb.get("optional", {})}.items():
                self.assertIn(t, types, f"{name}.{f}")

    def test_every_fact_has_an_owner(self):
        owners = set(self.v.raw["owners"])
        for name, fact in {**self.v.raw["facts"], **self.v.raw["factFamilies"]}.items():
            self.assertIn(fact["owner"], owners, name)

    def test_all_names_are_lower_camel_case(self):
        def walk(node, path="$"):
            if isinstance(node, dict):
                for k, v in node.items():
                    self.assertRegex(k, CAMEL, path)
                    walk(v, f"{path}.{k}")
            elif isinstance(node, list):
                for x in node:
                    if isinstance(x, str):
                        self.assertRegex(x, CAMEL, path)
        walk(self.v.raw)

    def test_fact_owner_resolves_families(self):
        self.assertEqual(self.v.fact_owner("attr.MU"), "sheet")
        self.assertEqual(self.v.fact_owner("gmFact.fromBehind"), "gm")
        self.assertEqual(self.v.fact_owner("hero.mounted"), "loadout")
        self.assertIsNone(self.v.fact_owner("nope"))

    def test_targets_accept_prefixes_and_contexts(self):
        self.assertTrue(self.v.is_target("pa"))
        self.assertTrue(self.v.is_target("opponent.pa"))
        self.assertFalse(self.v.is_target("pa_shield"))
        self.assertEqual(self.v.target_contexts("pa"), ["with"])

    def test_every_fact_type_is_declared(self):
        types = set(self.v.raw["factTypes"])
        for name, fact in {**self.v.raw["facts"], **self.v.raw["factFamilies"]}.items():
            self.assertIn(fact["type"], types, name)

    def test_events_are_the_specs_and_damage(self):
        # Spec §7's events, plus `damaged` (ruling R53): LE lost to a hit, which is not a `paid`;
        # and `clockAdvanced` / `stated` (ruling R56): the clock and a lasting fact change only by
        # an event too.
        self.assertEqual(self.v.raw["events"], ["paid", "damaged", "progressed", "completed", "brokenOff",
                                                "itemChanged", "gained", "cleared", "logged", "clockAdvanced",
                                                "stated"])

    def test_a_recurring_costs_start_is_a_derived_fact(self):
        # Ruling R57: a recurring cost counts from its start, `upkeep.<rule>.<clause>` (the minute
        # or round it began), which the engine states with a `stated` event.
        self.assertEqual(self.v.raw["factFamilies"]["upkeep."], {"owner": "derived", "type": "int"})
        self.assertEqual(self.v.fact_owner("upkeep.zaubermodifikationen.ZM5"), "derived")
