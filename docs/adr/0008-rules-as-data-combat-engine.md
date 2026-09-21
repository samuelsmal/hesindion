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
  states a number for the GM, as `CombatManeuver.infoText()` already does for Finte ("Gegner PA −4")
  — so it does not reverse ADR-0005. Without it, the tiered numbers of a Basismanöver exist in
  neither the effects data nor the i18n fallback.
- `dice` carries **`recipient`**, because Schildspalter's damage lands on the defender's shield.

`actionEconomy` has **`forbids`** as well as `grants`: *"keine Verteidigung in dieser KR"* is a
removal, and encoding it as a grant reads backwards.

**Conditions are a closed predicate set, not a string.** The combat corpus needs exactly ten:
`combatTechnique(in:)` (34 rules), `targetState(_)` (23), `mounted` (20), `targetSize(≤)` (16),
`attribute(_, ≥)` (16), `runUp(≥)` (13), `weaponReach(_)` (6), `defenseCount(≥)` (4),
`armorAtMost(_)` (3), `offHandWeapon` (1). Six already exist as `ModifierContext` fields. No
expression language, no interpreter: a novel condition costs an enum case and is greppable.

An eleventh predicate, **`gmFlag(<slug>)`**, carries the conditions no mechanical predicate can
express — *"at known location"*, *"ambush detection"*, *"principles violated"*. It takes a
constrained camelCase slug, never prose, and the engine surfaces it as a GM toggle rather than
applying it, the way `ModifierContext.targetIsSurprised` already works under ADR-0005. Without it,
conditional bonuses silently become unconditional, which is worse than not modelling them: `SA_22`
would grant its +1 everywhere rather than at a known location.

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
edges in the data for the named exceptions (*Sturmangriff kann nicht mit Finte kombiniert werden*,
*Riposte kann nicht mit einem Basismanöver kombiniert werden*). The current single-select picker is
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
  `effect.condition`, so `SA_43`'s "BE −1 *while mounted*" would apply as −1 on AT/PA/AW, on foot,
  permanently. Fixing it is part of this decision, not an alternative to it.
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

<https://dsa.ulisses-regelwiki.de/Reiterkampf.html> is one chapter page, and the app hardcodes two
of its mechanics: `Hesindion/Engine/SharedModifiers.swift`'s mounted BE relief and
`Hesindion/Engine/DefenseModifiers.swift`'s `mountedDodgePenalty`. Both bind any mounted hero, with
or without `SA_43`. They are exactly the kind of literal this ADR says should be data, and nothing
in the corpus could hold them, because an authored file needed an Optolith id and a chapter page has
none. The near-miss: `SA_43`'s file recorded the BE clause as non-existent — the clause is on that
page, and the Swift had implemented it all along.

**The corpus therefore covers chapter rules as well as abilities**, under the `CHAP_` id namespace
ADR-0007's amendment defines. Nothing about the effect union, the predicate set or the parameter
vocabulary changes: `CHAP_Reiterkampf` encodes its two constants as ordinary `modifier` rows gated
on the `mounted` predicate this ADR already lists, and its remaining clauses are `reminder` rows
with `UNENCODED:` notes.

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
- `CHAP_Reiterkampf`'s BE row is `scope: combat`, matching the clause, while
  `SharedModifiers.encumbrance` applies the same relief in `spellCasting` and `liturgyCasting`. That
  divergence is recorded in the authored file's note and in `CHANGELOG.md` as an open question; it
  is not settled here, and no Swift was changed. It is the same unresolved seam as this ADR's last
  consequence about `CheckDomain` having no domain for INI or GS — a mounted Zauberprobe is where
  `scope` and `CheckDomain` disagree in the other direction.

## Related

- **ADR-0005** — why opponent-side effects are GM-adjudicated; reaffirmed here.
- **ADR-0007** — where rule data comes from and how it is kept true to the rule website.
