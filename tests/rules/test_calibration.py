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
import hashlib
import json
import pathlib
import re

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


def _normalise(field, value):
    """Two spellings of one mechanic are one mechanic.

    `when` is defined by schema.json as *"preconditions, ANDed together"* -- a
    set, not a sequence -- so two encodings listing `runUp` and `attribute` in
    opposite orders state the same gate. `add` is a free-form expression string,
    so `'2 + ceil(self.gs / 2)'` and `'2 + ceil(self.gs/2)'` are the same
    expression. Both are latent false-failure sources at 222 rules; neither has
    fired yet on the recorded run, which is exactly when to close them.
    """
    if field == "when" and isinstance(value, list):
        return sorted(json.dumps(p, sort_keys=True, ensure_ascii=True, default=str) for p in value)
    if field == "add" and isinstance(value, str):
        return re.sub(r"\s+", "", value)
    return value


def _mechanics(row):
    """One effect row reduced to what Tier 1 grades."""
    if not isinstance(row, dict):
        return {"<malformed>": repr(row)}
    return {
        k: _normalise(k, v) for k, v in row.items()
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


def graded_digest(doc) -> str:
    """The SHA-256 of one authored rule reduced to exactly what Tier 1 grades.

    `tests/rules/golden/MANIFEST.yaml` records this beside each golden file's
    byte hash, and `test_golden.py` checks both. That turns the calibration
    carve-out from a promise into a mechanism. Before it, a golden file's byte
    hash plus an English `golden_edits` entry was the whole of what separated a
    legitimate note-only edit from "call it note-only and skip the gate": both
    look identical to CI, and only a reader comparing the diff against the claim
    could tell them apart.

    With it, the claim is checkable. A note-only edit provably *cannot* move this
    digest -- `note` is not in `TIER1_FIELDS`, and the rule root is not read here
    at all -- and a mechanical edit provably *does* move it, however plausible
    the justification and however carefully the byte hash was updated.

    It is derived from `tier1_verdict`'s own comparison (the sorted multiset of
    `_key` over the non-reminder rows) rather than reimplemented beside it, so
    the guard cannot drift from the thing it guards: widening `TIER1_FIELDS` or
    changing `_normalise` moves both at once.
    """
    payload = json.dumps(sorted(_key(e) for e in _rows(doc, reminders=False)),
                         ensure_ascii=True)
    return "sha256:" + hashlib.sha256(payload.encode("utf-8")).hexdigest()


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


def test_the_rubric_does_not_fail_on_two_spellings_of_one_mechanic():
    """`when` is a set per schema.json and `add` is an expression, so neither
    may be compared as written. Nothing in the recorded run exercises either,
    which is precisely why it is pinned: a false failure at 222 rules would look
    exactly like a real one."""
    reordered = {"type": "dice", "when": [{"attribute": {"gs": 4}}, {"runUp": 4}]}
    as_authored = {"type": "dice", "when": [{"runUp": 4}, {"attribute": {"gs": 4}}]}
    assert _key(reordered) == _key(as_authored)

    spaced = {"type": "dice", "add": "2 + ceil(self.gs / 2)"}
    tight = {"type": "dice", "add": "2+ceil(self.gs/2)"}
    assert _key(spaced) == _key(tight)

    # …and it still distinguishes mechanics that differ.
    assert _key(spaced) != _key({"type": "dice", "add": "3 + ceil(self.gs / 2)"})
    assert _key(as_authored) != _key({"type": "dice", "when": [{"runUp": 4}]})


def test_the_recorded_run_covers_the_whole_golden_corpus():
    """A gate that silently graded nine rules would report nine of nine."""
    assert sorted(RUN["expected"]) == sorted(GOLDEN_IDS)
    assert "sonnet" in RUN["run"]["model"] or "opus" in RUN["run"]["model"]


@pytest.mark.parametrize("rule_id", GOLDEN_IDS)
def test_tier_1_matches_what_the_calibration_recorded(rule_id):
    """Each rule's Tier 1 verdict is pinned to what the live run actually earned.

    Be clear about what this can and cannot catch. It never runs the pipeline,
    so a brief edit or a driver change cannot fail it -- only a *live re-run*
    can show what those did, and the first version of this docstring claimed
    otherwise. What it pins is the recorded measurement against the two things
    that can move underneath it without a re-run: the golden files (an edit to
    one changes the comparison, which `test_golden.py` catches by hash and this
    catches by meaning) and the rubric itself (widening or narrowing
    `TIER1_FIELDS`, or the normalisation in `_normalise`, silently changes what
    7 of 10 meant). It is a regression pin on a measurement, not a test of the
    pipeline, and the twenty calls are the only thing that tests the pipeline.

    It is also not "assert the failures away". A `false` in RUN.yaml is a
    recorded measurement with a recorded reason, and flipping one is a claim
    that has to be re-measured live -- which is why it is pinned in both
    directions.
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


def test_the_tier_1_result_is_the_fraction_the_gate_reported(request):
    """The gate's headline number, derived from the files rather than restated.

    Whole-branch review finding 6: `python3 -m pytest tests/ -q` exits 0 and
    prints no verdict, so a failed gate reads as a green suite. This print is
    additive -- it does not change what the assertions below check, and it does
    not make the test fail on the gate result, which `test_calibration.py:212-228`
    (above) argues is deliberate and right. It only makes the failure visible to
    whoever ran the suite and only glanced at the exit code.

    Fix round 1: a plain `print()` is captured by pytest and shown only for a
    *failing* test -- this one passes by design, so under plain
    `python3 -m pytest tests/ -q` (no `-s`) the line was silently swallowed and
    the symptom finding 6 names was unchanged. `request.config.get_terminal_
    writer()` writes through pytest's own terminal-reporter channel, which is
    not subject to per-test output capturing, so the line reaches the terminal
    under `-q` exactly as it would under `-v` or `-s`.
    """
    passing = [r for r in GOLDEN_IDS if tier1_verdict(r)[0]]
    assert len(passing) == sum(1 for v in RUN["expected"].values() if v)
    request.config.get_terminal_writer().line(
        f"CALIBRATION GATE: FAILED — Tier 1 {len(passing)}/{len(GOLDEN_IDS)} — "
        "no authoring wave (docs/rules-pipeline-status.md §3)"
    )
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
    the expected state of an ungraded proposal, not an error.

    `allow_missing_ruleset` is the one waiver, and it is about this recording
    rather than about the field. `ruleset` (ADR-0009) was added to the schema
    after this run was captured, and these bytes are agent output: writing the
    field into them would be inventing output the agents never produced and
    falsifying the measurement the gate grades. The alternative -- dropping the
    lint call -- is the unlinted-rule-file hole Task 4 closed once already, so
    the waiver is exactly one required key wide and everything else still has to
    pass. The next recorded run gets no waiver: both briefs now ask for the
    field, so a proposal without one is a real authoring failure.
    """
    for rule_id in GOLDEN_IDS:
        path = _run_path(rule_id)
        if not path.exists():
            continue
        errors = lint_file(path, allow_disagreement=True, allow_missing_ruleset=True)
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


def test_ruleset_is_outside_what_tier_1_grades():
    """ADR-0009 added a root-level `ruleset` to every authored rule, including
    the ten golden ones. That edit updated `MANIFEST.yaml`'s hashes without a
    live re-run, and this is the claim that justified it: Tier 1 grades *effect
    rows* on `TIER1_FIELDS`, `ruleset` is neither an effect-row field nor listed
    there, and nothing else here reads the rule root except the Tier 2 report's
    `excludes`. So no byte the backfill changed is an input to any of the ten
    `expected` verdicts. Pinned rather than argued once in RUN.yaml: adding
    `ruleset` to TIER1_FIELDS later would silently invalidate that argument.
    """
    assert "ruleset" not in TIER1_FIELDS
    for rule_id in GOLDEN_IDS:
        doc = _load(GOLDEN_DIR / f"{rule_id}.yaml")
        assert doc["ruleset"] == "core", f"{rule_id} is not a core rule any more -- re-read RUN.yaml"
        assert not any("ruleset" in row for row in doc["effects"])
