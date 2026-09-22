#!/usr/bin/env python3
"""The authored corpus as a graph, so withholding can follow the rule and not the id.

Why this exists
---------------
`prepare_workspace` used to withhold exactly the authored file of each rule in the
run and redact that rule's id and German name everywhere else. That closes the
channel a token-shaped grep can see, and leaves open the one it cannot: a
*different* authored file that encodes the same mechanic is an answer key for the
graded rule while carrying neither its id nor its name. The whole-branch review
recorded one live instance as its section 6 -- a chapter file and an ability file
encoding one clause from the two ends -- and ruled that the workspace must withhold
the transitive closure of the graded rules over the corpus's own mechanical
adjacency.

The closure is computed from the corpus as it is. There is deliberately **no
declared `related:`/`modifies:` schema field**: the adjacency that leaked was one
nobody had spotted, so an edge that depends on an author spotting it inherits the
defect it is supposed to remove. Every edge below is derivable from fields the
schema already requires and the linter already checks.

The four edges
--------------
1. ``excludes`` (:data:`EDGE_EXCLUDES`) -- ``A.excludes`` naming ``B``. Walked
   **undirected**: if ``B`` is the graded rule, ``A`` still names it and still
   states a Tier 2 field of it, so the edge leaks in both directions even though
   the field is written on one side only.
2. ``parameterOverride.parameter`` (:data:`EDGE_PARAMETER`) -- two rules
   overriding the same dotted parameter path. One states what the other's constant
   is. The path is unvalidated today (that is a separate blocker); this consumes
   the field, it does not check it.
3. Graded-axis collision (:data:`EDGE_AXIS`) -- two non-reminder effect rows that
   agree on every axis Tier 1 grades a row's shape by: ``type``, ``target``,
   ``scope`` and ``side``. A file whose rows collide with a graded rule's rows on
   those axes encodes the same mechanic on the same value, whether or not anybody
   declared a relationship, and that is what makes it an answer key. This is the
   edge that catches the section 6 instance. ``scope`` collides by **subsumption**
   as well as by equality -- see :func:`_scopes_collide` for the ruling and for
   why ``target`` is deliberately not widened the same way.
4. ``when``-predicate identity (:data:`EDGE_PREDICATE`) -- two non-reminder rows
   gated on the same predicate. Added in fix round 1 after the first three were
   measured against the corpus and found to leave ``SA_43`` adjacent to nothing:
   its whole encoding is one ``legality`` row with one ``when`` predicate, it
   declares no axis, and the file that carries that same gate on every one of its
   own rows -- and names ``SA_43`` in two notes -- stayed in its workspace. A
   neighbour that states the gate is a fuller answer key for that rule than a
   neighbour that states the shape, and ``SA_43`` is the rule the stability
   measurement most depends on (it is the source of the ``when``-dropping datum).

A row that declares **none** of ``target``/``scope``/``side`` has no axis to
collide on, and edge 3 does not fire on it. That is not an oversight and it is not
a narrowing of the ruling: those three fields are the modifier union's axes, and
without the restriction the degenerate all-absent key would make every
``parameterOverride`` row adjacent to every other, which would swallow edge 2
whole -- and edge 2 is specified separately, as a distinct edge with a distinct
detail, precisely because parameter identity rather than row shape is what makes
two overrides neighbours. Two ``dice`` rows, two ``actionEconomy`` rows and two
``recovery`` rows are likewise not neighbours by virtue of sharing an effect type;
`grants`, `forbids`, `state` and `recipient` would each be a *further* edge, and
adding one is a ruling, not an implementation detail. What reaches an axis-less
row instead is edge 4, which is about the row's *gate* rather than its shape --
that is the boundary's cost, measured and then closed.

Over-withholding is the safe direction. Every edge here is an over-approximation
of "encodes the same mechanic" on purpose: two rules that both ease AT in combat
are neighbours under edge 3 even when their values and gates differ, because the
alternative is deciding in code how close is too close, and a wrong answer there
is silent. What that costs is recorded per run by :meth:`Withholding.render`, so a
reader of a measurement can see what it controlled for rather than infer it.

No rule prose lives here or in the report this writes: ids, file names, field
names, axis values and edge kinds only (Data Policy, `AGENTS.md`).
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Sequence

import yaml

# Reused rather than copied. `NON_RULE_FILES` already exists in four hand-synced
# call sites that `tests/rules/test_shared_constants.py` pins against each other;
# a fifth copy here would be a fifth thing to keep in sync and the test would not
# see it.
from scripts.rules_lint.lint import NON_RULE_FILES

REPO_ROOT = Path(__file__).resolve().parents[2]
RULES_DIR = REPO_ROOT / "specs" / "rules"

EDGE_EXCLUDES = "excludes"
EDGE_PARAMETER = "parameter-path"
EDGE_AXIS = "graded-axis"
EDGE_PREDICATE = "when-predicate"

#: `side`'s schema default. One row spelling it and another leaving it implicit is
#: one axis, exactly as `test_calibration.SCHEMA_DEFAULTS` treats it for grading.
SIDE_DEFAULT = "hero"

#: The modifier union's axes. A row declaring none of them has nothing for edge 3
#: to collide on -- see the module docstring.
AXES: tuple[str, ...] = ("target", "scope", "side")

__all__ = [
    "EDGE_EXCLUDES", "EDGE_PARAMETER", "EDGE_AXIS", "EDGE_PREDICATE",
    "AXES", "SIDE_DEFAULT",
    "Edge", "Reason", "Withholding",
    "load_corpus", "axis_keys", "parameter_paths", "excludes_of",
    "when_predicates", "build_graph", "withholding",
]


# ── one edge ─────────────────────────────────────────────────────────────────

@dataclass(frozen=True, order=True)
class Edge:
    """One reason two authored files are adjacent.

    `kind` is one of the three `EDGE_*` constants; `detail` says which field or
    which axes carried it, in field-name terms only.
    """
    kind: str
    detail: str

    def __str__(self) -> str:  # pragma: no cover - trivial
        return f"{self.kind} ({self.detail})"


@dataclass(frozen=True, order=True)
class Reason:
    """Why one file joined a graded rule's closure.

    `via` is the already-withheld file the edge hangs off, which is the graded
    rule itself at `hops == 1` and an intermediate neighbour beyond it. Keeping
    `via` and `hops` rather than just the edge is what makes a transitive pull
    auditable: "withheld because it collides with a rule that collides with the
    graded one" and "withheld because it collides with the graded one" are
    different facts about a measurement.

    `edges` holds **every** edge running between `via` and `rule_id`, sorted, not
    the first or cheapest one. A pair joined by both `excludes` and a graded-axis
    collision is a different fact from a pair joined by `excludes` alone, and a
    report that shows one of the two understates what it controlled for.
    """
    hops: int
    rule_id: str
    via: str
    edges: tuple[Edge, ...]

    @property
    def summary(self) -> str:
        """The edges, as one line of report detail."""
        return "; ".join(f"{e.kind}: {e.detail}" for e in self.edges)


# ── reading the corpus ───────────────────────────────────────────────────────

def load_corpus(rules_dir: Path | str = RULES_DIR) -> dict[str, dict]:
    """Every authored rule file in `rules_dir`, keyed by its file stem.

    Keyed by stem rather than by the `id:` inside, because the stem is what
    `prepare_workspace` withholds and what a report has to name. `lint.py`
    enforces that the two agree.
    """
    rules_dir = Path(rules_dir)
    corpus: dict[str, dict] = {}
    if not rules_dir.is_dir():
        return corpus
    for path in sorted(rules_dir.glob("*.yaml")):
        if path.name in NON_RULE_FILES:
            continue
        doc = yaml.safe_load(path.read_text(encoding="utf-8"))
        corpus[path.stem] = doc if isinstance(doc, dict) else {}
    return corpus


def _rows(doc: dict) -> list[dict]:
    """The non-reminder effect rows. A reminder carries `note` and `when` only --
    no axis, no parameter, nothing Tier 1 grades a shape by."""
    effects = doc.get("effects") or []
    return [e for e in effects
            if isinstance(e, dict) and e.get("type") != "reminder"]


def axis_keys(doc: dict) -> set[tuple[str, str, str, str]]:
    """Every graded-axis key this rule's rows occupy: `(type, target, scope, side)`.

    A row that declares none of `AXES` is skipped -- see the module docstring for
    why that is a deliberate boundary of edge 3 rather than a gap in it.
    """
    keys = set()
    for row in _rows(doc):
        if not any(row.get(axis) is not None for axis in AXES):
            continue
        keys.add((
            str(row.get("type")),
            str(row.get("target")),
            str(row.get("scope")),
            str(row.get("side", SIDE_DEFAULT)),
        ))
    return keys


def _scopes_collide(a: str, b: str) -> bool:
    """Whether two rows' `scope` values put them in the same domain.

    Equal scopes collide. So does `all` against any narrower scope, in one
    direction only: `scope` is a **domain filter, not a label** -- `all` means
    every domain and `combat` means the combat domains -- so a `scope: all` row
    mechanically subsumes a `scope: combat` row on the same target, and the two
    encode the same mechanic over an overlapping domain.

    Ruled 2026-09-21 (Task 11a fix round 1) after the exact-equality reading was
    measured against the corpus and found to leave a live channel: `SA_41` (the
    one golden rule that has never passed) carries the corpus's only
    `modifier target: be scope: all` row, `CHAP_Reiterkampf` carries its only
    `modifier target: be scope: combat` row, and under exact equality the second
    stayed in the first's workspace -- a worked `modifier target: be` row in
    front of the rule whose recorded failure is that it invented a
    `parameterOverride` path instead of one.

    **`target` is deliberately not widened the same way.** `target: all` reads as
    a wildcard too, and wildcarding it links every modifier row to every other:
    measured against the graph as it ships, that takes nine of the ten golden
    rules to 21 withheld files and the ten-rule batch to 22 of 28. That is the swallow-everything failure the
    axis-less boundary above exists to avoid, and it buys no channel that this
    one does not already close.
    """
    return a == b or a == "all" or b == "all"


def _axis_collisions(
    a: set[tuple[str, str, str, str]],
    b: set[tuple[str, str, str, str]],
) -> list[str]:
    """Every graded-axis collision between two rules' key sets, as report detail.

    Pairwise rather than a set intersection, because `scope` collides by
    subsumption and not only by equality (see `_scopes_collide`).
    """
    details = set()
    for kind_a, target_a, scope_a, side_a in a:
        for kind_b, target_b, scope_b, side_b in b:
            if (kind_a, target_a, side_a) != (kind_b, target_b, side_b):
                continue
            if not _scopes_collide(scope_a, scope_b):
                continue
            if scope_a == scope_b:
                scope = f"scope={scope_a}"
            else:
                wider, narrower = (scope_a, scope_b) if scope_a == "all" else (scope_b, scope_a)
                scope = f"scope={wider} subsumes {narrower}"
            details.add(f"type={kind_a} target={target_a} {scope} side={side_a}")
    return sorted(details)


def when_predicates(doc: dict) -> set[str]:
    """Every `when` predicate this rule's non-reminder rows are gated on, each as
    canonical JSON.

    A predicate is a single-key mapping and `when` ANDs them, so one shared
    predicate is one shared gate -- the unit the edge is about. Rows with no
    `when` contribute nothing: an ungated row shares no gate with another ungated
    row, and treating "both unconditional" as an edge would link most of the
    corpus to most of the corpus for no leak, which is the same failure the
    axis-less boundary rejects.

    Reminders are excluded for consistency with the other edges. On the corpus as
    it stands, including them would change no edge: every predicate a reminder
    row carries is already carried by a non-reminder row of the same file.
    """
    out = set()
    for row in _rows(doc):
        for predicate in row.get("when") or []:
            out.add(json.dumps(predicate, sort_keys=True, ensure_ascii=True, default=str))
    return out


def parameter_paths(doc: dict) -> set[str]:
    """Every dotted parameter path this rule overrides."""
    return {str(row["parameter"]) for row in _rows(doc)
            if row.get("type") == "parameterOverride" and row.get("parameter")}


def excludes_of(doc: dict) -> set[str]:
    """The ids this rule's `excludes` names, if any."""
    listed = doc.get("excludes") or []
    return {str(i) for i in listed} if isinstance(listed, (list, tuple, set)) else set()


