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
    # `attribute` is no longer unconditionally required (fix round 1, M1: it's
    # only required when `operation: add` — see test_recovery_scale_without_
    # attribute_is_accepted / test_recovery_add_without_attribute_is_still_rejected
    # below). `value`/`operation`/`per` stay required regardless.
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
    assert any("operation" in e for e in errs)
    assert any("per" in e for e in errs)
    assert any("value" in e for e in errs)


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


# --- note key (fix round 1, M6: English annotation, comment ban stays) ---

def test_note_at_root_is_accepted(tmp_path):
    body = VALID.replace(
        "subgroup: spezialmanoever",
        "subgroup: spezialmanoever\nnote: Tier ladder scaled per Stufe, see task-3 fix round 1",
    )
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    assert lint_file(p) == []


def test_note_on_effect_is_accepted(tmp_path):
    body = VALID.replace(
        'add: "2 + ceil(self.gs / 2)"',
        'add: "2 + ceil(self.gs / 2)"\n    note: Half of the AT penalty is added as flat damage',
    )
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    assert lint_file(p) == []


def test_note_with_non_ascii_is_rejected(tmp_path):
    # A German umlaut is exactly what `note` must keep out (Data Policy).
    body = VALID.replace(
        "subgroup: spezialmanoever",
        "subgroup: spezialmanoever\nnote: Prüfung gelingt automatisch",
    )
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    assert lint_file(p)  # rejected: non-ASCII


def test_note_over_length_cap_is_rejected(tmp_path):
    body = VALID.replace(
        "subgroup: spezialmanoever",
        f"subgroup: spezialmanoever\nnote: {'a' * 201}",
    )
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    assert lint_file(p)  # rejected: over the 200-char cap


# --- recovery conditional relaxation (fix round 1, M1) ---

def _recovery_doc(extra: str) -> str:
    return textwrap.dedent("""
        id: ADV_75
        subgroup: none
        source:
          url: https://dsa.ulisses-regelwiki.de/ADV_75.html
          checked: 2026-09-20
          hash: sha256:{h}
        effects:
          - type: recovery
            {extra}
    """).format(h="0" * 64, extra=extra)


def test_recovery_scale_without_attribute_is_accepted(tmp_path):
    p = tmp_path / "ADV_75.yaml"
    p.write_text(_recovery_doc("value: 0.5\n    operation: scale\n    per: duration"))
    assert lint_file(p) == []


def test_recovery_add_without_attribute_is_still_rejected(tmp_path):
    p = tmp_path / "ADV_75.yaml"
    p.write_text(_recovery_doc("value: 1\n    operation: add\n    per: regenerationCycle"))
    errs = lint_file(p)
    assert any("attribute" in e for e in errs)


def test_recovery_add_with_attribute_passes(tmp_path):
    p = tmp_path / "ADV_75.yaml"
    p.write_text(_recovery_doc("attribute: LE\n    value: 1\n    operation: add\n    per: regenerationCycle"))
    assert lint_file(p) == []


# --- Task 4 fix round 1 (Q4): open-vocabulary slug shape + registration ---
#
# ADR-0008 leaves `grants`/`forbids`/`legality.action`/`gmFlag` open because
# they are not finite over 232 rules. Open was previously *unconstrained*:
# `forbids: "keine Verteidigung in dieser KR"` linted clean, which is a Data
# Policy hole, not untidiness. Two layers now close it -- a slug pattern in
# schema.json, and registration in specs/rules/vocabulary.yaml -- and the
# second is the one that catches the failure an open vocabulary actually dies
# of: a well-formed synonym nobody agreed on.

def _action_economy_doc(field: str, token: str) -> str:
    return textwrap.dedent("""
        id: SA_66
        subgroup: spezialmanoever
        source:
          url: https://dsa.ulisses-regelwiki.de/SA_66.html
          checked: 2026-09-20
          hash: sha256:{h}
        effects:
          - type: actionEconomy
            {field}: {token}
    """).format(h="0" * 64, field=field, token=token)


def test_registered_forbids_token_is_accepted(tmp_path):
    p = tmp_path / "SA_66.yaml"
    p.write_text(_action_economy_doc("forbids", "defense"))
    assert lint_file(p) == []


