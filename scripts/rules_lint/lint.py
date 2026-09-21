"""Validate authored rule files. Schema first, then the repo rules the schema cannot express."""
import json, pathlib, re, sys, unicodedata, urllib.parse
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

REPO_ROOT = pathlib.Path(__file__).parents[2]
SCHEMA = json.loads((REPO_ROOT / "specs/rules/schema.json").read_text())

# Files under specs/rules/ that are not one-rule-per-file authored specs. Kept
# in sync by hand with `scripts/rules_sync/check.py`'s NON_RULE_FILES and
# `scripts/build_rules_db/build_db.py`'s `import_effects` skip list — three
# small local constants rather than a shared module, matching the DELAY/HEADERS
# precedent already set between check.py and the old scraper. Adding a fourth
# non-rule file means editing all three.
NON_RULE_FILES = {"SOURCES.yaml", "vocabulary.yaml"}

# The open-vocabulary registry (Task 4 fix round 1, Q4). ADR-0008 leaves
# `actionEconomy.grants`/`forbids`, `legality.action` and the `gmFlag`
# predicate open on purpose, because they are not finite over 232 rules.
# schema.json constrains each to a slug shape; this file is what stops a slug
# nobody has agreed on from entering the corpus silently. The mapping is
# {schema location -> registry section}.
VOCABULARY = yaml.safe_load((REPO_ROOT / "specs/rules/vocabulary.yaml").read_text())
_VOCABULARY_SECTIONS = ("grants", "forbids", "legalityAction", "gmFlag")

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

# `propose.py` marks a rule whose two independent encodings disagreed by
# prefixing its root note (Task 6). The marker is a note rather than a `#`
# comment because comments are rejected outright above -- but an unresolved
# disagreement must not reach `main` either, so the default lint rejects it and
# only the driver that writes it passes `allow_disagreement=True`.
DISAGREEMENT_PREFIX = "DISAGREEMENT:"

# Chapter rules (schema.json, `#/$defs/ruleId`). A chapter page has no Optolith
# id, so its id is derived from the one identifier it does have: the page its
# `source.url` already records. The checks below are what makes that a rule
# rather than a convention -- without them "the id is the page slug" is a
# sentence in a schema description that nothing enforces, and two files could
# encode the same page under two ids, or one id could drift off its page while
# both still lint clean.
CHAPTER_PREFIX = "CHAP_"

# Transliterated rather than stripped: the site's URLs carry umlauts
# percent-encoded (e.g. KSF_Vorsto%C3%9F.html), and dropping them would fold
# two different pages onto one slug. German transliteration first, then an
# ASCII fold for anything else, then non-alphanumerics out.
_TRANSLITERATE = {
    "ä": "ae", "ö": "oe", "ü": "ue",
    "Ä": "Ae", "Ö": "Oe", "Ü": "Ue",
    "ß": "ss",
}

# The placeholder every migrated rule was seeded with (see
# scripts/rules_sync/check.py). Spelled locally rather than imported: lint.py
# must not grow a `requests` dependency to know one string.
_UNVERIFIED_STEM = "UNVERIFIED"


def chapter_slug(url: str) -> str:
    """The ASCII PascalCase slug a chapter id must carry, derived from its page URL."""
    stem = urllib.parse.unquote(urllib.parse.urlparse(url).path).rsplit("/", 1)[-1]
    stem = re.sub(r"\.html?$", "", stem, flags=re.IGNORECASE)
    for source, replacement in _TRANSLITERATE.items():
        stem = stem.replace(source, replacement)
    stem = unicodedata.normalize("NFKD", stem).encode("ascii", "ignore").decode("ascii")
    return re.sub(r"[^A-Za-z0-9]", "", stem)


def _lint_chapter_rule(doc: dict) -> list[str]:
    """The three invariants a `CHAP_` file carries beyond the schema."""
    rule_id = str(doc.get("id") or "")
    if not rule_id.startswith(CHAPTER_PREFIX):
        return []

    errors = []
    if doc.get("subgroup") != "none":
        errors.append(
            f"chapter rule {rule_id}: subgroup must be 'none' -- a chapter page is a "
            "situation, not a maneuver a hero selects in a Kampfrunde"
        )

    url = str((doc.get("source") or {}).get("url", ""))
    slug = chapter_slug(url)
    if not slug or slug == _UNVERIFIED_STEM:
        errors.append(
            f"chapter rule {rule_id}: needs a real source.url -- a chapter id *is* its "
            "page, so the UNVERIFIED placeholder leaves the id deriving from nothing"
        )
    elif rule_id != CHAPTER_PREFIX + slug:
        errors.append(
            f"chapter rule {rule_id}: id must be '{CHAPTER_PREFIX}{slug}', derived from "
            f"source.url ({url}) -- one file per page, and the id says which page"
        )
    return errors


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


def _registered(section: str) -> set:
    """The slugs glossed under one `vocabulary.yaml` section."""
    return set((VOCABULARY or {}).get(section) or {})


