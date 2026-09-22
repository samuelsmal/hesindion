# ADR-0008: Rules as Data — the Combat Rule Engine

## Status

Accepted — amended 2026-09-21 (see *Amendment* below)

## Context

A hero with the Sonderfertigkeit *Sturmangriff* (`SA_62`) cannot use it, and would get the wrong
damage if they could. Investigating why showed the cause is structural, not a missed case:

- **The data-driven path is dead code.** `Hesindion/Engine/RuleEffectModifiers.swift` — the only
  code that turns database effects into modifiers — has no callers. `ModifierEngine.shared` is a
  static list of hand-written Swift definitions, and the `effects` table reaches the app only
  through `RuleDetail`, i.e. for *display* in the rule browser. No combat number comes from data.
- **The import classification is circular.** `OptolithImportService.isCombatSpecialAbility(id:)`
  answers "is this a combat ability?" with "does it already have a hand-written combat effect?".
  Nine rules qualify. Every other combat SF is filed under `generalSpecialAbilities`, where no
  combat code looks — so `SA_62` would not work even if a `hasSturmangriff` check were added.
  This already misfires in shipped features: `SA_884` (Plänkler-Formation) and `SA_160`/`SA_161`
  (Gezielter Angriff/Schuss, the Trefferzonen halving) can never be true from a real import. Tests
  miss it because they assign `combatSpecialAbilities` directly.
- **One mechanism is expressible, and there are ten.** A census of all 232 combat special abilities
  (`group_id IN (3, 9, 10, 11, 12)`) by what their rule text asks for: 90 have opponent-side
  outcomes, 73 are flat modifiers on the hero's own check, 50 call for a probe, 40 inflict a
  Zustand, 33 add a **die** rather than a number, 33 carry preconditions, 29 touch action economy,
  27 **override an existing constant**, 18 scale per Stufe, 9 grant legality. `ModifierDefinition`
  is `(ModifierContext) -> ModifierLine?` folded into an `Int`: it covers the 73 and nothing else.
- **The constants those 27 abilities rewrite are Swift literals** — `-(defenseCount * 3)` in
  `DefenseModifiers`, the reach matrix in `CombatManeuver`, the zone penalties in
  `HitZoneModifiers`, the dual-wield base in `Hero`.
- **Maneuvers are a closed Swift enum.** `CombatManeuver` has six cases and
  `CombatAttackViews.availableManeuvers` is a hand-maintained list — the line that forgot
  Sturmangriff.

The data vocabulary was never the problem: `rules.yaml` already declares ten effect types
(`modifier`, `damageModifier`, `opponentModifier`, `restriction`, `stateGain`, `negation`,
`damageRedirect`, `narrative`, `recovery`, `incapacitated`). The engine grew a handler for one.

## Decision

**Rules are data. Adding an ability is authoring, not programming.** A new special ability that uses
an existing mechanism costs one authored file (ADR-0007) and a database rebuild. No Swift.

**The engine returns a result, not a number.** `resolve(context) -> EngineResult`, carrying
`lines` (the existing `ModifierLine` breakdown), `dice`, `parameters`, `restrictions`, `probes` and
`reminders`. Resolution order is `parameters → overrides → modifiers → Zustand cap → outputs`; the
−5 Zustand cap runs after modifiers and never sees parameter overrides.

**Effects are a closed typed union** of nine cases — `modifier`, `parameterOverride`, `dice`,
`actionEconomy`, `probe`, `legality`, `stateGain`, `recovery`, `reminder`. Closed, so an unhandled
case is a compile error rather than a silent no-op.

Three qualifiers carry information the union would otherwise lose, all established by checking the
schema against the 79 existing effect rows before any rule was authored:

- `modifier` carries **`target`** (which check: at/pa/aw/fk/ini/gs/be/le/talent/all) and **`scope`**.
  Dropping these is the precise defect this ADR rejects its first alternative for; a union that
  cannot say *which* value a modifier moves reproduces it.
- `modifier` carries **`side: hero | opponent`**. An opponent-side modifier is display-only — it
  states a number for the GM, the way `CombatManeuver.infoText()` already renders a maneuver's
  opponent-side line — so it does not reverse ADR-0005. Without it, the tiered numbers of a
  Basismanöver exist in neither the effects data nor the i18n fallback.
