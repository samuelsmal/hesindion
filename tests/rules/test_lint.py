import pathlib, textwrap, pytest
from scripts.rules_lint.lint import lint_file

VALID = textwrap.dedent("""
    id: SA_62
    subgroup: spezialmanoever
    source:
      url: https://dsa.ulisses-regelwiki.de/SA_62.html
      book: US25001
      page: 249
      checked: 2026-09-20
      hash: sha256:{h}
    excludes: [SA_48]
    effects:
      - type: dice
        add: "2 + ceil(self.gs / 2)"
        when: [{{runUp: 4}}, {{attribute: {{gs: 4}}}}]
""").format(h="0" * 64)

def write(tmp_path: pathlib.Path, body: str) -> pathlib.Path:
    p = tmp_path / "SA_62.yaml"; p.write_text(body); return p

def test_valid_file_passes(tmp_path):
    assert lint_file(write(tmp_path, VALID)) == []

def test_rule_text_is_rejected(tmp_path):
    errs = lint_file(write(tmp_path, VALID + "text: Das Manöver …\n"))
    assert any("text" in e and "Data Policy" in e for e in errs)

def test_unknown_effect_type_is_rejected(tmp_path):
    errs = lint_file(write(tmp_path, VALID.replace("type: dice", "type: teleport")))
    assert any("teleport" in e for e in errs)

def test_unknown_predicate_is_rejected(tmp_path):
    errs = lint_file(write(tmp_path, VALID.replace("runUp: 4", "phaseOfMoon: full")))
    assert any("phaseOfMoon" in e for e in errs)

def test_missing_hash_is_rejected(tmp_path):
    errs = lint_file(write(tmp_path, VALID.replace(f"  hash: sha256:{'0'*64}\n", "")))
    assert any("hash" in e for e in errs)

def test_filename_must_match_id(tmp_path):
    p = tmp_path / "SA_63.yaml"; p.write_text(VALID)
    assert any("filename" in e for e in lint_file(p))


# --- Fix round 1: modifier target/scope/side (C1, C2) ---

MODIFIER_BASE = textwrap.dedent("""
    id: SA_65
    subgroup: passiv
    source:
      url: https://dsa.ulisses-regelwiki.de/SA_65.html
      checked: 2026-09-20
      hash: sha256:{h}
    effects:
      - type: modifier
        {extra}
""")


def modifier_doc(extra: str) -> str:
    return MODIFIER_BASE.format(h="0" * 64, extra=extra)


def test_modifier_missing_target_is_rejected(tmp_path):
    p = tmp_path / "SA_65.yaml"
    p.write_text(modifier_doc("value: 4\n    scope: combat"))
    errs = lint_file(p)
    assert any("target" in e for e in errs)


def test_modifier_missing_scope_is_rejected(tmp_path):
    p = tmp_path / "SA_65.yaml"
    p.write_text(modifier_doc("value: 4\n    target: pa"))
    errs = lint_file(p)
    assert any("scope" in e for e in errs)


def test_modifier_with_target_and_scope_passes(tmp_path):
    p = tmp_path / "SA_65.yaml"
    p.write_text(modifier_doc("value: 4\n    target: pa\n    scope: combat"))
    assert lint_file(p) == []


def test_modifier_side_opponent_is_accepted(tmp_path):
    p = tmp_path / "SA_48.yaml"
    body = MODIFIER_BASE.format(h="0" * 64, extra=(
        "value: -2\n    target: pa\n    scope: combat\n    side: opponent"
    )).replace("id: SA_65", "id: SA_48")
    p.write_text(body)
    assert lint_file(p) == []


def test_modifier_unknown_target_is_rejected(tmp_path):
    p = tmp_path / "SA_65.yaml"
    p.write_text(modifier_doc("value: 4\n    target: banana\n    scope: combat"))
    errs = lint_file(p)
    assert any("banana" in e for e in errs)


# --- Fix round 1: dice recipient (C3) ---

def test_dice_recipient_defender_shield_is_accepted(tmp_path):
    body = VALID.replace(
        'add: "2 + ceil(self.gs / 2)"',
        'add: "2 + ceil(self.gs / 2)"\n    recipient: defenderShield',
    )
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    assert lint_file(p) == []


def test_dice_unknown_recipient_is_rejected(tmp_path):
    body = VALID.replace(
        'add: "2 + ceil(self.gs / 2)"',
        'add: "2 + ceil(self.gs / 2)"\n    recipient: theMoon',
    )
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    errs = lint_file(p)
    assert any("theMoon" in e for e in errs)


# --- Fix round 1: actionEconomy forbids, recovery type (C4) ---

def test_action_economy_forbids_is_accepted(tmp_path):
    body = textwrap.dedent("""
        id: COND_1
        subgroup: none
        source:
          url: https://dsa.ulisses-regelwiki.de/COND_1.html
          checked: 2026-09-20
          hash: sha256:{h}
        effects:
          - type: actionEconomy
            forbids: allActions
    """).format(h="0" * 64)
    p = tmp_path / "COND_1.yaml"
    p.write_text(body)
    assert lint_file(p) == []


