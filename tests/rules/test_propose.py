"""Tests for scripts/rules_sync/propose.py -- the authoring driver.

The driver's contract is everything *except* the encoding: batching, selectors,
provenance, linting, diffing, review files and the summary table. So every test
here injects a `FakeRunner` with recorded agent payloads. **The suite makes zero
model calls and zero network calls** -- that is a requirement of the task, not an
optimisation, and `test_subprocess_runner_*` asserts the real runner's invocation
by capturing `subprocess.run` rather than spawning `claude`.

No real DSA rule text appears here either (same discipline as `test_check.py`):
the German below is invented placeholder prose, and one test uses it to prove the
driver rejects an encoding that echoes it back.
"""
import sqlite3
import subprocess
import textwrap

import pytest
import yaml

from scripts.rules_sync.normalise import ContentContainerError
from scripts.rules_sync.propose import (
    MAX_BATCH,
    AgentEncoding,
    FakeRunner,
    RuleInput,
    RunnerError,
    SubprocessRunner,
    build_verifier_prompt,
    chunk,
    diff_effects,
    load_rule_inputs,
    parse_agent_output,
    prepare_workspace,
    propose,
    render_summary,
    resolve_provenance,
)

# Invented placeholder rule text -- not a capture of any real Regelwiki page.
TEXT_A = "Der Held erhaelt einen Bonus von 2 auf seine Attacke, solange er beritten kaempft."
TEXT_B = "Die Verteidigung des Helden ist um 4 erleichtert. Dafuer verliert er seine Aktion."


def envelope(rule_id: str, body: str, rationale: str = "clause 1 -> row 1") -> str:
    """One agent envelope, in the format the agent briefs specify."""
    return (
        f"=== RULE {rule_id} ===\n"
        "```yaml\n"
        f"{textwrap.dedent(body).strip()}\n"
        "```\n"
        f"--- rationale ---\n{rationale}\n"
        f"=== END {rule_id} ===\n"
    )


RULE_A = RuleInput("SA_901", "passiv", TEXT_A, "Platzhalter A")
RULE_B = RuleInput("SA_902", "spezialmanoever", TEXT_B, "Platzhalter B")

ENCODING_A = """
id: SA_901
subgroup: passiv
effects:
- type: modifier
  target: at
  scope: combat
  value: 2
  when:
  - mounted: true
  note: Clause 1 of 1 - flat attack bonus gated on a modelled predicate
"""

ENCODING_B = """
id: SA_902
subgroup: spezialmanoever
effects:
- type: modifier
  target: pa
  scope: combat
  value: 4
  note: Clause 1 - the parry half of the defence bonus
- type: actionEconomy
  forbids: furtherActions
  note: Clause 2 - the cost this SF charges for clause 1
"""

# Same rule, a different reading: the second agent read the bonus as 2, not 4.
ENCODING_B_DISAGREEING = """
id: SA_902
subgroup: spezialmanoever
effects:
- type: modifier
  target: pa
  scope: combat
  value: 2
  note: Clause 1 - the parry half of the defence bonus
- type: actionEconomy
  forbids: furtherActions
  note: Clause 2 - the cost this SF charges for clause 1
"""


def agreeing_runner() -> FakeRunner:
    return FakeRunner({
        ("rule-author", "batch-1"): envelope("SA_901", ENCODING_A) + envelope("SA_902", ENCODING_B),
        ("rule-verifier", "SA_901"): envelope("SA_901", ENCODING_A),
        ("rule-verifier", "SA_902"): envelope("SA_902", ENCODING_B),
    })


def run(tmp_path, runner, rules=(RULE_A, RULE_B), **kwargs):
    return propose(
        list(rules), runner,
        rules_dir=tmp_path / "specs" / "rules",
        proposals_dir=tmp_path / ".proposals",
        **kwargs,
    )


# ── the acceptance behaviour ─────────────────────────────────────────────────