- `dice` carries **`recipient`**, because a die a rule adds does not always land on the target: a
  clause can direct it at a piece of the opponent's equipment instead, and the union has no other
  way to say where the damage goes.

`actionEconomy` has **`forbids`** as well as `grants`: a clause that *takes away* a defence or an
action for the round is a removal, and encoding it as a grant reads backwards.

**Conditions are a closed predicate set, not a string.** The combat corpus needs exactly ten:
`combatTechnique(in:)` (34 rules), `targetState(_)` (23), `mounted` (20), `targetSize(≤)` (16),
`attribute(_, ≥)` (16), `runUp(≥)` (13), `weaponReach(_)` (6), `defenseCount(≥)` (4),
`armorAtMost(_)` (3), `offHandWeapon` (1). Six already exist as `ModifierContext` fields. No
expression language, no interpreter: a novel condition costs an enum case and is greppable.

An eleventh predicate, **`gmFlag(<slug>)`**, carries the conditions no mechanical predicate can
express — the circumstances that are the GM's to rule on rather than the app's to evaluate, of which
the corpus already holds several and `specs/rules/vocabulary.yaml` registers each one by one. It
takes a constrained camelCase slug, never prose, and the engine surfaces it as a GM toggle rather
than applying it, the way `ModifierContext.targetIsSurprised` already works under ADR-0005. Without
it, a bonus a page grants only in a stated situation silently becomes unconditional, which is worse
than not modelling it at all: the rule fires on every check and the breakdown gives no sign that it
should not have.

**DSA constants become named parameters** (`defense.multiplePenaltyPerStep`, `dualWield.penalty`,
`reach.matrix`, `zone.*`, `passierschlag.penalty`, …) that abilities override with an explicit
operation — `set`, `shiftSteps`, `scale`. Meisterparade becomes
`set defense.multiplePenaltyPerStep = -2`, Unterlaufen `shiftSteps reach.matrix by tier`, Gezielter
Angriff `scale zone.* by 0.5`. Errata and house rules then change a value, not a code path. The
per-hero Fokus-Regeln (`FokusRule`) are re-expressed as parameter override sets, so optional rules
and abilities share one mechanism.

**Stacking.** Effects from different abilities stack — a hero may combine a Basismanöver, one active
Spezialmanöver and any number of passive abilities in a Kampfrunde, and all of their effects apply.
The single exception is two `set` overrides of the *same* parameter: Meisterparade (−3 → −2) and
Machtvolle Meisterparade (−3 → −1) each rewrite the same constant from the same base, so the
strongest applies rather than accumulating. Any other exception must be stated in the data.

**Maneuver selection is slotted, and the slots come from the data.** `rules.subgroup_id` already
classifies every combat SF as `1 = Passiv`, `2 = Basismanöver`, `3 = Spezialmanöver` — subgroup 2 is
exactly Finte, Präziser Schuss/Wurf, Präziser Stich, Wuchtschlag, Unterlaufen. Selection is
therefore one Basismanöver plus one active Spezialmanöver plus the hero's passives, with `excludes`
edges in the data for the exceptions the pages state — some bar one named other maneuver, others bar
the Basismanöver slot as a whole. The current single-select picker is
replaced: it does not merely fail to ban illegal pairs, it forbids legal ones.

**Damage becomes an expression, not a string.** 33 abilities add a die (`+1W6` Todesstoß, `1W3`
Entwaffnen). `MeleeWeapon.damage: String` and the regex in `CombatAttackViews.adjustedDamage()`
cannot carry that, so a `DamageExpression` value type replaces the string through the `CombatStep`
payloads and the views that render them.

**An unmodelled ability degrades to its rule text — never to silence.** Every ability a hero owns
that has no structured effects emits a `reminder` carrying its text from `rules_i18n`, rendered like
the existing `WoundEffectReminderCard`. All 232 are covered from day one. Structured effects are
then authored where the table needs them, and coverage is a visible number rather than a hidden gap.

**Opponent-side effects stay GM-adjudicated, per ADR-0005** — 90 of 232 abilities touch the
opponent, and the opponent is still not modelled. They are promoted from "missing" to a first-class
`reminder` output: the app applies the hero-side AT modifier, shows the damage die, and states the
consequence for the GM.

**Import classification is fixed at the source**: an ability is a combat ability when
`rules.group_id IN (3, 9, 10, 11, 12)`, not when someone has already hand-written an effect for it.

## Considered Alternatives

