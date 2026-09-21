"""The rule graph: four mechanical edges, walked transitively.

`prepare_workspace` withholds a graded rule's own authored file and redacts its id
and German name. Neither reaches a *different* authored file that encodes the same
mechanic -- that file is the rule's answer key while carrying no token redaction
can find. The whole-branch review recorded one live instance as its section 6, and
ruled that the workspace must withhold the transitive closure of the graded rules
over the corpus's own mechanical adjacency. Fix round 1 added the fourth edge and
widened `scope` to subsume, after both gaps were measured against the corpus
rather than argued about -- see `_scopes_collide` and `when_predicates`.

Everything here runs against synthetic corpora, one property per test, because a
test written against the real corpus measures the corpus rather than the rule: the
28 files it holds today would let a closure that only ever walked one hop pass a
transitivity test by luck. The one exception is
`test_propose.py::test_the_workspace_withholds_the_neighbour_that_encodes_a_graded_rules_clause`,
which is deliberately written against the real files, because the pair it names is
the instance section 6 is about.

No rule prose here. The synthetic rules carry ids in a namespace no corpus uses
(`SA_9NN`) and invented mechanics, so nothing in this file states a DSA rule.
"""
import pytest

from scripts.rules_sync.rule_graph import (
    EDGE_AXIS,
    EDGE_EXCLUDES,
    EDGE_PARAMETER,
    EDGE_PREDICATE,
    build_graph,
    load_corpus,
    withholding,
)


def rule(rule_id, *, effects=(), excludes=None):
    doc = {"id": rule_id, "subgroup": "none", "ruleset": "core",
           "effects": [dict(e) for e in effects]}
    if excludes is not None:
        doc["excludes"] = list(excludes)
    return doc


def mod(target="at", scope="combat", side=None, value=1, **extra):
    row = {"type": "modifier", "target": target, "scope": scope, "value": value}
    if side is not None:
        row["side"] = side
    row.update(extra)
    return row


def gated(rule_id, predicate, *, effect_type="legality", **row):
    """A rule whose single row carries a `when` gate and (by default) no axis."""
    return rule(rule_id, effects=[{"type": effect_type, "when": [predicate], **row}])


def kinds(w, rule_id):
    """`{neighbour: {edge kinds}}` for one graded rule's closure.

    A set per neighbour, not one kind: since fix round 1 a `Reason` carries every
    edge running to the file it hung off, because a pair joined by two edges is a
    different control from a pair joined by one.
    """
    return {r.rule_id: {e.kind for e in r.edges} for r in w.reasons[rule_id]}


def details(w, rule_id, neighbour):
    """The detail strings of every edge to one neighbour."""
    return sorted(e.detail for r in w.reasons[rule_id] if r.rule_id == neighbour
                  for e in r.edges)


# ── edge 1: excludes, in both directions ─────────────────────────────────────

def test_an_excludes_edge_pulls_in_the_rule_it_names():
    corpus = {
        "SA_901": rule("SA_901", excludes=["SA_902"], effects=[mod(target="pa")]),
        "SA_902": rule("SA_902", effects=[mod(target="aw")]),
        "SA_903": rule("SA_903", effects=[mod(target="gs", scope="movement")]),
    }
    w = withholding(["SA_901"], corpus=corpus)
    assert kinds(w, "SA_901") == {"SA_902": {EDGE_EXCLUDES}}


def test_an_excludes_edge_is_walked_backwards_too():
    """The field is written on one side. The leak runs both ways: a rule that
    names the graded one still states a Tier 2 field of it (`excludes` is graded
    by Tier 2 and reported as a disagreement by the driver), and the graded rule
    has no field of its own to give that away."""
    corpus = {
        "SA_901": rule("SA_901", excludes=["SA_902"], effects=[mod(target="pa")]),
        "SA_902": rule("SA_902", effects=[mod(target="aw")]),
    }
    w = withholding(["SA_902"], corpus=corpus)
    assert kinds(w, "SA_902") == {"SA_901": {EDGE_EXCLUDES}}


def test_an_excludes_entry_naming_no_authored_file_is_not_an_edge():
    corpus = {"SA_901": rule("SA_901", excludes=["SA_999"], effects=[mod()])}
    assert withholding(["SA_901"], corpus=corpus).neighbours == set()


# ── edge 2: the same parameterOverride path ──────────────────────────────────

