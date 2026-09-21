"""The golden corpus is frozen by content hash, not by a duplicate copy.

Task 4 fix round 1, Q5. `tests/rules/golden/` used to hold a second copy of
the ten authored files. Two copies of the same bytes have exactly one failure
mode -- they drift -- and the copy under `tests/` was invisible to
`make rules-lint`, which globs `specs/rules/` only, so it was also the one
place in the repo where a `text:` key or a German comment could have reached
git unchecked (Data Policy, AGENTS.md).

`MANIFEST.yaml` replaces it: the same freeze semantics (an edit to a golden
rule is a loud failure naming the remedy), no second copy, and the drift class
stops existing rather than being detected.

**Two hashes, because the freeze and the calibration gate are not the same
thing.** `bytes` freezes the file. `graded` freezes the file reduced to what
`test_calibration`'s Tier 1 actually grades, and it is what makes the
calibration carve-out checkable instead of merely asserted -- see
`MANIFEST.yaml`'s description and `test_calibration.graded_digest`.
"""
import hashlib
import pathlib
import re

import pytest
import yaml

from tests.rules.test_calibration import graded_digest

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
MANIFEST_PATH = REPO_ROOT / "tests" / "rules" / "golden" / "MANIFEST.yaml"
RULES_DIR = REPO_ROOT / "specs" / "rules"

MANIFEST = yaml.safe_load(MANIFEST_PATH.read_text(encoding="utf-8"))
GOLDEN = MANIFEST["rules"]

# The ten the task authored, spelled out rather than derived from the manifest:
# the manifest is the artefact under test, so a test that read its ids from it
# would pass just as happily if someone deleted nine entries.
EXPECTED_IDS = {
    "SA_40", "SA_41", "SA_43", "SA_48", "SA_59",
    "SA_62", "SA_65", "SA_66", "SA_67", "SA_661",
}

BYTES_REMEDY = (
    "golden corpus drifted -- the file's bytes no longer match "
    "tests/rules/golden/MANIFEST.yaml. If this change to the authored rule is "
    "intended, update its `bytes` hash in the same commit. Whether that is the "
    "whole remedy is what the `graded` hash decides: if the companion `graded` "
    "assertion still passes AND the only root keys you touched are `note`, "
    "`source.checked`, `ruleset` or `source.title` -- the enumerated carve-out, "
    "not every root key -- record why under `golden_edits` in the recorded "
    "run's RUN.yaml and stop there. If you touched `subgroup`, `excludes` or "
    "`id`, the `graded` assertion still passes but this is NOT the carve-out: "
    "those three are table-visible (maneuver slot, a Tier 2 mechanical field, "
    "and the rule's own identity) and still mean a live re-run. If `graded` "
    "fails too, this is a mechanical change to the pipeline's reference "
    "encoding and it means re-running the calibration (Task 7). See "
    "MANIFEST.yaml's description for the full carve-out."
)

GRADED_REMEDY = (
    "a golden rule's *graded* encoding changed -- re-run calibration. This hash "
    "covers exactly what tests/rules/test_calibration.py's Tier 1 grades: the "
    "non-reminder effect rows, reduced to TIER1_FIELDS and normalised the way "
    "tier1_verdict normalises them. `note`, `source.checked` and the rule root "
    "are not inputs, so a note-only edit cannot reach this hash. That it moved "
    "means a recorded verdict was computed from bytes that no longer exist, and "
    "no `golden_edits` justification can substitute for a live re-run. (If "
    "TIER1_FIELDS or _normalise is what changed, the gate's rubric moved and "
    "the recorded 7/10 means something different -- which is the other thing "
    "this hash is here to make loud.)"
)


def test_manifest_covers_exactly_the_ten_golden_rules():
    assert set(GOLDEN) == EXPECTED_IDS, BYTES_REMEDY


@pytest.mark.parametrize("rule_id", sorted(GOLDEN))
def test_golden_rule_matches_its_recorded_hash(rule_id):
    path = RULES_DIR / f"{rule_id}.yaml"
    assert path.exists(), f"{path} is missing -- {BYTES_REMEDY}"
    actual = "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()
    assert actual == GOLDEN[rule_id]["bytes"], (
        f"{path.name}: recorded {GOLDEN[rule_id]['bytes']} != current {actual} -- {BYTES_REMEDY}"
    )


@pytest.mark.parametrize("rule_id", sorted(GOLDEN))
def test_golden_rule_matches_its_recorded_graded_hash(rule_id):
    """The mechanical half of the calibration carve-out.

    Before this existed, a byte hash plus an English `golden_edits` entry was
    all that separated a legitimate note-only edit from "call it note-only and
    skip the gate" -- the two produce identical evidence. This hash cannot be
    moved by a note-only edit and cannot be left still by a mechanical one.
    """
    path = RULES_DIR / f"{rule_id}.yaml"
    doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    actual = graded_digest(doc)
    assert actual == GOLDEN[rule_id]["graded"], (
        f"{path.name}: recorded {GOLDEN[rule_id]['graded']} != current {actual} -- {GRADED_REMEDY}"
    )