def test_recovery_effect_requires_its_fields(tmp_path):
    body = textwrap.dedent("""
        id: SA_1
        subgroup: none
        source:
          url: https://dsa.ulisses-regelwiki.de/SA_1.html
          checked: 2026-09-20
          hash: sha256:{h}
        effects:
          - type: recovery
    """).format(h="0" * 64)
    p = tmp_path / "SA_1.yaml"
    p.write_text(body)
    errs = lint_file(p)
    assert any("attribute" in e for e in errs)
    assert any("operation" in e for e in errs)
    assert any("per" in e for e in errs)


def test_recovery_effect_complete_passes(tmp_path):
    body = textwrap.dedent("""
        id: SA_1
        subgroup: none
        source:
          url: https://dsa.ulisses-regelwiki.de/SA_1.html
          checked: 2026-09-20
          hash: sha256:{h}
        effects:
          - type: recovery
            attribute: LE
            value: 2
            operation: add
            per: regenerationCycle
    """).format(h="0" * 64)
    p = tmp_path / "SA_1.yaml"
    p.write_text(body)
    assert lint_file(p) == []


# --- I1: tier range ---

def test_tier_seven_is_accepted(tmp_path):
    body = VALID.replace("type: dice", "type: dice\n    tier: 7")
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    assert lint_file(p) == []


def test_tier_eight_is_rejected(tmp_path):
    body = VALID.replace("type: dice", "type: dice\n    tier: 8")
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    assert any("tier" in e for e in lint_file(p))


# --- I2: predicate value shapes ---

def test_when_predicate_with_bad_value_is_rejected(tmp_path):
    # mounted: banana instead of a boolean
    body = VALID.replace("runUp: 4", "mounted: banana")
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    errs = lint_file(p)
    assert errs  # rejected; specific message is jsonschema's own type-mismatch wording


def test_when_predicate_with_nonsense_object_is_rejected(tmp_path):
    body = VALID.replace("runUp: 4", "runUp: {nonsense: [1, 2]}")
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    assert lint_file(p)  # rejected


# --- I5: crash guards ---

def test_empty_effects_reports_instead_of_crashing(tmp_path):
    body = VALID.split("effects:")[0] + "effects:\n"
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    errs = lint_file(p)  # must not raise
    assert errs


def test_list_root_reports_instead_of_crashing(tmp_path):
    p = tmp_path / "SA_62.yaml"
    p.write_text("- foo\n- bar\n")
    errs = lint_file(p)  # must not raise
    assert any("mapping" in e for e in errs)


# --- I4: comments as a text-smuggling route ---

def test_comment_is_rejected(tmp_path):
    body = VALID + "# Das Manöver kostet 2 AsP und wirkt sofort.\n"
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    errs = lint_file(p)
    assert any("comment" in e for e in errs)


def test_nested_text_key_in_when_is_rejected(tmp_path):
    # 'text' smuggled two levels deep, inside a predicate's own value — the
    # shallow top-level/effects-level check in round 1 would have missed this.
    body = textwrap.dedent("""
        id: SA_62
        subgroup: spezialmanoever
        source:
          url: https://dsa.ulisses-regelwiki.de/SA_62.html
          checked: 2026-09-20
          hash: sha256:{h}
        effects:
          - type: dice
            add: "1W6"
            when:
              - attribute:
                  gs: 4
                  text: smuggled prose
    """).format(h="0" * 64)
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    errs = lint_file(p)
    assert any("text" in e and "Data Policy" in e for e in errs)


# --- I6/I7: url pattern, excludes id pattern ---

def test_url_without_scheme_is_rejected(tmp_path):
    body = VALID.replace(
        "url: https://dsa.ulisses-regelwiki.de/SA_62.html",
        "url: not a url at all",
    )
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    assert lint_file(p)  # rejected


def test_excludes_with_invalid_id_is_rejected(tmp_path):
    body = VALID.replace("excludes: [SA_48]", "excludes: [not-an-id, '']")
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    assert lint_file(p)  # rejected


# --- gmFlag predicate (eleventh predicate, Task 3 controller ruling) ---

def test_gmflag_valid_slug_is_accepted(tmp_path):
    body = VALID.replace("runUp: 4", "gmFlag: knownLocation")
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    assert lint_file(p) == []


def test_gmflag_with_digit_is_rejected(tmp_path):
    body = VALID.replace("runUp: 4", "gmFlag: ambush2")
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    assert lint_file(p)  # rejected: pattern is letters only


def test_gmflag_with_uppercase_first_char_is_rejected(tmp_path):
    body = VALID.replace("runUp: 4", "gmFlag: Ambush")
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    assert lint_file(p)  # rejected: must start lowercase


def test_gmflag_with_prose_is_rejected(tmp_path):
    body = VALID.replace("runUp: 4", "gmFlag: 'at known location'")
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    assert lint_file(p)  # rejected: spaces not allowed, prose can't enter through it