- **Wire up `RuleEffectModifiers` as written and stop there.** Rejected. It covers the 73 flat
  modifiers and mis-encodes the rest: it drops `effect.attribute` entirely and ignores
  `effect.condition`, so an encumbrance row an authored file gates on `mounted` would apply to a
  hero on foot, permanently, at its full value. Fixing it is part of this decision, not an
  alternative to it.
- **Modifiers and maneuvers as data, everything else in Swift.** Rejected: it leaves the 27
  constant-overriding and 33 dice-adding abilities as per-ability Swift work, which schedules the
  next refactor rather than avoiding it.
- **Model a lightweight opponent** so Entwaffnen, Zu Fall bringen and Betäubungsschlag resolve in
  app. Rejected — reverses ADR-0005 and pulls in NPC defence values, states and initiative that the
  GM already tracks.
- **A general expression language for conditions and formulas.** Rejected as overengineering: ten
  predicates cover the entire combat corpus, and an interpreter would be harder to test than the
  rules it evaluates.
- **Incremental migration behind a flag.** Considered seriously and rejected by the maintainer: two
  engines running side by side is the four-authorities problem of ADR-0007 in a new place.

## Consequences

- Adding an ability with a known mechanism is an authoring change. Adding a genuinely new *mechanism*
  is a new case in the effect union plus one handler — bounded, additive, and rare: the census finds
  ten mechanisms across the whole combat corpus, of which this decision implements eight.
- **A parity harness is a precondition, not a follow-up.** Today's engine output is captured as
  golden files across the nine wired abilities × all `CheckDomain`s before the swap, and asserted
  identical after. A single-pass engine replacement without it is an unverifiable rewrite.
- A coverage test replaces the failure that produced this ADR: for every rule a hero owns, assert
  either structured effects or an explicit reminder. Sturmangriff would have failed it loudly.
- The Flutter port benefits directly. A Swift-hardcoded ruleset has to be rewritten for
  `hesindion_app`; `rules.db` plus this schema is portable, so the rules stop being implemented
  twice.
- Reminder cards will be noisy at first, because most abilities start unstructured. That is the
  intended trade: visible and unmodelled beats invisible.
- `CombatManeuver`, `availableManeuvers`, `adjustedDamage()` and the `CombatStep` damage payloads all
  change. This is the largest single cost and it is in the views, not the engine.
- Rule constants stop being greppable as literals. `defense.multiplePenaltyPerStep` is one
  indirection away from `-3`, which is the price of making errata a data change.
- **`CheckDomain` has no domain for INI or GS.** It covers melee attack/parry/dodge, ranged attack,
  spell and liturgy casting, and talent checks — so no `scope` value can express what Belastung and
  Belastungsgewöhnung actually reach, which is AT/PA/AW *and* INI *and* GS. `scope: combat`
  under-covers and `scope: all` over-covers into spell and liturgy casting. Today this is invisible
  because the data-driven path is dead and `Hero.belastungPenalty` computes it in Swift. The engine
  work must either add the two domains or keep BE as a derived value outside the domain model; it
  cannot be settled by choosing a scope string. Found while migrating `SA_41`, whose two duplicate
  legacy sources disagreed on exactly this.

## Amendment (2026-09-21): "rules are data" includes the rules no ability owns

This ADR's census counts abilities — 232 combat special abilities, 73 flat modifiers, 27 constant
overrides — and its decision is written in terms of them. The constants it wants moved out of Swift
are not all owned by abilities, and the difference was invisible until a ruling went wrong.

<https://dsa.ulisses-regelwiki.de/Reiterkampf.html> is one chapter page, and the app hardcodes
**three** of its mechanics, in three different engine files:
`Hesindion/Engine/SharedModifiers.swift`'s `encumbrance`,
`Hesindion/Engine/DefenseModifiers.swift:47`'s `mountedDodgePenalty`, and
`Hesindion/Engine/MeleeModifiers.swift:14-20`'s `vorteilhaftePosition` (rendered by
`CombatAttackViews.swift:440-482`). What each of the three computes is in the Swift at those
locations and in `specs/rules/CHAP_Reiterkampf.yaml`, which now carries all three as authored rows —
neither restated here. **All three bind anyone in the situation that page describes, ability or
not**, and that is the point: they are exactly the kind of literal this ADR says should be data, and
nothing in the corpus could hold them, because an authored file needed an Optolith id and a chapter
page has none. The near-miss: `SA_43`'s file recorded one of the three as non-existent — the clause
is on that page, and the Swift had implemented it all along.

