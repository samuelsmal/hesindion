"""coverage.py: per-page status, the coverage table, the sections, --list and --check."""
import tempfile
import unittest
from pathlib import Path

from rules_sync import coverage
from rules_sync.check import RuleSource
from rules_sync.pages import Registry

B = "https://dsa.ulisses-regelwiki.de/"


def src(rule_id, url, h, reviewed=False, path=Path("dummy.yaml"), primary=True):
    return RuleSource(rule_id, path, B + url, h, reviewed, primary)


def also(rule_id, url, reviewed=False):
    return RuleSource(rule_id, Path("dummy.yaml"), B + url, None, reviewed, False)


def reg_with(pages_by_key):
    r = Registry()
    r.pages.update(pages_by_key)
    return r


class StatusesTests(unittest.TestCase):
    def test_one_page_of_each_of_the_seven_statuses(self):
        reg = reg_with({
            "gone.html": {"in": "A / x", "kind": "rule", "hash": "h", "gone": "2026-10-01"},
            "skipped.html": {"in": "A / x", "kind": "rule", "hash": "h", "skip": "not a rule"},
            "new.html": {"in": "A / x", "kind": "rule", "hash": "h"},
            "changed.html": {"in": "A / x", "kind": "rule", "hash": "h2"},
            "unhashed.html": {"in": "A / x", "kind": "rule", "hash": "h"},
            "reviewed.html": {"in": "A / x", "kind": "rule", "hash": "h"},
            "drafted.html": {"in": "A / x", "kind": "rule", "hash": "h"},
        })
        sources = [
            src("R1", "changed.html", "h_old"),
            src("R2", "unhashed.html", None),
            src("R3", "reviewed.html", "h", reviewed=True),
            src("R4", "drafted.html", "h", reviewed=False),
        ]
        st = coverage.statuses(reg, sources)
        self.assertEqual(st["gone.html"], "gone")
        self.assertEqual(st["skipped.html"], "skipped")
        self.assertEqual(st["new.html"], "new")
        self.assertEqual(st["changed.html"], "changed")
        self.assertEqual(st["unhashed.html"], "unhashed")
        self.assertEqual(st["reviewed.html"], "reviewed")
        self.assertEqual(st["drafted.html"], "drafted")

    def test_two_rules_one_reviewed_one_not_is_drafted(self):
        reg = reg_with({"p.html": {"in": "A / x", "kind": "rule", "hash": "h"}})
        sources = [src("R1", "p.html", "h", reviewed=True), src("R2", "p.html", "h", reviewed=False)]
        self.assertEqual(coverage.statuses(reg, sources)["p.html"], "drafted")

    def test_two_rules_different_hashes_one_matching_is_changed(self):
        reg = reg_with({"p.html": {"in": "A / x", "kind": "rule", "hash": "h"}})
        sources = [src("R1", "p.html", "h"), src("R2", "p.html", "h_stale")]
        self.assertEqual(coverage.statuses(reg, sources)["p.html"], "changed")

    def test_index_and_broken_pages_are_excluded(self):
        reg = reg_with({
            "i.html": {"in": "A", "kind": "index"},
            "b.html": {"in": "A / y", "kind": "broken"},
        })
        st = coverage.statuses(reg, [])
        self.assertEqual(st, {})


