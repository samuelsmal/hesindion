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
import sqlite3
import textwrap

from scripts.build_rules_db.verify_db import check_authored_fields

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


def _fixture(tmp_path, *, ruleset_written=True, title_written=True):
    rules_dir = tmp_path / "rules"
    rules_dir.mkdir()
    (rules_dir / "CHAP_Reiterkampf.yaml").write_text(CHAPTER_FILE)
    (rules_dir / "SA_62.yaml").write_text(ABILITY_FILE)

    db = tmp_path / "rules.db"
    conn = sqlite3.connect(db)
    conn.execute(
        "CREATE TABLE rules (id TEXT PRIMARY KEY, category TEXT, ruleset TEXT, title TEXT)"
    )
    conn.executemany(
        "INSERT INTO rules (id, category, ruleset, title) VALUES (?, ?, ?, ?)",
        [
            ("CHAP_Reiterkampf", "chapter",
             "core" if ruleset_written else None,
             "Reiterkampf" if title_written else None),
            ("SA_62", "special_ability",
             "focus.trefferzonen" if ruleset_written else None, None),
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
