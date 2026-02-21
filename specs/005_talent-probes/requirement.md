# Overview

Extend the commands and long-pressing on a given talent to trigger a talent-check command.

Use the below talent check attribute map. Store it as a fixed lookup table. It should come with the
application.

1. If triggered the check shall first lookup what attributes are being checked
2. Then it shall lookup what the corresponding values are of the given hero.
3. Then it shall lookup what the talent value is of the given hero and given talent.
4. Then it shall roll a 20-faced dice (integer values ranging from 1-20, inclusive, canonically
   referred to as a d20) for each attribute.
    1. Each dice must be below or equal to the corresponding attribute value of the hero to pass
    2. If a dice is above the correpsonding attribute value, the hero needs to reduce said value by
       spending from his talent value.
5. The remaining talent-values are devided by three and rounded up, this gives the QS, or
   Qualitätsstufe.
6. The modificators can be applied to the attributes individually. 
    1. They can be defined in the modal, by long-pressing on each individual modificator, which
       shall trigger a new modal which will allow the users to increase or decrease the modificator.
    2. The second way to determined the modificator is by looking at the hero state. A hero can be
       overloaded, or hurt, which has an impact on the check. This state is part of a different
       requirement and will be specified separately.
7. The dice roll shall be triggered through a user tapping on the row of the dices. Prior to that
   show random numbers in the given range of a d20, show a new number every 0.2 seconds. Use a
   separate random call for each attribute check.
   1. Display then the overall result and QS.

# Talent Check Wireframe

 ┌──────────────────────────┐
 │    ┌────────────────┐    │
 │    │Fliegen        7│    │◄───────    Talent to check, and talent value of hero
 │    └────────────────┘    │
 │    ┌────┐┌────┐┌────┐    │
 │    │ MU ││ KL ││ FF │    │
 │    │    ││    ││    │    │◄───────    Attributes from Hero
 │    │ 13 ││ 11 ││  3 │    │
 │    └────┘└────┘└────┘    │
 │    ┌────┐┌────┐┌────┐    │
 │    │ +1 ││ +1 ││ +1 │    │◄───────    Modificators, can be changed by a long-press
 │    └────┘└────┘└────┘    │            Default to 0
 │    ┌────┐┌────┐┌────┐    │
 │    │ 3  ││ 15 ││  3 │    │◄───────    Dice throws for each attribute
 │    └────┘└────┘└────┘    │
 │    ┌────┐┌────┐┌────┐    │
 │    │ 0  ││  -3││  0 │    │◄───────    Results for each attribute
 │    └────┘└────┘└────┘    │
 │┌────────────────────────┐│
 ││7- 0 + -3 + 0 = 4 -> QS2││◄───────    Overall result and QS
 │└────────────────────────┘│
 └──────────────────────────┘


# Talent Check Attribute Map

