"""The calibration gate (Task 7): grade a recorded pipeline run against the golden ten.

**This module makes no model calls.** The gate's measurement costs roughly twenty
live agent calls, so the run is made once by hand, its output recorded under
`tests/rules/calibration/<date>-<model>/`, and graded here. That keeps the gate
reproducible -- `pytest` re-derives the verdict from bytes, every time, for free --
and keeps the expensive half a deliberate act. `tests/conftest.py`'s autouse
fixture enforces the "no live agents" half; nothing here would trip it anyway.

The rubric, fixed before the run
--------------------------------
Task 6 established that byte equality with the golden files is *not* the target.
Its first end-to-end run reproduced two hand-authored files down to the wording of
every note, because both agents had read those files -- so byte equality is the
signature of contamination, and a properly isolated agent should diverge on
modelling choices. The gate is therefore two-tiered.

**Tier 1 -- graded, must match.** Every *mechanical* effect row must match the
golden's, compared as an unordered multiset on the fields that say what the rule
does: `type`, `target`, `value`, `tier`, `when`, `side`, `recipient`,
`parameter`/`set`/`scale`/`shiftSteps`, `grants`/`forbids`, `add`, `action`,
`scope`, and the remaining value-bearing fields of the effect union. `note` is
excluded (two agents wording the same mechanic differently is not a disagreement
about the rule) and so is a schema default written out explicitly, for the reason
`propose._SCHEMA_DEFAULTS` gives.

**Tier 2 -- reported, never graded.** Whether a clause became a `reminder` row or
an `UNENCODED:` root note, note wording, effect ordering, and the number of
reminder rows. These are the choices a correctly isolated agent is *expected* to
make differently, and `test_tier_2_divergences_are_reported` prints them rather
than asserting on them.

`excludes` sits deliberately in Tier 2 here, and it is the one Tier 2 item worth
watching: it is mechanical, but resolving "cannot be combined with <German name>"
to a rule id requires the corpus entry for that rule, which the calibration
workspace withholds *because it is one of the ten being graded*. That is an
artefact of grading all ten at once, not a property of a production wave.
"""
import json
import pathlib

import pytest
import yaml

from scripts.rules_lint.lint import lint_file

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
GOLDEN_DIR = REPO_ROOT / "specs" / "rules"
RUN_DIR = REPO_ROOT / "tests" / "rules" / "calibration" / "2026-09-21-sonnet"
RUN = yaml.safe_load((RUN_DIR / "RUN.yaml").read_text(encoding="utf-8"))

# Spelled out rather than read from the manifest or from the run directory: both
# are artefacts under test, and a gate that derived its own scope from them would
# pass just as happily over three rules as over ten.
GOLDEN_IDS = [
    "SA_40", "SA_41", "SA_43", "SA_48", "SA_59",
    "SA_62", "SA_65", "SA_66", "SA_67", "SA_661",
]

# Every field of the effect union except `note`. Listing them rather than taking
# "all keys" means a field added to schema.json arrives here as a deliberate
# edit instead of silently widening or narrowing what the gate compares.
TIER1_FIELDS = frozenset({
    "type", "tier", "when", "stacks", "target", "scope", "side", "value",
    "parameter", "set", "shiftSteps", "scale", "add", "recipient", "grants",
    "forbids", "skill", "state", "level", "action", "attribute", "operation",
    "per",
})

# Same reasoning as propose._SCHEMA_DEFAULTS: one encoding spelling a declared
# default and the other leaving it implicit is the same encoding.
SCHEMA_DEFAULTS = {"side": "hero", "recipient": "target"}

REMEDY = (
    "The pipeline's encoding diverged from the hand-authored one. Fix the agent "
    "brief (.claude/agents/rule-author.md, rule-verifier.md) and re-run the "
    "calibration, then re-record tests/rules/calibration/; never edit the golden "
    "files under specs/rules/ to make this pass."
)


def _load(path):
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


def _mechanics(row):
    """One effect row reduced to what Tier 1 grades."""
    if not isinstance(row, dict):
        return {"<malformed>": repr(row)}
    return {
        k: v for k, v in row.items()
        if k in TIER1_FIELDS and not (k in SCHEMA_DEFAULTS and v == SCHEMA_DEFAULTS[k])
    }


def _key(row):
    return json.dumps(_mechanics(row), sort_keys=True, ensure_ascii=True, default=str)


def _rows(doc, *, reminders):
    effects = doc.get("effects") or []
    return [e for e in effects
            if isinstance(e, dict) and ((e.get("type") == "reminder") is reminders)]


def _run_path(rule_id):
    return RUN_DIR / f"{rule_id}.yaml"


