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
