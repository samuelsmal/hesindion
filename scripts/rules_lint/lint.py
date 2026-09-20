"""Validate authored rule files. Schema first, then the repo rules the schema cannot express."""
import json, pathlib, re, sys
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
# `source.checked` (format: date) is actually validated. `source.url` no longer
# uses `format: uri` at all (it was a no-op without the `rfc3987` extra, which
# this repo does not add) — it uses an enforced `pattern` instead.
VALIDATOR = Draft202012Validator(SCHEMA, format_checker=Draft202012Validator.FORMAT_CHECKER)

# A '#' that starts a token is a YAML comment (a '#' inside an unquoted scalar
# only starts a comment when preceded by whitespace or at line start; we don't
# attempt to special-case '#' inside quoted scalars — this repo's authored
# files have no legitimate reason to contain one, so any match is rejected).
_COMMENT_RE = re.compile(r"(?:^|\s)#")


def _first_comment_line(raw: str) -> int | None:
    for lineno, line in enumerate(raw.splitlines(), start=1):
        if _COMMENT_RE.search(line):
            return lineno
    return None


def _contains_text_key(node) -> bool:
    """Recursively look for a 'text' key anywhere in the parsed document —
    not just at the root or one level into `effects`, so it also catches a
    `text` key smuggled into a `when` predicate value or any other nesting."""
    if isinstance(node, dict):
        if "text" in node:
            return True
        return any(_contains_text_key(v) for v in node.values())
    if isinstance(node, list):
        return any(_contains_text_key(v) for v in node)
    return False


def lint_file(path: pathlib.Path) -> list[str]:
    errors: list[str] = []
    raw = path.read_text()
    try:
        doc = yaml.load(raw, Loader=_RuleLoader)
    except yaml.YAMLError as exc:
        return [f"{path.name}: unparseable YAML: {exc}"]

    if doc is None:
        doc = {}
    if not isinstance(doc, dict):
        return [f"{path.name}: root must be a YAML mapping (one rule per file), got {type(doc).__name__}"]

    if _contains_text_key(doc):
        errors.append(f"{path.name}: 'text' is not allowed — rule prose stays out of git (Data Policy)")

    comment_line = _first_comment_line(raw)
    if comment_line is not None:
        errors.append(
            f"{path.name}: line {comment_line}: '#' comments are not allowed — "
            "rule prose stays out of git (Data Policy)"
        )

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