def test_two_agreeing_rules_write_lint_clean_yaml_a_review_each_and_a_summary(tmp_path):
    """The task's behavioural acceptance criterion, first half: two rules with the
    fake runner produce lint-clean YAML, a review file per rule, and a summary."""
    proposals = run(tmp_path, agreeing_runner())

    assert [p.rule_id for p in proposals] == ["SA_901", "SA_902"]
    assert all(p.lint_errors == [] for p in proposals), [p.lint_errors for p in proposals]
    assert all(p.agreed for p in proposals)
    assert all(p.status == "written" for p in proposals)

    for rule_id in ("SA_901", "SA_902"):
        written = tmp_path / "specs" / "rules" / f"{rule_id}.yaml"
        assert written.exists()
        doc = yaml.safe_load(written.read_text())
        assert doc["id"] == rule_id
        assert list(doc) == ["id", "subgroup", "source", "effects"]
        assert (tmp_path / ".proposals" / f"{rule_id}.review.md").exists()

    summary = render_summary(proposals)
    assert "rule" in summary and "verdict" in summary and "lint" in summary
    assert "SA_901" in summary and "SA_902" in summary
    assert "2 written, 0 disagreement(s), 0 not written" in summary
    assert "Nothing was committed" in summary


def test_written_yaml_passes_the_real_linter(tmp_path):
    """`_lint_candidate` uses the repo's own `lint.py`, so a clean run means the
    file would survive `make rules-lint` -- not merely a local re-check."""
    from scripts.rules_lint.lint import lint_file

    run(tmp_path, agreeing_runner())
    for rule_id in ("SA_901", "SA_902"):
        assert lint_file(tmp_path / "specs" / "rules" / f"{rule_id}.yaml") == []


def test_disagreement_is_at_the_top_of_the_review_and_marked_in_the_yaml(tmp_path):
    """Second half of the acceptance criterion: when the two fakes disagree, the
    disagreement appears at the top of the review file and in the YAML -- never
    silently resolved."""
    runner = FakeRunner({
        ("rule-author", "batch-1"): envelope("SA_901", ENCODING_A) + envelope("SA_902", ENCODING_B),
        ("rule-verifier", "SA_901"): envelope("SA_901", ENCODING_A),
        ("rule-verifier", "SA_902"): envelope("SA_902", ENCODING_B_DISAGREEING),
    })
    a, b = run(tmp_path, runner)

    assert a.agreed and a.status == "written"
    assert not b.agreed and b.status == "disagreement"

    review = (tmp_path / ".proposals" / "SA_902.review.md").read_text()
    head = review.split("\n\n")[0:4]
    assert "## Verdict: DISAGREEMENT" in "\n\n".join(head), review[:600]
    assert review.index("## Verdict: DISAGREEMENT") < review.index("## Author rationale")
    assert "effect row(s) differ" in review
    assert "```diff" in review

    doc = yaml.safe_load((tmp_path / "specs" / "rules" / "SA_902.yaml").read_text())
    assert doc["note"].startswith("DISAGREEMENT:")
    assert ".proposals/SA_902.review.md" in doc["note"]
    # The author's numbers are written as the author gave them: the driver flags
    # the conflict, it does not pick a winner.
    assert doc["effects"][0]["value"] == 4

    assert "DISAGREE" in render_summary([a, b])
    assert "1 disagreement(s)" in render_summary([a, b])


def test_disagreement_marker_keeps_the_file_lint_clean(tmp_path):
    """The marker is a root `note`, not a `#` comment, because `lint.py` rejects
    comments outright (Data Policy). Both constraints have to hold at once."""
    from scripts.rules_lint.lint import lint_file

    runner = FakeRunner({
        ("rule-author", "batch-1"): envelope("SA_902", ENCODING_B),
        ("rule-verifier", "SA_902"): envelope("SA_902", ENCODING_B_DISAGREEING),
    })
    (proposal,) = run(tmp_path, runner, rules=(RULE_B,))
    path = tmp_path / "specs" / "rules" / "SA_902.yaml"
    assert "#" not in path.read_text()
    assert lint_file(path) == []
    assert proposal.lint_errors == []


