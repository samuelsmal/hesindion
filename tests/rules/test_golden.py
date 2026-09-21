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
"""
import hashlib
import pathlib

import pytest
import yaml

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

REMEDY = (
    "golden corpus drifted -- re-run calibration. If this change to the "
    "authored rule is intended, update tests/rules/golden/MANIFEST.yaml with "
    "the new hash in the same commit and re-run the pipeline calibration "
    "(Task 7); the ten golden files are its reference encoding. The one "
    "exception is an edit confined to fields Tier 1 does not grade -- `note`, "
    "`source.checked` -- which no re-run could re-measure: update the hash and "
    "record why under `golden_edits` in the recorded run's RUN.yaml instead. "
    "See MANIFEST.yaml's description for the full carve-out."
)


def test_manifest_covers_exactly_the_ten_golden_rules():
    assert set(GOLDEN) == EXPECTED_IDS, REMEDY


@pytest.mark.parametrize("rule_id", sorted(GOLDEN))
def test_golden_rule_matches_its_recorded_hash(rule_id):
    path = RULES_DIR / f"{rule_id}.yaml"
    assert path.exists(), f"{path} is missing -- {REMEDY}"
    actual = "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()
    assert actual == GOLDEN[rule_id], (
        f"{path.name}: recorded {GOLDEN[rule_id]} != current {actual} -- {REMEDY}"
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