def test_the_two_hashes_answer_different_questions():
    """Pin the property the carve-out rests on, rather than asserting it in prose.

    A `note` edit moves the byte hash and not the graded one; a `value` edit
    moves both; an edit to one of the enumerated *safe* root keys (`ruleset`,
    `source.title`, alongside `source.checked`) moves neither. That is the
    narrow claim MANIFEST.yaml's description now makes -- "this enumerated
    set", not "any root key that is not an effect row". If this ever stopped
    holding -- by `note` entering `TIER1_FIELDS`, or by `graded_digest`
    accidentally reading the whole file -- the carve-out would silently become
    either useless or unusable, and every other test here would still pass.

    `subgroup`, `excludes` and `id` also leave `graded` unchanged and are
    deliberately *not* exercised as a "still equal" case here: they are the
    keys the carve-out does not cover despite passing this same assertion, and
    `test_a_root_key_that_passes_graded_is_still_named_as_needing_a_rerun`
    below is where that distinction is pinned.
    """
    base = {
        "id": "SA_65", "subgroup": "passiv", "ruleset": "core",
        "source": {"title": "Placeholder Page Title", "checked": "2026-01-01"},
        "effects": [
            {"type": "modifier", "target": "pa", "scope": "combat", "value": 4,
             "note": "Clause 1 - the defensive stance's PA bonus"},
            {"type": "reminder", "note": "UNENCODED: clause 2"},
        ],
    }
    note_edited = {**base, "effects": [
        {**base["effects"][0], "note": "Clause 1 - reworded, same mechanic"},
        base["effects"][1],
    ]}
    value_edited = {**base, "effects": [
        {**base["effects"][0], "value": 2},
        base["effects"][1],
    ]}
    safe_root_edited = {
        **base,
        "ruleset": "focus.trefferzonen",
        "source": {"title": "A Different Page Title", "checked": "2027-06-01"},
    }

    assert graded_digest(note_edited) == graded_digest(base)
    assert graded_digest(safe_root_edited) == graded_digest(base)
    assert graded_digest(value_edited) != graded_digest(base)


#: The root keys that pass the `graded` assertion above (`graded_digest` never
#: reads the rule root) and are still not part of the carve-out -- table-visible
#: facts the calibration doesn't grade at all, not fields the carve-out was
#: written for. See MANIFEST.yaml's description and BYTES_REMEDY.
NOT_SAFE_DESPITE_PASSING_GRADED = ("subgroup", "excludes", "id")


@pytest.mark.parametrize("key, mutated_value", [
    ("subgroup", "spezialmanoever"),
    ("excludes", ["SA_67"]),
    ("id", "SA_66"),
])
def test_a_root_key_that_passes_graded_is_still_named_as_needing_a_rerun(key, mutated_value):
    """The coupling test finding 8 asks for.

    The safe-set enumeration used to live only in prose (MANIFEST.yaml's
    description, BYTES_REMEDY), and nothing failed if that prose and
    `graded_digest`'s actual behaviour disagreed -- a passing `graded`
    assertion looks identical whether the key touched is genuinely safe or
    merely un-graded. This closes the gap two ways: if `graded_digest` ever
    starts moving on one of these keys, the first assertion below catches it;
    if the prose ever stops naming one of them as still requiring a re-run
    despite passing, the second and third assertions do.
    """
    assert key in NOT_SAFE_DESPITE_PASSING_GRADED
    base = {
        "id": "SA_65", "subgroup": "passiv", "ruleset": "core", "excludes": [],
        "source": {"title": "Placeholder Page Title", "checked": "2026-01-01"},
        "effects": [
            {"type": "modifier", "target": "pa", "scope": "combat", "value": 4,
             "note": "Clause 1 - the defensive stance's PA bonus"},
            {"type": "reminder", "note": "UNENCODED: clause 2"},
        ],
    }
    mutated = {**base, key: mutated_value}

    assert graded_digest(mutated) == graded_digest(base), (
        f"`{key}` used to leave `graded` unchanged and no longer does -- "
        "MANIFEST.yaml's description and BYTES_REMEDY must stop naming it as "
        "an exception, since the carve-out's own mechanism now catches it"
    )
    # A plain substring check would pass on "id" for the wrong reason -- it is
    # a substring of "invalidates", "side", "identical" and more, so an "id in
    # text" assertion could stay green with no mention of the field at all.
    # Prose here quotes a field name in backticks (`` `id` ``, `` `subgroup` ``),
    # so that is what is checked for.
    backticked = re.compile(rf"`{re.escape(key)}`")
    assert backticked.search(MANIFEST["description"]), (
        f"`{key}` passes the `graded` assertion but is not named in "
        "MANIFEST.yaml's description as still requiring a re-run despite that"
    )
    assert backticked.search(BYTES_REMEDY), (
        f"`{key}` passes the `graded` assertion but is not named in "
        "BYTES_REMEDY as still requiring a re-run despite that"
    )


def test_golden_directory_holds_no_duplicate_rule_bodies():
    """The copies are gone and must stay gone: a `.yaml` file reappearing here
    is a second, unlinted copy of an authored rule (see module docstring)."""
    strays = sorted(p.name for p in MANIFEST_PATH.parent.glob("*.yaml")
                    if p.name != "MANIFEST.yaml")
    assert strays == [], (
        f"{strays} duplicate the authored rules under specs/rules/ and are not "
        "linted by `make rules-lint`; the manifest freezes them by hash instead"
    )
