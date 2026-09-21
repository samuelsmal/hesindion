"""Rebuild rules.db to a temp path and compare canonical dumps, then check the
authored corpus actually reached it.

SQLite does not guarantee byte-stable files, so compare `.dump` output, not bytes.

The dump comparison answers "is the shipped database what a rebuild produces".
It does *not* answer "did the build carry the authored fields across", because a
field the build drops is dropped identically on both sides: two NULL columns
compare equal and the check passes. That is exactly how `ruleset` could have been
added to every authored file, documented in an ADR, and still reached the engine
as nothing. So the authored fields are checked against the files that declare
them, not against another copy of the build's own output.
"""
from __future__ import annotations

import hashlib, json, pathlib, sqlite3, subprocess, sys, tempfile

import yaml

# Kept in sync by hand with scripts/rules_lint/lint.py's NON_RULE_FILES,
# scripts/rules_sync/check.py's NON_RULE_FILES (which additionally carries
# schema.json -- it is deliberately not equal to this one) and
# scripts/build_rules_db/build_db.py's NON_RULE_FILES — four small local
# constants rather than a shared module, the same precedent lint.py's comment
# states. `tests/rules/test_shared_constants.py` asserts the four stay in the
# stated relationship.
NON_RULE_FILES = {"SOURCES.yaml", "vocabulary.yaml"}
# Kept in sync by hand with scripts/rules_lint/lint.py's and
# scripts/build_rules_db/build_db.py's CHAPTER_PREFIX; the same test above
# asserts the three spellings agree.
CHAPTER_PREFIX = "CHAP_"
# Kept in sync by hand with scripts/rules_sync/check.py's and
# scripts/build_rules_db/build_db.py's UNVERIFIED_URL; the same test asserts
# the spellings agree. A file still carrying it has no page to check against.
UNVERIFIED_URL = "https://dsa.ulisses-regelwiki.de/UNVERIFIED"

# `make rules-resolve`'s output, which `build_db.py` reads. Same default path as
# `scripts/rules_sync/resolve.RESOLVED_MAP_PATH` and `build_db.DEFAULT_RESOLVED_MAP`
# -- not imported, because this module is run as a script with no package on the
# path, the same reason build_db.py carries its own copy.
RESOLVED_MAP = pathlib.Path(__file__).resolve().parents[2] / ".cache" / "rules_resolve" / "resolved_urls.json"


def dump_hash(db: pathlib.Path) -> str:
    out = subprocess.run(["sqlite3", str(db), ".dump"], capture_output=True, check=True).stdout
    return hashlib.sha256(out).hexdigest()


def check_authored_fields(db: pathlib.Path, rules_dir: pathlib.Path) -> list[str]:
    """Every authored rule's `ruleset`, its real `source.url`, and every chapter
    rule's `source.title`, present in the database and equal to what the file
    declares.

    `ruleset` decides whether a rule fires for everybody or for nobody (ADR-0009);
    `source.title` is the only name a chapter rule has to show in a breakdown,
    since it has no `rules_i18n` row; and `source_url` is the page the authoring
    driver is to fetch instead of the Optolith seed (ADR-0007, plan Task 10).
    All three are silent when missing: the engine filters nothing, the UI renders
    an id, and the driver keeps reading the seed. Hence a loud check here, and
    here rather than in the dump comparison above, which is blind to this whole
    class -- a column the build drops is dropped identically on both sides and
    two NULLs compare equal.

    A file still carrying the `UNVERIFIED` placeholder is skipped for
    `source_url`: the placeholder is deliberately not written to the database
    (`build_db.UNVERIFIED_URL`), so its absence there is correct, not missing.
    """
    errors: list[str] = []
    conn = sqlite3.connect(db)
    try:
        for path in sorted(p for p in rules_dir.glob("*.yaml") if p.name not in NON_RULE_FILES):
            doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
            rule_id = doc.get("id")
            if not rule_id:
                continue
            row = conn.execute(
                "SELECT ruleset, title, source_url FROM rules WHERE id = ?", (rule_id,)
            ).fetchone()
            if row is None:
                errors.append(f"{rule_id}: authored in {path.name} but has no row in rules")
                continue
            db_ruleset, db_title, db_source_url = row
            authored_url = (doc.get("source") or {}).get("url")
            if authored_url and authored_url != UNVERIFIED_URL and db_source_url != authored_url:
                errors.append(
                    f"{rule_id}: rules.source_url is {db_source_url!r}, {path.name} says "
                    f"{authored_url!r} -- the authoring driver reads the database, so a "
                    "source.url that stops at the YAML leaves it reading the Optolith seed"
                )
            if db_ruleset != doc.get("ruleset"):
                errors.append(
                    f"{rule_id}: rules.ruleset is {db_ruleset!r}, {path.name} says "
                    f"{doc.get('ruleset')!r} -- the engine reads the database, so a ruleset "
                    "that stops at the YAML applies to nobody"
                )
            if rule_id.startswith(CHAPTER_PREFIX):
                want = (doc.get("source") or {}).get("title")
                if db_title != want:
                    errors.append(
                        f"{rule_id}: rules.title is {db_title!r}, {path.name} says {want!r} -- "
                        "a chapter rule has no rules_i18n row, so this is the only name a "
                        "breakdown line citing it can display"
                    )
    finally:
        conn.close()
    return errors


