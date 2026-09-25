"""rulec's command line: `check` validates the rule files, `build` compiles them to `rules.json`."""
import argparse
import sys
from pathlib import Path

from . import compile, rules, vocab
from .errors import RulecError

EXAMPLES = Path(__file__).resolve().parents[2] / "docs" / "rules-rework" / "examples"


def main(argv=None):
    p = argparse.ArgumentParser(prog="rulec")
    sub = p.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("check")
    c.add_argument("--rules", type=Path, default=EXAMPLES / "rules")
    c.add_argument("--situations", type=Path, default=EXAMPLES / "situations")
    c.add_argument("--only", nargs="*", default=None, help="report errors only for these files")
    b = sub.add_parser("build")
    b.add_argument("--rules", type=Path, default=EXAMPLES / "rules")
    b.add_argument("--situations", type=Path, default=EXAMPLES / "situations")
    b.add_argument("--out", type=Path, required=True)
    a = p.parse_args(argv)
    v = vocab.load()
    book, errors = rules.check(a.rules, v)
    if a.cmd == "check" and a.only is not None:
        errors = [e for e in errors if any(str(e.file).endswith(o) for o in a.only)]
    for e in errors:
        print(e)
    if errors:
        print(f"{len(errors)} errors")
        return 1
    if a.cmd == "build":
        try:
            obj = compile.build_rules(book, v, rules.shared_rulings(a.rules))
        except RulecError as e:
            print(e)
            return 1
        path = a.out / "rules.json"
        compile.write(obj, path)
        print(f"wrote {path} ({len(book)} rules)")
        return 0
    n_cl = sum(len(r["clauses"]) for r in book.values())
    n_ef = sum(len(c.get("effects", [])) for r in book.values() for c in r["clauses"])
    print(f"ok: {len(book)} rules, {n_cl} clauses, {n_ef} effects")
    return 0


if __name__ == "__main__":
    sys.exit(main())
