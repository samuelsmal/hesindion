"""`make rules-db-verify` must catch an authored field that never reached the database.

The dump comparison it was built on cannot: a field the build drops is dropped
identically on both sides, so two NULL columns compare equal and the check
passes. That is how `ruleset` could be required by the schema, argued in an ADR
and backfilled across all 28 files while the engine -- which reads the database,
not `specs/rules/` -- still saw nothing. These tests are about the half that has
to compare the database against the *files*.

No Optolith source and no `sqlite3` binary are needed: `check_authored_fields`
takes a database path and a rules directory, so a three-row fixture exercises it.
"""
import json
import sqlite3
import textwrap

from scripts.build_rules_db.verify_db import (
    check_authored_fields,
    check_resolution_reached_the_db,
)

CHAPTER_FILE = textwrap.dedent("""
    id: CHAP_Reiterkampf
    subgroup: none
    ruleset: core
    source:
      url: https://dsa.ulisses-regelwiki.de/Reiterkampf.html
      title: Reiterkampf
      checked: '2026-09-21'
      hash: sha256:{h}
    effects:
    - type: reminder
      note: 'UNENCODED: clause 1'
""").format(h="0" * 64)

ABILITY_FILE = textwrap.dedent("""
    id: SA_62
    subgroup: spezialmanoever
    ruleset: focus.trefferzonen
    source:
      url: https://dsa.ulisses-regelwiki.de/SA_62.html
      checked: '2026-09-21'
      hash: sha256:{h}
    effects:
    - type: modifier
      target: at
      scope: combat
      value: 2
""").format(h="0" * 64)


UNVERIFIED_FILE = textwrap.dedent("""
    id: SA_99
    subgroup: passiv
    ruleset: core
    source:
      url: https://dsa.ulisses-regelwiki.de/UNVERIFIED
      checked: '1970-01-01'
      hash: sha256:{h}
    effects:
    - type: reminder
      note: 'UNENCODED: nobody has looked at this rule yet'
""").format(h="0" * 64)


def _fixture(tmp_path, *, ruleset_written=True, title_written=True, url_written=True):
    rules_dir = tmp_path / "rules"
    rules_dir.mkdir()
    (rules_dir / "CHAP_Reiterkampf.yaml").write_text(CHAPTER_FILE)
    (rules_dir / "SA_62.yaml").write_text(ABILITY_FILE)
    (rules_dir / "SA_99.yaml").write_text(UNVERIFIED_FILE)

    db = tmp_path / "rules.db"
    conn = sqlite3.connect(db)
    conn.execute(
        "CREATE TABLE rules (id TEXT PRIMARY KEY, category TEXT, ruleset TEXT, "
        "title TEXT, source_url TEXT)"
    )
    conn.executemany(
        "INSERT INTO rules (id, category, ruleset, title, source_url) VALUES (?, ?, ?, ?, ?)",
        [
            ("CHAP_Reiterkampf", "chapter",
             "core" if ruleset_written else None,
             "Reiterkampf" if title_written else None,
             "https://dsa.ulisses-regelwiki.de/Reiterkampf.html" if url_written else None),
            ("SA_62", "special_ability",
             "focus.trefferzonen" if ruleset_written else None, None,
             "https://dsa.ulisses-regelwiki.de/SA_62.html" if url_written else None),
            # The placeholder is deliberately never written to the database, so
            # this row's NULL is correct rather than missing.
            ("SA_99", "special_ability",
             "core" if ruleset_written else None, None, None),
        ],
    )
    conn.commit()
    conn.close()
    return db, rules_dir


def test_a_fully_populated_database_passes(tmp_path):
    db, rules_dir = _fixture(tmp_path)
    assert check_authored_fields(db, rules_dir) == []


def test_a_dropped_ruleset_is_caught(tmp_path):
    """The failure the dump comparison is blind to, and the one that matters
    most: a rule whose set never reached the database is a rule the engine
    cannot filter, so an optional rule applies to every hero."""
    db, rules_dir = _fixture(tmp_path, ruleset_written=False)
    errors = check_authored_fields(db, rules_dir)
    assert any("CHAP_Reiterkampf" in e and "ruleset" in e for e in errors)
    assert any("SA_62" in e and "ruleset" in e for e in errors)


def test_a_dropped_chapter_title_is_caught(tmp_path):
    db, rules_dir = _fixture(tmp_path, title_written=False)
    errors = check_authored_fields(db, rules_dir)
    assert any("CHAP_Reiterkampf" in e and "title" in e for e in errors)


def test_an_optolith_rule_is_not_asked_for_a_title(tmp_path):
    """`SA_62`'s row has a NULL title in every fixture above and is never an
    error: an Optolith id has a `rules_i18n` row carrying the real name."""
    db, rules_dir = _fixture(tmp_path)
    assert not any("SA_62" in e and "title" in e for e in check_authored_fields(db, rules_dir))