def check_resolution_reached_the_db(
    db: pathlib.Path, rules_dir: pathlib.Path, map_path: pathlib.Path | None = None
) -> list[str]:
    """Every URL `make rules-resolve` confirmed is in `rules.source_url`, except
    where an authored file legitimately overrode it.

    Without this, a checkout with no `.cache/rules_resolve/` builds a database
    whose `source_url` is NULL for all 200-odd resolved rules, `make rules-db`
    says so in one informational line, and `make rules-db-verify` reports
    "rules.db is current" -- because it is: the resolution is not an input to
    the rebuild comparison. "Current" and "complete" are different claims, and
    the driver that is going to read this column cannot tell them apart.

    A missing map is reported, not failed: a fresh checkout legitimately has not
    run the resolver yet, and the remedy is a command, not a repair.

    Rules whose authored file carries a real `source.url` are skipped here, and
    checked by `check_authored_fields` instead. `build_db.import_effects`
    deliberately writes the authored URL over the resolved one -- a URL a person
    reviewed outranks one a crawl resolved -- so for those rules the map's value
    *not* reaching the database is the designed behaviour, not a failure. (This
    exclusion is not theoretical: the first version of this check reported
    `SA_40` as stale for exactly that reason.)
    """
    map_path = map_path or RESOLVED_MAP
    if not map_path.exists():
        print(
            f"note: no resolution at {map_path} -- rules.source_url carries only the "
            "URLs the authored files record. Run `make rules-resolve && make rules-db` "
            "before anything reads that column.",
            file=sys.stderr,
        )
        return []

    resolved = (json.loads(map_path.read_text(encoding="utf-8")).get("resolved") or {})
    overridden = authored_urls(rules_dir)
    errors: list[str] = []
    conn = sqlite3.connect(db)
    try:
        for rule_id, url in sorted(resolved.items()):
            if rule_id in overridden:
                continue
            row = conn.execute("SELECT source_url FROM rules WHERE id = ?", (rule_id,)).fetchone()
            if row is None:
                errors.append(f"{rule_id}: resolved to a page but has no row in rules")
            elif row[0] != url:
                errors.append(
                    f"{rule_id}: rules.source_url is {row[0]!r}, the resolution says {url!r} "
                    "-- run `make rules-db` to carry it in"
                )
    finally:
        conn.close()
    if errors:
        checked = len(resolved) - len(set(resolved) & set(overridden))
        errors.append(f"{len(errors)} of {checked} resolved URL(s) did not reach rules.db")
    return errors


def authored_urls(rules_dir: pathlib.Path) -> dict[str, str]:
    """`{rule_id: url}` for every authored file carrying a real URL -- the ones a
    person reviewed and committed, which outrank a resolved URL. The files still
    holding the `UNVERIFIED` placeholder are not in here: the placeholder is not
    a URL and is deliberately never written to the database."""
    out: dict[str, str] = {}
    for path in sorted(p for p in rules_dir.glob("*.yaml") if p.name not in NON_RULE_FILES):
        doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        url = (doc.get("source") or {}).get("url")
        if doc.get("id") and url and url != UNVERIFIED_URL:
            out[doc["id"]] = url
    return out


def main(shipped: str, source: str, rules: str) -> int:
    with tempfile.TemporaryDirectory() as tmp:
        fresh = pathlib.Path(tmp) / "rules.db"
        subprocess.run([sys.executable, "scripts/build_rules_db/build_db.py",
                        "--source", source, "--effects", rules, "--output", str(fresh)], check=True)
        if dump_hash(pathlib.Path(shipped)) != dump_hash(fresh):
            print("rules.db is stale — run `make rules-db`", file=sys.stderr)
            return 1

    errors = check_authored_fields(pathlib.Path(shipped), pathlib.Path(rules))
    errors += check_resolution_reached_the_db(pathlib.Path(shipped), pathlib.Path(rules))
    if errors:
        for e in errors:
            print(e, file=sys.stderr)
        print(f"rules.db is a faithful rebuild, but {len(errors)} check(s) failed on what it "
              "carries -- see above", file=sys.stderr)
        return 1
    print("rules.db is current")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:4]))