def test_a_long_author_note_yields_to_the_marker_rather_than_overflowing(tmp_path):
    """`note` is capped at 200 characters by the schema. When the author's own
    note will not fit beside the marker, the marker wins and the author's note
    survives verbatim in the review file."""
    long_note = "x" * 190
    encoding = ENCODING_B.replace("subgroup: spezialmanoever", f"subgroup: spezialmanoever\nnote: {long_note}")
    runner = FakeRunner({
        ("rule-author", "batch-1"): envelope("SA_902", encoding),
        ("rule-verifier", "SA_902"): envelope("SA_902", ENCODING_B_DISAGREEING),
    })
    (proposal,) = run(tmp_path, runner, rules=(RULE_B,))
    doc = yaml.safe_load((tmp_path / "specs" / "rules" / "SA_902.yaml").read_text())
    assert len(doc["note"]) <= 200
    assert doc["note"].startswith("DISAGREEMENT:")
    assert long_note not in doc["note"]
    assert long_note in (tmp_path / ".proposals" / "SA_902.review.md").read_text()
    assert proposal.lint_errors == []


def test_a_missing_verifier_encoding_is_a_disagreement_not_a_pass(tmp_path):
    """An unusable second opinion is not agreement. Treating it as one is exactly
    how a second pass becomes theatre."""
    runner = FakeRunner({
        ("rule-author", "batch-1"): envelope("SA_901", ENCODING_A),
        ("rule-verifier", "SA_901"): "the model wandered off and wrote prose",
    })
    (proposal,) = run(tmp_path, runner, rules=(RULE_A,))
    assert not proposal.agreed
    assert "no usable encoding" in proposal.disagreement_summary
    doc = yaml.safe_load((tmp_path / "specs" / "rules" / "SA_901.yaml").read_text())
    assert doc["note"].startswith("DISAGREEMENT:")


def test_lint_failure_aborts_that_rule_without_writing(tmp_path):
    """An unregistered vocabulary token is the corpus's own failure mode (a second
    spelling of an existing idea). The rule must not reach specs/rules/, and the
    other rule in the same batch must be unaffected."""
    bad = ENCODING_B.replace("forbids: furtherActions", "forbids: noFurtherActions")
    runner = FakeRunner({
        ("rule-author", "batch-1"): envelope("SA_901", ENCODING_A) + envelope("SA_902", bad),
        ("rule-verifier", "SA_901"): envelope("SA_901", ENCODING_A),
        ("rule-verifier", "SA_902"): envelope("SA_902", bad),
    })
    a, b = run(tmp_path, runner)

    assert a.status == "written"
    assert b.status == "lint-failed"
    assert not (tmp_path / "specs" / "rules" / "SA_902.yaml").exists()
    assert any("vocabulary.yaml" in e for e in b.lint_errors)
    review = (tmp_path / ".proposals" / "SA_902.review.md").read_text()
    assert "Lint — FAILED, nothing was written" in review
    assert "was NOT written" in review
    assert "1 written, " in render_summary([a, b])
    assert "1 not written" in render_summary([a, b])


def test_schema_violation_also_aborts_without_writing(tmp_path):
    bad = ENCODING_A.replace("type: modifier", "type: teleport")
    runner = FakeRunner({
        ("rule-author", "batch-1"): envelope("SA_901", bad),
        ("rule-verifier", "SA_901"): envelope("SA_901", bad),
    })
    (proposal,) = run(tmp_path, runner, rules=(RULE_A,))
    assert proposal.status == "lint-failed"
    assert not (tmp_path / "specs" / "rules" / "SA_901.yaml").exists()


# ── the independence the whole design exists for ─────────────────────────────

def test_the_verifier_is_never_shown_the_authors_encoding(tmp_path):
    """If this ever fails, the second pass has become agreement theatre."""
    runner = agreeing_runner()
    run(tmp_path, runner)

    verifier_prompts = [prompt for agent, _, prompt in runner.calls if agent == "rule-verifier"]
    assert len(verifier_prompts) == 2
    for prompt in verifier_prompts:
        assert "target: at" not in prompt and "target: pa" not in prompt
        assert "effects:" not in prompt
        assert "```yaml" not in prompt
        assert "rule-author" not in prompt
    # and each verifier sees exactly one rule's text
    assert TEXT_A in verifier_prompts[0] and TEXT_B not in verifier_prompts[0]