# ── the graph ────────────────────────────────────────────────────────────────

def build_graph(corpus: dict[str, dict]) -> dict[str, dict[str, frozenset[Edge]]]:
    """Undirected adjacency over the four edges, as `{a: {b: {edges}}}`.

    Symmetric by construction: every edge is written to both ends, including
    `excludes`, which the corpus writes on one side only, and graded-axis
    collision, whose `scope` subsumption is one-sided per row but symmetric per
    pair.
    """
    keys = {rid: axis_keys(doc) for rid, doc in corpus.items()}
    params = {rid: parameter_paths(doc) for rid, doc in corpus.items()}
    gates = {rid: when_predicates(doc) for rid, doc in corpus.items()}
    names = sorted(corpus)

    graph: dict[str, dict[str, set[Edge]]] = {rid: {} for rid in names}

    def link(a: str, b: str, edge: Edge) -> None:
        graph[a].setdefault(b, set()).add(edge)
        graph[b].setdefault(a, set()).add(edge)

    for i, a in enumerate(names):
        for b in names[i + 1:]:
            if b in excludes_of(corpus[a]) or a in excludes_of(corpus[b]):
                link(a, b, Edge(EDGE_EXCLUDES, "excludes"))
            for path in sorted(params[a] & params[b]):
                link(a, b, Edge(EDGE_PARAMETER, path))
            for detail in _axis_collisions(keys[a], keys[b]):
                link(a, b, Edge(EDGE_AXIS, detail))
            for predicate in sorted(gates[a] & gates[b]):
                link(a, b, Edge(EDGE_PREDICATE, predicate))

    return {a: {b: frozenset(edges) for b, edges in sorted(nbrs.items())}
            for a, nbrs in graph.items()}


