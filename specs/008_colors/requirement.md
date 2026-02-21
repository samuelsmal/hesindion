# Overview

## Attribute Colours

Use the following colors as the primary colour, either in backgrounds or as borders depending on the
location for the attributes:

| Attribute | English version | RGB Colour | Text Colour |
|-|-|-|-|
| MU | courage    | #c54747 | white |
| KL | sagacity   | #a85bd4 | white |
| IN | intuition  | #339b5b | white |
| CH | charisma   | #000000 | white |
| FF | dexterity  | #cac158 | black |
| GE | agility    | #5398bb | white |
| KO | constitution | #ffffff | black |
| KK | strength   | #c28e46 | black |

Colors are sourced from the official DSA game booklets and are **fixed** — they do not adapt to
dark mode. The Neo-Brutalist black border ensures KO (white) remains visually distinct from the
background.

Apply this in the HeroDetailView.swift view. For now this is only the attributes bar,
but later it will be used in a different modal when we do the dice throws / abilities checks which
are based on the attributes.

## Delivery

Create `iDSACompanion/Theme/AttributeColors.swift` — a `Color` extension with:

- One static property per attribute (e.g. `Color.attrMU`, `Color.attrCH`)
- A lookup helper `Color.attributeBackground(for label: String) -> Color` mapping abbreviation
  strings to background colors, returning `Color.yellow` as fallback for unknown labels
- A matching helper `Color.attributeForeground(for label: String) -> Color` for text color,
  returning `Color.black` as fallback

## Hero Attribute Colours

- Upon loading a character define a primary colour. This colour is fixed but should be used
  throughout the HeroDetailView.
- The Fields, e.g. experience, personalData, ... should colour a colour scheme based on the primary
  colour of the hero. Go from darkest to lightest.