def test_verifier_prompt_contains_only_the_rule_text_and_its_identity():
    prompt = build_verifier_prompt(RULE_A)
    assert RULE_A.rule_id in prompt
    assert RULE_A.subgroup in prompt
    assert TEXT_A in prompt
    # nothing about the other agent, and above all no encoding to be nudged toward
    assert "rule-author" not in prompt
    assert "```yaml" not in prompt
    assert "type:" not in prompt


# ── rule text is an input, never an output ───────────────────────────────────

def test_rule_text_echoed_back_by_an_agent_is_rejected_before_writing(tmp_path):
    """The linter cannot see prose smuggled into a free-form field (AGENTS.md
    names this as its known limit). The driver's shingle check is the backstop."""
    leaky = ENCODING_A.replace(
        "note: Clause 1 of 1 - flat attack bonus gated on a modelled predicate",
        "skill: Der Held erhaelt einen Bonus von 2 auf",
    )
    runner = FakeRunner({
        ("rule-author", "batch-1"): envelope("SA_901", leaky),
        ("rule-verifier", "SA_901"): envelope("SA_901", ENCODING_A),
    })
    (proposal,) = run(tmp_path, runner, rules=(RULE_A,))
    assert proposal.status == "lint-failed"
    assert any("rule text leaked" in e for e in proposal.lint_errors)
    assert not (tmp_path / "specs" / "rules" / "SA_901.yaml").exists()


def test_no_rule_text_reaches_the_written_yaml_on_a_normal_run(tmp_path):
    run(tmp_path, agreeing_runner())
    for rule_id, text in (("SA_901", TEXT_A), ("SA_902", TEXT_B)):
        written = (tmp_path / "specs" / "rules" / f"{rule_id}.yaml").read_text()
        assert text not in written
        assert written.isascii()
        assert "text:" not in written


def test_the_review_file_warns_that_it_is_not_committable(tmp_path):
    run(tmp_path, agreeing_runner())
    review = (tmp_path / ".proposals" / "SA_901.review.md").read_text()
    assert "Not committable" in review
    assert ".proposals/` is git-ignored" in review


def test_proposals_dir_is_gitignored():
    from scripts.rules_sync.propose import REPO_ROOT

    ignored = (REPO_ROOT / ".gitignore").read_text().splitlines()
    assert ".proposals/" in [line.strip() for line in ignored]


# ── provenance is not the agent's job ────────────────────────────────────────

def test_an_agent_supplied_source_is_discarded(tmp_path):
    invented = ENCODING_A.replace("subgroup: passiv", textwrap.dedent("""\
        subgroup: passiv
        source:
          url: https://dsa.ulisses-regelwiki.de/KSF_Erfunden.html
          checked: '2026-09-21'
          hash: sha256:""" + "a" * 64))
    runner = FakeRunner({
        ("rule-author", "batch-1"): envelope("SA_901", invented),
        ("rule-verifier", "SA_901"): envelope("SA_901", ENCODING_A),
    })
    (proposal,) = run(tmp_path, runner, rules=(RULE_A,))
    doc = yaml.safe_load((tmp_path / "specs" / "rules" / "SA_901.yaml").read_text())
    assert doc["source"]["url"].endswith("/UNVERIFIED")
    assert doc["source"]["hash"] == "sha256:" + "0" * 64
    assert "KSF_Erfunden" not in (tmp_path / "specs" / "rules" / "SA_901.yaml").read_text()
    assert "discarded" in (tmp_path / ".proposals" / "SA_901.review.md").read_text()
    assert "unverified placeholder" in proposal.provenance_note


def test_provenance_for_an_unknown_rule_is_the_placeholder_check_py_reports(tmp_path):
    from scripts.rules_sync import check

    source, note = resolve_provenance("SA_999", tmp_path)
    assert source == {
        "url": check.UNVERIFIED_URL,
        "checked": check.UNVERIFIED_CHECKED,
        "hash": check.UNVERIFIED_HASH,
    }
    assert check._is_unverified(source["url"], source["checked"], source["hash"])
    assert "unverified placeholder" in note


