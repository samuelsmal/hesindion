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
import hashlib, pathlib, sqlite3, subprocess, sys, tempfile

import yaml

# Kept in sync by hand with `scripts/rules_lint/lint.py`'s NON_RULE_FILES and
# `build_db.py`'s `import_effects` skip list -- the same three small local
# constants those two already note.
NON_RULE_FILES = {"SOURCES.yaml", "vocabulary.yaml"}
CHAPTER_PREFIX = "CHAP_"


def dump_hash(db: pathlib.Path) -> str:
    out = subprocess.run(["sqlite3", str(db), ".dump"], capture_output=True, check=True).stdout
    return hashlib.sha256(out).hexdigest()


def check_authored_fields(db: pathlib.Path, rules_dir: pathlib.Path) -> list[str]:
    """Every authored rule's `ruleset` -- and every chapter rule's `source.title`
    -- is present in the database and equal to what the file declares.

    `ruleset` decides whether a rule fires for everybody or for nobody (ADR-0009),
    and `source.title` is the only name a chapter rule has to show in a breakdown,
    since it has no `rules_i18n` row. Both are silent when missing: the engine
    filters nothing and the UI renders an id. Hence a loud check here.
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
                "SELECT ruleset, title FROM rules WHERE id = ?", (rule_id,)
            ).fetchone()
            if row is None:
                errors.append(f"{rule_id}: authored in {path.name} but has no row in rules")
                continue
            db_ruleset, db_title = row
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


def main(shipped: str, source: str, rules: str) -> int:
    with tempfile.TemporaryDirectory() as tmp:
        fresh = pathlib.Path(tmp) / "rules.db"
        subprocess.run([sys.executable, "scripts/build_rules_db/build_db.py",
                        "--source", source, "--effects", rules, "--output", str(fresh)], check=True)
        if dump_hash(pathlib.Path(shipped)) != dump_hash(fresh):
            print("rules.db is stale — run `make rules-db`", file=sys.stderr)
            return 1

    errors = check_authored_fields(pathlib.Path(shipped), pathlib.Path(rules))
    if errors:
        for e in errors:
            print(e, file=sys.stderr)
        print(f"rules.db is current but {len(errors)} authored field(s) did not reach it",
              file=sys.stderr)
        return 1
    print("rules.db is current")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:4]))