def _closure_for(graph: dict[str, dict[str, frozenset[Edge]]], seed: str) -> list[Reason]:
    """Breadth-first closure of one graded rule, each neighbour recorded with
    **every** edge that runs to the file it first hung off.

    All of them, not the cheapest: the report's job is to say what the
    measurement controlled for, and "withheld because of an `excludes` edge"
    reads as a Tier 2 adjacency when the same pair also collides on the axes
    Tier 1 grades. Deterministic -- neighbours are visited in sorted order and
    the edge list is sorted.
    """
    if seed not in graph:
        return []
    seen = {seed}
    frontier = [(seed, 0)]
    reasons: list[Reason] = []
    while frontier:
        node, hops = frontier.pop(0)
        for neighbour, edges in sorted(graph[node].items()):
            if neighbour in seen:
                continue
            seen.add(neighbour)
            reasons.append(Reason(hops + 1, neighbour, node, tuple(sorted(edges))))
            frontier.append((neighbour, hops + 1))
    return reasons


# ── what a run withholds ─────────────────────────────────────────────────────

REPORT_PREAMBLE = """\
# Withheld from this run

What the sanitised authoring workspace did **not** contain, and why. Section 6 of
`docs/rules-pipeline-review-findings.md` requires it: without this list a later
reader of a calibration or stability number cannot tell "this rule had no authored
neighbour" from "the graph missed the neighbour it had", and a measurement whose
controls are unstated is not a measurement.

Each graded rule's own authored file is withheld, as it always was. Beyond that,
the run withholds the **transitive closure** of the graded rules over four edges
computed from the corpus itself (`scripts/rules_sync/rule_graph.py`):

- `{excludes}` -- one rule's `excludes` names the other. Walked in both directions.
- `{parameter}` -- both rules override the same `parameterOverride.parameter` path.
- `{axis}` -- a non-reminder effect row of each agrees on every axis Tier 1 grades
  a row's shape by: `type`, `target`, `scope`, `side`. `scope` collides by
  subsumption as well as by equality, which the detail spells out when it applies.
- `{predicate}` -- a non-reminder row of each is gated on the same `when` predicate.

Every edge between a pair is listed, not the first one found: a pair joined by
both `{excludes}` and `{axis}` is a different control from a pair joined by
`{excludes}` alone.

`hops 1` means the edge runs to the graded rule itself; `hops 2` and beyond mean it
runs to a file already withheld for it, named as `via`.

No rule prose here: ids, file names, field names, axis values and edge kinds only.
"""


