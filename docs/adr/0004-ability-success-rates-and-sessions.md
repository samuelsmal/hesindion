# ADR-0004: Ability success rates and play-session grouping

## Status

Accepted

## Context

Players wanted to judge their characters' abilities at a glance and to see how
real rolls have played out — both overall and per game night. Two questions had to
be answered:

1. **What is the theoretical chance** an ability check succeeds, given the hero's
   attributes and skill points?
2. **What actually happened** — the recorded success rate, grouped into play
   sessions.

For (1), the DSA 5 check has no simple closed form (FP compensation across three
dice plus critical overrides), but the sample space is tiny (20³ = 8000).

For (2), the action log already stores every talent check
(`TalentCheckPayload { talentName, qualityLevel, succeeded }` + `timestamp`), so no
schema change was needed. We only needed a rule for what constitutes a "session".

## Decision

- **Theoretical rate** = exact enumeration of all 8000 equally-likely 3d20 outcomes
  through `SkillCheckEngine.evaluate` (`SkillCheckEngine.successProbability`). The
  rate shown on a row uses the **base** attributes + FP, with **no situational
  modifier**, since modifiers vary per roll. Results are memoized per (attributes,
  FP) so rendering a full talent list doesn't re-enumerate.
- **Session** = a maximal run of log entries where consecutive entries are less than
  **8 hours** apart; a gap of ≥ 8h starts a new session (`SessionGrouper`,
  `defaultGap = 8h`). 8h cleanly separates real-life game nights while tolerating
  in-session breaks.
- **Recorded stats** (`TalentStatistics`) operate on a lightweight `Check` value
  (name, succeeded, date) decoded from the log, keeping the aggregation pure and
  unit-testable without SwiftData.

## Consequences

- Talent rows show a traffic-light dot + % (theoretical) inline at all times. The
  recorded stats (overall %, Proben count, session count, best session) are hidden by
  default and revealed under every row at once by the Talents section's
  "Aufgezeichnete Werte" toggle — keeping the default view uncluttered rather than
  inlining aggregations on every row.
- The Log panel gains per-session header rows (date · success rate · count).
- The 8h threshold is a heuristic; if it misclassifies long sessions or back-to-back
  nights it can be tuned in one place (`SessionGrouper.defaultGap`).
- The theoretical rate ignores permanent penalties (e.g. Belastung); if that proves
  confusing, the modifier argument is already threaded through `successProbability`.
