# Companion Format

Edit a companion in Optolith's pet editor. Hesindion reads these fields when you import the
export, so there is no other file and no build step. A plain Optolith export imports directly; the
fields below add what Optolith has no field for. Design and reasons:
`docs/plans/2026-10-03-companion-text-format-design.md`, ADR-0021.

## Each field is one line

Optolith's text inputs drop line breaks. Type or paste every field below as **one line**. The
format never needs a line break.

## Fields

| Optolith field | Content | Hesindion shows |
|---|---|---|
| PA | integer | VW |
| RS | integer | RS |
| AP | Optolith's own numbers | AP spent and total |
| Talente | `Name N` items, no labels. An item without a number is a note, not a problem. | talents |
| Sonderfertigkeiten | labels `Vorteile`, `Nachteile`, `Sonderfertigkeiten`, `Ausbildung`, `Tricks` | advantages, disadvantages, abilities, training, tricks |
| Notizen | labels `Angriffe` and `BE`; every other segment is prose | attacks, BE; the prose stays as notes |

An empty PA or RS shows nothing. A missing `BE` segment shows nothing.

## General rules

- A field is a list of segments separated by `;`.
- A segment is `Label: content`. The label is case-insensitive. Space around `;`, `:` and `,` is
  ignored.
- Inside a segment, `,` separates the items.
- Neither `;` nor `,` separates inside parentheses. `Klettern (keine Probe erlaubt; Pferde können
  nicht klettern)` is one item.
- An item can end with a note in parentheses. The app shows the note but does not use it for a
  comparison: `Mächtiger Schlag (-4 auf Gegner Kraftakt)` counts as `Mächtiger Schlag`.

## Attacks

An `Angriffe` item is `Name AT n TP xWy±z RW kurz|mittel|lang`, for example
`Biss AT 16 TP 1W6+3 RW kurz`. The name can contain spaces (`Huf und Biss`). The `±z` part is
optional. An item can end with a note in parentheses; the attack is read without it, and the
note is not kept: `Biss AT 16 TP 1W6+3 RW kurz (nur liegend)` is the attack Biss.

Without an `Angriffe` segment, the pet gets one attack from Optolith's own attack, AT, TP and
reach fields, if the attack name is not empty.

With an `Angriffe` segment, the pet's attacks are the `Angriffe` items. When Optolith's attack
field names one of them and its AT or TP differs, Hesindion reports it (see `attackMismatch`
below) and keeps the `Angriffe` item. An empty AT or TP field in Optolith is not compared, and
spaces in Optolith's TP do not count (`2W6 + 7` is `2W6+7`).

## Problems

A part that cannot be read is reported. An `Angriffe` item, a `BE` value or a Sonderfertigkeiten
segment that cannot be read is not imported. A Talente value that cannot be read and attack-like
prose in Notizen stay as text, in the talents and the notes. With an `attackMismatch`, the
`Angriffe` item is kept and Optolith's attack field is not used. After the import a modal says
"Nicht alles in den Begleiterfeldern war lesbar. Der Rest ist importiert. Korrigiere diese Stellen
in Optolith und importiere erneut:" and lists each part; the companion sheet keeps the list until
a clean re-import. There are six kinds of problem (the first has two messages, depending on whether the label is missing or unknown):

| Kind | When | Message |
|---|---|---|
| `noLabel` | a Sonderfertigkeiten segment has no label | ohne Bezeichnung (Vorteile:, Nachteile:, Sonderfertigkeiten:, Ausbildung:, Tricks:) |
| `unknownLabel` | a Sonderfertigkeiten segment has an unknown label | unbekannte Bezeichnung |
| `badAttack` | an `Angriffe` item does not match the attack grammar | kein Angriff (Name AT 15 TP 1W6+2 RW kurz) |
| `badBE` | the `BE` value is not an integer | BE ist keine Zahl |
| `badTalentValue` | a Talente item's last word starts with a digit but is not an integer (`Kraftakt 8a`) | der Wert ist keine Zahl |
| `attackMismatch` | Optolith's attack field names an attack from `Angriffe`, and its AT or TP, when not empty, differs | weicht vom gleichen Angriff unter Angriffe ab |
| `attackOutsideAngriffe` | a Notizen prose segment contains attack-like text (`AT` and digits, later `TP`) | Angriff ausserhalb von Angriffe:, nicht gelesen |

An unknown label in Notizen is not a problem; it is prose (`Kampfverhalten: …`). A Talente item
whose last word has no digit is a note.

## Example: Kupperus

Copy each line into the matching Optolith field, as one line.

PA:

```
14
```

RS:

```
0
```

Sonderfertigkeiten:

```
Vorteile: Ruhiges Temperament, Geduldig, Ausdauernd, Heldenwuchs, Zähes Tier, Schnell, Stark, Tapfer, Sprungsicher, Loyal; Sonderfertigkeiten: Mächtiger Schlag (-4 auf Gegner Kraftakt); Ausbildung: Reittier, Kampftier; Tricks: Aus, Fass I, Fass II, Komm, Sitz
```

Notizen:

```
Angriffe: Tritt AT 19 TP 1W6+8 RW mittel, Biss AT 16 TP 1W6+3 RW kurz, Niederreiten AT 19 TP 2W6+7 RW mittel; BE: 0; Kampfverhalten: Svellttaler Kaltblüter sind besonnen …
```
