"""Rebuild rules.db to a temp path and compare canonical dumps.

SQLite does not guarantee byte-stable files, so compare `.dump` output, not bytes.
"""
import hashlib, subprocess, sys, tempfile, pathlib

def dump_hash(db: pathlib.Path) -> str:
    out = subprocess.run(["sqlite3", str(db), ".dump"], capture_output=True, check=True).stdout
    return hashlib.sha256(out).hexdigest()

def main(shipped: str, source: str, rules: str) -> int:
    with tempfile.TemporaryDirectory() as tmp:
        fresh = pathlib.Path(tmp) / "rules.db"
        subprocess.run([sys.executable, "scripts/build_rules_db/build_db.py",
                        "--source", source, "--effects", rules, "--output", str(fresh)], check=True)
        if dump_hash(pathlib.Path(shipped)) != dump_hash(fresh):
            print("rules.db is stale — run `make rules-db`", file=sys.stderr)
            return 1
    print("rules.db is current")
    return 0

if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:4]))