def test_an_authored_rule_with_no_row_at_all_is_caught(tmp_path):
    db, rules_dir = _fixture(tmp_path)
    conn = sqlite3.connect(db)
    conn.execute("DELETE FROM rules WHERE id = 'CHAP_Reiterkampf'")
    conn.commit()
    conn.close()
    assert any("no row in rules" in e for e in check_authored_fields(db, rules_dir))


def test_a_dropped_source_url_is_caught(tmp_path):
    """The same blind spot as `ruleset`, one task later and one column over.
    `source_url` is the page the authoring driver is meant to fetch instead of
    the Optolith seed (ADR-0007, plan Task 10); a `source.url` that stops at the
    YAML leaves the driver reading the seed, silently, which is the defect the
    calibration gate failed on."""
    db, rules_dir = _fixture(tmp_path, url_written=False)
    errors = check_authored_fields(db, rules_dir)
    assert any("CHAP_Reiterkampf" in e and "source_url" in e for e in errors)
    assert any("SA_62" in e and "source_url" in e for e in errors)


def test_the_unverified_placeholder_is_not_expected_in_the_database(tmp_path):
    """`SA_99` still carries `.../UNVERIFIED`, and `build_db.py` deliberately
    does not write it -- it is not a URL, and writing it would hand the driver a
    page to fetch that does not exist. Its NULL column is correct, and demanding
    it here would make the honest build fail."""
    db, rules_dir = _fixture(tmp_path)
    assert not any("SA_99" in e for e in check_authored_fields(db, rules_dir))


def _write_map(tmp_path, resolved):
    path = tmp_path / "resolved_urls.json"
    path.write_text(json.dumps({"resolved": resolved, "reported": []}), encoding="utf-8")
    return path


def test_a_resolution_that_never_reached_the_database_is_caught(tmp_path):
    """The state the dump comparison cannot see at all: both sides of a rebuild
    read the same resolution, so a column that never gets filled is empty
    identically in both and the dumps match. Without this check, a checkout
    whose `make rules-db` ran before `make rules-resolve` reports "rules.db is
    current" with every resolved URL missing -- and the next task's driver is
    going to read that column."""
    db, rules_dir = _fixture(tmp_path)
    conn = sqlite3.connect(db)
    conn.execute("INSERT INTO rules (id, category) VALUES ('SA_151', 'special_ability')")
    conn.commit()
    conn.close()

    map_path = _write_map(tmp_path, {"SA_151": "https://dsa.ulisses-regelwiki.de/PH_Eins.html"})
    errors = check_resolution_reached_the_db(db, rules_dir, map_path)
    assert any("SA_151" in e and "did not reach" not in e for e in errors)
    assert errors[-1].startswith("1 of 1 resolved URL(s) did not reach")


def test_an_authored_url_overriding_a_resolved_one_is_not_a_failure(tmp_path):
    """`build_db.import_effects` writes the authored `source.url` over whatever
    the resolution put in the same column, on purpose: a URL a person reviewed
    and committed outranks one a crawl resolved. So for those rules the map's
    value not reaching the database is the designed behaviour. The first version
    of this check did not know that and reported a golden rule as stale."""
    db, rules_dir = _fixture(tmp_path)
    map_path = _write_map(tmp_path, {"SA_62": "https://dsa.ulisses-regelwiki.de/PH_Anders.html"})
    assert check_resolution_reached_the_db(db, rules_dir, map_path) == []


def test_a_resolution_that_did_reach_the_database_passes(tmp_path):
    db, rules_dir = _fixture(tmp_path)
    conn = sqlite3.connect(db)
    conn.execute(
        "INSERT INTO rules (id, category, source_url) "
        "VALUES ('SA_151', 'special_ability', 'https://dsa.ulisses-regelwiki.de/PH_Eins.html')"
    )
    conn.commit()
    conn.close()
    map_path = _write_map(tmp_path, {"SA_151": "https://dsa.ulisses-regelwiki.de/PH_Eins.html"})
    assert check_resolution_reached_the_db(db, rules_dir, map_path) == []


def test_a_resolved_rule_with_no_row_at_all_is_caught(tmp_path):
    db, rules_dir = _fixture(tmp_path)
    map_path = _write_map(tmp_path, {"SA_404": "https://dsa.ulisses-regelwiki.de/PH_Eins.html"})
    assert any("SA_404" in e and "no row in rules" in e
               for e in check_resolution_reached_the_db(db, rules_dir, map_path))


def test_a_missing_resolution_is_reported_but_not_failed(tmp_path, capsys):
    """A fresh checkout legitimately has not run the resolver yet: the remedy is
    a command, not a repair. But it must not be silent, which it was."""
    db, rules_dir = _fixture(tmp_path)
    assert check_resolution_reached_the_db(db, rules_dir, tmp_path / "absent.json") == []
    assert "make rules-resolve" in capsys.readouterr().err
