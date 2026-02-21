# Overview of spec 006_combat-mode

- This command is called `Combat`, or `Kampf` in German
- The long-press trigger is on any Weapon or Shield element.
- It will open a new view

# Wireframe


   ┌────────────────────────────       Back button
   │
   │
   ▼
 ┌────────────────────┐
 │ ◄                  │
 │                    │
 │ ┌───────────────┐  │
 │ │LP      13 / 30│  │  ◄───────  LifeEnergy Progress Bar
 │ └───────────────┘  │
 │ ─────────────────  │
 │ ┌───────────────┐  │
 │ │ Actions       │  │
 │ └───────────────┘  │
 │  ┌─────────────┐   │
 │  │   Angriff   │   │  ◄───────  Trigger attack
 │  └─────────────┘   │
 │  ┌─────────────┐   │
 │  │   Parieren  │   │  ◄───────  Trigger Parieren
 │  └─────────────┘   │
 │  ┌─────────────┐   │
 │  │  Ausweichen │   │  ◄───────  Trigger Ausweichen
 │  └─────────────┘   │
 │                    │
 │                    │
 └────────────────────┘


## Trigger: Attack

- Is a flow of two modals
    1. Selection of attack and weapon
    2. Execution of attack


### Selection of attack and weapon

 ┌────────────────┐
 │                │
 │   Angriff      │
 │                │
 │ ────────────── │
 │                │
 │ Rabenschnabel  │  <- List all weapons and shields
 │                │
 │ Langschwert    │
 │                │
 │ Großschild     │
 │                │
 │ Raufen         │ <- Means attack without a weapon
 │                │
 └────────────────┘

- Tapping on an item selects it.

### Execution of the attack



   ┌────────────────┐
   │                │
   │  Angriff       │
   │  Rabenschnabel │
   │ ────────────── │
   │      ┌──┐      │
   │      │AT│      │
   │      │  │      │◄───────    Weapon AT value
   │      │14│      │
   │      └──┘      │
   │      ┌──┐      │
   │    ▲ │ 3│ ▼    │◄───────    Modificator
   │      └──┘      │
   │      ┌──┐      │
   │      │11│      │◄───────    Dice throw
   │      └──┘      │
   │      ┌──┐      │
   │      │11│      │◄───────    Result
   │      └──┘      │
   │                │
   └────────────────┘


- The dice thow is a single 20d, use the same animation as before
    - The user can trigger the throw by pressing on the button
- The modificator can be positive or negative


## LifeEnergryValue Progress bar

- The progress bar's background and font colour shall change with the following LifeEnergyValue.current to LifeEnergyValue.max match:
- The LP stands for `Lebenspunkte` which is the German display text.
- The progress bar shall be displayed as a real progress bar, meaning two layers of backgrounds
    - The one in the back is white
    - The one in front is determined by the "Progress Bar Colours" section below.

### Progress Bar Colours


| predicate | background | text colour |
|-|-|- |
| current == 0 | black | white |
| current <= 5 | dark red | white |
| current < 1 / 4 * max | light red | white |
| current < 1 / 2 * max | orange | white |
| current < 3 / 4 * max | yellow | white |

The colours shall just be an indicator and be replaced with real RGB values.
