# ADR-0020: A creature is a subject of its own

## Status

Accepted, 2026-10-01.

## Context

A mount in pain (issue #48) lowers its GS, AT and VW, and at Schmerz IV it cannot act. The rules
engine had no way to say so. Every Zustand in the catalog (`COND_6` and the others) is the hero's:
its levels, its effects and its Handlungsunfähig status all read the hero's situation. COND_6's
`SZ3` (the Schmerz thresholds as fractions of LE) is the hero's too, while a creature carries its
own thresholds in its Bestiarium entry. Until now the app kept the mount's GS and the Sturmangriff
bonus in Swift (`Hero.mountGS`), and no Schmerz Stufe was ever computed for the mount.

## Decision

A creature is evaluated as a subject of its own, with the same rules the hero is evaluated by.

- `CreatureSheet` (`Packages/RulesEngine`) is the creature's `HeroSheet`: the owned rules (the breed
  rule, the animal advantages that have a rule file), the base values from the companion build and
  the current LE.
- `Situation(creature:)` states those, plus the sheet fact `subject`, and `COND_6` then applies to
  the creature without change. `SZ3` only applies to the hero (`subject` is the hero); the breed
  rule (`svellttaler-kaltblut.SK10`, `elenviner-vollblut.EV10`) supplies the creature's thresholds,
  scaled to its LE, and `zaehes-tier` shifts the Stufe by one.
- `Engine.mountFacts(in:)` evaluates the mount's situation and states three facts in the hero's
  situation, owner `derived`: `mount.gs`, `mount.schmerz` (the Stufe the mount has, before Zähes
  Tier) and `mount.handlungsunfaehig`. RK14 (Sturmangriff zu Pferd) reads the current GS from them.
  The breakdowns stay with `MountFacts`/`MountValues` (a `Fact` holds none): the companion sheet's GS, VW and status buttons open them, and the combat root's Schmerz line opens the Stufe's breakdown (issue #51). The Sturmangriff TP line has no tap.
- The app side is `PetSheetMapping` (the only code that knows `Pet` and `CreatureSheet`) and
  `MountValues`.

## Alternatives

- **B: `mount.`-prefixed copies of COND_6.** Every effect would exist twice, and the engine and the
  compiler would need prefix special cases. Rejected.
- **C: the app computes the Stufe.** The thresholds would stay outside the rules, and no breakdown
  could show them. Rejected.

## Consequences

- A companion or an opponent can be a subject the same way: build a `CreatureSheet`, evaluate it,
  state the facts that matter in the other situation.
- In a creature's situation `hero.levelOf.*` reads the subject's Stufe. The names do not change.
- A mount without a breed rule has no thresholds. The engine does not ask about it; its Stufe is 0
  (`SZ3` is the hero's), `MountValues.hasBreedRule` is false, and the app shows the rule as not
  applied ("Schwellen unbekannt"), as ADR-0018 asks.
- Each further creature rule (another breed, another animal advantage) is a rule file in
  `specs/rules/creatures/` and needs no Swift.
