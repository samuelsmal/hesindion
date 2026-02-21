# Overview of Spec 005 Talent Probes

Extend the commands and long-pressing on a given talent to trigger a talent-check command.

Use the below talent check attribute map. Store it as a fixed lookup table. It should come with the
application.

1. If triggered the check shall first lookup what attributes are being checked
2. Then it shall lookup what the corresponding values are of the given hero.
   - Attribute keys in the map (e.g. `"IN"`) are display names; use a lookup table to map them to
     the corresponding Swift property on `Attributes` (e.g. `"IN"` → `inValue`).
3. Then it shall lookup what the talent value is of the given hero and given talent.
4. Then it shall roll a 20-faced dice (integer values ranging from 1-20, inclusive, canonically
   referred to as a d20) for each attribute.
    1. Each dice must be below or equal to the corresponding attribute value (plus modifier) to pass.
    2. If a dice is above the corresponding attribute value (plus modifier), the hero needs to reduce
       the talent value by spending the excess (dice − (attribute + modifier)).
5. Before calculating QS, check for critical outcomes based on the dice results:
   - If **two or more dice show 1**, the result is a **Kritischer Patzer** (catastrophic failure).
     Skip the normal calculation view and show only the Kritischer Patzer result.
   - If **two or more dice show 20**, the result is a **Kritischer Erfolg** (catastrophic success).
     Skip the normal calculation view and show only the Kritischer Erfolg result.
   - Critical outcomes take precedence over the normal QS calculation.
   Otherwise, if the accumulated spending exceeds the talent value the result is QS 0, an automatic
   failure. Otherwise the remaining talent value is divided by three and rounded up, giving the QS
   (Qualitätsstufe, range QS 1–6).
6. The modificators can be applied to the attributes individually.
    1. They can be defined in the modal, by long-pressing on each individual modificator, which
       shall trigger a new modal which will allow the users to increase or decrease the modificator.
       Modifiers support negative values (e.g. to represent penalties). Default is 0.
    2. The second way to determined the modificator is by looking at the hero state. A hero can be
       overloaded, or hurt, which has an impact on the check. This state is part of a different
       requirement and will be specified separately.
7. The dice roll shall be triggered through a user tapping on the row of the dices. Prior to that
   show random numbers in the given range of a d20, show a new number every 0.2 seconds. Use a
   separate random call for each attribute check.
   1. Display then the overall result and QS.

# Result Colours

Use background and font colour on the result row / critical outcome banner to communicate the outcome:

| Result               | Background    | Text  |
|----------------------|--------------|-------|
| Kritischer Patzer    | Red          | White |
| QS 0 (failure)       | Black        | White |
| QS 1                 | Dark green   | White |
| QS 2                 | Green        | White |
| QS 3                 | Medium green | White |
| QS 4                 | Bright green | Black |
| QS 5                 | Light green  | Black |
| QS 6                 | Yellow-green | Black |
| Kritischer Erfolg    | Vibrant green | White |

Adjust exact shades so text is always legible. QS 6 is the maximum normal result.
Kritischer Erfolg uses a more saturated / vivid green than QS 6 to visually stand apart.

# Modal Architecture

- Implement a new `TalentProbeModal` view in its own file
  (`iDSACompanion/Views/TalentProbeModal.swift`).
- The modal is opened by:
  - Selecting "Probe: \<TalentName\>" from the command palette, **or**
  - Long-pressing directly on a talent row in `HeroDetailView`.
- The check is **purely informational** — it does not mutate any hero or talent data.
- The user cannot re-roll after the dice are revealed.
- The modal is dismissed by swiping up anywhere on it (same pattern as existing modals).

# Talent Check Wireframe

 ┌──────────────────────────┐
 │    ┌────────────────┐    │
 │    │Fliegen        7│    │◄───────    Talent to check, and talent value of hero
 │    └────────────────┘    │
 │    ┌────┐┌────┐┌────┐    │
 │    │ MU ││ IN ││ GE │    │
 │    │    ││    ││    │    │◄───────    Attributes from Hero (correct per JSON map)
 │    │ 13 ││ 11 ││  3 │    │
 │    └────┘└────┘└────┘    │
 │    ┌────┐┌────┐┌────┐    │
 │    │ +1 ││ +1 ││ +1 │    │◄───────    Modificators (default 0, illustration uses +1)
 │    └────┘└────┘└────┘    │            Long-press to change; supports negative values
 │    ┌────┐┌────┐┌────┐    │
 │    │ 3  ││ 15 ││  3 │    │◄───────    Dice throws for each attribute (tap row to roll)
 │    └────┘└────┘└────┘    │
 │    ┌────┐┌────┐┌────┐    │
 │    │ 0  ││  -3││  0 │    │◄───────    Results for each attribute
 │    └────┘└────┘└────┘    │
 │┌────────────────────────┐│
 ││7 - 0 + -3 + 0 = 4 → QS2││◄───────    Overall result and QS (coloured per QS table)
 │└────────────────────────┘│
 └──────────────────────────┘

Example calculation (Fliegen checks MU/IN/GE per JSON map):
- Effective attributes after +1 modifiers: MU=14, IN=12, GE=4
- Dice: 3 ≤ 14 → spend 0; 15 > 12 → spend 3; 3 ≤ 4 → spend 0
- Remaining talent: 7 − 3 = 4 → QS ceil(4/3) = 2

# Talent Check Attribute Map

Can be found under `talent_probe_attributes.json`