def write_provenanced_rule(rules_dir, rule_id="SA_901", url="https://example.invalid/a.html"):
    rules_dir.mkdir(parents=True, exist_ok=True)
    (rules_dir / f"{rule_id}.yaml").write_text(yaml.safe_dump({
        "id": rule_id,
        "subgroup": "passiv",
        "source": {"url": url, "book": "US25001", "page": 246,
                   "checked": "2026-01-01", "hash": "sha256:" + "b" * 64},
        "effects": [],
    }, sort_keys=False))
    return url


def test_existing_provenance_is_carried_forward_verbatim_when_not_re_fetching(tmp_path):
    rules_dir = tmp_path / "specs" / "rules"
    url = write_provenanced_rule(rules_dir)
    source, note = resolve_provenance("SA_901", rules_dir)
    assert source == {"url": url, "book": "US25001", "page": 246,
                      "checked": "2026-01-01", "hash": "sha256:" + "b" * 64}
    assert "carried forward" in note and "not re-fetched" in note


class StubFetcher:
    def __init__(self, result):
        self.result = result
        self.calls = []

    def get(self, url):
        self.calls.append(url)
        if isinstance(self.result, Exception):
            raise self.result
        return self.result


def test_verify_source_re_hashes_through_the_deterministic_half(tmp_path):
    """The hash comes from `normalise.hash_html` over a real fetch -- the same
    reduction `check.py` compares against -- not from anything a model said."""
    from scripts.rules_sync.normalise import hash_html

    rules_dir = tmp_path / "specs" / "rules"
    write_provenanced_rule(rules_dir)
    html = "<html><body><main><p>Platzhalter.</p></main></body></html>"
    fetcher = StubFetcher(html)
    source, note = resolve_provenance("SA_901", rules_dir, fetcher=fetcher, today="2026-09-21")
    assert source["hash"] == hash_html(html)
    assert source["checked"] == "2026-09-21"
    assert fetcher.calls == ["https://example.invalid/a.html"]
    assert "re-fetched and re-hashed" in note


@pytest.mark.parametrize("failure", [
    ContentContainerError("empty content container"),
    RuntimeError("connection reset"),
])
def test_a_failed_re_fetch_carries_forward_rather_than_fabricating(tmp_path, failure):
    """`hash_html` can raise (Task 5, fix round 4). A failed fetch must never
    become a hash -- it keeps the old values and says what went wrong."""
    rules_dir = tmp_path / "specs" / "rules"
    write_provenanced_rule(rules_dir)
    source, note = resolve_provenance("SA_901", rules_dir, fetcher=StubFetcher(failure), today="2026-09-21")
    assert source["hash"] == "sha256:" + "b" * 64
    assert source["checked"] == "2026-01-01"
    assert "carried forward unchanged" in note


# ── batching and selectors ───────────────────────────────────────────────────

def test_batches_are_capped_at_twelve():
    assert [len(b) for b in chunk(list(range(30)))] == [12, 12, 6]
    assert [len(b) for b in chunk(list(range(30)), 50)] == [12, 12, 6]
    assert [len(b) for b in chunk(list(range(5)), 2)] == [2, 2, 1]
    assert chunk([]) == []


def test_one_author_call_per_batch_and_one_verifier_call_per_rule(tmp_path):
    rules = [RuleInput(f"SA_9{n:02d}", "passiv", TEXT_A) for n in range(1, 16)]
    payloads = {("rule-author", f"batch-{n}"): "" for n in (1, 2)}
    payloads.update({("rule-verifier", r.rule_id): "" for r in rules})
    runner = FakeRunner(payloads)
    proposals = run(tmp_path, runner, rules=rules)

    author_calls = [label for agent, label, _ in runner.calls if agent == "rule-author"]
    verifier_calls = [label for agent, label, _ in runner.calls if agent == "rule-verifier"]
    assert sorted(author_calls) == ["batch-1", "batch-2"]
    assert len(verifier_calls) == len(rules) == 15
    assert len(rules) > MAX_BATCH
    assert all(p.status == "error" for p in proposals)  # empty payloads -> no envelopes