**The corpus therefore covers chapter rules as well as abilities**, under the `CHAP_` id namespace
ADR-0007's amendment defines. Nothing about the effect union, the predicate set or the parameter
vocabulary changes: the mounted-combat page's constants are encoded with effect types this ADR
already defines and predicates it already lists, and the clauses its grammar cannot express are
`reminder` rows with `UNENCODED:` notes. See `specs/rules/CHAP_Reiterkampf.yaml` for which clause is
which and for every row's fields — not restated here.

This split between encoded rows and reminders was wrong once already, and in the way the amendment
itself warns about. One clause was originally filed as an `UNENCODED:` reminder on the reasoning that
it "reads off the mount, which is not a modelled entity" — true of the clause it had been bundled
with, and false of that one, which turns on the opponent rather than on the mount and so needs
nothing the app does not model. An authored ability rule already encoded a clause of the same shape,
using only predicates this ADR's grammar lists and tokens `vocabulary.yaml` already registers, and
the relationship between the two was recorded in the ability's own note — so the baseline was sitting
unowned on an ability, which is the `SA_43` error repeated on the page that corrects it. Corrected
2026-09-21: the clause is encoded rather than deferred, and the reminder that had absorbed it now
covers only the clause it was written for. Both files carry the details; cite them rather than this
paragraph.

*(Reworded 2026-09-21, Task 11a fix round 1 — third repair round on this pair. The previous version
named the chapter file's row count, effect type and gating predicate, and stated the ability's target
and the class of its gate in English. Since Task 11a the workspace withholds the graph closure, so
both files are withheld together whenever either is graded — and a passage restating one of them
defeats withholding the other exactly as ADR-0008's earlier two repairs did. The convention those
settled: name a clause by its position and mechanism, cite `specs/rules/<id>.yaml` for its contents.)*

*(Amendment opening reworded 2026-09-22, Task 11a fix round 2 — fourth round, and the reason the
third bought less than it looked. The Swift census three paragraphs above glossed each of the three
hardcoded mechanics in English, naming a target for each and a gate class for one. It was deferred
twice as the weaker instance; the arithmetic then changed under it. With the `scope`-subsumption and
`when`-predicate edges, `SA_41`, `SA_43`, `SA_661` and `CHAP_Reiterkampf` are one closure, so a
passage in a copied file that describes those rows is now adjacent to four graded rules rather than
one. The census keeps its case — one page's mechanics hardcoded in three engine files, binding
anyone in the situation, with nowhere in the corpus to put them — by citing the Swift locations and
the authored file instead of saying what each computes.)*

This matters for the scope of the engine rewrite. Authoring all 232 abilities would still have left
the mounted-combat, Beengte-Umgebung and multiple-defence constants in Swift — a rule that fires for
every hero, hidden in a file nobody reviews as rule data, while the corpus reported full coverage.
The coverage ratchet counts abilities; it cannot count what it has no id for.

Consequences:

- The remaining chapter pages the app hardcodes are follow-on work, tracked as Task 12 in
  `docs/plans/2026-09-20-rules-pipeline-and-authoring.md`. They are not authored by this amendment.
- A chapter rule cannot degrade to rule text: there is no `rules_i18n` row for it, because there is
  no Optolith entry. "Never to silence" is held by its own authored `reminder` rows instead, which
  makes those rows load-bearing rather than optional.
- One authored row in `specs/rules/CHAP_Reiterkampf.yaml` and the Swift that implemented the same
  mechanic (`Hesindion/Engine/SharedModifiers.swift`) diverged. The divergence was recorded in the
  authored file's note and in `CHANGELOG.md` as an open question; this amendment did not settle it,
  and no Swift was changed at the time. **Settled 2026-09-21 in the data's favour:** the authored
  row stands as written and the Swift was brought into line with it. Those two files hold what each
  now contains and `CHANGELOG.md` under *Fixed* holds the change; **which field diverged, and which
  way, is not stated here.** The *other* half of the seam stands: this ADR's last consequence about
  `CheckDomain` having no domain for INI or GS is still open, and so is the second, separate row
  that `docs/rules-pipeline-status.md` §8 carries under its own standing ruling.

  *(Mechanical content **removed** 2026-09-22, Task 11a fix round 3 — fourth repair pass on this one
  bullet, after `030230e`, `95b710b` and `fe7e944`, the last of whose subject line is "ADR-0008's
  settled bullet stops restating the row it says it doesn't". Each of those three removed a literal
  and left a paraphrase, and a paraphrase of a row is still the row: until this pass the bullet named
  one of the row's graded fields outright and restated a second in English, in the same sentence as
  its second "not restated here". The bullet's argument — a divergence existed, it was an open
  question, it was settled in the data's favour, the Swift changed — needs neither. The test this
  passage failed three
  times is not "did I remove the value" but **"could a reader reconstruct any part of the row from
  what is left"**, and a fourth paraphrase would have failed it a fourth time. Since Task 11a the
  workspace withholds the graph closure, and `SA_41`, `SA_43`, `SA_661` and `CHAP_Reiterkampf` are
  one closure, so this bullet sat adjacent to four graded rules rather than one.)*

