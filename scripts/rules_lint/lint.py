"""Validate authored rule files. Schema first, then the repo rules the schema cannot express."""
import json, pathlib, sys
import yaml
from jsonschema import Draft202012Validator

# PyYAML's SafeLoader implicitly resolves bare ISO-8601 dates (e.g.
# `checked: 2026-09-20`) to datetime.date, not str — so schema's
# `source.checked: {"type": "string", "format": "date"}` would reject every
# valid file. Drop that implicit resolver so dates stay strings and the
# schema (not PyYAML) owns date validation via format checking.
class _RuleLoader(yaml.SafeLoader):
    pass


_RuleLoader.yaml_implicit_resolvers = {
    key: [(tag, regexp) for tag, regexp in resolvers if tag != "tag:yaml.org,2002:timestamp"]
    for key, resolvers in yaml.SafeLoader.yaml_implicit_resolvers.items()
}

SCHEMA = json.loads((pathlib.Path(__file__).parents[2] / "specs/rules/schema.json").read_text())

# Format checking is opt-in in `jsonschema` — a bare Draft202012Validator ignores
# "format" keywords entirely. We enable the library's default FormatChecker so
# `source.checked` (format: date) is actually validated. We deliberately do not
# add the `rfc3987` extra that would make `source.url` (format: uri) strict:
# without it, "uri" is simply not a registered checker and the keyword is a
# no-op for that field, same as leaving format checking off for it. That keeps
# this linter from ever rejecting a syntactically odd-but-intentional
# provenance URL — including Task 3's deliberate placeholder,
# `https://dsa.ulisses-regelwiki.de/UNVERIFIED` for unverified sources, which
# is a well-formed URL anyway and would pass either way.
VALIDATOR = Draft202012Validator(SCHEMA, format_checker=Draft202012Validator.FORMAT_CHECKER)


def lint_file(path: pathlib.Path) -> list[str]:
    errors: list[str] = []
    try:
        doc = yaml.load(path.read_text(), Loader=_RuleLoader) or {}
    except yaml.YAMLError as exc:
        return [f"{path.name}: unparseable YAML: {exc}"]

    if "text" in doc or any("text" in e for e in doc.get("effects", []) if isinstance(e, dict)):
        errors.append(f"{path.name}: 'text' is not allowed — rule prose stays out of git (Data Policy)")

    for err in VALIDATOR.iter_errors(doc):
        errors.append(f"{path.name}: {'.'.join(str(p) for p in err.absolute_path) or '<root>'}: {err.message}")

    if doc.get("id") and path.stem != doc["id"]:
        errors.append(f"{path.name}: filename must match id ({doc['id']}.yaml)")
    return errors


def main(root: str = "specs/rules") -> int:
    files = sorted(pathlib.Path(root).glob("*.yaml"))
    errors = [e for f in files if f.name != "SOURCES.yaml" for e in lint_file(f)]
    for e in errors:
        print(e, file=sys.stderr)
    print(f"{len(files)} rule file(s), {len(errors)} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