class AlsoPageTests(unittest.TestCase):
    """An `also` page is named but carries no hash of its own: it is never `changed` or
    `unhashed` through it."""

    def test_an_also_page_is_drafted_not_changed(self):
        reg = reg_with({
            "primary.html": {"in": "A / x", "kind": "rule", "hash": "h1"},
            "also.html": {"in": "A / x", "kind": "rule", "hash": "h2"},
        })
        sources = [src("R1", "primary.html", "h1"), also("R1", "also.html")]
        st = coverage.statuses(reg, sources)
        self.assertEqual(st["primary.html"], "drafted")
        self.assertEqual(st["also.html"], "drafted")

    def test_an_also_page_of_reviewed_rules_is_reviewed(self):
        reg = reg_with({"also.html": {"in": "A / x", "kind": "rule", "hash": "h2"}})
        st = coverage.statuses(reg, [also("R1", "also.html", reviewed=True),
                                     also("R2", "also.html", reviewed=True)])
        self.assertEqual(st["also.html"], "reviewed")

    def test_a_page_named_as_primary_and_as_also_follows_the_primary_hash(self):
        reg = reg_with({"p.html": {"in": "A / x", "kind": "rule", "hash": "h"}})
        self.assertEqual(coverage.statuses(reg, [src("R1", "p.html", "h_old"), also("R2", "p.html")])["p.html"],
                         "changed")
        self.assertEqual(coverage.statuses(reg, [src("R1", "p.html", None), also("R2", "p.html")])["p.html"],
                         "unhashed")
        self.assertEqual(coverage.statuses(reg, [src("R1", "p.html", "h", reviewed=True),
                                                 also("R2", "p.html", reviewed=False)])["p.html"],
                         "drafted")

    def test_the_changed_section_names_only_primary_sources(self):
        reg = reg_with({"p.html": {"in": "A / x", "kind": "rule", "hash": "h"}})
        sources = [src("R1", "p.html", "h_old"), also("R2", "p.html")]
        out = coverage.render(reg, sources, coverage.statuses(reg, sources))
        self.assertIn("  p.html: R1\n", out)


class UnknownTests(unittest.TestCase):
    def test_a_rule_naming_a_page_not_in_the_registry_is_unknown(self):
        reg = reg_with({"known.html": {"in": "A / x", "kind": "rule", "hash": "h"}})
        sources = [src("R1", "known.html", "h"), src("R2", "missing.html", "h")]
        unk = coverage.unknown(reg, sources)
        self.assertEqual([s.rule_id for s in unk], ["R2"])


class NonRulePageTests(unittest.TestCase):
    """Important 3: a rule whose page is an index, broken or gone is listed, and --check fails."""

    def reg(self):
        return reg_with({
            "i.html": {"in": "A", "kind": "index"},
            "b.html": {"in": "A / y", "kind": "broken"},
            "g.html": {"in": "A / z", "kind": "rule", "hash": "h", "gone": "2026-10-01"},
            "ok.html": {"in": "A / x", "kind": "rule", "hash": "h"},
        })

    def test_lists_rule_id_page_and_kind(self):
        sources = [src("R1", "i.html", None), src("R2", "b.html", None), src("R3", "g.html", "h"),
                   src("R4", "ok.html", "h"), src("R5", "missing.html", None)]
        self.assertEqual(coverage.on_non_rule_page(self.reg(), sources),
                         [("R1", "i.html", "index"), ("R2", "b.html", "broken"), ("R3", "g.html", "gone")])
        out = coverage.render(self.reg(), sources, coverage.statuses(self.reg(), sources))
        self.assertIn("rules on a non-rule page:\n  R1 i.html (index)\n  R2 b.html (broken)\n"
                      "  R3 g.html (gone)\n", out)

    def test_nothing_to_list_means_no_section(self):
        sources = [src("R4", "ok.html", "h")]
        out = coverage.render(self.reg(), sources, coverage.statuses(self.reg(), sources))
        self.assertNotIn("non-rule page", out)


class RunCheckTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())

    def _write_pages(self, text):
        p = self.root / "pages.yaml"
        p.write_text(text, encoding="utf-8")
        return p

    def _write_rule(self, name, rule_id, url, h=None, reviewed=False, rule_name=None):
        rules_root = self.root / "rules"
        rules_root.mkdir(exist_ok=True)
        path = rules_root / name
        reviewed_yaml = "reviewed: { by: '@x', date: 2026-09-25 }\n" if reviewed else "reviewed: null\n"
        hash_line = f"  hash: {h}\n" if h else ""
        name_line = f"name: {rule_name}\n" if rule_name else ""
        path.write_text(
            f"id: {rule_id}\n{name_line}source:\n  url: {url}\n{hash_line}{reviewed_yaml}",
            encoding="utf-8",
        )
        return rules_root

    def test_check_returns_1_when_a_page_is_changed(self):
        pages_path = self._write_pages(
            "synced: 2026-09-26\nskip: {}\npages:\n"
            "  changed.html: {title: X, in: 'A / x', kind: rule, hash: h_new}\n"
        )
        rules_root = self._write_rule("r1.yaml", "R1", B + "changed.html", h="h_old")
        status = coverage.run(pages_path, rules_root, check=True)
        self.assertEqual(status, 1)

    def test_check_returns_0_when_nothing_is_changed(self):
        pages_path = self._write_pages(
            "synced: 2026-09-26\nskip: {}\npages:\n"
            "  ok.html: {title: X, in: 'A / x', kind: rule, hash: h}\n"
        )
        rules_root = self._write_rule("r1.yaml", "R1", B + "ok.html", h="h", reviewed=True)
        status = coverage.run(pages_path, rules_root, check=True)
        self.assertEqual(status, 0)

    def test_check_returns_1_when_a_rule_has_an_unknown_page(self):
        pages_path = self._write_pages("synced: 2026-09-26\nskip: {}\npages: {}\n")
        rules_root = self._write_rule("r1.yaml", "R1", B + "missing.html")
        status = coverage.run(pages_path, rules_root, check=True)
        self.assertEqual(status, 1)

    def test_check_returns_1_when_a_rule_is_on_an_index_page(self):
        pages_path = self._write_pages(
            "synced: 2026-09-26\nskip: {}\npages:\n"
            "  i.html: {title: X, in: 'A', kind: index}\n"
        )
        rules_root = self._write_rule("r1.yaml", "R1", B + "i.html")
        self.assertEqual(coverage.run(pages_path, rules_root, check=True), 1)
        self.assertEqual(coverage.run(pages_path, rules_root, check=False), 0)

    def test_missing_pages_yaml_prints_message_and_exits_0_or_1(self):
        pages_path = self.root / "nope.yaml"
        rules_root = self.root / "empty_rules"
        rules_root.mkdir()
        self.assertEqual(coverage.run(pages_path, rules_root, check=False), 0)
        self.assertEqual(coverage.run(pages_path, rules_root, check=True), 1)

    def test_list_of_an_unknown_status_exits_2(self):
        pages_path = self._write_pages("synced: 2026-09-26\nskip: {}\npages: {}\n")
        rules_root = self.root / "empty_rules"
        rules_root.mkdir()
        status = coverage.run(pages_path, rules_root, list_status="bogus")
        self.assertEqual(status, 2)

    def test_list_of_a_known_status_exits_0(self):
        pages_path = self._write_pages(
            "synced: 2026-09-26\nskip: {}\npages:\n"
            "  new.html: {title: X, in: 'A / x', kind: rule, hash: h}\n"
        )
        rules_root = self.root / "empty_rules"
        rules_root.mkdir()
        status = coverage.run(pages_path, rules_root, list_status="new")
        self.assertEqual(status, 0)


class RenderTests(unittest.TestCase):
    def test_render_has_table_header_and_sections(self):
        reg = reg_with({
            "changed.html": {"in": "A / x", "kind": "rule", "hash": "h_new"},
            "i.html": {"in": "A", "kind": "index"},
            "b.html": {"in": "A / y", "kind": "broken"},
        })
        sources = [src("R1", "changed.html", "h_old", path=Path(tempfile.mktemp(suffix=".yaml")))]
        sources[0].path.write_text("id: R1\nname: Beispielregel\n", encoding="utf-8")
        st = coverage.statuses(reg, sources)
        out = coverage.render(reg, sources, st)
        self.assertIn("pages", out)
        self.assertIn("changed", out)
        self.assertIn("index pages: 1, broken pages: 1", out)
        self.assertIn("changed.html", out)
        self.assertIn("R1", out)


if __name__ == "__main__":
    unittest.main()