def test_two_rules_overriding_the_same_parameter_are_neighbours():
    """One states what the other's constant is."""
    corpus = {
        "SA_901": rule("SA_901", effects=[
            {"type": "parameterOverride", "parameter": "invented.knob", "set": 2}]),
        "SA_902": rule("SA_902", effects=[
            {"type": "parameterOverride", "parameter": "invented.knob", "scale": 0.5}]),
        "SA_903": rule("SA_903", effects=[
            {"type": "parameterOverride", "parameter": "invented.other", "set": 1}]),
    }
    w = withholding(["SA_901"], corpus=corpus)
    assert kinds(w, "SA_901") == {"SA_902": {EDGE_PARAMETER}}
    assert details(w, "SA_901", "SA_902") == ["invented.knob"]


def test_two_parameter_overrides_of_different_paths_are_not_neighbours():
    """The degenerate reading of edge 3 -- every `parameterOverride` row shares
    an all-absent axis key with every other -- would make edge 2 redundant and
    swallow half the corpus. Rows with no axis do not collide."""
    corpus = {
        "SA_901": rule("SA_901", effects=[
            {"type": "parameterOverride", "parameter": "invented.knob", "set": 2}]),
        "SA_902": rule("SA_902", effects=[
            {"type": "parameterOverride", "parameter": "invented.other", "set": 1}]),
    }
    assert withholding(["SA_901"], corpus=corpus).neighbours == set()


def test_rows_with_no_axis_do_not_collide_on_their_effect_type_alone():
    """Same boundary, stated for the other axis-less effect types: two `dice`
    rows, or two `actionEconomy` rows, are not neighbours merely for being the
    same kind of row. `grants`, `forbids`, `state` and `recipient` would each be
    a further edge; adding one is a ruling, not an implementation detail."""
    corpus = {
        "SA_901": rule("SA_901", effects=[{"type": "dice", "add": "1W6"}]),
        "SA_902": rule("SA_902", effects=[{"type": "dice", "add": "2W6"}]),
        "SA_903": rule("SA_903", effects=[{"type": "actionEconomy", "grants": "inventedGrant"}]),
        "SA_904": rule("SA_904", effects=[{"type": "actionEconomy", "forbids": "inventedBan"}]),
    }
    assert withholding(["SA_901"], corpus=corpus).neighbours == set()
    assert withholding(["SA_903"], corpus=corpus).neighbours == set()


# ── edge 3: graded-axis collision ────────────────────────────────────────────

def test_rows_colliding_on_every_graded_axis_are_neighbours():
    corpus = {
        "SA_901": rule("SA_901", effects=[mod(target="at", scope="combat", value=2)]),
        "SA_902": rule("SA_902", effects=[mod(target="at", scope="combat", value=-4)]),
    }
    w = withholding(["SA_901"], corpus=corpus)
    assert kinds(w, "SA_901") == {"SA_902": {EDGE_AXIS}}
    assert details(w, "SA_901", "SA_902") == \
        ["type=modifier target=at scope=combat side=hero"]


@pytest.mark.parametrize("differing", [
    {"target": "pa"},
    {"target": "all"},
    {"side": "opponent"},
    {"scope": "movement"},
])
def test_a_row_differing_on_any_one_axis_is_not_a_collision(differing):
    """`type`, `target` and `side` are matched by equality, and so are two
    *narrow* scopes.

    The previous version of this test also listed `{"scope": "all"}` here, and
    its docstring said widening `scope` was "a ruling with a measurable cost, so
    it is pinned here rather than left to the next reader's judgement". **The
    ruling was made (fix round 1, 2026-09-21) and it went the other way for
    `scope` only** -- see `_scopes_collide` and
    `test_a_scope_all_row_subsumes_a_narrower_scope_on_the_same_target` below.
    `scope` is a domain filter, not a label, so `all` mechanically subsumes
    `combat`; the corpus's only two `be` rows are exactly that pair, and under
    equality the chapter file stayed in `SA_41`'s workspace with a worked
    `modifier target: be` row intact.

    **`target: all` was measured and deliberately not widened**, which is why it
    is now a case here rather than the `scope` one: wildcarding it links every
    modifier row to every other, taking nine of the ten golden rules to 20
    withheld files and the ten-rule batch to 22 of 28 -- the swallow-everything
    failure `test_rows_with_no_axis_do_not_collide_on_their_effect_type_alone`
    rejects for axis-less rows, arrived at from the other side.
    """
    base = dict(target="at", scope="combat", value=2)
    corpus = {
        "SA_901": rule("SA_901", effects=[mod(**base)]),
        "SA_902": rule("SA_902", effects=[mod(**{**base, **differing})]),
    }
    assert withholding(["SA_901"], corpus=corpus).neighbours == set()


