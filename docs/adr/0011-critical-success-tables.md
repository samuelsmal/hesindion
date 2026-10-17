# ADR-0011: Critical Success Tables — apply the TP, state the rest

## Status

Accepted. Applies [ADR-0005](0005-trefferzonen-offence-defence-asymmetry.md)'s
asymmetry to a second set of optional rules.

## Context

The app already implements the *basic* critical-success rules: a confirmed
critical AT or FK halves the opponent's defence and doubles the damage, a
confirmed critical parry grants a Passierschlag, and a Patzer routes to one of the
four Patzertabellen.

Issue #11 asks for the three **optional** rules from *Aventurisches Kompendium 2*
(p. 100ff) that replace those single outcomes with tables:

| Rule | Replaces |
|---|---|
| Kritische Erfolge beim Angriff | double damage |
| Kritische Erfolge bei Verteidigung im Nahkampf | the Passierschlag |
| Kritischer Erfolg bei Verteidigung im Fernkampf | "the next defence does not drop by 3" |

Each is a 2W6 table of eleven categories, and each nests a further **Fokusregel**
that refines the category with a 1W20 — 33 sub-tables in all. The results are a
mix of three kinds of thing:

1. arithmetic on the damage the app is already computing (+2 TP, ×1½, ×2, ×3),
2. conditions on the **opponent** (Betäubung, Schmerz, Blutend, Bewusstlos, a
   Körperbeherrschung check against falling), and
3. modifiers on the **hero** that last "bis zum Ende der nächsten KR" (+2 AT,
   +3 VW, a Vorteilhafte Position, "the opponent may use no manoeuvres").

Kind 2 has nothing to be applied to: opponents are not modelled (ADR-0005). Kind 3
could be applied, but there is no temporary-modifier store in the combat session —
`ModifierEngine` builds its lines fresh from hero state on every screen, and
nothing in `Hero`'s session block expires at the end of a round.

## Decision

**Apply the TP; state everything else.** `CriticalDamage` — `.unchanged`,
`.bonus(Int)`, `.oneAndAHalf`, `.double`, `.triple` — replaces the
`isDoubleDamage: Bool` that `CombatStep.opponentDefense` used to carry, and flows
into the same total the damage screen already prints. The rest of each result is
rendered as the published German sentence, for the GM to adjudicate.

`.double` is what the basic rule was, so the boolean it replaces was this type all
along with three of its five cases missing.

**The table is offered, not imposed.** The rule's own wording is permissive —
"*kann auch* diese Tabelle benutzt werden" — so a confirmed critical with the
Fokus-Regel on asks which way to resolve it: the basic rule, or the table. This is
the shape `CombatFumbleChoiceView` has had all along, where a Patzer offers 1W6+2
SP *or* the Patzertabelle, and the reason is the same: on a bad roll the table is
worse than the rule it replaces, and choosing to take that risk is the player's,
at the moment it happens. A per-hero setting made weeks ago cannot make it.

**One Fokus-Regel per table, plus one for the Fokusregel.** Four new `FokusRule`
cases. The rule wiki treats the three tables as three independent optional rules
and a group may well want criticals on the attack without the defensive ones, so
collapsing them into a single switch would misreport what the table plays with.
The fourth (`kritischeErfolgeDetail`) turns on the 1W20 step for whichever tables
are active; on its own it does nothing, which its subtitle says.

**The rules text is quoted in German, verbatim, uncorrected.** `FumbleTable` set
this precedent and it holds for the same reason: a GM checking the book has to
find the same words. The published sub-tables say "der Held" in several places
where the effect plainly lands on the target, and the ranged table titles one
category "Gute Angriffsposition" in the 2W6 column and "Gute Angriffssituation"
in the Fokusregel heading. Both are transcribed as printed with a comment saying
so, so a future reader does not "fix" them.

