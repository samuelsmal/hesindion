"""The rule graph: three mechanical edges, walked transitively.

`prepare_workspace` withholds a graded rule's own authored file and redacts its id
and German name. Neither reaches a *different* authored file that encodes the same
mechanic -- that file is the rule's answer key while carrying no token redaction
can find. The whole-branch review recorded one live instance as its section 6, and
ruled that the workspace must withhold the transitive closure of the graded rules
over the corpus's own mechanical adjacency.

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


def kinds(w, rule_id):
    """`{neighbour: edge kind}` for one graded rule's closure."""
    return {r.rule_id: r.edge.kind for r in w.reasons[rule_id]}


# ── edge 1: excludes, in both directions ─────────────────────────────────────

def test_an_excludes_edge_pulls_in_the_rule_it_names():
    corpus = {
        "SA_901": rule("SA_901", excludes=["SA_902"], effects=[mod(target="pa")]),
        "SA_902": rule("SA_902", effects=[mod(target="aw")]),
        "SA_903": rule("SA_903", effects=[mod(target="gs", scope="movement")]),
    }
    w = withholding(["SA_901"], corpus=corpus)
    assert kinds(w, "SA_901") == {"SA_902": EDGE_EXCLUDES}


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
    assert kinds(w, "SA_902") == {"SA_901": EDGE_EXCLUDES}


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
    assert kinds(w, "SA_901") == {"SA_902": EDGE_PARAMETER}
    assert w.reasons["SA_901"][0].edge.detail == "invented.knob"


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
    assert kinds(w, "SA_901") == {"SA_902": EDGE_AXIS}
    assert w.reasons["SA_901"][0].edge.detail == \
        "type=modifier target=at scope=combat side=hero"


@pytest.mark.parametrize("differing", [
    {"target": "pa"},
    {"scope": "all"},
    {"side": "opponent"},
])
def test_a_row_differing_on_any_one_axis_is_not_a_collision(differing):
    """Exact equality on all four axes, with no wildcard expansion: `scope: all`
    is a value, not a superset. Widening that is a ruling with a measurable cost
    (it would pull every `all`/`all` rule into every combat rule's closure), so
    it is pinned here rather than left to the next reader's judgement."""
    base = dict(target="at", scope="combat", value=2)
    corpus = {
        "SA_901": rule("SA_901", effects=[mod(**base)]),
        "SA_902": rule("SA_902", effects=[mod(**{**base, **differing})]),
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
    assert kinds(withholding(["SA_901"], corpus=corpus), "SA_901") == {"SA_902": EDGE_AXIS}


def test_a_reminder_row_is_not_an_answer_key():
    """Reminders carry `note` and `when` only -- nothing Tier 1 grades a shape
    by -- and every `UNENCODED:` clause in the corpus is one. Collision on them
    would link every chapter rule to every other for no leak."""
    corpus = {
        "SA_901": rule("SA_901", effects=[{"type": "reminder", "when": [{"mounted": True}]}]),
        "SA_902": rule("SA_902", effects=[{"type": "reminder", "when": [{"mounted": True}]}]),
    }
    assert withholding(["SA_901"], corpus=corpus).neighbours == set()


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
    """The three edges are one graph, not three. A chain that changes edge type
    at each hop still closes."""
    corpus = {
        "SA_901": rule("SA_901", excludes=["SA_902"], effects=[mod(target="le", scope="derived")]),
        "SA_902": rule("SA_902", effects=[
            {"type": "parameterOverride", "parameter": "invented.knob", "set": 1}]),
        "SA_903": rule("SA_903", effects=[
            {"type": "parameterOverride", "parameter": "invented.knob", "set": 2},
            mod(target="at", scope="combat")]),
        "SA_904": rule("SA_904", effects=[mod(target="at", scope="combat")]),
    }
    w = withholding(["SA_901"], corpus=corpus)
    assert w.files == {"SA_901", "SA_902", "SA_903", "SA_904"}
    assert kinds(w, "SA_901") == {
        "SA_902": EDGE_EXCLUDES, "SA_903": EDGE_PARAMETER, "SA_904": EDGE_AXIS}


def test_several_graded_rules_get_one_closure_each_and_one_withheld_set():
    corpus = {
        "SA_901": rule("SA_901", effects=[mod(target="at", scope="combat")]),
        "SA_902": rule("SA_902", effects=[mod(target="at", scope="combat")]),
        "SA_903": rule("SA_903", effects=[mod(target="gs", scope="movement")]),
        "SA_904": rule("SA_904", effects=[mod(target="gs", scope="movement")]),
    }
    w = withholding(["SA_901", "SA_903"], corpus=corpus)
    assert kinds(w, "SA_901") == {"SA_902": EDGE_AXIS}
    assert kinds(w, "SA_903") == {"SA_904": EDGE_AXIS}
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


def test_the_report_is_deterministic():
    """It is a run artefact a reader compares across passes; set iteration order
    leaking into it would make five identical runs produce five different files."""
    assert withholding(["SA_661"]).render() == withholding(["SA_661"]).render()