def test_unregistered_but_well_formed_forbids_token_is_rejected(tmp_path):
    p = tmp_path / "SA_66.yaml"
    p.write_text(_action_economy_doc("forbids", "noDefense"))
    errs = lint_file(p)
    assert any("noDefense" in e and "vocabulary.yaml" in e for e in errs)


def test_unregistered_grants_token_is_rejected(tmp_path):
    p = tmp_path / "SA_66.yaml"
    p.write_text(_action_economy_doc("grants", "freeAction"))
    errs = lint_file(p)
    assert any("freeAction" in e and "vocabulary.yaml" in e for e in errs)


def test_rule_prose_in_forbids_is_rejected_by_the_slug_pattern(tmp_path):
    # The hole this pattern closes: before it, `type: string` accepted a
    # whole German clause here, and the linter's `text`-key and comment scans
    # do not look inside a legitimately free-form string field (AGENTS.md
    # records that known limit).
    p = tmp_path / "SA_66.yaml"
    p.write_text(_action_economy_doc("forbids", '"keine Verteidigung in dieser KR"'))
    errs = lint_file(p)
    assert any("does not match" in e for e in errs)


def test_unregistered_gm_flag_is_rejected(tmp_path):
    body = textwrap.dedent("""
        id: SA_22
        subgroup: none
        source:
          url: https://dsa.ulisses-regelwiki.de/SA_22.html
          checked: 2026-09-20
          hash: sha256:{h}
        effects:
          - type: modifier
            target: at
            scope: combat
            value: 1
            when: [{{gmFlag: phaseOfMoon}}]
    """).format(h="0" * 64)
    p = tmp_path / "SA_22.yaml"
    p.write_text(body)
    errs = lint_file(p)
    assert any("phaseOfMoon" in e and "vocabulary.yaml" in e for e in errs)


def test_unregistered_legality_action_is_rejected(tmp_path):
    body = textwrap.dedent("""
        id: SA_43
        subgroup: passiv
        source:
          url: https://dsa.ulisses-regelwiki.de/SA_43.html
          checked: 2026-09-20
          hash: sha256:{h}
        effects:
          - type: legality
            action: teleportAtWill
    """).format(h="0" * 64)
    p = tmp_path / "SA_43.yaml"
    p.write_text(body)
    errs = lint_file(p)
    assert any("teleportAtWill" in e and "vocabulary.yaml" in e for e in errs)


def test_legality_action_pattern_allows_the_schemas_own_example():
    # `legality.action`'s documented example is "basismanoever+spezialmanoever".
    # A naive camelCase-only pattern would have rejected the schema's own
    # worked example, so the `+`-joined form is allowed deliberately.
    import re
    from scripts.rules_lint.lint import SCHEMA
    pattern = SCHEMA["properties"]["effects"]["items"]["properties"]["action"]["pattern"]
    assert re.fullmatch(pattern, "basismanoever+spezialmanoever")
    assert not re.fullmatch(pattern, "eine Kombination aus zwei Manoevern")


def test_vocabulary_registry_itself_lints_clean():
    from scripts.rules_lint.lint import lint_vocabulary
    assert lint_vocabulary() == []


def test_vocabulary_rejects_a_non_ascii_gloss(tmp_path):
    from scripts.rules_lint.lint import lint_vocabulary
    p = tmp_path / "vocabulary.yaml"
    p.write_text("forbids:\n  defense: Keine Verteidigung möglich\n", encoding="utf-8")
    errs = lint_vocabulary(p)
    assert any("ASCII" in e and "Data Policy" in e for e in errs)


def test_vocabulary_rejects_an_unknown_section(tmp_path):
    from scripts.rules_lint.lint import lint_vocabulary
    p = tmp_path / "vocabulary.yaml"
    p.write_text("modifiers:\n  at: something\n", encoding="utf-8")
    errs = lint_vocabulary(p)
    assert any("unknown section" in e for e in errs)