**The Passierschlag is a flag, not a number.** Six of the melee table's eleven
results hand the hero an immediate Passierschlag, most with a modifier attached ("um 2
erschwert", "+3 TP bei Gelingen", and one that grants two strikes). Only whether
the strike is granted is modelled; the numbers stay in the quoted text and are
dialled into the Passierschlag screen's own Mod stepper, which is where every
other modifier in this app is entered.

**The screen asks which defence it was.** The app knows the hero parried; it does
not know whether the incoming attack was melee or ranged, and the two defensive
tables differ on exactly that. `CombatStep.criticalSuccess(table: nil, …)` means
"ask", and the screen only does so when both defensive rules are on — a table
that plays with one of them gets no question.

## Consequences

- **A low roll is worse than the rule it replaced, on purpose.** Melee results 2–6
  grant no Passierschlag at all, and attack results 10–11 leave the damage alone.
  That is why the choice above exists, and why the screen also states what the
  basic rule would have done once the table has settled — so the player can see
  the trade rather than wonder where their free strike went. Two things follow
  and are pinned by `CriticalSuccessFlowTests`: the execution screen must *not*
  offer the Passierschlag beside the table (that choice now belongs to the next
  screen), and `showNeueAktion` must not let the player leave before resolving.
- **"Nochmal würfeln" is `effect == nil`.** Twenty-two of the 33 sub-tables end in
  a reroll band. Modelling it as absence rather than as a sentence keeps the view
  from printing an empty box, and the reroll button comes back rather than the
  screen settling on nothing.
- **The published `Schwerer betäubender Treffer` table has a hole**: it jumps from
  13-14 to 19-20, leaving 15-18 unassigned. Filled with a reroll, which is what
  its neighbour does and the only reading that leaves every 1W20 resolvable.
  `CriticalSuccessTableTests` asserts all 33 tables tile 1...20, which is how the
  hole was found and how the next one would be.
- **Every settled roll in the app now goes through `DiceRoller`; every animation
  frame deliberately does not.** This is the rule the codebase was missing, and
  the split matters in both directions:

  - A *settled* roll on `Int.random` cannot be reached by `ScriptedDice`, so its
    edge case can only be rolled for and hoped at. That was true of the AT roll
    and its confirmation, the FK roll and its confirmation, every damage roll, the
    Schip "W6 wiederholen" and "Neuer Wurf" rerolls, the initiative W6, the
    Passierschlag's AT, the command palette's die, and the fumble table's 2W6 —
    which is why `test03ReminderCard` retries its attack up to five times.
  - An *animation* frame on `DiceRoller` is worse: it drains the queue.
    `SkillCheckModal.startAnimation` drew all three tumbling dice from
    `DiceRoller` in a loop, emptying a `dice_script` long before `roll()` reached
    it. Every talent, spell, liturgy and Reiten check funnels through that modal,
    so **no** skill check in the app could be driven to its Kritischer Erfolg or
    Patzer. Its Schip reroll had the opposite fault, on `Int.random`.

  Both are fixed everywhere, which is what makes "the edge case is reachable from
  every dice check" true rather than true of the attack only. `WeatherGenerator`'s
  1W20 is left alone: it generates a world, it is not a check, and it already has
  an injectable generator for its tests.
- **The Passierschlag has no criticals, by rule** — "AT –4, keine Manöver, keine
  Kritischen Erfolge/Patzer" (Regelwerk p237), which `CombatPassierschlagView`
  already stated in a comment and in its own info box. It is the one d20 in combat
  that correctly does not reach a table, and its settled roll was still routed
  through `DiceRoller` so its hit/miss branch can be chosen by a test.
- **Taking the basic rule is logged as such.** `criticalTableResult` records
  either the category (with its 1W20 where one was rolled) or the basic rule's
  name, so the log says which way the critical went rather than only that one
  happened.
- **`CombatActionPayload` gained `criticalTableResult`.** Optional, so payloads
  written before it existed still decode, and separate from `fumbleTableResult`
  rather than reusing a field whose name says fumble.
- **`Color.dsaCritical`** replaces `0x00c853` written out longhand in three combat
  files, and `Color.dsaPositive` — which already existed — replaces six surviving
  copies of `0x2E7D32` beside them. The critical outcome bar's
  `.font(.system(…, weight: .bold))` became `.dsaHeading`, `weight: .bold` being
  `DSAType.heading` exactly; it was the last text in the app the type scale did
  not govern.
- **Hero-side buffs remain unmodelled.** If a temporary-modifier store with
  round expiry ever lands, kind 3 above becomes applicable and this decision
  should be revisited. Until then the durations are printed and the player tracks
  them, as they would at a table without an app.
