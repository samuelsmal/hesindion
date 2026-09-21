"""Whole-branch review finding 5: four hand-synced copies of one list, and the
sync comments had already drifted before anyone added a fifth call site.

`NON_RULE_FILES` exists as a local constant in four modules (`scripts/rules_lint/lint.py`,
`scripts/rules_sync/check.py`, `scripts/build_rules_db/verify_db.py` and
`scripts/build_rules_db/build_db.py`), and `CHAPTER_PREFIX` in three of those four
(every site but `check.py`, which has no chapter-id concept). Each site's comment says
it is "kept in sync by hand" with the others -- but nothing ever checked that, and the
comments themselves had already gone stale, naming only some of the other sites.

The four-small-local-constants arrangement (rather than a shared module) is a
deliberate preference stated in each site's comment. This test does not change that;
it makes the preference safe rather than merely stated, by asserting the relationship
the comments claim: `lint.py`, `verify_db.py` and `build_db.py` agree exactly;
`check.py` additionally carries `schema.json`, which is justified (it is not equal to
the other three on purpose) and must stay that way -- this test fails if that
difference either disappears or widens.
"""
from scripts.build_rules_db.build_db import CHAPTER_PREFIX as BUILD_DB_CHAPTER_PREFIX
from scripts.build_rules_db.build_db import NON_RULE_FILES as BUILD_DB_NON_RULE_FILES
from scripts.build_rules_db.verify_db import CHAPTER_PREFIX as VERIFY_DB_CHAPTER_PREFIX
from scripts.build_rules_db.verify_db import NON_RULE_FILES as VERIFY_DB_NON_RULE_FILES
from scripts.rules_lint.lint import CHAPTER_PREFIX as LINT_CHAPTER_PREFIX
from scripts.rules_lint.lint import NON_RULE_FILES as LINT_NON_RULE_FILES
from scripts.rules_sync.check import NON_RULE_FILES as CHECK_NON_RULE_FILES


def test_lint_verify_db_and_build_db_non_rule_files_agree():
    """These three glob specs/rules/ the same way, so their skip lists must match
    exactly. A rule file added to one and not the others is a silent skip in one
    tool and not the other two -- that is the realised defect finding 5 names."""
    assert LINT_NON_RULE_FILES == VERIFY_DB_NON_RULE_FILES == BUILD_DB_NON_RULE_FILES


def test_check_py_non_rule_files_is_the_other_three_plus_schema_json():
    """check.py's set is deliberately not equal to the other three -- it
    additionally carries schema.json. Asserting the relationship rather than
    equality is the point: it must catch a missed entry without also demanding
    the one intentional difference be "fixed" away."""
    assert CHECK_NON_RULE_FILES == LINT_NON_RULE_FILES | {"schema.json"}


def test_chapter_prefix_spellings_agree():
    """lint.py, verify_db.py and build_db.py each derive a chapter rule's id
    from its source.url stem using this prefix. check.py has no chapter-id
    concept, so it carries no CHAPTER_PREFIX to check."""
    assert LINT_CHAPTER_PREFIX == VERIFY_DB_CHAPTER_PREFIX == BUILD_DB_CHAPTER_PREFIX