## Amendment (2026-09-21): the fields this decision leaves open are registered, not free

This ADR closes two vocabularies — nine effect types and eleven condition predicates — and says
nothing about the fields it deliberately leaves open. Several are open on purpose:
`actionEconomy.grants` and `forbids`, `legality.action`, the `gmFlag` slug, and
`parameterOverride.parameter`. Closing them to enums was considered and rejected for the reason this
ADR already gives for `dice.add`: they are not finite over 232 rules, and a premature enum makes
every novel ability a schema pull request.

**Open is not the same as unrecorded.** Each open token must be glossed in one line in
`specs/rules/vocabulary.yaml`, and `scripts/rules_lint/lint.py` rejects an unregistered one. A new
token is then a one-line reviewable diff instead of a string nobody has ever read, the whole set of
tokens the engine will have to handle is enumerable before the engine is written, and the registry
becomes the enum later, when the corpus says what its members are. This also closes the *shape* of
those fields — a slug pattern, so a free-text sentence cannot enter through them, which was a Data
Policy hole the closed enums had disguised.

**`parameterOverride.parameter` is the one open field with no registry, and it has already cost a
rule.** It is a free string that nothing validates, so a parameter path that names no DSA constant
lints clean, encodes to a silent no-op, and reads as a confident encoding. A calibration proposal for
`SA_41` invented one — where the authoring brief's `UNENCODED:` escape hatch was the mandated answer
— and both the linter and the author/verifier cross-check passed it. Until it is registered and
linted like the others, **a `parameter` value is a claim nothing checks**, and that is a blocker on
any authoring wave rather than a quality improvement. The named-parameter vocabulary this ADR
introduces is the list it should be checked against.

The general rule this states, for fields added later: a field whose values are not enumerable in
advance is registered and linted, never left free. The failure mode of an unregistered open field is
silent and indistinguishable from success, which is the failure mode this whole ADR exists to remove.

## Note (2026-09-21): a worked example cites its rule file instead of restating it

The Decision and both amendments above were edited on 2026-09-21 to remove the *graded values* of
individual rules: a row spelled out in schema field names, an opponent-side value quoted as a German
display string, a `dice` row's recipient named in English, an encumbrance row's value and gate, the
AT ease a chapter clause grants, and three registered `gmFlag` slugs quoted as the conditions they
stand for. **No decision changed and no argument was dropped** — a qualifier that exists because an
opponent-side number is display-only loses nothing by not naming the rule whose number it was. What
went is only the part from which one rule's encoding could be reconstructed.

The reason is mechanical rather than editorial. `prepare_workspace`
(`scripts/rules_sync/propose.py`) copies every file under `docs/adr/` into the sanitised workspace
the authoring agents run in, and redaction there removes a withheld rule's id and its German ability
name and nothing else. A row stated in field names carries neither token, so it survived intact —
and four of the ten rules the calibration gate grades had their answers sitting in this file. The
gate's own rubric (`tests/rules/test_calibration.py`, `docs/rules-pipeline-status.md` §2) reads a
reproduction of the golden encoding as evidence of contamination rather than success, so the next
run would have scored higher and measured less.

The convention that replaces it is the one the authored `note` fields already follow: **name the
clause by position and mechanism, and cite `specs/rules/<id>.yaml` for its contents** — a citation
that is precedent to a human with the repository and nothing at all to an agent, because the
workspace withholds exactly that file. `tests/rules/test_workspace_leaks.py` fails on a
re-introduction of the shapes it can recognise; its docstring is honest about the ones it cannot.