def test_every_token_the_corpus_uses_is_registered():
    """The end-to-end guarantee, over the real corpus rather than a fixture."""
    from scripts.rules_lint.lint import NON_RULE_FILES, REPO_ROOT, lint_file as _lint
    rules_dir = REPO_ROOT / "specs" / "rules"
    errors = [e for p in sorted(rules_dir.glob("*.yaml"))
              if p.name not in NON_RULE_FILES
              for e in _lint(p)]
    assert errors == []


# --- Chapter rules: the second id namespace (schema.json `#/$defs/ruleId`) ---
#
# A chapter page binds anyone in the situation it describes and has no Optolith
# id, so its id is derived from the page its `source.url` already records. The
# derivation is the whole guarantee -- without these checks "the id is the page
# slug" is a schema description nothing enforces.

CHAPTER = textwrap.dedent("""
    id: CHAP_Reiterkampf
    subgroup: none
    source:
      url: https://dsa.ulisses-regelwiki.de/Reiterkampf.html
      book: US25001
      page: 239
      checked: 2026-09-21
      hash: sha256:{h}
    effects:
      - type: modifier
        target: aw
        scope: combat
        value: -2
        when: [{{mounted: true}}]
""").format(h="0" * 64)


def test_chapter_rule_is_accepted(tmp_path):
    p = tmp_path / "CHAP_Reiterkampf.yaml"
    p.write_text(CHAPTER)
    assert lint_file(p) == []


def test_chapter_id_that_does_not_match_its_page_is_rejected(tmp_path):
    body = CHAPTER.replace("id: CHAP_Reiterkampf", "id: CHAP_Berittenerkampf")
    p = tmp_path / "CHAP_Berittenerkampf.yaml"
    p.write_text(body)
    errs = lint_file(p)
    assert any("CHAP_Reiterkampf" in e and "source.url" in e for e in errs)


def test_chapter_id_may_not_be_a_maneuver_slot(tmp_path):
    body = CHAPTER.replace("subgroup: none", "subgroup: basismanoever")
    p = tmp_path / "CHAP_Reiterkampf.yaml"
    p.write_text(body)
    errs = lint_file(p)
    assert any("subgroup must be 'none'" in e for e in errs)


def test_chapter_id_needs_a_real_page(tmp_path):
    body = textwrap.dedent("""
        id: CHAP_UNVERIFIED
        subgroup: none
        source:
          url: https://dsa.ulisses-regelwiki.de/UNVERIFIED
          checked: 1970-01-01
          hash: sha256:{h}
        effects:
          - type: reminder
            note: 'UNENCODED: placeholder'
    """).format(h="0" * 64)
    p = tmp_path / "CHAP_UNVERIFIED.yaml"
    p.write_text(body)
    errs = lint_file(p)
    assert any("needs a real source.url" in e for e in errs)


def test_chapter_id_and_optolith_id_namespaces_cannot_collide():
    """Every Optolith id ends in digits, every chapter id in letters."""
    import re
    from scripts.rules_lint.lint import SCHEMA
    pattern = SCHEMA["$defs"]["ruleId"]["pattern"]
    assert re.fullmatch(pattern, "CHAP_Reiterkampf")
    assert re.fullmatch(pattern, "SA_43")
    assert not re.fullmatch(pattern, "CHAP_43")
    assert not re.fullmatch(pattern, "SA_Reiterkampf")


def test_excludes_still_refuses_a_chapter_id(tmp_path):
    """An excludes edge bans a Kampfrunde combination between two selectable
    maneuvers; a chapter rule is never selected, so it cannot sit on that edge."""
    body = VALID.replace("excludes: [SA_48]", "excludes: [CHAP_Reiterkampf]")
    p = tmp_path / "SA_62.yaml"
    p.write_text(body)
    assert lint_file(p)  # rejected


def test_chapter_slug_transliterates_a_percent_encoded_umlaut():
    from scripts.rules_lint.lint import chapter_slug
    assert chapter_slug("https://dsa.ulisses-regelwiki.de/Vorsto%C3%9F.html") == "Vorstoss"
    assert chapter_slug("https://dsa.ulisses-regelwiki.de/Beengte-Umgebung.html") == "BeengteUmgebung"