@pytest.mark.parametrize("graded, neighbour", [("SA_901", "SA_902"), ("SA_902", "SA_901")])
def test_a_scope_all_row_subsumes_a_narrower_scope_on_the_same_target(graded, neighbour):
    """The ruling of fix round 1. Symmetric per pair even though subsumption is
    one-sided per row: whichever end is graded, the other is the answer key."""
    corpus = {
        "SA_901": rule("SA_901", effects=[mod(target="be", scope="all", value=-1)]),
        "SA_902": rule("SA_902", effects=[mod(target="be", scope="combat", value=-1)]),
        "SA_903": rule("SA_903", effects=[mod(target="be", scope="movement", value=-1)]),
    }
    w = withholding([graded], corpus=corpus)
    assert kinds(w, graded)[neighbour] == {EDGE_AXIS}
    assert details(w, graded, neighbour) == \
        ["type=modifier target=be scope=all subsumes combat side=hero"]
    # and `all` reaches the third row too, so it is one component, not a chain
    assert w.files == {"SA_901", "SA_902", "SA_903"}


def test_two_narrow_scopes_do_not_collide_through_a_shared_wider_one():
    """Subsumption is not transitivity in disguise at the *row* level: `combat`
    and `movement` are different domains and their rows are not each other's
    answer key. They can still end up in one closure through a `scope: all` row
    that subsumes both -- which is a graph fact the report shows, hop by hop, not
    a claim that the two narrow rows collide."""
    corpus = {
        "SA_901": rule("SA_901", effects=[mod(target="be", scope="combat")]),
        "SA_902": rule("SA_902", effects=[mod(target="be", scope="movement")]),
    }
    assert withholding(["SA_901"], corpus=corpus).neighbours == set()


def test_side_hero_spelled_and_side_hero_implied_are_one_axis():
    """`side`'s schema default, treated exactly as `test_calibration` treats it
    for grading: one encoding spelling a declared default and the other leaving
    it implicit is one encoding, so it must also be one axis."""
    corpus = {
        "SA_901": rule("SA_901", effects=[mod(side="hero")]),
        "SA_902": rule("SA_902", effects=[mod(side=None)]),
    }
    assert kinds(withholding(["SA_901"], corpus=corpus), "SA_901") == {"SA_902": {EDGE_AXIS}}


def test_a_reminder_row_is_not_an_answer_key():
    """Reminders carry `note` and `when` only -- nothing Tier 1 grades a shape
    by -- and every `UNENCODED:` clause in the corpus is one. Collision on them
    would link every chapter rule to every other for no leak."""
    corpus = {
        "SA_901": rule("SA_901", effects=[{"type": "reminder", "when": [{"mounted": True}]}]),
        "SA_902": rule("SA_902", effects=[{"type": "reminder", "when": [{"mounted": True}]}]),
    }
    assert withholding(["SA_901"], corpus=corpus).neighbours == set()


# ── edge 4: the same `when` predicate ────────────────────────────────────────

def test_rows_gated_on_the_same_predicate_are_neighbours():
    """Fix round 1's second Important finding, in the abstract. A rule whose
    whole encoding is one axis-less row plus one `when` predicate is invisible to
    edges 1-3, and a file carrying that same gate states the half of it that the
    gate *is*."""
    corpus = {
        "SA_901": gated("SA_901", {"mounted": True}, action="inventedAction"),
        "SA_902": gated("SA_902", {"mounted": True}, effect_type="dice", add="1W6"),
        "SA_903": gated("SA_903", {"offHandWeapon": True}, effect_type="dice", add="1W6"),
    }
    w = withholding(["SA_901"], corpus=corpus)
    assert kinds(w, "SA_901") == {"SA_902": {EDGE_PREDICATE}}
    assert details(w, "SA_901", "SA_902") == ['{"mounted": true}']


def test_rows_gated_on_different_predicates_are_not_neighbours():
    corpus = {
        "SA_901": gated("SA_901", {"gmFlag": "inventedFlag"}),
        "SA_902": gated("SA_902", {"gmFlag": "otherInventedFlag"}),
    }
    assert withholding(["SA_901"], corpus=corpus).neighbours == set()