def test_a_runner_failure_on_one_batch_does_not_take_down_the_run(tmp_path):
    def boom(prompt):
        raise RunnerError("model unavailable")

    runner = FakeRunner({
        ("rule-author", "batch-1"): boom,
        ("rule-verifier", "SA_901"): envelope("SA_901", ENCODING_A),
        ("rule-verifier", "SA_902"): envelope("SA_902", ENCODING_B),
    })
    proposals = run(tmp_path, runner)
    assert all(p.status == "error" for p in proposals)
    assert all("model unavailable" in p.error for p in proposals)
    assert all(p.review_path.exists() for p in proposals)
    assert list((tmp_path / "specs" / "rules").glob("*.yaml")) == []


def make_db(tmp_path):
    db = tmp_path / "rules.db"
    conn = sqlite3.connect(db)
    conn.executescript("""
        CREATE TABLE rules (id TEXT PRIMARY KEY, group_id INTEGER, subgroup_id INTEGER);
        CREATE TABLE rules_i18n (rule_id TEXT, locale TEXT, name TEXT, description TEXT,
                                 level1 TEXT, level2 TEXT, level3 TEXT, level4 TEXT);
    """)
    rows = [
        ("SA_901", 3, 1, "Platzhalter A", TEXT_A, None),
        ("SA_902", 3, 3, "Platzhalter B", TEXT_B, None),
        ("SA_903", 3, 2, "Platzhalter C", TEXT_A, "Stufe eins Platzhalter"),
        ("SA_904", 9, 1, "Platzhalter D", TEXT_B, None),
        ("SA_905", 3, 2, "Platzhalter E", None, None),
    ]
    for rule_id, group, subgroup, name, description, level1 in rows:
        conn.execute("INSERT INTO rules VALUES (?,?,?)", (rule_id, group, subgroup))
        conn.execute("INSERT INTO rules_i18n VALUES (?,?,?,?,?,NULL,NULL,NULL)",
                     (rule_id, "de-DE", name, description, level1))
    conn.commit()
    conn.close()
    return db


def test_ids_selector_preserves_the_order_asked_for(tmp_path):
    db = make_db(tmp_path)
    rules = load_rule_inputs(db, ids=["SA_902", "SA_901"])
    assert [r.rule_id for r in rules] == ["SA_902", "SA_901"]
    assert rules[0].subgroup == "spezialmanoever"
    assert rules[1].subgroup == "passiv"
    assert rules[1].text == TEXT_A


def test_group_selector(tmp_path):
    db = make_db(tmp_path)
    assert [r.rule_id for r in load_rule_inputs(db, group=3)] == ["SA_901", "SA_902", "SA_903"]
    assert [r.rule_id for r in load_rule_inputs(db, group=9)] == ["SA_904"]


def test_subgroup_selector(tmp_path):
    """Task 9 drives its waves by group and subgroup, so both flags ship here."""
    db = make_db(tmp_path)
    rules = load_rule_inputs(db, subgroup=(3, 2))
    assert [r.rule_id for r in rules] == ["SA_903"]
    assert rules[0].subgroup == "basismanoever"
    assert "Stufe 1: Stufe eins Platzhalter" in rules[0].text


def test_a_rule_with_no_text_is_skipped_rather_than_proposed_from_nothing(tmp_path):
    db = make_db(tmp_path)
    assert [r.rule_id for r in load_rule_inputs(db, subgroup=(3, 2))] == ["SA_903"]  # not SA_905


def test_unknown_ids_and_bad_selectors_fail_loudly(tmp_path):
    db = make_db(tmp_path)
    with pytest.raises(KeyError, match="SA_999"):
        load_rule_inputs(db, ids=["SA_901", "SA_999"])
    with pytest.raises(ValueError):
        load_rule_inputs(db, ids=["SA_901"], group=3)
    with pytest.raises(ValueError):
        load_rule_inputs(db)
    with pytest.raises(FileNotFoundError, match="make rules-db"):
        load_rule_inputs(tmp_path / "nope.db", ids=["SA_901"])


# ── parsing and diffing ──────────────────────────────────────────────────────

def test_parse_agent_output_tolerates_chatter_around_the_envelopes():
    text = ("Sure, here are the two rules.\n\n"
            + envelope("SA_901", ENCODING_A)
            + "\nAnd the second:\n\n"
            + envelope("SA_902", ENCODING_B)
            + "\nLet me know if you want changes.\n")
    parsed = parse_agent_output(text)
    assert set(parsed) == {"SA_901", "SA_902"}
    assert parsed["SA_901"].doc["effects"][0]["value"] == 2
    assert parsed["SA_901"].rationale == "clause 1 -> row 1"