## Related

- **ADR-0005** — why opponent-side effects are GM-adjudicated; reaffirmed here.
- **ADR-0007** — where rule data comes from and how it is kept true to the rule website.

## Amendment (2026-09-21): stored heroes are migrated by repair, not by re-import

The Decision above fixed `OptolithImportService.isCombatSpecialAbility` to classify by Optolith
group rather than by whether someone had already hand-authored an effect for the rule — "Import
classification is fixed at the source." That statement was true of new imports and silent about
existing ones: `combatSpecialAbilities` and `generalSpecialAbilities` are written once, at import,
and stay whatever they were classified as at the time. A hero imported before this decision keeps
the old split forever unless something touches it again.

The whole-branch review named this (finding 3) and the user ruled: add a reclassification repair
pass rather than requiring re-import. The precedent is `DerivedValueRepair` (ADR-0006), which
exists for the identical shape of problem — a formula fix at import time that does not reach heroes
already in the store — and is run once, idempotently, from `ContentView`'s `.task`. This decision's
own classification fix is the same shape one namespace over: not a derived value but a
classification, so it is a sibling pass, `SpecialAbilityClassificationRepair`, rather than an
addition to `DerivedValueRepair`'s attribute- and species-keyed contract. It re-splits a hero's two
special-ability arrays through the same predicate the import now uses, is idempotent by
construction, and is wired in beside `DerivedValueRepair.repairAll` with the same
save-only-if-changed discipline. See `CHANGELOG.md` under `[Unreleased]` → `Fixed` for what changes
at the table for an existing hero.

## Amendment (2026-09-21): the CheckDomain seam has two rows to reconcile, and wiring the data path in is not an append

The whole-branch review (finding 4) named a live instance of the pattern ADR-0007 exists to
remove, one file apart from where this ADR's own census was taken. `Hesindion/Engine/SharedModifiers.swift`'s
`mountedReliefDomains`, and the case `Hesindion/Engine/RuleEffectModifiers.swift`'s
`domainsForScope` selects for `specs/rules/CHAP_Reiterkampf.yaml`'s mounted-relief row, are two
independent Swift readings of that row's authored `scope` token, and the two readings disagree. It
is invisible today only because `RuleEffectModifiers` still has no callers; both sites now carry a
comment naming the other and saying which one the authored row is implemented by
(`SharedModifiers.swift:18-20`, `RuleEffectModifiers.swift:49-67`).

**The engine plan inherits a double-count hazard, not only a disagreement.** `ModifierEngine.shared`
(`ModifierEngine.swift:124-134`) registers the hand-written `SharedModifiers`/`MeleeModifiers`/
`DefenseModifiers` definitions, which encode the same mechanics as the 109 authored effect rows the
build now loads into `rules.db`. Appending `RuleEffectModifiers.load`'s output to that registry as
written would fire every migrated rule twice. **Wiring the data path in means deleting the
hand-written definition it replaces in the same commit that starts reading its authored row — never
appending to the list.**

**The CheckDomain consequence above names one seam; the branch has since made a second one
concrete** (whole-branch review §3, "Ruling on item 3") — see that consequence, not restated here,
for why no `scope` value can settle it. The mounted relief's own row has since diverged the same
way, in a second place: what `SharedModifiers.encumbrance`'s own `domains` list
(`SharedModifiers.swift:29`) declares and what the case `RuleEffectModifiers.domainsForScope`
(`RuleEffectModifiers.swift:49-67`) selects for the same authored token disagree, exactly as
`mountedReliefDomains` and that case disagree above. **The engine plan therefore has two rows to
reconcile against `CheckDomain`, not one:** the unmounted penalty's row (`specs/rules/SA_41.yaml`,
read through `domainsForScope`) and the mounted relief's row (`specs/rules/CHAP_Reiterkampf.yaml`,
implemented directly in `SharedModifiers.encumbrance`). Neither row's authored scope value, target
or domain count is stated anywhere in this amendment — see the cited files for both. This is not
settled by picking a string for either row; `docs/rules-pipeline-status.md` §8 records why for the
first, and the same reasoning holds for the second.

Do not change `RuleEffectModifiers.domainsForScope` to make the two Swift readings agree — that is a
behaviour change to a dead code path, and it is the engine plan's decision to make once it settles
what `CheckDomain` covers, not this documentation task's.
