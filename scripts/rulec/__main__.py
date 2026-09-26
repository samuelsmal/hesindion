"""rulec's command line: `check` validates the rule and situations files, `build` compiles them to
`rules.json` and `situations.json`.

The situations default to the `situations` directory next to the rules directory and are skipped
when that does not exist; a `--situations` directory given explicitly must exist. The Probe table
(`checks.yaml` next to the rules directory, `--checks`; Task 34) is checked when it exists and goes
into situations.json as `checks`."""
import argparse
import sys
from pathlib import Path

from . import checks, compile, rules, situations, vocab
from .errors import RulecError

EXAMPLES = Path(__file__).resolve().parents[2] / "docs" / "rules-rework" / "examples"


def main(argv=None):
    p = argparse.ArgumentParser(prog="rulec")
    sub = p.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("check")
    c.add_argument("--rules", type=Path, default=EXAMPLES / "rules")
    c.add_argument("--situations", type=Path, default=None)
    c.add_argument("--checks", type=Path, default=None)
    c.add_argument("--only", nargs="*", default=None, help="report errors only for these files")
    b = sub.add_parser("build")
    b.add_argument("--rules", type=Path, default=EXAMPLES / "rules")
    b.add_argument("--situations", type=Path, default=None)
    b.add_argument("--checks", type=Path, default=None)
    b.add_argument("--out", type=Path, required=True)
    a = p.parse_args(argv)
    v = vocab.load()
    book, errors = rules.check(a.rules, v)
    shared = rules.shared_rulings(a.rules)

    checks_path = a.checks if a.checks is not None else Path(a.rules).parent / "checks.yaml"
    table = {}
    if a.checks is not None and not checks_path.is_file():
        errors.append(RulecError(f"no checks table {checks_path}", str(checks_path)))
    elif checks_path.is_file():
        table, check_errors = checks.load(checks_path)
        errors += check_errors

    sit_dir = a.situations if a.situations is not None else Path(a.rules).parent / "situations"
    compiled = None
    if a.situations is not None and not sit_dir.is_dir():
        errors.append(RulecError(f"no situations directory {sit_dir}", str(sit_dir)))
    elif sit_dir.is_dir():
        # The reach index straight from the book: `build_rules` would also fail on unreachable
        # clauses, which is a build error, not a situation error.
        reach = compile._reach([book[k] for k in sorted(book)])
        compiled, sit_errors = situations.check(sit_dir, book, reach, v, shared, checks=table)
        errors += sit_errors

    if a.cmd == "check" and a.only is not None:
        errors = [e for e in errors if any(str(e.file).endswith(o) for o in a.only)]
    for e in errors:
        print(e)
    if errors:
        print(f"{len(errors)} errors")
        return 1
    n_pending = sum(1 for s in compiled or [] if s["pending"])
    if a.cmd == "build":
        try:
            obj = compile.build_rules(book, v, shared)
        except RulecError as e:
            print(e)
            return 1
        path = a.out / "rules.json"
        compile.write(obj, path)
        print(f"wrote {path} ({len(book)} rules)")
        if compiled is not None:
            spath = a.out / "situations.json"
            compile.write(compile._jsonable({"vocabularyVersion": v.version, "situations": compiled,
                                                     "checks": table}), spath)
            print(f"wrote {spath} ({len(compiled)} situations, {n_pending} pending)")
        return 0
    n_cl = sum(len(r["clauses"]) for r in book.values())
    n_ef = sum(len(c.get("effects", [])) for r in book.values() for c in r["clauses"])
    tail = f", {len(compiled)} situations ({n_pending} pending)" if compiled is not None else ""
    print(f"ok: {len(book)} rules, {n_cl} clauses, {n_ef} effects{tail}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
