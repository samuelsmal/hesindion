# Worked rule examples

These come before any design for the rules rework. Each takes a rule, or a small cluster of
rules that touch each other, from its page on <https://dsa.ulisses-regelwiki.de/>, splits it into
clauses and states **what the app must show in concrete situations** — the numbers and the rule
each one comes from. The surprises are meant to show up here rather than halfway through an
implementation.

Each example comes in three parts:

| Part | Where | What it is |
|---|---|---|
| The write-up | `<example>.md` | Clauses in plain words, and what the app gets wrong |
| The rule files | [`rules/`](./rules/) | A **draft** of the one-file-per-rule YAML, written for these rules |
| The situations | [`situations/`](./situations/) | Hero + situation → expected values and the rule and clause behind every line, as YAML, so a test can run them against any engine |

The YAML format is a sketch to find out what the rules need, not a decision. Where writing a rule
down in it was awkward, the rule file says so in a `# FORMAT:` comment — those are the input to the
design.

## Layout of the draft rule files

```
rules/
  core/          rules without an Optolith id: Reiterkampf, Vorteilhafte Position, …
  conditions/    Zustände (COND_*) and Status (STATE_*)
  abilities/     SA_*, one file per special ability
  advantages/    ADV_*
  disadvantages/ DISADV_*
  equipment/     ITEMTPL_*: a weapon's table row and its Waffenvorteil/-nachteil
  creatures/     animal profiles and their abilities: a mount, what it can do in a fight
  talents/       TAL_*: a talent rule, not owned — gated on `check.talent` (see "Facts" below)
  rulings.yaml   rulings that cut across several rules
situations/      one file per example
sweeps/          the rules that affect one hero, for the review TUI
```