def test_two_ungated_rows_are_not_neighbours_for_being_ungated():
    """The axis-less boundary, restated for edge 4: "both unconditional" is not a
    shared gate. Without this, every ungated row in the corpus would be adjacent
    to every other and the closure would swallow everything."""
    corpus = {
        "SA_901": rule("SA_901", effects=[{"type": "legality", "action": "inventedA"}]),
        "SA_902": rule("SA_902", effects=[{"type": "legality", "action": "inventedB"}]),
    }
    assert withholding(["SA_901"], corpus=corpus).neighbours == set()


def test_one_shared_predicate_is_enough_even_when_the_gates_differ_in_extent():
    """`when` ANDs its predicates, so a row gated on two of them is still gated
    on each. A neighbour that states one of the graded rule's predicates has
    stated a predicate of it, and the whole-gate reading would miss that."""
    corpus = {
        "SA_901": gated("SA_901", {"mounted": True}),
        "SA_902": rule("SA_902", effects=[{"type": "legality", "action": "inventedB", "when": [
            {"mounted": True}, {"gmFlag": "inventedFlag"}]}]),
    }
    assert kinds(withholding(["SA_901"], corpus=corpus), "SA_901") == {"SA_902": {EDGE_PREDICATE}}


# ── the closure is transitive ────────────────────────────────────────────────

def test_the_closure_is_transitive_across_a_chain_of_three():
    """A -> B -> C withholds all three when A is graded. C shares no edge with A:
    a one-hop implementation passes every edge-type test above and fails here,
    which is why this is its own test and its own corpus."""
    corpus = {
        "SA_901": rule("SA_901", effects=[mod(target="at", scope="combat")]),
        "SA_902": rule("SA_902", effects=[mod(target="at", scope="combat"),
                                          mod(target="pa", scope="combat")]),
        "SA_903": rule("SA_903", effects=[mod(target="pa", scope="combat")]),
        "SA_904": rule("SA_904", effects=[mod(target="gs", scope="movement")]),
    }
    w = withholding(["SA_901"], corpus=corpus)
    assert w.files == {"SA_901", "SA_902", "SA_903"}
    assert "SA_904" not in w.files


def test_a_transitive_pull_records_the_file_it_hung_off_not_the_graded_rule():
    """"Withheld because it collides with a rule that collides with the graded
    one" and "withheld because it collides with the graded one" are different
    facts about a measurement, and the report has to be able to tell a reader
    which it is."""
    corpus = {
        "SA_901": rule("SA_901", effects=[mod(target="at", scope="combat")]),
        "SA_902": rule("SA_902", effects=[mod(target="at", scope="combat"),
                                          mod(target="pa", scope="combat")]),
        "SA_903": rule("SA_903", effects=[mod(target="pa", scope="combat")]),
    }
    by_id = {r.rule_id: r for r in withholding(["SA_901"], corpus=corpus).reasons["SA_901"]}
    assert (by_id["SA_902"].hops, by_id["SA_902"].via) == (1, "SA_901")
    assert (by_id["SA_903"].hops, by_id["SA_903"].via) == (2, "SA_902")


def test_the_closure_mixes_edge_types_along_one_chain():
    """The four edges are one graph, not four. A chain that changes edge type at
    each hop still closes."""
    corpus = {
        "SA_901": rule("SA_901", excludes=["SA_902"], effects=[mod(target="le", scope="derived")]),
        "SA_902": rule("SA_902", effects=[
            {"type": "parameterOverride", "parameter": "invented.knob", "set": 1}]),
        "SA_903": rule("SA_903", effects=[
            {"type": "parameterOverride", "parameter": "invented.knob", "set": 2},
            mod(target="at", scope="combat")]),
        "SA_904": rule("SA_904", effects=[
            mod(target="at", scope="combat", when=[{"mounted": True}])]),
        "SA_905": gated("SA_905", {"mounted": True}),
    }
    w = withholding(["SA_901"], corpus=corpus)
    assert w.files == {"SA_901", "SA_902", "SA_903", "SA_904", "SA_905"}
    assert kinds(w, "SA_901") == {
        "SA_902": {EDGE_EXCLUDES}, "SA_903": {EDGE_PARAMETER},
        "SA_904": {EDGE_AXIS}, "SA_905": {EDGE_PREDICATE}}


