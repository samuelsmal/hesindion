import unittest

from rulec import vocab, yamlload
from rulec.errors import RulecError
from rulec.forms import Forms


class ValueFormTests(unittest.TestCase):
    def setUp(self):
        self.f = Forms(vocab.load())

    def test_a_number(self):
        self.assertEqual(self.f.value(2), {"number": 2})

    def test_a_level_expression_with_a_minus_offset(self):
        self.assertEqual(self.f.value("level - 1"), {"level": {"times": 1, "plus": -1}})

    def test_a_level_expression_with_a_multiplier(self):
        self.assertEqual(self.f.value("2 * level"), {"level": {"times": 2, "plus": 0}})

    def test_a_negated_level_expression(self):
        self.assertEqual(self.f.value("-level"), {"level": {"times": -1, "plus": 0}})

    def test_a_proportion_fills_in_every_default(self):
        # Controller ruling: `per: hero.wundschwelle` is neither a fact nor a target in the
        # vocabulary; the acceptance example is rewritten with `per: wundschwelle` (a target).
        self.assertEqual(
            self.f.value({"of": "hit.sp", "per": "wundschwelle", "round": "down"}),
            {
                "proportion": {
                    "of": {"fact": "hit.sp"},
                    "per": {"target": {"name": "wundschwelle"}},
                    "times": 1,
                    "above": 0,
                    "round": "down",
                    "min": None,
                    "max": None,
                }
            },
        )

    def test_a_proportion_with_a_number_per(self):
        self.assertEqual(
            self.f.value({"of": "hit.sp", "per": 2}),
            {
                "proportion": {
                    "of": {"fact": "hit.sp"},
                    "per": {"number": 2},
                    "times": 1,
                    "above": 0,
                    "round": "up",
                    "min": None,
                    "max": None,
                }
            },
        )

    def test_a_proportion_of_a_sum(self):
        # kampfwerte.KW9: (MU + GE) / 2, rounded once, as one line.
        p = self.f.value({"of": ["attr.MU", "attr.GE"], "per": 2})["proportion"]
        self.assertEqual(p["of"], {"sum": [{"fact": "attr.MU"}, {"fact": "attr.GE"}]})
        self.assertEqual(p["per"], {"number": 2})

    def test_a_sum_of_one_operand_is_an_error(self):
        with self.assertRaises(RulecError):
            self.f.value({"of": ["attr.MU"], "per": 2})

    def test_a_proportion_bound_may_be_an_operand_or_a_list_of_them(self):
        # SA_62.ST2: ⌈(GS + 4)/2⌉, at most 10 and at most the natural GS, as one line.
        p = self.f.value({"of": ["gs", 4], "per": 2, "max": [10, "gsNatural"], "min": "hero.gs"})["proportion"]
        self.assertEqual(p["of"], {"sum": [{"target": {"name": "gs"}}, {"number": 4}]})
        self.assertEqual(p["max"], {"each": [{"number": 10}, {"target": {"name": "gsNatural"}}]})
        self.assertEqual(p["min"], {"fact": "hero.gs"})
        self.assertEqual(self.f.value({"of": "gs", "max": 10})["proportion"]["max"], 10)   # a number stays

    def test_a_bad_bound_is_an_error(self):
        for bound in ([10], "nope", {"of": "gs"}):
            with self.assertRaises(RulecError):
                self.f.value({"of": "gs", "max": bound})

    def test_the_level_target_takes_a_rule(self):
        self.assertEqual(self.f.target("level(rule: COND_1)"), {"name": "level", "rule": "COND_1"})

    def test_a_table_lookup(self):
        self.assertEqual(
            self.f.value("table(trefferzonen.TZ11, hit.zone)"),
            {"table": {"name": "trefferzonen.TZ11", "key": "hit.zone"}},
        )

    def test_a_free_formula_is_rejected(self):
        with self.assertRaisesRegex(RulecError, "value outside the four forms"):
            self.f.value("ktw + floor(MU / 3)", line=7)


class TargetFormTests(unittest.TestCase):
    def setUp(self):
        self.f = Forms(vocab.load())

    def test_a_target_with_context(self):
        self.assertEqual(self.f.target("pa(with: shield)"), {"name": "pa", "with": "shield"})

    def test_a_prefixed_target_without_context(self):
        self.assertEqual(self.f.target("opponent.at"), {"name": "opponent.at"})

    def test_an_unknown_target_is_rejected(self):
        with self.assertRaisesRegex(RulecError, "unknown target"):
            self.f.target("pa_shield")

    def test_a_context_the_target_does_not_take_is_rejected(self):
        with self.assertRaisesRegex(RulecError, "aw takes no context with"):
            self.f.target("aw(with: x)")


class ConditionFormTests(unittest.TestCase):
    def setUp(self):
        self.f = Forms(vocab.load())

    def test_two_facts_become_all(self):
        self.assertEqual(
            self.f.condition({"hero.mounted": True, "round.defencesMade": {"atLeast": 1}}),
            {
                "all": [
                    {"fact": "hero.mounted", "is": True},
                    {"fact": "round.defencesMade", "atLeast": 1},
                ]
            },
        )

    def test_a_single_fact_is_not_wrapped_in_all(self):
        self.assertEqual(
            self.f.condition({"hero.mounted": True}),
            {"fact": "hero.mounted", "is": True},
        )

    def test_a_list_value_becomes_in(self):
        self.assertEqual(
            self.f.condition({"loadout.weapon": ["Schwert", "Dolch"]}),
            {"fact": "loadout.weapon", "in": ["Schwert", "Dolch"]},
        )

    def test_any_nests(self):
        self.assertEqual(
            self.f.condition({"any": [{"hero.mounted": True}, {"round.number": {"atLeast": 2}}]}),
            {
                "any": [
                    {"fact": "hero.mounted", "is": True},
                    {"fact": "round.number", "atLeast": 2},
                ]
            },
        )

    def test_all_nests(self):
        self.assertEqual(
            self.f.condition({"all": [{"hero.mounted": True}, {"round.defencesMade": {"atLeast": 1}}]}),
            {
                "all": [
                    {"fact": "hero.mounted", "is": True},
                    {"fact": "round.defencesMade", "atLeast": 1},
                ]
            },
        )

    def test_not_nests(self):
        self.assertEqual(
            self.f.condition({"not": {"hero.mounted": True}}),
            {"not": {"fact": "hero.mounted", "is": True}},
        )

    def test_an_unknown_fact_is_rejected(self):
        with self.assertRaisesRegex(RulecError, "unknown fact"):
            self.f.condition({"nope.fact": True})


class SelectorFormTests(unittest.TestCase):
    def setUp(self):
        self.f = Forms(vocab.load())

    def test_a_kind_with_ids(self):
        self.assertEqual(
            self.f.selector({"defence": ["pa", "aw"]}),
            {"kind": "defence", "ids": ["pa", "aw"]},
        )

    def test_two_kinds_are_rejected(self):
        with self.assertRaisesRegex(RulecError, "a selector names exactly one kind"):
            self.f.selector({"attack": ["x"], "defence": ["y"]})


class YamlLoadTests(unittest.TestCase):
    def test_line_numbers_survive_loading(self):
        doc = yamlload.loads("a: 1\nb:\n  c: [1, 2]\n", "x.yaml")
        self.assertEqual(doc["b"].line, 3)          # 1-based line of the mapping's first key
        self.assertEqual(yamlload.line_of(doc, "b"), 2)


if __name__ == "__main__":
    unittest.main()