Every `<file>.yaml` under `rules/` is written in the engine's rule format
([design §4](../../plans/2026-09-24-rules-engine-design.md#4-the-rule-format)), the same format the compiler
(`scripts/rulec`) reads. **The vocabulary is closed**: an id, verb, target, fact, owner or value
form outside [`specs/rules/vocabulary.json`](../../../specs/rules/vocabulary.json) is a compile
error, not a warning. `make rules-check` runs the compiler over every rule file; run it after
every edit. This section is what it checks against — the rest of the vocabulary (`kinds`,
`comparisons`, `selectorKinds`, item fields, …) is in the JSON itself.

### The file header (design §4.1)

```yaml
id: waffeneigenschaften
name: Waffeneigenschaften
kind: core                        # specialAbility | advantage | disadvantage | condition | state
                                  # | core | equipment | creature | talent
ruleset: fokus.waffeneigenschaften # or `core`, the default
source: { url, book, page, checked, hash, also: [...] }
reviewed: null                    # or { by, date }
levels: 7                         # when the rule has Stufen, e.g. ADV_25 Hohe Lebenskraft
options: sid                      # when the hero file chooses one, e.g. DISADV_37 Schlechte Eigenschaft
provides: { ... }                 # tables and ordered scales other rules read
clauses: [ ... ]
rulings: [ ... ]
agentPass: null                   # the review queue's flag; see "What waits for an agent"
```

(from `rules/core/waffeneigenschaften.yaml`, trimmed). The `# DRAFT FORMAT — see ../../README.md.`
comment (`../README.md.` for `rulings.yaml`) at the top of every file points back here.

### Clauses (design §4.2)

Every clause has its verbatim `id` and `text`, and **exactly one** of:

| Key | Meaning | Example |
|---|---|---|
| `effects: [...]` | What the app does with it | most clauses |
| `unencoded: <why>` | The app cannot apply it; the player sees the text | `trefferzonen.TZ7`: "creatures are not modelled; …" |
| `none: <why>` | Nothing to do at the table: a prerequisite, a cost, the page's own example | `ADV_49.ZH5`: "purchase prerequisite, not a rule at the table" |

A clause that could not be encoded is shown to the player as text, never dropped. `rulec check`
refuses a clause with none, or more than one, of these three keys.

### Effects and their verbs (design §4.3)

An effect is one verb with its payload, plus `when` (a condition over facts, see "Facts" below),
and optionally `ruling` (an id or a list), `because` (the reason text shown when it forbids or does
not apply) and `phase` (design §5.2, only where the default is wrong). The verb is one of these
twenty-two — a verb outside this list is a compile error — each shown below as it is actually
written in a migrated clause:

| Group | Verb | As written | Clause |
|---|---|---|---|
| Value | `add` | `add: { to: at, value: 2 }` | `SA_862.F2` |
| | `set` | `set: { to: sp, value: { of: hit.tp } }` | `schaden.S5` |
| | `multiply` | `multiply: { to: regeneration.le, by: 0.5, round: up }` | `regeneration.R6` |
| | `cap` | `cap: { to: [at, pa, aw, fk, check.modifier, gs, ini], over: { ruleKind: condition }, min: -5 }` | `zustaende.Z3` |
| | `floor` | `floor: { to: regeneration.le, min: 0 }` | `regeneration.R4` |
| | `useLevel` | `useLevel: { rule: COND_6, as: "level - 1" }` | `ADV_49.ZH1` |
| Line control | `replace` | `replace: { line: { line: schaden.S3 }, with: { of: loadout.weapon.leit, above: loadout.weapon.schadensschwelle } }` | `schaden.S4` |
| | `suppress` | `suppress: { line: { line: kampfwerte.KW9 } }` | `reiterkampf.RK1` |
| Legality | `forbid` | `forbid: { what: { defence: weaponParry } }` | `groessenkategorie.GK4` |
| | `require` | `require: { that: { hero.mounted: true, opponent.onFoot: true }, enables: true, for: { rule: vorteilhafte-position } }` | `reiterkampf.RK2` |
| | `limit` | `limit: { per: action, what: { manoeuvre: { kind: basismanoever } }, max: 1 }` | `kampfsonderfertigkeiten.KS3` |
| Player and GM | `offer` | `offer: { choice: ignoresRS, default: false }` | `schaden.S5` |
| | `ask` | `ask: { fact: gmFact.triggerModifier, who: gm }` | `DISADV_37.SE4` |
| | `tell` | `tell: { to: player, text: "gibt der Schlechten Eigenschaft nach" }` | `DISADV_37.SE2` |
| Data | `provide` | `provide: { name: trefferzonen.TZ6, value: { kopf: -10, torso: -4, arme: -8, beine: -8 } }` | `trefferzonen.TZ6` |
| | `derive` | `derive: { to: iniBase, sum: [{ of: mount.iniBase }] }` | `reiterkampf.RK1` |
| Consequence | `check` | `check: { of: { talent: TAL_23 } }` | `DISADV_37.SE1` |
| | `gain` | `gain: { rule: STATE_8 }` | `zustaende.Z5` |
| | `cost` | `cost: { pool: asp, amount: { of: spell.costPerInterval }, every: { minutes: spell.interval } }` | `zaubermodifikationen.ZM5` |
| | `process` | `process: { id: laden, steps: 1, advancedBy: { action: laden }, completes: [{ item: { instance: { loadout: weapon }, change: { loaded: true } } }] }` | `ladezeiten.LZ2` |
| | `item` | `item: { instance: { loadout: mount }, change: { ridden: false } }` | `reiterkampf.RK6` |
| | `reroll` | `reroll: { die: { dice: any }, keep: better, max: 1, per: action }` | `ADV_4.B1` |

`check` carries `onSuccess` and `onFailure` lists of effects (see `DISADV_37.SE1`/`SE2` above: the
check is `SE1`, its `onFailure` line is `SE2`'s `tell`). `gain` covers Zustand Stufen and Status in
both directions — negative `levels` removes them.

Targets (design §4.4) are one closed list too: `at`, `pa`, `aw`, `fk`, `ini`, `gs`, `leMax`,
`wundschwelle`, `tp`, `rs`, `sp`, and the stage targets of a check (`check.attribute`,
`check.modifier`, `check.fw`, `check.qs`, `check.dice`), with `opponent.<target>`, `mount.<target>`
and `ally.<target>` for the other side of the table or a mount/companion, and `pa(with: weapon |
shield)` for a defence with a named piece in hand.

### Values (design §4.5)

Four forms only — never a free formula, so each clause has one readable encoding. This is what
`scripts/rulec/forms.py` (`Forms.value`) actually accepts, extensions included:

| Form | Example | Notes |
|---|---|---|
| a number | `2` (`SA_862.F2`) | |
| a level expression | `level` (`ADV_25.HL1`), `level - 1` (`ADV_49.ZH1`) | also `N * level`, `level + N` |
| a proportion | `{ of: hit.sp, per: wundschwelle, times: -1, round: down }` (`trefferzonen.TZ8`) | `of`/`per` are **operands**: a number, a fact, a target, or a summed list of those (`sum: [{ of: [attr.MU, attr.GE], per: 2, round: up }]`, `(Mut + Gewandtheit) / 2`, `kampfwerte.KW9`). `above` (default 0) is a number, or an operand naming a fact (`DISADV_37.SE4`: `above: gmFact.triggerModifier`) or a target (`schaden.S3`: `above: loadout.weapon.schadensschwelle`). `min`/`max` are a number, an operand, or a **list of operands, all of which bind** (`max: [10, gsNatural]`, `SA_62.ST2`: at most 10 and at most the natural GS). `round` names the shared ruling it follows where the page does not say (`round-up`). |
| a table lookup | `table(trefferzonen.TZ6, choice.targetZone)` (`trefferzonen.TZ5`) | `name` is a `provide`d table (or a nested key into one, `trefferzonen-ruestungsschutz.RS4.belastung`); `key` is the fact or target whose value looks the row up. |

### Facts and their owners (design §4.6)

`when` is `all` / `any` / `not` over named **facts**. Every fact has one **owner**, which decides
who is asked for it and is recorded on every line that used it. In a situation file
(`scripts/rulec/situations.py`), each section maps to one owner (a prefixed section names the fact
with that prefix):

| Situation section | Owner | Prefix |
|---|---|---|
| `choose` | `player` | — |
| `gm` | `gm` | — |
| `opponent` | `gm` | `opponent.` |
| `ally` | `player` | `ally.` |
| `round` | `round` | `round.` |
| `loadout` | `loadout` | `loadout.` |
| `rolls` | `roll` | — |

(A rule file's own facts add two more owners the vocabulary lists but no situation section states
directly: `sheet` — attributes, owned rules, talents, `hero.has` — and `derived`, a value another
query computed.) A fact nobody has stated is **unknown**, not false; an effect whose `when` depends
on an unknown fact produces a question, not a guess.

See [`specs/rules/vocabulary.json`](../../../specs/rules/vocabulary.json) for the full, closed
lists this section only samples (all facts, targets, verbs, comparisons, `selectorKinds`, item
fields, …), and
[the design](../../plans/2026-09-24-rules-engine-design.md#4-the-rule-format) for the reasoning
behind the format. [`MIGRATION.md`](./MIGRATION.md) has the file-by-file record of the 2026-09
migration into this format — its "Expectation conflicts for the owner", "Open questions" and
"Notes for the engine tasks" sections are what is still unresolved.

## How rulings are kept

A **ruling** is our reading of a rule where the page is ambiguous, silent, or reads oddly. It is
data, kept beside the rule it interprets, and answered there — not in chat.

- **Where.** A ruling about one rule lives in that rule's file, under `rulings:`. A ruling that
  applies to many rules (rounding, what a Kampfstil's technique list means) lives in
  [`rules/rulings.yaml`](./rules/rulings.yaml).
- **An open ruling is written to be answered cold:** the question, the `context` (what the page
  says, what the app does now), the `situations` it decides, lettered `options` each with what
  it would mean for the app, and a `recommended` option with the reason.
- **Answering** is an edit — in the [review TUI](#reviewing-with-the-tui) or by hand: write the
  option letter, or your own words, into `answer:` and commit. The next pass turns it into
  `status: decided` with `decided: { by, date }` (by GitHub handle), and updates the effects and
  situations that rest on it.
- **[`RULINGS.md`](./RULINGS.md)** is the index, generated by `python3 rulings.py` and by the review
  TUI after every edit: open ones first, each with a link to the line to edit; then
  answered-to-process; then decided. `rulings.py --check` fails when the index is stale or a
  ruling is malformed.
- **Effects name the ruling they rest on** (`ruling: <id>`), so changing a ruling shows everything
  it moves, and re-encoding a clause shows the ruling it must honour.
- **In game,** a line resting on a ruling is marked *Auslegung*; tapping it shows the page's words,
  the question and the answer. A clause waiting on an open ruling is shown as text with its
  question and applies nothing.
- **GM and house-rule adjustments** (from the `mounted-jouster` ruling: "other rules, GM decisions,
  house rules may lower it") are not rulings: they are inputs the design has to provide, shown as
  their own lines.

## Reviewing with the TUI

```
make rules-review
```

It lists every rule file with what it needs: `? n` open rulings, `· review` not yet read against its
page, `⟳ agent` waiting for an agent, `✓` reviewed. The right side shows the selected rule: its
source, the rulings (open first, with options and the recommendation), each clause's page text next
to its effects (comments and `# FORMAT:` notes included), and the situations that name the rule,
with what the app does today where it differs. It opens on a short help with the flow and these
keys; `?` shows it again.

| Key | Does |
|---|---|
| `n` | the next thing that needs you: each open ruling in turn, then rules to review. Leaving a rule with rulings still open asks first: `y` moves on, `n` stays |
| `p` | back to where `n` came from, one jump at a time, including rulings you have answered since |
| `enter` | on a ruling: choose its answer from the options (or press the option's letter). The last choices write your own answer instead, send the ruling back to the agent, or clear your answer. On a clause or situation: open it in the editor |
| `r` | mark the rule reviewed (`reviewed: { by, date }`); again to withdraw |
| `a` | send it back to the agent: a note on what is wrong, about the focused ruling or clause (or the whole rule). For a ruling whose question or options are wrong. It stays open but leaves the `n` list until the agent has redone it. An empty note removes the flag |
| `e` | open `$VISUAL`/`$EDITOR` at the focused clause, ruling or situation; the tool reloads after |
| `o` | open the rule's page in the browser |
| `f` / `/` | filter: needs you, all, agent queue, reviewed / search by id, name, kind |
| `j` / `k` | move between the cards on the right |
| `?` | the help shown at start |

**Sweeps.** `make rules-review SWEEP=boronmir` shows only the rules that affect one hero, as
[`sweeps/boronmir.yaml`](./sweeps/boronmir.yaml) lists them: the hero file's own special abilities,
advantages, disadvantages and items (less a `skip` list, each with why), plus the core rules and
Zustände that reach the hero. `n`, the counts and the filters then stay within it.
`make rules-sweep SWEEP=boronmir` prints the same rules with what each still needs, and the ones not
drafted yet.

It signs with your GitHub handle, from `gh` unless `make rules-review BY=@handle` or
`HESINDION_REVIEWER` says otherwise. Every change is a one-key edit to the rule file — nothing else
in the file moves, and an edit that would change more than that is refused — and `RULINGS.md` is
regenerated after it, so `git diff` is the record of the session. The edits are in `rulefiles.py`, tested by
`make test-rules-review` (which also runs `rulings.py --check`).

## What waits for an agent

`make rules-queue` prints it; `make rules-agent` starts Claude Code on it (interactive, so you can
watch and steer; it does not commit). Two kinds:

- **An answered ruling.** Turn it into `status: decided` with `decided: { by, date }` (the person
  who answered, and the day), and update the effects and situations that rest on it.
- **A flagged rule**, `agentPass: { requested: { by, date }, about: [...], note }`. The note says
  what is wrong; `about`, when present, names the clauses and rulings it concerns. Re-read the page,
  then fix what the note names. For a ruling, that means rewriting its question, context, options
  and recommendation. It stays `status: open` with `answer: null`, and the owner answers it afresh.
  If the note is right that the ruling is not needed, remove it and the `ruling:` references to it.
  If you disagree with the note, say why in the ruling's `context` rather than ignoring it. Then
  delete the `agentPass` block. If the pass changed a clause's effects, withdraw the rule's
  `reviewed` (set it to `null`): the review was of the old version.

Whatever you change, keep it inside the closed vocabulary ("Layout of the draft rule files" above)
and run `make rules-check` after every edit — it compiles every rule file against
[`specs/rules/vocabulary.json`](../../../specs/rules/vocabulary.json) and catches an unknown verb,
target, fact or value form before it reaches `make test-rules-review`.

## The set

Chosen to cover each kind of mechanic ADR-0013's census found (flat modifiers, opponent-side
effects, per-Stufe scaling, preconditions, dice, overriding a constant, legality, action economy,
Zustände) and every place where two rules meet. Examples 14–18 fill in the rest of what affects
one hero, Boronmir ([`sweeps/boronmir.yaml`](./sweeps/boronmir.yaml)): his own abilities, the core
combat values, and his horse and weapons. Example 19 adds what he took in his 2026-09-24 export.
Examples 20–22 are a probe beyond melee (magic, ranged combat, talent checks), to find engine
concepts the rest of the set does not need; each write-up ends with what it found.

| # | Example | Rules | What it exercises | Status |
|---|---|---|---|---|
| 1 | [Belastung](./belastung.md) | COND_1, Rüstung und Belastung, SA_41, Reiterkampf RK7 | leveled Zustand; which checks a Zustand reaches; a Stufe that makes a hero incapacitated; stacking with a situational relief | **draft, rulings given** |
| 2 | [Reiterkampf](./reiterkampf.md) | Reiterkampf, Vorteilhafte Position, SA_43, SA_661, SA_62 | a core rule without an Optolith id; legality; a rule raising another rule's bonus; an order replacing an action; two rules with one name | **draft, rulings given** |
| 3 | [Mehrfache Verteidigung](./mehrfache-verteidigung.md) | GRW_mehrfacheVerteidigung, SA_923 Vinsalt-Stil, SA_65 Verteidigungshaltung | a counter over the round; a style changing a core constant | **draft, for review** |
| 4 | [Schmerz and the Zustand cap](./schmerz.md) | COND_6, the Zustand cap, Schicksalspunkte (Verteidigung, Zustand ignorieren) | several Zustände at once; a cap; what a Schip removes and what it cannot | **draft, for review** |
| 5 | [Reichweite](./reichweite.md) | GRW_reichweite, SA_172/SA_173 Unterlaufen | a matrix of constants; a per-Stufe shift of that matrix | **draft, for review** |
| 6 | [Trefferzonen](./trefferzonen.md) | GRW_zonenaufschlag, SA_160, SA_161, STATE_13, Fokusregel Trefferzonen-RS | an optional rule set (Fokusregel); one rule halving another | **draft, for review** |
| 7 | [Liegend](./liegend.md) | STATE_10 | penalties on the other side of the table; a value set rather than modified (GS 1) | **draft, for review** |
| 8 | [Finte](./finte.md) | SA_48 | per-Stufe cost and effect split between hero and opponent; Basismanöver; mutual exclusion | **draft, for review** |
| 9 | [Wuchtschlag](./wuchtschlag.md) | SA_67 | per-Stufe trade of AT for TP; choosing a lower Stufe | **draft, for review** |
| 10 | [Sturmangriff](./sturmangriff.md) | SA_62 | a precondition (run-up); a damage formula using GS; a consequence for the opponent on failure | **draft, for review** |
| 11 | [Beidhändiger Kampf](./beidhaendiger-kampf.md) | the core two-weapon rule, SA_42, ADV_5 Beidhändig | action economy; off-hand penalties; an advantage and an SF together | **draft, for review** |
| 12 | [Kampfreflexe](./kampfreflexe.md) | SA_51 | a value outside any check (INI) | **draft, for review** |
| 13 | [Verweichlicht](./verweichlicht.md) | DISADV_57 | a disadvantage; a talent check, not combat | **draft, for review** |
| 14 | [Boronmirs Kampfsonderfertigkeiten](./boronmir-sf.md) | SA_66 Vorstoß, SA_59 Schildspalter, SA_40 Aufmerksamkeit, SA_884 Plänkler-Formation | a whole-round manoeuvre announced at round start; a manoeuvre written from both sides of the table (damage to an item's StP); a bonus on one talent application; a bonus an ally's SF grants | **draft, for review** |
| 15 | [Lebensenergie](./lebensenergie.md) | ADV_25, ADV_49, ADV_44, ADV_75, Lebensenergie (Basiswert), Regeneration | a derived value's breakdown; an advantage choosing which Stufe of another rule's table applies; a rolled resource gain with situational lines, halving, floor and cap; an effect on a Zustand's duration and cause | **draft, for review** |
| 16 | [Kampfwerte, Schaden und Schilde](./kampfwerte.md) | kampfwerte, schaden, schilde, at-pa-modifikatoren | derived values and their breakdown (AT/PA/AW/INI, rounding, the higher Leiteigenschaft); a weapon value above a threshold (Schadensbonus); a passive vs an active choice per defence (shield bonus single or doubled); a defence forbidden by the kind of attack; a rolled value whose modifiers stay live (INI) | **draft, for review** |
| 17 | [Kampfsituationen](./kampfsituationen.md) | GRW_passierschlag, GRW_angriffVonHinten, GRW_beengteUmgebung, GRW_groessenkategorie | a free attack with no defence and no crits; a GM fact that also unlocks another rule's clause (RK5); a penalty table keyed on the piece in hand (reach or shield size); a defence restriction by opponent size | **draft, for review** |
| 18 | [Kupperus und Boronmirs Waffen](./kupperus-und-waffen.md) | svellttaler-kaltblut, maechtiger-schlag, ruhiges-temperament, ITEMTPL_19, ITEMTPL_35, ITEMTPL_29, waffeneigenschaften | creature rules (a profile read by another rule, an animal's advantage landing on the rider's check); weapon data; a Fokusregel that covers only some clauses of a file | **draft, for review** |
| 19 | [Boronmirs neue Fähigkeiten](./boronmir-neu.md) | SA_862 Formation, ADV_54 Eisern, DISADV_37 Schlechte Eigenschaft | one SF written as a larger copy of another, and the two meeting; an advantage on a value defined by a Fokusregel; a disadvantage whose only effect is a check it offers, with a GM modifier and a select option (`sid`) naming which one | **draft, for review** |
| 20 | [Probe: Zaubermodifikationen](./probe-magie.md) | zaubermodifikationen, SA_74 Verbotene Pforten | a rule moving the parameters of the action being taken (cost, casting time, range) along ordered scales; costs paid into named pools, split and falling through (AsP, then LeP); a cost that recurs over game time | **probe, draft** |
| 21 | [Probe: Fernkampf](./probe-fernkampf.md) | fernkampf, ladezeiten, SA_60 Schnellladen | a process that runs over several actions (Zielen, Laden); item state that changes in a fight and gates actions (loaded, strung); a weapon value changed by another rule | **probe, draft** |
| 22 | [Probe: Fertigkeitsproben](./probe-fertigkeiten.md) | fertigkeitsproben, ADV_4 Begabung, SA_9 Fertigkeitsspezialisierung | a check as a staged procedure (attributes, pool, dice, result, QS) with rules hooking into each stage; an effect replacing a die after the roll | **probe, draft** |

## What the app gets wrong

Found while writing the examples; each is detailed in its write-up. "Per the page" means the
rule page says so plainly; "per ruling" means a decided ruling does. Divergences that depend on an
open ruling are listed in the write-ups, not here.

| Example | Finding | Where | Basis |
|---|---|---|---|
| 1 | Belastung never reaches a talent check (Reiten on horseback: relieved by 1) | `SharedModifiers.encumbrance` | ruling belastung-reach, rk7-reiten |
| 1 | Any number of armours can be equipped, and they add up | `HeroDetailView`, `Hero.totalEquippedBE` | ruling several-armour-pieces |
| 1 | Belastung IV applies −4 instead of making the hero Handlungsunfähig | `SharedModifiers.encumbrance`, `StateCatalog` (belastung has no `handlungsunfaehigAtLevel`) | page |
| 2 | Vorstoß and Schildspalter are offered on horseback | `CombatAttackViews.availableManeuvers` | ruling mounted-manoeuvres |
| 2, 10 | Sturmangriff (SA_62) is never offered on foot; the app's one Sturmangriff is the mounted order | `CombatManeuver.sturmangriff` | ruling two-sturmangriffe |
| 2 | The mounted Sturmangriff rounds the mount's GS/2 down | `Hero.sturmangriffDamageBonus` | ruling round-up, ADR-0006 |
| 2 | The mounted dodge −2 names no rule | `DefenseModifiers.mountedDodgePenalty` (`rules: []`) | page |
| 3 | Parries and dodges are counted separately for the multiple-defence penalty; the page counts every earlier defence | `CombatSituation.defensesSoFar`, `CombatView` | page |
| 3 | A defence whose value has dropped to 0 or below is never blocked (the value after every modifier, the Schip +4 included) | `CombatRootView.defenseBlocked` | page; ruling zero-value |
| 3 | Verteidigungshaltung (SA_65) does not exist | catalog `todo` | page |
| 3 | The Schip +4 on a defence names no rule | `DefenseModifiers.schipDefenseBoost` (`rules: []`) | page |
| 4 | Schmerz never lowers GS (−1/−2/−3; GS 0 at Stufe IV even after the check) | `Hero.effectiveGeschwindigkeit`, `Hero.totalGsPenalty` | page; ruling schmerz-iv-gs |
| 4 | Schmerz IV has no Selbstbeherrschung check before each action; the hero is simply Handlungsunfähig | `StateCatalog` (schmerz) | page; ruling schmerz-iv-check |
| 4 | The Zustand cap reaches checks only; GS and INI penalties from Zustände are never capped at −5 | `ModifierEngine.applyingZustandCap` | ruling cap-scope |
| 4 | A Schip "Zustand ignorieren" never ignores Belastung | `SharedModifiers.encumbrance`, `Hero.hasIgnorableZustand` | ruling schip-ignore-belastung |
| 5 | Unterlaufen and Verbessertes Unterlaufen do not exist; the full reach penalty is always paid | `availableManeuvers`, catalog `todo` | page |
| 6 | An aimed attack at a winzig opponent pays both the size modifier and the zone penalty | catalog `GRW_groessenkategorie` | page |
| 6 | The hit zone on the hero is rolled on the hero's own size table, ignoring the attacker's size | `CombatDamageViews`, `HitZoneTable.lookup` | page; ruling relative-size-table |
| 6 | Trefferzonen-Rüstungsschutz (armour by zone) is not modelled | `Hero.totalEquippedBE` | page |
| 6 | Having Gezielter Angriff/Schuss halves every aimed attack; the halving is the announced Spezialmanöver, lost on horseback and with Unterlaufen | `CombatZonePicker`, `HitZoneModifiers.penalty` | ruling halving-by-manoeuvre |
| 6 | Against an überrascht opponent Gezielter Angriff/Schuss halves before easing by 2, so the penalty is 1 too small (Torso 0 instead of −1, Kopf −3 instead of −4) | `HitZoneModifiers.penalty` | ruling surprised-then-halved |
| 6 | An aimed shot keeps the ranged target-size modifier (Kopf of a groß target with Gezielter Schuss −1 instead of −5) | `RangedModifiers` (size) | ruling zone-replaces-size |
| 6 | A failed arm Wundeffekt only reminds; the one-handed weapon stays in the loadout | `WoundEffectCatalog` | ruling wundeffekt-arm-drop |
| 6 | A surprised hero can still parry and dodge, and combat setup never asks whether the hero is surprised | `StateCatalog` (ueberrascht), `CombatSetupView` | ruling hero-no-defence |
| 7 | A Handlungsunfähig hero moves at GS 1 rather than 0 | `Hero.effectiveGeschwindigkeit` | page |
| 7 | Handlungsunfähig never asks whether the hero lies: set by hand or through Bewusstlos it always implies Liegend; reached through Zustände it implies nothing | `Hero.impliedStateIDs`, `StateCatalog` (implies liegend) | page; ruling handlungsunfaehig-liegend |
| 7 | A prone hero shoots at no penalty; Liegend's −4 reaches only melee | catalog STATE_10 (domain meleeAttack) | ruling liegend-attacks |
| 7 | Standing up is no action; its cost and the opponent's Passierschlag are never mentioned | — | page |
| 8, 9, 10, 14 | Only one manoeuvre per attack; one Basismanöver and one Spezialmanöver combine (Wuchtschlag + Sturmangriff, Schildspalter or Vorstoß), an excluded combination is not explained, and no manoeuvre shows whether it is a Basis- or Spezialmanöver | `CombatAttackViews.selectedManeuver` (one `CombatManeuver`) | page (kampfsonderfertigkeiten.KS3–KS5), ruling manoeuvre-combination |
| 8, 9, 14 | Manoeuvres are offered with any weapon: Finte with a Morgenstern, Wuchtschlag with a Dolch, Vorstoß with the Großschild, Schildspalter with the Langschwert | `CombatAttackViews.availableManeuvers` | ruling sf-technique-lists |
| 8 | Only the highest Finte Stufe is offered; any Stufe up to the owned one may be announced (Wuchtschlag already offers them) | `CombatAttackViews.availableManeuvers` (`hero.finteTier`) | ruling tiered-manoeuvre-stufe |
| 8 | Finte's hint says "Gegner PA −2"; the page says Verteidigung, so it is wrong when the opponent dodges | `CombatManeuver.infoText` | page |
| 11 | The off hand is picked alphabetically: with Schwert and Dolch, the Schwert takes the −4 | `CombatLoadoutPicker.apply` | page |
| 11 | Spezialmanöver are offered on a double attack; only Basismanöver are allowed | `availableManeuvers` | page |
| 11 | A Kettenwaffe can be paired with a second weapon; only a shield is allowed | `CombatLoadoutPicker.canSelect` | page |
| 11 | No weapon-and-shield double attack, and no shield attack at all | `Hero.isDualWielding` | page |
| 11 | Raufen cannot be one hand of a double attack; each fist counts as a weapon (fist and fist, or weapon and fist, the off hand at −4) | `CombatLoadoutPicker.canSelect` | ruling raufen-double-attack |
| 11 | The dual-wield lines cite SA_42 and ADV_5 for the core rule's −2/−4 | `MeleeModifiers.dualAttackPenalty`, `offHandPenalty`, `DefenseModifiers` | page |
| 12 | Kampfreflexe is ignored: INI is 1–3 too low for every hero with it, mounted too | `OptolithImportService`, `DerivedValueFormulas.initiative`, catalog `todo` | page; mounted per ruling kampfreflexe-mounted |
| 13 | Verweichlicht silently does nothing without Trefferzonen | catalog `DISADV_57` | page |
| 14 | Vorstoß can be picked at any attack in the round, even after the hero has parried; the page wants it announced at the start of the round | `CombatAttackViews.availableManeuvers`, `proceed()` | page |
| 14 | Vorstoß is offered while Liegend | `CombatAttackViews.availableManeuvers` | page |
| 14 | Schildspalter is offered against any opponent; the app never asks whether the opponent has a shield | `availableManeuvers`, `OpponentProfile` | page |
| 14 | Schildspalter's note says only "Schaden gegen Schild-SP", not that the opponent may only parry with the shield (without its bonus) or dodge | `CombatManeuver.infoText` | page |
| 14 | Aufmerksamkeit's +2 is never applied; the hint shows on every Sinnesschärfe check and says "Überraschung vermeiden", not Hinterhalt entdecken | `TalentProbeModal.hints`, catalog SA_40 `byHand` | page; ruling aufmerksamkeit-when |
| 14 | Only an owner of Plänkler-Formation can be in one; the page lets a companion's SF carry the whole line | `CombatSetupView` (`hero.hasPlaenklerFormation`) | page |
| 14 | Plänkler-Formation is set once at combat setup and cannot be left mid-fight | `CombatSetupView`, `CombatRootView.plaenklerActive` | page |
| 14 | Plänkler-Formation's +1 applies on horseback too | `CombatSituation.chosenOptions`, catalog SA_884 | ruling plaenkler-mounted |
| 14 | An opponent's Schildspalter cannot be stated: the weapon parry and the full shield parry are offered, the damage goes to the hero's LeP, and a shield's StP are never reduced | `CombatDefenseSetupView`, `Shield.structurePoints` (maximum only) | ruling schildspalter-shield-bonus, schildspalter-against-hero |
| 15 | Niedrige Lebenskraft is ignored: 2 LE too many at Stufe II | `OptolithImportService.computeDerivedValues`, catalog `DISADV_28` todo | page |
| 15 | Zäher Hund lowers the Stufe the hero has, not only its effects: Boronmir with Belastung II, Schmerz III and Betäubung III counts 7 Stufen and keeps acting; at Schmerz I no chip | `Hero.effectiveSchmerzLevel`, `Hero.totalZustandLevels` | ruling zaeher-hund-counts |
| 15 | Zäher Hund does nothing at Schmerz IV: after a passed Selbstbeherrschung check he should act at −3, GS −3 | `Hero.effectiveSchmerzLevel` | ruling zaeher-hund-iv |
| 15 | Verbesserte Regeneration III gives +2, not +3 | `Hero.verbessertRegenerationLEBonus` | page |
| 15 | A Vergiftet or Krank hero regenerates normally | `RegenerierenSheet` | page |
| 15 | Regeneration is never halved in a wet or cold camp, never stopped in a storm or tied to a horse, and the advantage's bonus is added even then | `RegenerierenSheet` | page; ruling vr-halving |
| 15 | Schnell wieder auf den Beinen is ignored: Betäubung and Berauscht show the full 3 h and 2 h | catalog `ADV_75` todo, `state.betaeubung.removal` / `state.berauscht.removal` | page; ruling alcohol-scope |
| 16, 18 | No Schadensbonus: TP never include the Leiteigenschaft above the Schadensschwelle (a Rabenschnabel with KK 15 does 1W6+4, should be 1W6+5; with KK 16, 1W6+6: 16.22, 18.17), though the export carries `primaryThreshold` on every weapon. Boronmir's own 1W6+4 is right only because his KK 14 is at the threshold | `OptolithImportService.formatDamage`, `parseItems`, `DamageModifiers.lines` | page |
| 16 | The weapon parry (with the passive shield bonus) is offered against ranged attacks; the defence never asks whether the attack is ranged | `CombatDefenseSetupView`, `OpponentProfile` | page |
| 16 | A Parierwaffe gives no passive PA bonus, and a Linkhand turns the loadout into a dual-wield | `Hero.passiveShieldPABonus`, `OptolithImportService` (drops `isParryingWeapon`), `Hero.isDualWielding` | page |
| 16 | Peitschen attack with MU instead of FF | `OptolithImportService.parseCombatTechniques`, `parseItems` | page |
| 16 | INI is stored as a total, so a change of Belastung mid-fight never reaches it | `Hero.activeCombatInitiative`, `CombatInitiativeRollView` | page |
| 16 | The take-damage screen has no "ignores RS" option | `CombatDamageViews` | page |
| 16 | LE is clamped at 0 and there is no "im Sterben" state | `CombatDamageViews`, `StateCatalog` | page |
| 16 | AT and PA are single numbers written at import with no breakdown; the passive shield bonus and the Belastung on INI are folded into the base with no line | `OptolithImportService`, `CombatAttackViews`, `DefenseRoute`, `CombatInitiativeRollView.heroBaseINI` | requirement; page |
| 17 | Beengte Umgebung has no shield rows: the Großschild never takes its −6 AT / −4 PA (every shield imports with reach kurz; no shield sizes exist) | catalog `GRW_beengteUmgebung`, `OptolithImportService.parseItems` | page |
| 17 | The Beengte Umgebung penalty on a parry follows the main weapon, not the parrying piece: bare hands + Großschild parries at 0 instead of −4 | `Situation.loadoutReach` | page |
| 17 | Mounted and attacked from behind, the shield parry is still offered and the shield's passive bonus stays on the weapon parry (Boronmir: 12 and 9; should be no shield parry, weapon parry 6); the weapon-arm side is never asked | `CombatDefenseSetupView`, `DefenseRoute.parryPossible`, `Hero.passiveShieldPABonus` | page (reiterkampf.RK5); ruling mounted-from-behind-shield |
| 17 | Mounted, a Passierschlag from a fighter on foot damages the hero; RK11 makes the mount the target, then RK10's Reiten check | `CombatDamageViews` | page (reiterkampf.RK11); ruling passierschlag-on-mount |
| 17 | The Angriff-von-hinten −4 is applied to a dodge against a ranged attack; it is for melee only | `CombatDefenseSetupView` | ruling from-behind-ranged |
| 17 | A Passierschlag cannot be aimed at a zone (Trefferzonen on); it may, at the full penalty without halving | `CombatAttackViews` (zone picker hidden) | ruling passierschlag-zone |
| 17 | A Passierschlag is a plain roll ≤ AT: at AT 0 a 1 misses, at AT 20+ a 20 hits | `CombatPassierschlagView` | ruling passierschlag-dice |
| 18 | Niederreiten uses the AT of the first attack parsed from the notes, not the Niederreiten line (right for Kupperus only because his Tritt is also 15) | `CombatAttackViews.niederreitenButton` | page |
| 18 | Niederreiten is offered for a mount with no Niederreiten line, with the first attack's AT and the export's dp | `CombatAttackViews.niederreitenButton` | ruling niederreiten-without-profile |
| 18 | A ridden horse's Tritt and Biss are offered beside the rider's own attack and rolled at once; they are orders that take the rider's action and a Reiten (Kampfmanöver) check | `CombatAttackViews.mountAttackSection` | page (reiterkampf.RK12); ruling mount-own-attack |
| 18 | The Dornenspitze's "nur gegen RS 6 oder mehr" note also invites the −2 against a creature's natural RS | `rsNote`, `CombatAttackViews.rsText` | ruling dornenspitze-rs |
| 18 | The Mächtiger Schlag Kraftakt penalty is rounded down: Kupperus (KK 25) −2, the page −3 | `CombatAttackViews` (`(kk - 20) / 2`) | page |
| 18 | The Großschild's "−1 AT auf die Hauptwaffe" is not applied | `OptolithImportService.shieldNote`, `MeleeModifiers` | page |
| 18 | Waffenvorteile and -nachteile always apply; they belong to the Fokusregel Waffeneigenschaften, which the app does not have | catalog `ITEMTPL_19`, `WeaponFumbleExtras`, `FokusRule` | page; ruling rabenschnabel-waffeneigenschaft |
| 18 | With that Fokusregel on, the Großschild's GS −1 and its INI-tie rule are missing, and its +1 PA note says "Fernkampf" where the page says Pfeile and Bolzen | `Hero.totalGsPenalty`, `shieldNote` | page |
| 18 | Kupperus can carry 210 Stein (Packesel); the app gives every pet KK × 2 = 50 | `Pet.carryingCapacity`, `Hero.totalCarryingCapacity` | page |
| 18 | Ruhiges Temperament (+1 on Reiten) is never applied: Boronmir's Reiten checks on Kupperus get 0, not +1. The export has no field for an animal's Vorteile; Kupperus's free-text `skills` names it (typed by the player), and the app shows that text only | `CombatMountPreCheckView`, `parsePets` (`Pet.specialSkills`) | page |
| 19 | Formation (SA_862) does not exist: no toggle, no +2 AT or VW | catalog SA_862 `todo`, `CombatAbility`, `CombatSetupView` | page |
| 19 | Eisern's +1 on the Wundschwelle is applied but named nowhere: the sheet shows only the total | `HeroDetailView` (`wundschwelle.max`), `CombatWundschwelleRow` | page |
| 19 | Schlechte Eigenschaft offers no Willenskraft check, and the GM's modifier for it has no line of its own | `HeroDetailView.disadvantagesSection`, `TalentProbeModal`, catalog DISADV_37 `todo` | page |
| 20 | No spell ever costs AsP: the cost is parsed with `Int(aeCostShort)`, and every one of the 781 costs in `rules.db` carries text ("16 AsP", "4 AsP + 2 AsP pro 5 Min") | `SpellProbeModal.baseCost`, `CombatSpellViews` | data |
| 20 | No Zaubermodifikation can be chosen (only "max N" as text); Geste/Formel weglassen never count toward the limit; a maintained spell's upkeep is never charged; Verbotene Pforten does not exist | `SpellProbeModal`, `Situation.spellModifications` (never set) | page |
| 20 | The Ablenkung table changes the spell check; the page puts it on the Selbstbeherrschung (Störungen ignorieren) check | `SpellProbeModal` | page |
| 21 | No ranged modifier names a rule (`rules: []` on all eight), and the distance TP is computed in the view | `RangedModifiers` | page |
| 21 | A ranged attack can be taken in melee; mounted there is no Trab and the Langbogen is offered; an invisible target is −6 instead of hit on a 1 only | `CombatRootView`, `RangedModifiers` | page |
| 21 | No Ladezeit, so Schnellladen does nothing; Zielen gives +2/+4 without spending the actions; cover can only be entered as a smaller "Größe" | `CombatFernkampfExecutionView`, `RangedModifiers` | page |
| 22 | No Fertigkeitsspezialisierung is applied (checks carry no Anwendungsgebiet); a hand-entered +2 lowers the attributes' Erschwernis instead of raising the FW, a different QS (22.3) | `TalentProbeModal`, `SkillCheckModal` | page |
| 22 | Begabung does not exist; the only reroll is a Schip, offered only on a failure | `SkillCheckModal` | page |
| 22 | A check can be rolled with an effective attribute of 0 or less; the modifier can be set per attribute, the page has one for all three | `SkillCheckModal` | page |

Confirmed correct: Belastungsgewöhnung (−1 Belastung per Stufe, extras kept); Belastung on spell
and liturgy casting; Schmerz on every check; the −5 Zustand cap; eight Zustand levels making a hero
Handlungsunfähig; the double-attack −2/−4 arithmetic and the off-hand parry.