@dataclass
class Withholding:
    """One run's withheld set, per graded rule, with the edge that pulled each in."""
    graded: list[str]
    reasons: dict[str, list[Reason]] = field(default_factory=dict)
    #: Graded rules whose id matches no authored file. They are still withheld
    #: (there is nothing to withhold), and they have no neighbours by definition.
    unauthored: list[str] = field(default_factory=list)

    @property
    def neighbours(self) -> set[str]:
        """Every file withheld *because of* an edge, across all graded rules."""
        return {r.rule_id for rs in self.reasons.values() for r in rs}

    @property
    def files(self) -> set[str]:
        """Every file stem this run withholds: the graded rules and their closure."""
        return set(self.graded) | self.neighbours

    def render(self) -> str:
        """The run's withholding report, as Markdown."""
        out = [REPORT_PREAMBLE.format(
            excludes=EDGE_EXCLUDES, parameter=EDGE_PARAMETER, axis=EDGE_AXIS,
            predicate=EDGE_PREDICATE)]
        out.append(
            f"**{len(self.files)} authored file(s) withheld** for "
            f"{len(self.graded)} graded rule(s): {len(self.graded)} graded, "
            f"{len(self.neighbours - set(self.graded))} pulled in by the rule graph alone.\n")
        for rule_id in self.graded:
            out.append(f"## {rule_id}\n")
            if rule_id in self.unauthored:
                out.append(
                    f"`specs/rules/{rule_id}.yaml` does not exist in this corpus, so nothing "
                    "was withheld for it and it has no neighbours.\n")
                continue
            out.append(f"- `specs/rules/{rule_id}.yaml` -- the graded rule itself\n")
            rs = self.reasons.get(rule_id, [])
            if not rs:
                out.append(
                    "**No neighbours.** This rule is adjacent to no authored file under any of "
                    "the four edges, so its own file is the whole of what was withheld for it. "
                    "Stated rather than left silent: an empty section here means the graph was "
                    "walked and found nothing, not that it was not walked.\n")
                continue
            out.append(f"Neighbours withheld ({len(rs)}):\n")
            for r in rs:
                via = "the graded rule" if r.via == rule_id else f"`{r.via}`"
                out.append(
                    f"- `specs/rules/{r.rule_id}.yaml` -- {r.summary} "
                    f"(hops {r.hops}, via {via})")
            out.append("")
        return "\n".join(out).rstrip() + "\n"