def tier1_verdict(rule_id):
    """(passed, detail). `detail` names the first differing row, by design: over
    nine rows of a tier ladder a full diff is unreadable and the first missing
    row is almost always the whole story."""
    run_path = _run_path(rule_id)
    if not run_path.exists():
        return False, (
            f"{rule_id}: the run produced no file. The proposal was rejected before "
            f"it could be written -- see RUN.yaml's `failures` entry"
        )
    golden = sorted(_key(e) for e in _rows(_load(GOLDEN_DIR / f"{rule_id}.yaml"), reminders=False))
    run = sorted(_key(e) for e in _rows(_load(run_path), reminders=False))
    if golden == run:
        return True, ""

    remaining = list(run)
    missing = []
    for row in golden:
        if row in remaining:
            remaining.remove(row)
        else:
            missing.append(row)
    first = (f"golden row {golden.index(missing[0])} has no counterpart in the run: {missing[0]}"
             if missing else
             f"run row {run.index(remaining[0])} has no counterpart in the golden: {remaining[0]}")
    return False, (
        f"{rule_id}: {len(golden)} golden mechanical row(s) vs {len(run)} from the run; "
        f"{len(missing)} missing, {len(remaining)} extra. First difference: {first}. {REMEDY}"
    )


def test_the_recorded_run_covers_the_whole_golden_corpus():
    """A gate that silently graded nine rules would report nine of nine."""
    assert sorted(RUN["expected"]) == sorted(GOLDEN_IDS)
    assert "sonnet" in RUN["run"]["model"] or "opus" in RUN["run"]["model"]


@pytest.mark.parametrize("rule_id", GOLDEN_IDS)
def test_tier_1_matches_what_the_calibration_recorded(rule_id):
    """Each rule's Tier 1 verdict is pinned to what the live run actually earned.

    This is not "assert the failures away". A `false` in RUN.yaml is a recorded
    measurement with a recorded reason, and flipping one is a claim about the
    pipeline that has to be re-measured live. What this test protects is the
    other direction: a brief edit, a driver change or a schema change that
    quietly moves a rule from matching to not is a failure here, without anyone
    spending twenty model calls to notice.
    """
    passed, detail = tier1_verdict(rule_id)
    expected = RUN["expected"][rule_id]
    if expected:
        assert passed, detail
    else:
        assert not passed, (
            f"{rule_id} now matches the golden encoding, which RUN.yaml records as a "
            f"known divergence ({RUN['failures'].get(rule_id, '').strip()}). If a live "
            f"re-run confirms it, update RUN.yaml in the same commit."
        )


def test_the_tier_1_result_is_the_fraction_the_gate_reported():
    """The gate's headline number, derived from the files rather than restated."""
    passing = [r for r in GOLDEN_IDS if tier1_verdict(r)[0]]
    assert len(passing) == sum(1 for v in RUN["expected"].values() if v)
    assert len(passing) == 7, (
        f"Tier 1 is {len(passing)}/10, recorded as 7/10. "
        "A live re-run is the only thing that may change this number."
    )


def test_every_recorded_proposal_lints():
    """`make rules-lint` globs specs/rules/ only, so a rule file living under
    tests/ is unlinted unless something here lints it -- which is exactly the
    hole Task 4 fix round 1 closed by deleting the duplicate golden bodies. These
    files have to stay, because grading recorded output is what makes the gate
    free to re-run; so they get linted instead of trusted. `allow_disagreement`
    matches the driver: a proposal carrying an unresolved DISAGREEMENT: marker is
    the expected state of an ungraded proposal, not an error."""
    for rule_id in GOLDEN_IDS:
        path = _run_path(rule_id)
        if not path.exists():
            continue
        errors = lint_file(path, allow_disagreement=True)
        assert errors == [], f"{path.name}: {errors}"


def test_tier_2_divergences_are_reported_and_never_graded(capsys):
    """Tier 2 is a report, not a gate. A correctly isolated agent is *supposed*
    to choose differently here; Task 6's contaminated run is what byte-level
    agreement actually looks like."""
    lines = []
    for rule_id in GOLDEN_IDS:
        run_path = _run_path(rule_id)
        if not run_path.exists():
            lines.append(f"{rule_id}: not written by the run")
            continue
        golden, run = _load(GOLDEN_DIR / f"{rule_id}.yaml"), _load(run_path)
        g_rem, r_rem = _rows(golden, reminders=True), _rows(run, reminders=True)
        bits = []
        if len(g_rem) != len(r_rem):
            bits.append(f"reminder rows golden={len(g_rem)} run={len(r_rem)}")
        if golden.get("excludes") != run.get("excludes"):
            bits.append(f"excludes golden={golden.get('excludes')} run={run.get('excludes')}")
        g_order = [_key(e) for e in _rows(golden, reminders=False)]
        r_order = [_key(e) for e in _rows(run, reminders=False)]
        if g_order != r_order and sorted(g_order) == sorted(r_order):
            bits.append("same mechanical rows in a different order")
        if bits:
            lines.append(f"{rule_id}: " + "; ".join(bits))
    with capsys.disabled():
        print("\nTier 2 divergences (reported, not graded):")
        print("\n".join(f"  {line}" for line in lines) or "  none")
    # The only assertion Tier 2 earns: the report was produced.
    assert isinstance(lines, list)