def test_several_graded_rules_get_one_closure_each_and_one_withheld_set():
    corpus = {
        "SA_901": rule("SA_901", effects=[mod(target="at", scope="combat")]),
        "SA_902": rule("SA_902", effects=[mod(target="at", scope="combat")]),
        "SA_903": rule("SA_903", effects=[mod(target="gs", scope="movement")]),
        "SA_904": rule("SA_904", effects=[mod(target="gs", scope="movement")]),
    }
    w = withholding(["SA_901", "SA_903"], corpus=corpus)
    assert kinds(w, "SA_901") == {"SA_902": {EDGE_AXIS}}
    assert kinds(w, "SA_903") == {"SA_904": {EDGE_AXIS}}
    assert w.files == {"SA_901", "SA_902", "SA_903", "SA_904"}


# ── the graph itself ─────────────────────────────────────────────────────────

def test_the_graph_is_symmetric_on_every_edge():
    corpus = {
        "SA_901": rule("SA_901", excludes=["SA_902"], effects=[mod(target="at")]),
        "SA_902": rule("SA_902", effects=[mod(target="at")]),
    }
    graph = build_graph(corpus)
    assert graph["SA_901"]["SA_902"] == graph["SA_902"]["SA_901"]
    assert {e.kind for e in graph["SA_901"]["SA_902"]} == {EDGE_EXCLUDES, EDGE_AXIS}


def test_every_edge_of_a_pair_reaches_the_report_not_just_the_first():
    """Fix round 1, minor 4. The closure used to keep one edge per pair, so a
    pair joined by both `excludes` and a graded-axis collision reported as
    `excludes` alone -- which reads as a Tier 2 adjacency and understates what
    the measurement controlled for."""
    corpus = {
        "SA_901": rule("SA_901", excludes=["SA_902"], effects=[mod(target="at")]),
        "SA_902": rule("SA_902", effects=[mod(target="at")]),
    }
    w = withholding(["SA_901"], corpus=corpus)
    assert kinds(w, "SA_901") == {"SA_902": {EDGE_EXCLUDES, EDGE_AXIS}}
    body = w.render()
    assert "excludes: excludes" in body
    assert "graded-axis: type=modifier target=at scope=combat side=hero" in body


def test_an_unauthored_graded_id_withholds_nothing_and_says_so():
    """`--ids` takes ids from `rules.db`, which holds 232 rules against a corpus
    of 28: most of a run's ids have no authored file at all, and that must be a
    stated fact rather than a crash or a silent empty section."""
    w = withholding(["SA_999"], corpus={"SA_901": rule("SA_901", effects=[mod()])})
    assert w.unauthored == ["SA_999"]
    assert w.files == {"SA_999"}
    assert "does not exist in this corpus" in w.render()


def test_the_real_corpus_loads_and_every_rule_is_its_own_file_stem():
    corpus = load_corpus()
    assert len(corpus) >= 28
    assert all(doc.get("id") == stem for stem, doc in corpus.items())


# ── the report ───────────────────────────────────────────────────────────────

def test_the_report_names_each_withheld_file_and_the_edge_that_pulled_it_in():
    corpus = {
        "SA_901": rule("SA_901", effects=[mod(target="at", scope="combat")]),
        "SA_902": rule("SA_902", effects=[mod(target="at", scope="combat")]),
    }
    body = withholding(["SA_901"], corpus=corpus).render()
    assert "specs/rules/SA_901.yaml" in body and "the graded rule itself" in body
    assert "specs/rules/SA_902.yaml" in body
    assert EDGE_AXIS in body
    assert "type=modifier target=at scope=combat side=hero" in body


def test_a_rule_with_no_neighbours_says_so_rather_than_saying_nothing():
    """Section 6's requirement, and the reason the report exists: silence must
    not be readable as absence. A reader of the next measurement has to be able
    to tell "this rule had no authored neighbour" from "the graph missed it"."""
    body = withholding(["SA_901"], corpus={
        "SA_901": rule("SA_901", effects=[mod(target="at", scope="combat")]),
        "SA_902": rule("SA_902", effects=[mod(target="gs", scope="movement")]),
    }).render()
    assert "No neighbours." in body
    assert "SA_902" not in body


def test_the_report_carries_no_rule_prose_only_ids_and_field_names():
    """Data Policy. The report is an artefact of a run over the real corpus, so
    it is built from the real corpus here -- the one thing it must never do is
    carry a `note`, which is where every non-mechanical sentence in an authored
    file lives."""
    body = withholding(["SA_661", "SA_41"]).render()
    notes = [row.get("note") for doc in load_corpus().values()
             for row in (doc.get("effects") or []) if isinstance(row, dict) and row.get("note")]
    notes += [doc["note"] for doc in load_corpus().values() if doc.get("note")]
    offenders = [n for n in notes if n in body]
    assert offenders == [], offenders


