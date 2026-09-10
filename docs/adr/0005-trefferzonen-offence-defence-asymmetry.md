# ADR-0005: Trefferzonen Apply on Defence Only

## Status

Accepted

## Context

The DSA 5 Fokus-Trefferzonenregeln are symmetric on paper: any combatant who takes damage at or above
their Wundschwelle suffers a zone-specific wound effect — Betäubung from a head hit, Liegend from a
leg hit, extra damage from a torso hit — resisted by a Selbstbeherrschung check.

Hesindion is not symmetric. It models exactly one combatant: the hero. Opponents have no LP, no KO,
no Wundschwelle and no states; the whole combat flow is written from the hero's point of view, with
the GM adjudicating the other side at the table. There is nothing for a wound effect to be applied
*to* when the hero is the attacker.

## Decision

Implement the rules asymmetrically, and be explicit that this is the design rather than an omission.

**Offence** (hero attacking): the announced zone feeds a `ModifierLine` into the existing
`ModifierEngine` via `HitZoneModifiers`, so the Zonenaufschlag affects the attack roll like any other
modifier. After a landed hit, a read-only card states that zone's wound effect for the GM. Nothing is
computed or applied.

**Defence** (hero taking damage): the zone is rolled or tapped, the damage is compared against the
hero's Wundschwelle, a Selbstbeherrschung check can avert the effect, and on failure the effect is
applied for real through `Hero.setStateLevel(_:level:)`.

The one rule that reads opponent state — the Zonenaufschlag is eased by 2 against a *surprised*
target — is a GM-driven flag on `ModifierContext`, deliberately **not** wired to the `ueberrascht`
entry in `StateCatalog`. That entry describes the hero; the rule is about the opponent.

## Considered Alternatives

- **Model opponents.** A lightweight opponent with KO, LP and states would make wound effects
  symmetric and is the "correct" reading of the rules. Rejected for now: it is a new persisted model
  plus its own UI, far larger than these rules, and it changes what the app *is* — a hero companion,
  not a full encounter tracker. If an opponent model ever arrives, the offence side gains real
  application and the reminder card becomes redundant; the rules model (`HitZone`, `HitZoneTable`,
  `WoundEffectCatalog`, `WoundEffectResolver`) already has no hero assumptions baked in and would
  serve both sides unchanged.
- **Skip the offence side entirely** and ship only defence. Rejected: the Zonenaufschlag is the part
  players interact with most — announcing a called shot is the decision that costs them something.

## Consequences

- The feature is honest about what it knows. The offence card presents as a GM prompt with no
  buttons, so it cannot be mistaken for a pending action.
- The pure rules types carry no hero dependency, so adding an opponent model later is additive.
- The asymmetry must be re-explained whenever someone reads the offence side and asks why the wound
  effect is not applied. This ADR is that explanation.
- `targetIsSurprised` looks like it should read hero state and does not. The field carries a comment
  saying so, because it is exactly the kind of thing a future contributor would "fix".