def test_parse_agent_output_reports_a_broken_block_per_rule():
    text = envelope("SA_901", ENCODING_A) + "=== RULE SA_902 ===\n```yaml\n: : :\n```\n=== END SA_902 ===\n"
    parsed = parse_agent_output(text)
    assert parsed["SA_901"].doc is not None
    assert parsed["SA_902"].doc is None
    assert "unparseable YAML" in parsed["SA_902"].error


def test_parse_agent_output_rejects_a_non_mapping_root():
    parsed = parse_agent_output("=== RULE SA_901 ===\n```yaml\n- a\n- b\n```\n=== END SA_901 ===\n")
    assert parsed["SA_901"].doc is None
    assert "must be a YAML mapping" in parsed["SA_901"].error


def test_missing_envelope_means_no_encoding_not_an_empty_one():
    assert parse_agent_output("I could not encode this rule.") == {}


def test_diff_ignores_note_prose_but_not_mechanics():
    a = {"effects": [{"type": "modifier", "target": "at", "scope": "combat", "value": 2, "note": "one wording"}]}
    b = {"effects": [{"type": "modifier", "target": "at", "scope": "combat", "value": 2, "note": "quite another"}]}
    assert diff_effects(a, b) == []
    b["effects"][0]["value"] = 3
    assert diff_effects(a, b) != []


def test_diff_catches_a_missing_row():
    a = {"effects": [{"type": "reminder", "note": "x"}, {"type": "reminder", "note": "y"}]}
    b = {"effects": [{"type": "reminder", "note": "x"}]}
    assert diff_effects(a, b) != []


def test_subgroup_and_excludes_disagreements_are_reported(tmp_path):
    other = ENCODING_B.replace("subgroup: spezialmanoever", "subgroup: basismanoever")
    runner = FakeRunner({
        ("rule-author", "batch-1"): envelope("SA_902", ENCODING_B),
        ("rule-verifier", "SA_902"): envelope("SA_902", other),
    })
    (proposal,) = run(tmp_path, runner, rules=(RULE_B,))
    assert not proposal.agreed
    assert any("subgroup" in d for d in proposal.scalar_diffs)
    assert "Non-effect fields" in (tmp_path / ".proposals" / "SA_902.review.md").read_text()


# ── the subprocess runner, without spawning anything ─────────────────────────

def test_subprocess_runner_argv_is_the_verified_invocation(tmp_path):
    runner = SubprocessRunner(model="opus")
    argv = runner.argv("rule-author")
    assert argv[:2] == ["claude", "-p"]
    for flag, value in (("--output-format", "json"), ("--model", "opus"),
                        ("--permission-mode", "dontAsk"), ("--permission-prompts", "none"),
                        ("--tools", "Read,Grep,Glob")):
        assert argv[argv.index(flag) + 1] == value
    assert "--no-session-persistence" in argv
    assert "--strict-mcp-config" in argv
    # read-only by construction: nothing here can write a file or fetch a page
    assert not {"Write", "Edit", "Bash", "WebFetch"} & set(argv[argv.index("--tools") + 1].split(","))
    # the agent's brief is appended as a system prompt, frontmatter stripped
    appended = argv[argv.index("--append-system-prompt") + 1]
    assert appended.startswith("You encode DSA 5 rules")
    assert "name: rule-author" not in appended


def test_subprocess_runner_puts_the_prompt_on_stdin_not_in_argv(monkeypatch):
    """Rule text in argv would reach the process table and the shell history."""
    seen = {}

    class Completed:
        returncode = 0
        stdout = '{"is_error": false, "subtype": "success", "result": "ok"}'
        stderr = ""

    def fake_run(argv, **kwargs):
        seen["argv"] = argv
        seen["input"] = kwargs.get("input")
        return Completed()

    monkeypatch.setattr(subprocess, "run", fake_run)
    out = SubprocessRunner()("SECRET RULE TEXT", agent="rule-author", label="batch-1")
    assert out == "ok"
    assert seen["input"] == "SECRET RULE TEXT"
    assert not any("SECRET RULE TEXT" in part for part in seen["argv"])