def _unregistered_tokens(doc) -> list[str]:
    """Every open-vocabulary slug this document uses that `vocabulary.yaml`
    does not gloss. Runs after schema validation has already rejected the
    *shape* of a slug, so what is left to catch is a well-formed token nobody
    has written down — e.g. a second author spelling SA_66's lost-defence
    token `noDefense` while the corpus already says `defense`. Divergent
    synonyms are the failure an open vocabulary actually dies of, and they are
    invisible to a schema."""
    errors = []
    for effect in doc.get("effects") or []:
        if not isinstance(effect, dict):
            continue
        for field, section in (("grants", "grants"), ("forbids", "forbids")):
            token = effect.get(field)
            if isinstance(token, str) and token not in _registered(section):
                errors.append(
                    f"actionEconomy {field}: '{token}' is not registered in "
                    "specs/rules/vocabulary.yaml — add a one-line English gloss there"
                )
        if effect.get("type") == "legality":
            token = effect.get("action")
            if isinstance(token, str) and token not in _registered("legalityAction"):
                errors.append(
                    f"legality action: '{token}' is not registered in "
                    "specs/rules/vocabulary.yaml — add a one-line English gloss there"
                )
        for predicate in effect.get("when") or []:
            if not isinstance(predicate, dict):
                continue
            token = predicate.get("gmFlag")
            if isinstance(token, str) and token not in _registered("gmFlag"):
                errors.append(
                    f"gmFlag: '{token}' is not registered in "
                    "specs/rules/vocabulary.yaml — add a one-line English gloss there"
                )
    return errors


def lint_vocabulary(path: pathlib.Path | None = None) -> list[str]:
    """Check `vocabulary.yaml` itself: known sections only, and every gloss a
    non-empty ASCII string. A registry that may hold German prose would just
    relocate the Data Policy hole it exists to close."""
    doc = yaml.safe_load(path.read_text()) if path else VOCABULARY
    errors = []
    if not isinstance(doc, dict):
        return ["vocabulary.yaml: root must be a YAML mapping"]
    for section, entries in doc.items():
        if section == "description":
            continue
        if section not in _VOCABULARY_SECTIONS:
            errors.append(
                f"vocabulary.yaml: unknown section '{section}' — expected one of "
                f"{', '.join(_VOCABULARY_SECTIONS)}"
            )
            continue
        if not isinstance(entries, dict):
            errors.append(f"vocabulary.yaml: section '{section}' must be a mapping of slug to gloss")
            continue
        for slug, gloss in entries.items():
            if not isinstance(gloss, str) or not gloss.strip():
                errors.append(f"vocabulary.yaml: {section}.{slug} needs a non-empty English gloss")
            elif not gloss.isascii():
                errors.append(
                    f"vocabulary.yaml: {section}.{slug} gloss must be ASCII — "
                    "rule prose stays out of git (Data Policy)"
                )
    return errors


def lint_file(path: pathlib.Path, *, allow_disagreement: bool = False) -> list[str]:
    """Validate one authored rule file.

    `allow_disagreement` exists for `scripts/rules_sync/propose.py` alone: it
    writes a file whose root note carries the `DISAGREEMENT:` marker on purpose,
    for a human to resolve. Everywhere else -- `make rules-lint`, CI -- an
    unresolved disagreement is an error, so a proposal cannot be committed
    without someone deciding which of the two readings is right.
    """
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

    errors.extend(f"{path.name}: {e}" for e in _unregistered_tokens(doc))
    errors.extend(f"{path.name}: {e}" for e in _lint_chapter_rule(doc))

    if not allow_disagreement and str(doc.get("note") or "").startswith(DISAGREEMENT_PREFIX):
        errors.append(
            f"{path.name}: unresolved {DISAGREEMENT_PREFIX} marker on the root note -- the two "
            "independent encodings of this rule disagreed. Read .proposals/"
            f"{path.stem}.review.md, decide which reading is right, fix the file and remove the "
            "marker. A proposal is not an authored rule until someone has chosen."
        )

    if doc.get("id") and path.stem != doc["id"]:
        errors.append(f"{path.name}: filename must match id ({doc['id']}.yaml)")
    return errors


def main(root: str = "specs/rules") -> int:
    files = [f for f in sorted(pathlib.Path(root).glob("*.yaml")) if f.name not in NON_RULE_FILES]
    errors = [e for f in files for e in lint_file(f)]

    # The registry is linted too, wherever it sits next to the rules it governs
    # — otherwise `lint.py path/to/other/rules` would enforce glosses from the
    # repo's vocabulary while never checking that directory's own.
    vocabulary = pathlib.Path(root) / "vocabulary.yaml"
    if vocabulary.exists():
        errors.extend(lint_vocabulary(vocabulary))

    for e in errors:
        print(e, file=sys.stderr)
    print(f"{len(files)} rule file(s), {len(errors)} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