def withholding(
    graded_ids: Iterable[str],
    rules_dir: Path | str = RULES_DIR,
    corpus: dict[str, dict] | None = None,
) -> Withholding:
    """What a run over `graded_ids` must withhold, and why.

    `corpus` is the seam the synthetic-corpus tests use; production callers pass
    a directory.
    """
    graded: list[str] = list(dict.fromkeys(str(i) for i in graded_ids))
    docs = load_corpus(rules_dir) if corpus is None else corpus
    graph = build_graph(docs)
    return Withholding(
        graded=graded,
        reasons={rid: _closure_for(graph, rid) for rid in graded if rid in docs},
        unauthored=[rid for rid in graded if rid not in docs],
    )


def _cli(argv: Sequence[str] | None = None) -> int:  # pragma: no cover - a convenience
    import argparse

    parser = argparse.ArgumentParser(
        prog="python3 -m scripts.rules_sync.rule_graph",
        description="Print what a run over these rule ids would withhold, and why. "
                    "Reads the corpus; makes no model calls and writes nothing.")
    parser.add_argument("ids", help="Comma-separated rule ids")
    parser.add_argument("--rules-dir", type=Path, default=RULES_DIR)
    args = parser.parse_args(argv)
    print(withholding([i.strip() for i in args.ids.split(",") if i.strip()],
                      rules_dir=args.rules_dir).render())
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(_cli())