@pytest.mark.parametrize("stdout, returncode, expected", [
    ('{"is_error": true, "subtype": "error_max_turns", "result": "x"}', 0, "reported failure"),
    ("not json", 0, "unparseable JSON"),
    ("", 1, "exited 1"),
])
def test_subprocess_runner_turns_a_bad_reply_into_a_runner_error(monkeypatch, stdout, returncode, expected):
    class Completed:
        pass

    completed = Completed()
    completed.returncode = returncode
    completed.stdout = stdout
    completed.stderr = "boom"
    monkeypatch.setattr(subprocess, "run", lambda argv, **kw: completed)
    with pytest.raises(RunnerError, match=expected):
        SubprocessRunner()("prompt", agent="rule-author", label="batch-1")


def test_fake_runner_refuses_a_call_nobody_recorded():
    with pytest.raises(RunnerError, match="no response"):
        FakeRunner({})("prompt", agent="rule-author", label="batch-1")


# ── the script commits nothing ───────────────────────────────────────────────

def test_a_run_leaves_only_untracked_or_modified_files(tmp_path):
    """Acceptance: `git status` after a run shows files for review, and no commit
    was made."""
    repo = tmp_path / "repo"
    (repo / "specs" / "rules").mkdir(parents=True)
    subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
    subprocess.run(["git", "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q",
                    "--allow-empty", "-m", "base"], cwd=repo, check=True)
    head_before = subprocess.run(["git", "rev-parse", "HEAD"], cwd=repo,
                                 capture_output=True, text=True, check=True).stdout

    propose([RULE_A], agreeing_runner(),
            rules_dir=repo / "specs" / "rules", proposals_dir=repo / ".proposals")

    status = subprocess.run(["git", "status", "--porcelain"], cwd=repo,
                            capture_output=True, text=True, check=True).stdout
    head_after = subprocess.run(["git", "rev-parse", "HEAD"], cwd=repo,
                                capture_output=True, text=True, check=True).stdout
    assert head_after == head_before
    assert status.strip()
    assert all(line.startswith("??") for line in status.strip().splitlines()), status


# ── the workspace an agent is allowed to see ─────────────────────────────────

def test_the_workspace_withholds_the_authored_file_for_every_rule_in_the_run(tmp_path):
    """Found end-to-end, not in theory: given file tools and the repo as cwd, the
    agents read `specs/rules/SA_65.yaml` and reproduced the hand-authored file
    down to the wording of every note. An author/verifier agreement reached that
    way measures nothing, and Task 7's calibration against the golden ten would
    have scored a copy as a pass."""
    ws = prepare_workspace(tmp_path / "ws", ["SA_65", "SA_66"])

    assert not (ws / "specs" / "rules" / "SA_65.yaml").exists()
    assert not (ws / "specs" / "rules" / "SA_66.yaml").exists()
    # precedent the briefs name by path is still there
    assert (ws / "specs" / "rules" / "SA_67.yaml").exists()
    assert (ws / "specs" / "rules" / "SA_48.yaml").exists()
    assert (ws / "specs" / "rules" / "schema.json").exists()
    assert (ws / "specs" / "rules" / "vocabulary.yaml").exists()
    assert (ws / "docs" / "adr" / "0008-rules-as-data-combat-engine.md").exists()
    assert "SA_65, SA_66" in (ws / "README.md").read_text()


def test_the_workspace_never_carries_the_rule_database(tmp_path):
    """`rules.db` holds the text of all 232 rules. Each agent is handed exactly
    the one text it needs, in its prompt; a copy of the database in its cwd would
    hand it the other 231 for nothing."""
    ws = prepare_workspace(tmp_path / "ws", ["SA_65"])
    assert list(ws.rglob("*.db")) == []


def test_an_empty_exclusion_set_is_allowed(tmp_path):
    ws = prepare_workspace(tmp_path / "ws", [])
    assert (ws / "specs" / "rules" / "SA_65.yaml").exists()
    assert "(none)" in (ws / "README.md").read_text()