```
{
  "talents": [
    {
      "name": "Fliegen",
      "checks": ["MU", "IN", "GE"]
    },
    {
      "name": "Gaukeleien",
      "checks": ["MU", "CH", "FF"]
    },
    {
      "name": "Klettern",
      "checks": ["MU", "GE", "KK"]
    },
    {
      "name": "Körperbeherrschung",
      "checks": ["GE", "GE", "KO"]
    },
    {
      "name": "Kraftakt",
      "checks": ["KO", "KK", "KK"]
    },
    {
      "name": "Reiten",
      "checks": ["CH", "GE", "KK"]
    },
    {
      "name": "Schwimmen",
      "checks": ["GE", "KO", "KK"]
    },
    {
      "name": "Selbstbeherrschung",
      "checks": ["MU", "MU", "KO"]
    },
    {
      "name": "Singen",
      "checks": ["KL", "CH", "KO"]
    },
    {
      "name": "Sinnesschärfe",
      "checks": ["KL", "IN", "IN"]
    },
    {
      "name": "Tanzen",
      "checks": ["KL", "CH", "GE"]
    },
    {
      "name": "Taschendiebstahl",
      "checks": ["MU", "FF", "GE"]
    },
    {
      "name": "Verbergen",
      "checks": ["MU", "IN", "GE"]
    },
    {
      "name": "Zechen",
      "checks": ["KL", "KO", "KK"]
    },
    {
      "name": "Bekehren & Überzeugen",
      "checks": ["MU", "KL", "CH"]
    },
    {
      "name": "Betören",
      "checks": ["MU", "CH", "CH"]
    },
    {
      "name": "Einschüchtern",
      "checks": ["MU", "IN", "CH"]
    },
    {
      "name": "Etikette",
      "checks": ["KL", "IN", "CH"]
    },
    {
      "name": "Gassenwissen",
      "checks": ["KL", "IN", "CH"]
    },
    {
      "name": "Menschenkenntnis",
      "checks": ["KL", "IN", "CH"]
    },
    {
      "name": "Überreden",
      "checks": ["MU", "IN", "CH"]
    },
    {
      "name": "Verkleiden",
      "checks": ["IN", "CH", "GE"]
    },
    {
      "name": "Willenskraft",
      "checks": ["MU", "IN", "CH"]
    },
    {
      "name": "Fährtensuchen",
      "checks": ["MU", "IN", "GE"]
    },
    {
      "name": "Fesseln",
      "checks": ["KL", "FF", "KK"]
    },
    {
      "name": "Fischen & Angeln",
      "checks": ["FF", "GE", "KO"]
    },
    {
      "name": "Orientierung",
      "checks": ["KL", "IN", "IN"]
    },
    {
      "name": "Pflanzenkunde",
      "checks": ["KL", "FF", "KO"]
    },
    {
      "name": "Tierkunde",
      "checks": ["MU", "MU", "CH"]
    },
    {
      "name": "Wildnisleben",
      "checks": ["MU", "GE", "KO"]
    },
    {
      "name": "Brett- & Glücksspiel",
      "checks": ["KL", "KL", "IN"]
    },
    {
      "name": "Geographie",
      "checks": ["KL", "KL", "IN"]
    },
    {
      "name": "Geschichtswissen",
      "checks": ["KL", "KL", "IN"]
    },
    {
      "name": "Götter & Kulte",
      "checks": ["KL", "KL", "IN"]
    },
    {
      "name": "Kriegskunst",
      "checks": ["MU", "KL", "IN"]
    },
    {
      "name": "Magiekunde",
      "checks": ["KL", "KL", "IN"]
    },
    {
      "name": "Mechanik",
      "checks": ["KL", "KL", "FF"]
    },
    {
      "name": "Rechnen",
      "checks": ["KL", "KL", "IN"]
    },
    {
      "name": "Rechtskunde",
      "checks": ["KL", "KL", "IN"]
    },
    {
      "name": "Sagen & Legenden",
      "checks": ["KL", "KL", "IN"]
    },
    {
      "name": "Sphärenkunde",
      "checks": ["KL", "KL", "IN"]
    },
    {
      "name": "Sternkunde",
      "checks": ["KL", "KL", "IN"]
    },
    {
      "name": "Alchimie",
      "checks": ["MU", "KL", "FF"]
    },
    {
      "name": "Boote & Schiffe",
      "checks": ["FF", "GE", "KK"]
    },
    {
      "name": "Fahrzeuge",
      "checks": ["CH", "FF", "KO"]
    },
    {
      "name": "Handel",
      "checks": ["KL", "IN", "CH"]
    },
    {
      "name": "Heilkunde Gift",
      "checks": ["MU", "KL", "IN"]
    },
    {
      "name": "Heilkunde Krankheiten",
      "checks": ["MU", "IN", "KO"]
    },
    {
      "name": "Heilkunde Seele",
      "checks": ["IN", "CH", "KO"]
    },
    {
      "name": "Heilkunde Wunden",
      "checks": ["KL", "FF", "FF"]
    },
    {
      "name": "Holzbearbeitung",
      "checks": ["FF", "GE", "KK"]
    },
    {
      "name": "Lebensmittelbearbeitung",
      "checks": ["IN", "FF", "FF"]
    },
    {
      "name": "Lederbearbeitung",
      "checks": ["FF", "GE", "KO"]
    },
    {
      "name": "Malen & Zeichnen",
      "checks": ["IN", "FF", "FF"]
    },
    {
      "name": "Metallbearbeitung",
      "checks": ["FF", "KO", "KK"]
    },
    {
      "name": "Musizieren",
      "checks": ["CH", "FF", "KO"]
    },
    {
      "name": "Schlösserknacken",
      "checks": ["IN", "FF", "FF"]
    },
    {
      "name": "Steinbearbeitung",
      "checks": ["FF", "FF", "KK"]
    },
    {
      "name": "Stoffbearbeitung",
      "checks": ["KL", "FF", "FF"]
    }
  ]
}
```
