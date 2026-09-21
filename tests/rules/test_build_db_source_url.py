"""`rules.source_url` -- the two writers that fill it, and which one wins.

The column is the map's home (plan Task 10): `rules.db` is a generated,
untracked build artifact, so recording a rule's page there puts it where the
authoring driver reads from without any ability name entering git. Two things
write it, in this order, and the order is the whole of the behaviour:

1. `import_resolved_urls` copies what `make rules-resolve` **confirmed**. Only
   rules whose three identity signals all agreed are in that file; the builder
   copies and does not re-judge.
2. `import_effects` writes the authored `specs/rules/*.yaml` files' own
   `source.url` over it, because a URL a person reviewed and committed outranks
   one a crawl resolved -- except for the `UNVERIFIED` placeholder, which is not
   a URL and must never reach the database as one.

Neither had a test. The consequence a reviewer confirmed by hand: a checkout
with no resolution builds a database whose `source_url` is NULL for every
resolved rule, `make rules-db` says so in one informational line, and
`make rules-db-verify` still reports "rules.db is current" -- because it is.
`tests/rules/test_verify_db.py` closes the verify side; this closes the build
side.

No Optolith source is needed: both functions take a connection, so a three-row
fixture exercises them. All ids and URLs here are placeholders.
"""
import json
import sqlite3
import textwrap

from scripts.build_rules_db.build_db import (
    UNVERIFIED_URL,
    import_effects,
    import_resolved_urls,
)

RESOLVED = "https://dsa.ulisses-regelwiki.de/PH_Resolved.html"
AUTHORED = "https://dsa.ulisses-regelwiki.de/PH_Authored.html"


def _rule_file(rule_id, url):
    return textwrap.dedent("""
        id: {rule_id}
        subgroup: passiv
        ruleset: core
        source:
          url: {url}
          checked: '2026-09-21'
          hash: sha256:{h}
        effects:
        - type: modifier
          target: at
          scope: combat
          value: 1
    """).format(rule_id=rule_id, url=url, h="0" * 64)


def _conn(rule_ids=("PH_1", "PH_2", "PH_3")):
    conn = sqlite3.connect(":memory:")
    conn.executescript(
        """
        CREATE TABLE rules (id TEXT PRIMARY KEY, category TEXT, ruleset TEXT,
                            title TEXT, source_url TEXT);
        CREATE TABLE effects (id INTEGER PRIMARY KEY AUTOINCREMENT, rule_id TEXT,
                              level INTEGER, type TEXT, attribute TEXT, value REAL,
                              scope TEXT, target TEXT, condition TEXT,
                              description TEXT, payload TEXT);
        """
    )
    conn.executemany(
        "INSERT INTO rules (id, category) VALUES (?, 'special_ability')",
        [(r,) for r in rule_ids],
    )
    conn.commit()
    return conn


def _map(tmp_path, resolved):
    path = tmp_path / "resolved_urls.json"
    path.write_text(json.dumps({"resolved": resolved, "reported": []}), encoding="utf-8")
    return path


def _url(conn, rule_id):
    return conn.execute("SELECT source_url FROM rules WHERE id = ?", (rule_id,)).fetchone()[0]


# ── the resolution half ──────────────────────────────────────────────────────

def test_a_confirmed_resolution_reaches_the_column(tmp_path):
    conn = _conn()
    import_resolved_urls(conn, _map(tmp_path, {"PH_1": RESOLVED}))
    assert _url(conn, "PH_1") == RESOLVED


def test_a_resolution_for_a_rule_the_database_does_not_have_is_counted_not_crashed(tmp_path, capsys):
    conn = _conn()
    import_resolved_urls(conn, _map(tmp_path, {"PH_1": RESOLVED, "PH_404": RESOLVED}))
    assert _url(conn, "PH_1") == RESOLVED
    out = capsys.readouterr().out
    assert "Applied 1" in out and "1 not in the DB" in out


def test_no_resolution_file_leaves_the_column_alone_and_says_so(tmp_path, capsys):
    """A build with no resolve run behind it is a legitimate state -- but it was
    a silent one, and the driver is about to read this column."""
    conn = _conn()
    import_resolved_urls(conn, tmp_path / "absent.json")
    assert _url(conn, "PH_1") is None
    assert "make rules-resolve" in capsys.readouterr().out


def test_an_empty_url_in_the_map_is_skipped(tmp_path):
    conn = _conn()
    import_resolved_urls(conn, _map(tmp_path, {"PH_1": ""}))
    assert _url(conn, "PH_1") is None


# ── the authored half, and which one wins ────────────────────────────────────

def test_an_authored_url_overwrites_a_resolved_one(tmp_path):
    """A URL a person reviewed and committed outranks one a crawl resolved.
    This is also why the closed-loop check in `test_resolve.py` compares the
    resolver's map against the files and *not* against the database: here, the
    two can never disagree."""
    conn = _conn()
    import_resolved_urls(conn, _map(tmp_path, {"PH_1": RESOLVED}))

    rules_dir = tmp_path / "rules"
    rules_dir.mkdir()
    (rules_dir / "PH_1.yaml").write_text(_rule_file("PH_1", AUTHORED), encoding="utf-8")
    import_effects(conn, rules_dir)

    assert _url(conn, "PH_1") == AUTHORED


def test_the_unverified_placeholder_never_overwrites_a_resolved_url(tmp_path):
    """The placeholder means "nobody has looked". Writing it over a resolved URL
    would replace a real page with a marker for one that does not exist, and
    hand the driver a 404 to fetch -- strictly worse than the NULL it replaces."""
    conn = _conn()
    import_resolved_urls(conn, _map(tmp_path, {"PH_1": RESOLVED}))

    rules_dir = tmp_path / "rules"
    rules_dir.mkdir()
    (rules_dir / "PH_1.yaml").write_text(_rule_file("PH_1", UNVERIFIED_URL), encoding="utf-8")
    import_effects(conn, rules_dir)

    assert _url(conn, "PH_1") == RESOLVED


def test_the_unverified_placeholder_is_never_written_at_all(tmp_path):
    """Not even where there was nothing to overwrite: NULL says "no page known",
    the placeholder says "this is the page", and only one of those is true."""
    conn = _conn()
    rules_dir = tmp_path / "rules"
    rules_dir.mkdir()
    (rules_dir / "PH_2.yaml").write_text(_rule_file("PH_2", UNVERIFIED_URL), encoding="utf-8")
    import_effects(conn, rules_dir)
    assert _url(conn, "PH_2") is None


def test_an_authored_file_does_not_disturb_another_rules_resolved_url(tmp_path):
    conn = _conn()
    import_resolved_urls(conn, _map(tmp_path, {"PH_1": RESOLVED, "PH_3": RESOLVED}))
    rules_dir = tmp_path / "rules"
    rules_dir.mkdir()
    (rules_dir / "PH_1.yaml").write_text(_rule_file("PH_1", AUTHORED), encoding="utf-8")
    import_effects(conn, rules_dir)
    assert _url(conn, "PH_3") == RESOLVED