def test_the_report_is_deterministic_under_a_reordered_corpus():
    """It is a run artefact a reader compares across passes; set or dict
    iteration order leaking into it would make five identical runs produce five
    different files.

    Fix round 1, minor 5: the first version of this compared two `render()` calls
    in one process, which **cannot fail** -- both share a string-hash seed, so set
    iteration order is identical by construction even if the code leaked it. The
    input is now explicitly reordered instead, which is the thing that varies in
    practice (`load_corpus` sorts, but a caller passing `corpus=` need not).
    """
    corpus = load_corpus()
    reversed_corpus = dict(reversed(list(corpus.items())))
    rotated = dict(list(corpus.items())[7:] + list(corpus.items())[:7])
    baseline = withholding(GOLDEN_IDS, corpus=corpus).render()
    assert withholding(GOLDEN_IDS, corpus=reversed_corpus).render() == baseline
    assert withholding(GOLDEN_IDS, corpus=rotated).render() == baseline


# ── the cost figures the budget decision is made against ─────────────────────

#: The batch the recorded calibration run used, and the one Task 11 repeats.
GOLDEN_IDS = [
    "SA_40", "SA_41", "SA_43", "SA_48", "SA_59",
    "SA_62", "SA_65", "SA_66", "SA_67", "SA_661",
]

#: Everything the ten-rule batch withholds, spelled out. Eight files beyond the
#: ten themselves.
BATCH_CLOSURE = {
    "SA_40", "SA_41", "SA_43", "SA_48", "SA_59", "SA_62", "SA_65", "SA_66", "SA_67", "SA_661",
    "CHAP_Reiterkampf", "COND_1", "COND_2", "COND_4", "COND_5", "COND_6", "COND_7", "DISADV_34",
}

COST_REMEDY = (
    "The closure over the real corpus changed. That is not automatically wrong -- "
    "a new authored file or a new edge moves it -- but it is the arithmetic a human "
    "authorises ~110 live model calls against, and it is quoted in "
    "docs/rules-pipeline-status.md section 2, CHANGELOG.md and the plan's Task 11a. "
    "Re-run the cost analysis and update all three in the same commit; do not edit "
    "these constants to match and stop there."
)


def test_the_ten_rule_batch_withholds_exactly_the_documented_set():
    """Fix round 1, minor 6. "18 of 28" and "8 pulled in by the graph" are the
    numbers the budget decision is made against, and nothing asserted them, so an
    edge change could silently rewrite the status doc's arithmetic."""
    w = withholding(GOLDEN_IDS)
    assert w.files == BATCH_CLOSURE, COST_REMEDY
    assert len(w.files) == 18, COST_REMEDY
    assert len(load_corpus()) == 28, COST_REMEDY
    assert sorted(w.files - set(GOLDEN_IDS)) == [
        "CHAP_Reiterkampf", "COND_1", "COND_2", "COND_4", "COND_5", "COND_6",
        "COND_7", "DISADV_34"], COST_REMEDY


def test_the_per_rule_closures_are_the_documented_sizes():
    """The other half of the documented arithmetic: run rule-by-rule, two of the
    ten have no neighbour at all and the other eight withhold 16 files each."""
    sizes = {rid: len(withholding([rid]).files) for rid in GOLDEN_IDS}
    assert {rid for rid, n in sizes.items() if n == 1} == {"SA_40", "SA_59"}, COST_REMEDY
    assert {rid for rid, n in sizes.items() if n == 16} == {
        "SA_41", "SA_43", "SA_48", "SA_62", "SA_65", "SA_66", "SA_67", "SA_661"}, COST_REMEDY


def test_no_surviving_file_carries_a_combat_scoped_modifier_row():
    """The claim `docs/rules-pipeline-status.md` section 2 makes about what the
    ten-rule workspace is left holding, checked rather than asserted in prose.
    It is the fact that makes the next measurement's combat rules harder, and a
    later corpus addition could quietly falsify it."""
    corpus = load_corpus()
    survivors = set(corpus) - withholding(GOLDEN_IDS).files
    offenders = sorted(
        stem for stem in survivors
        for row in (corpus[stem].get("effects") or [])
        if isinstance(row, dict) and row.get("type") == "modifier"
        and row.get("scope") == "combat")
    assert offenders == [], COST_REMEDY
