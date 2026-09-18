# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

- Rules evaluator (issue #27, step 2): `implemented` catalog entries drive the roll through `RuleEvaluator`; the calculation lists every owned rule that did not apply and why, offers manoeuvres and choices from the catalog, and asks the GM for facts a rule needs (rendered in step 3). Fifteen entries are implemented: Mehrfache Verteidigung, Reichweite, Beengte Umgebung, Vorteilhafte Position, Zonenaufschlag, Karmale Objekte, Gezielter Angriff, Gezielter Schuss, Wuchtschlag, Plänkler-Formation, Golgariten-Stil, Vinsalt-Stil, Verweichlicht, Liegend, Überrascht.
- `specs/data/rule-vocabulary.json`: the closed clause vocabulary, exported from Swift and enforced by `make rules-db`.
- The announcement's opponent section asks, when the hero is mounted, whether the opponent fights on foot; Vorteilhafte Position and Golgariten-Stil read the answer.
- **The Patzertabelle applies its result instead of describing it.** Rolling "Sturz" used to end at the rulebook's sentence: the player left the fight, found Körperbeherrschung on the hero sheet, remembered the −2, rolled it, and on a failure added Liegend by hand — every step of which the app already does elsewhere (owner report). Each entry of all four tables now carries a typed effect. *Sturz* offers the Körperbeherrschung −2 check on the spot and, on a **failed** one, sets Liegend — after which the next attack is 4 harder and the next defence 2, as the rules already had it. *Beule* raises Betäubung by one. *Waffe/Schild zerstört, verloren* or *stecken geblieben* takes the thing out of the loadout slot it was actually in, and a Kraftakt −1 puts a stuck one back. *Selbst verletzt* and *Selbst schwer verletzt* roll the weapon's own damage (doubled on a 12) and open the take-damage screen with the TP already in, so the armour and the Wundschwelle still apply. The screen says what it wrote and the log line reads "Patzer: Sturz → Liegend". Stolpern, Fuß verdreht, Zerrung, "beschädigt", Ladehemmung, Zu konzentriert, Kamerad getroffen and Fehlschuss are stated as before — all of them are temporary modifiers the app has no mechanism for yet, and it now says so rather than leaving the reader to wonder.
- **A prone hero flees at GS 1.** Liegend's third effect had no reader: the Fluchtversuch screen took the Geschwindigkeit straight off the hero's derived values and offered someone lying in the mud their full eight paces. It reads `Hero.effectiveGeschwindigkeit` now and names Liegend as the source, the way a modifier row does.

### Changed

- `ModifierContext` is `Situation`; the opponent is a roster entry with stated states and GM facts.
- A modifier line from the catalog is labelled with the rule's name and carries its id.
- The prone opponent's row in the opponent's defence box reads "Liegend" (the rule's name) instead of "Ziel liegt"; the toggle that sets it keeps that label.
- The Zonenaufschlag catalog clause (`GRW_zonenaufschlag`) now checks the Trefferzonen Fokusregel itself, not only that a zone is set — the zone picker was already hidden with the rule off (both flows: `zonesActive`/`trefferzoneSection` gate it, and both also null the announced zone before it reaches the engine), so this closes a gap in the engine rather than fixing something a player could see.

### Removed

- The `effects` table, `specs/data/rules.yaml`, the Regelwiki scraper and `RuleEffectModifiers`. Seventy-nine hand-written rows for 26 rules, read by code nothing called; the catalog replaces all of it
- The damage half of the attack-execution screen — dice state, animation and roll — which nothing had called since the damage moved to the opponent-defence screen

### Fixed

- **The combat result screens did not scroll.** `CombatOpponentDefenseView`, `CombatFumbleChoiceView`, `CombatFluchtView`, `CombatPassierschlagView`, `CombatExecutionView`, `CombatTakeDamageView`, `CombatMountDamageView` and `CombatMountPreCheckView` each sat in a plain `VStack` with a trailing `Spacer()`; in landscape, where the app is mostly held, the damage calculation, the wound effect and "Neue Aktion" could run off the bottom edge with no way to reach them. The header now stays pinned on every one of them and everything below it scrolls, the shape the announcement screen already used.
- **A failed Parade/Ausweichen left the player to find "Schaden nehmen" on their own.** The execution screen's outcome and the fumble-choice screen's resolved Patzer only ever offered "Neue Aktion" after a failed defence, so a blow that got through meant backing out to the combat root to look for the take-damage button. The primary action there now goes straight to the take-damage screen, with "Neue Aktion" kept underneath as a visibly quieter secondary for the GM who rules the blow did nothing.
- Golgariten-Stil follows the Regelwiki: Rabenschnabel *or* Großschild, +2 AT only on top of an existing Vorteilhafte Position against a foot fighter, +1 PA mounted, and no TP bonus.
- Vinsalt-Stil: Mehrfache Verteidigung at −2 instead of −3 with a Fechtwaffe, Armbrust or Zweihandschwert in hand (was not applied).
- **The "n. Parade/Ausweichen · −x" preview under the defence buttons showed a number the roll did not charge.** It was a hard-coded −3 per defence already made; Vinsalt-Stil's own −2 step (SA_923) is a catalog rule on `GRW_mehrfacheVerteidigung`, so a Vinsalt hero read −3 on the button and was charged −2. The preview now reads the same `GRW_mehrfacheVerteidigung` line the roll itself uses.
- Verweichlicht: the Wundeffekt's Selbstbeherrschung check is 2 harder (was not applied).
- Vorteilhafte Position gives +2 PA as well as +2 AT, and a mounted hero has it against a foot fighter without the toggle.
- **The Zustände showed a name and nothing else.** Belastung, Betäubung, Furcht, Paralyse, Schmerz and Verwirrung have no prose description; their content is the four level texts, which the rule screen never read. It reads them now, as Stufe I to IV
- **Beidhändiger Kampf was found by searching the ability's name.** An export that carried it under a different or untranslated name gave no reduction of the dual-attack penalty at all. It is read by its id (SA_42) now, like every other ability the app handles
- **217 of the 226 combat Sonderfertigkeiten were filed as general abilities.** The importer asked whether `rules.db` had a combat-scoped effects row for an ability, and that table had rows for nine of them. It reads Optolith's group now (`CombatSpecialAbilityGroup`, checked against the database by name), so an imported Riposte or Sturmangriff lands in the combat list like Finte does. A hero imported before this keeps the old split on the sheet until re-imported; every rule lookup already searches both lists, so nothing mechanical changes for them
- **Plänkler-Formation never appeared, for a hero who has Plänkler-Formation.** The importer files a Sonderfertigkeit by whether `rules.db` carries a combat-scoped effect for it; SA_884 has no effects row at all, so it landed in the *general* list while `hasPlaenklerFormation` searched only the combat one. Gezielter Angriff and Gezielter Schuss were lost the same way — a hero who paid for exactly "halve the Zonenaufschlag" never got it halved. The lookup searches both lists now, because which list a trait sits in is a property of the data and not of the rule
- **Every Sonderfertigkeit the app handles is now covered by a test.** The ids were typed inline at a dozen call sites, and an ability can go missing in three ways that all look identical on screen — the ability is on the hero sheet, and the roll is merely a little low. They live in one `CombatAbility` enum (twelve today), checked against `rules.db` by name; where each is reached is recorded in the rules catalog, not in the enum itself; and importing a hero carrying an ability the catalog marks `todo` fails a test rather than going unnoticed at the table
- **The damage screen showed a third kind of calculation, of numbers that no longer applied to anything.** A MANÖVER block recapped the hero's own AT modifiers — reach, manoeuvre, Zonenaufschlag — as bare bordered rows, after the roll they modified had already been made, under a heading that did not say what they applied to. In its place is the one figure that *is* wanted there: what the GM takes off the opponent's defence, in the same box as every other calculation
- **The armour was a screen of its own.** It asked the same kind of question as the weapon two steps later, could not go back, and ended in a full-bleed summary bar under a full-bleed button. It is a section of the preparation screen
- **The loadout rows were the last radio buttons in combat.** Everything else says "chosen" with the accent fill (ADR-0010), so the preparation screen said it two ways at once. And Raufen is a fist, not an open hand
- **The app called a Langschwert a hammer.** `hammer.fill` stood in for every weapon in the loadout, because SF Symbols ships no weapons at all. The melee glyphs are the app's own now, drawn in the same flat hard-edged language as the rest of it and mapped from the weapon's combat technique
- **Three rules were keyed to the wrong combat techniques.** The ids were bare strings with the names in comments, and the comments did not match `rules.db`: the two-handed grip was withheld from `CT_1`/`CT_3` "Dolche, Fechtwaffen" — Armbrüste and Dolche — so every rapier could be gripped in two hands; "needs both hands, no good from the saddle" was applied to `CT_7`/`CT_14` "Zweihandschwerter, Stangenwaffen" — *Lanzen* and Wurfwaffen — which forbade a mounted hero the lance and waved a Zweihänder through; and `isSchusswaffe` was `CT_11`/`CT_12` "Armbrüste, Bögen" — Schleudern and Schwerter — so no bow in the game counted as a Schusswaffe. They are one enum now, checked against the database
- **Reach was read off the wrong weapon.** The reach penalty and the Beengte-Umgebung penalty both took `hero.selectedWeapon`, whatever was actually being swung: an off-hand attack borrowed the main weapon's reach, a Schildattacke likewise, and Raufen — for which `selectedWeapon` is nil — fell back to *mittel*, so a bare-handed hero closed on a spear for no penalty at all. Unarmed is kurz
- **Aufmerksamkeit's +2 was offered on the wrong check.** The hint was gated on `TAL_8`, which is Selbstbeherrschung; Aufmerksamkeit (SA_40) eases *Sinnesschärfe*, `TAL_10`. Every wound-effect probe in combat carried a bonus that does not apply to it. The same modal also arrived in the hero sheet's gold in the middle of a fight; it now wears the colour of the screen that raised it
- **The critical table said the same thing three times.** The 2W6 category and the 1W20 refinement were two green boxes of equal weight, both opening with "Die Trefferpunkte samt Modifikatoren werden verdoppelt", above a dark bar saying `×2`. One box now, the result named once and its effects on numbered lines, with the damage line generated from the *resolved* multiplier — a 1W20 band can halve its category's ×2, and quoting both would have the screen contradict itself
- **The take-damage screen never said what it had done.** It reported "16 LP verloren" and offered "Neue Aktion". How much is left, and what applies now, went unsaid — including the part nothing writes: Schmerz is derived from the LP total and steps up on its own
- **The damage screen offered to leave while it was still asking.** "Bestanden / Misslungen" for the opponent's Selbstbeherrschung and "Neue Aktion" were live at the same time, which reads as though the question were optional; leaving dropped an announced Wundeffekt out of the reported total without saying so
- **"Weiter" was not the same kind of button as "Bestätigen".** All three primary actions leave the screen for the next one, but "Weiter" was pinned edge to edge below the scroll view with no border and no shadow — a tab bar, not a step. One component draws all of them, in the content column, at the end of the flow
- The take-damage screen's `12 TP − 0 RS + 4 WE = 16` was a formula string in a dark bar, a third grammar next to the row-based calculations everywhere else, and it stood *above* the two inputs that feed it. It is the same box as the rest now, last on the screen, with the total at the end
- The adventure heading and its date bar were the only content flush with the pane edges, which is what made them read as too wide, and the navigation title repeated the heading a centimetre above it
- **The damage screen showed two calculations and the dice twice**: the weapon's total in one dark bar, then a second bar below the wound effect restating it with the Wundeffekt added, with the rolled dice printed above both. There is one calculation now, last, with every part in it — dice, weapon, abilities, anything by hand, a critical's multiplier, the Wundeffekt — and the dice stand down once they have been rolled (their individual results ride along in the row's label)
- **"Zugefügter Schaden" was the wrong name for the total.** The damage dealt is TP − RS and the opponent's RS is not modelled, so the app can only state the TP: the total says **Gesamte Trefferpunkte**
- The combat root's actions are grouped by what the rules call them — AKTION, REAKTION, SCHICKSALSPUNKTE, EINTRAGEN — instead of one list in which "Schaden nehmen", which is not a rules action at all, sat between the two defences. Colour now means one thing each: red is rolled, gold costs a Schip, dark only records. The teal on "Ausrüstung wechseln" was a colour used nowhere else in the app
- The Schicksalspunkte chip and the RS chip were built twice and came out different heights (SF Symbols have different bounding boxes); they are one builder now. "Verteidigung stärken" was the only action with a left-aligned label
- "Vorteilhafte Position (+2)" never said +2 to *what*, and "Ziel ist überrascht" never said what it does. Both now carry their effect: `AT +2` and "Zonenaufschlag 2 geringer"
- The attack roll's calculation printed "AT" on the base row only, where the modifier rows are bare numbers; only the total names the attribute now. The captions under the stepper and the dice sat 2pt apart in the gap they leave, because one clears a shadow and the other does not
- The adventure title was the bare navigation title — system chrome on a screen of bordered boxes. It is the boxed heading the hero pane uses
- A hint row inside the skill-check modal drew its own border inside a spacing-0 stack, so the neighbour drawn after it covered the shared edge and the row came out with three borders (ADR-0007)
- **The critical table's 2W6 read as the damage.** `4 + 3 = 7` sat in three bare boxes with the sum in a dark bar — the grammar this app uses for a *result total* — on a screen about damage, with nothing naming it. "Is the hit 7 or 14?" is the obvious question, and the screen answered neither. The roll is now the same breakdown box as every other calculation, and its total row says what it is: `Kategorie (2W6)`. The multiplier bar says when it lands: "Wird beim Schadenswurf angewandt" (the TP itself are not known until the damage is rolled, where the ×2 appears as the last row of the calculation)
- **A finished combat could not be deleted from the log.** The combat header only collapsed its rows, and a collapsed combat leaves nothing to swipe, so the single-entry swipe — the only way in — was out of reach as well. The header now carries a visible trash for the whole fight, with the number of entries named in the confirmation, and every row carries the same trash beside its timestamp (the swipe still works). Deleting reverses each entry's LP change, as a single delete already did (issue #13)
- The log's delete confirmation was a system `confirmationDialog` — rounded corners, blurred material, tinted text, on a screen built without any of the three. It is `DSAModal` now, drawn by `SplitContentLayout` rather than inside the panel, because a modal placed in a side panel is bounded by it
- The "Held" label above the LP bar was printed even on foot, where it labels the only bar on screen. It appears with the mount's bar, which is what it exists to tell apart (issue #24)
- **The first defence of a round was already at −3.** The Mehrfache-Verteidigung count was incremented as the Parieren or Ausweichen button was tapped and then read back for the very defence that had incremented it. It is now counted when a defence roll is set up, so the first defence of the round is unmodified, the second is at −3 and the third at −6 (issue #20)
- **Parries and dodges are counted apart.** Mehrfache Verteidigung applies per defence type, so having parried twice no longer makes the round's first dodge harder, and the two buttons price their own next defence ("2. Parade · −3", "1. Ausweichen") (issue #20)
- **A hero with a shield or a second weapon defended with no modifiers at all.** That loadout picks the parrying weapon first, and the weapon list rolled a bare PA: no Mehrfache Verteidigung, no Schmerz, no Belastung, no Schicksalspunkt boost, nothing. Both ways into a defence now build their lines from one `CombatSituation`, and the roll screen shows the calculation (issue #20)
- **A dual-wield attack was penalised twice.** The weapon list added the dual-attack and off-hand penalties to the row's own number and the modifier engine added them again on the announcement screen. The rows now carry the weapon's own value and the engine owns every situational modifier (issue #19)
- **The two-handed grip was worth +2 TP for a button that promises +1** — the attack-choice screen folded the bonus into the formula and the announcement screen folded it in again (issue #19)
- Golgariten-Stil's **+1 TP for melee attacks from horseback** (SA_661) was never applied; only the AT half of the style was wired up (issue #19)
- Plänkler-Formation grants "+1 AT **oder** +1 VW" (SA_884), and VW is parry *and* dodge — the app gave the defensive half on the dodge alone (issue #19)
- Damage dealt was only written to the log inside the Schicksalspunkt reroll button, so a hero with no Schips dealt damage that was never logged. It is now logged once, as the settled total, on the way out of the screen
- The initiative screen offered the mount's INI to an unmounted hero, and picked the base by value, so a hero and mount with equal INI lit both buttons (issue #15)

### Added

- **A rules catalog with a status for every rule.** `rules.db` now says, for each of its 2675 rules, whether the app applies it automatically, handles it in code (and where), has read it and found no roll it touches, or has not read it yet. The build refuses a database where a rule is missing from the catalog, a pointer names code that does not exist, or the counts move without the committed snapshot moving with them; the rule detail screen shows the status. Forty-five rules are on record today. Issue #27
- **Every rule screen says what Hesindion does with the rule.** A section "In Hesindion" states whether the rule is applied automatically, handled by the app, has no effect on any roll the app makes, or is not implemented yet, from the rules catalog
- **The announcement always shows what the attack will hit for**, not only when a manoeuvre adds to it — the damage is half of what the screen is announcing, and on an unmodified swing the screen used to end on the AT with "Weiter" apparently welded to it. `CombatActionButton` also carries its own clearance now: a raised box's shadow draws outside its bounds and reserves no layout space, so the nominal gap came out at 3pt and the action read as the calculation's last row
- **A modifier row says where it comes from.** "Auswirkung auf den Schaden" named the category of the thing, which is the one part the reader could already see. The rows now say *Kritischer Treffer*, *Schwerer Treffer* (the table's own result, where the Fokusregel is in play), *Geweihte Waffe der Gegengottheit* and *Von Hand eingetragen*
- **A reminder that an action can be delayed**, in the combat root's AKTION section. Not a button — delaying is something the player says to the table and the app has no turn order to reorder — but the option is easy to forget and there was nowhere else it would be read from
- **The opponent is a thing the app knows about now** (`OpponentProfile`), not a question re-asked on every swing. Their weapon's reach, the body plan and size their hit zones are rolled on, and whether they are a demon last as long as the fight; whether they are surprised, on the ground or out-positioned lasts the swing. It all lives in one folded GEGNER section on the announcement — shut by default, with what is set readable on the lid, because most attacks answer none of it
- **An attack can roll its Trefferzone instead of declaring one**, on the *opponent's* table. The receiving side has had the 1W20 since the rule went in; the attacking side could only name a zone and pay its Zonenaufschlag. The zones offered are the opponent's too — a four-legged opponent has no Arme, and the app was offering the hero's own table for everything
- **Ziel liegt.** Status Liegend is −2 on the prone fighter's *defence* (and −4 on their attacks); the rules give the attacker nothing for it, so it is printed where it belongs — on the opponent's defence, not folded into the hero's AT
- **A screen that prepares the fight.** Armour restated with its RS, the weapon and shield chosen, mounted, Beengte Umgebung and the Plänkler-Formation choice — all of it before the initiative is rolled and all of it in one place. The loadout used to be picked two steps *after* the initiative, and the setup screen was skipped altogether for a hero with neither the formation nor a horse, so nothing before the first attack showed what the hero was about to fight with. "Ausrüstung wechseln" from the combat root is unchanged
- **Karmale Objekte (Fokusregel, optional, off by default).** A geweihte Waffe deals regular damage to a demon — that it reaches one at all is the exception — and doubles against a demon of its opposing deity. Neither fact can be derived: which weapons are consecrated is a per-hero setting under the rule's own toggle, because no export carries a Weihe and a name says nothing (a Rabenschnabel is Boron's symbol and also an ordinary war pick), and what is on the other end is the GM's answer, asked on the announcement screen. The doubling is announced before the roll and is its own row of the damage
- **The announcement screen adds itself up.** Every modifier was on it, one row each, but the AT they came to only appeared on the *next* screen — so the decision this screen exists for was made without its result in view. It now ends with the attack as it will be rolled, what the manoeuvre does to the opponent's defence, and the damage: the same three boxes, in the same grammar, as the screens that follow
- **The Trefferzonentabelle follows the hero's species, not one table for everybody.** Zwerge are klein, Menschen and Elfen mittel, and the ranges differ — the same 1W20 picks a different zone. The species list is the Fokusregel's own; where it has no answer the hero settings ask, right under the Trefferzonen toggle, and the choice overrides the list either way
- **The zone reveal names the limb.** A paired zone is a pair, and the roll decides which: odd left, even right. The table prints "Arme (links / rechts)" and the row that was hit names the side it landed on
- **Every Wuchtschlag tier the hero has is offered, not only the highest.** Wuchtschlag II may be swung as a I, and the trade — −2 AT per +2 TP — is the whole decision; offering the top tier alone made it for the player
- **The opponent-reach chips print what they cost.** "Kurz / Mittel / Lang" said nothing about the −2 per step it costs to reach past a longer weapon; each option now carries its own AT figure, from the same rule the roll applies
- **The opponent's Selbstbeherrschung is asked for before a Wundeffekt applies.** The attack side stated the effect and offered its damage straight away, as though the Wundeffekt were automatic; the receiving side has always made the player roll the check first. The card now asks how the opponent's check went — the die is theirs, thrown at the table, so the app takes the outcome rather than rolling for the other side — and only a failed check offers the extra damage (issue #11 follow-up)
- **A number you can roll or be told is now one fork, not two controls.** The Wundeffekt damage offered a roll button *and* a stepper at the same time, which left "what wins if I roll and then type?" unanswered. You choose the route, a roll happens immediately, and only the chosen route's result stays on screen
- **The Trefferzone reveal shows the table it rolled on**, with the row the die landed in lit, instead of the line "7: Torso". The zone tables are short enough to print, and printing them makes the roll checkable
- **`DSAOrDivider` — an either/or now looks like one.** Three screens ask the player to pick one of two routes to the same answer (take the basic rule or roll the Kritische-Erfolge table, name the Trefferzone or roll 1W20, roll the Wundeffekt damage or enter what was rolled at the table), and each was two controls stacked in a box, which reads as two unrelated actions. They are one group with an ODER rule between them now, both branches at the same weight — the critical choice had a dark button and a red one, this app's secondary/primary idiom, which recommended the table where the rules recommend neither
- **The Wundschwelle is on the take-damage screen whether or not the Trefferzonen Fokus-Regel is on** — the comparison lived inside the Wundeffekt panel, which needs that rule *and* a rolled zone, so a group not using the rule had to remember the threshold and do the arithmetic in their head. The row states where the hit stands either way, and says what is still missing before a Wundeffekt rather than implying one it cannot name. The zone effect itself remains the focus rule's business (issue #23)
- **The damage roll shows every part**: the dice, the weapon's own bonus, each ability or manoeuvre that added to it, anything entered by hand, and a critical's multiplier last — `5 (1W6) +4 Waffe +2 Wuchtschlag = 11 TP`. The bonuses now travel to the roll as named parts instead of being folded into a formula string, which is what made them uncheckable and, twice, double-counted. The announcement screen shows the same calculation before the dice (issue #19)
- The AT/PA/AW calculation is **always** on the roll screen, even when nothing modifies it: "nothing is modifying this roll" is itself the answer, and a roll that shows only its result cannot be checked at all
- A **TP modifier** on the damage roll, for what the app cannot know: no Optolith export carries a weapon's Leiteigenschaft threshold, so the TP/KK bonus had nowhere to go (the equipment data itself is issue #14)
- The Parieren and Ausweichen buttons print what defending again will cost ("2. Verteidigung · −3") before it is paid
- `CombatSituation` and `DamageModifiers` — the round's flags and the TP bonuses as pure values, so both are unit-testable, plus `DamageFormula`, which replaces four copies of the damage-parsing regex and three of the bonus-adding one. `CombatBreakdownBox` is the calculation box, now shared by the melee roll, the ranged roll (which had its own copy, one bordered row per line) and the damage
- `DefenseModifierFlowTests` drives two parries in one round on a seeded shield loadout, `DamageBreakdownFlowTests` a Wuchtschlag through to its TP, and five screenshots of the two; `-uitest-shield` puts the shield in the loadout that sends a parry through the weapon list
- `ComplicatedAttackFlowTests` drives one attack carrying five modifiers at once — a longer opponent weapon, an advantageous position, a surprised target's head, Wuchtschlag II — confirmed as a critical and doubled, and asserts the 26 TP that comes out the far end. Each part was already covered on its own; this is the one that checks they still add up together (screenshots `34`–`36`). `-uitest-wuchtschlag` raises the seeded hero's tier
- `WeaponReachTests` covers the reach matrix, all nine combinations, which had no cover at all, and `HeroBodyPlanTests` the species → table lookup and its override. `WeaponReachTests` now also covers *whose* reach it is — the off-hand weapon, the shield, the fist — through the engine
- `CombatAbilityCoverageTests` — the ids against the rules, the lookup against both lists the importer might use, and the sample hero against the set of abilities the app implements. `CombatTechniqueIDTests` checks all 21 combat-technique ids against `rules.db`, and the three rules keyed to them; `KarmalWeaponTests` the per-hero consecrated-weapon setting (the doubling rule itself, `GRW_karmaleObjekte`, later moved to `RuleFixtureTests` with the rules catalog); `CombatPreparationFlowTests` and `KarmalWeaponFlowTests` the two new flows end to end, with four screenshots (`37`–`40`). `WeaponStyleFlowTests` the other half of the question — Golgariten-Stil pays +2 AT and +1 TP to a mounted hero with a Rabenschnabel and a Großschild, and nothing at all to the same hero on foot (screenshot `40`). `-uitest-weapon`, `-uitest-consecrate`, `-uitest-mounted`, `-uitest-plaenkler` and `-uitest-fresh-combat` pick the weapon, mark it geweiht, resume the fight in the saddle or in formation, and leave the hero *out* of a running fight so the preparation flow can be walked
- `WundschwelleFlowTests` and `CombatLogDeletionFlowTests` — the Wundschwelle without the focus rule, and a fight deleted from the log; `-uitest-fokus-off` switches a Fokus-Regel back off for a test, which the seed otherwise turns on for everybody
- `WoundEffectPayload` carries the `combatId` of the fight it was recorded in, so deleting that fight takes it too. Optional, because entries written before the field existed have no value for it

## [0.4.0-rc.2] - 2026-09-12

### Added

- The basic rule stays available with the table switched on: a confirmed critical asks whether to take it — doubled damage, the Passierschlag, or the undiminished defence — or to roll the table. The optional rule's own wording is permissive ("kann auch diese Tabelle benutzt werden"), and on a low roll the table is worse than what it replaces, so the trade is the player's to make at the moment it happens. This is the shape the Patzer screen has always had
- Kritische Erfolge (DSA 5 Fokus-Regeln, optional, off by default) — the three 2W6 tables from *Aventurisches Kompendium 2* that replace the basic critical outcomes: double damage on a confirmed critical AT/FK, the Passierschlag on a critical melee defence, and the undiminished next defence on a critical ranged defence. Each nests the Fokusregel's further 1W20, so 33 sub-tables in all, quoted in German as published. Switched per hero and per table on the hero settings screen, so a group can adopt one without the others
- The damage arithmetic a critical table names is carried into the total the app computes — `+2 TP`, `×1½` (rounded up), `×2`, `×3`, or nothing at all on the two results that change no damage. Conditions on the opponent and the "bis zum Ende der nächsten KR" bonuses are stated for the GM, because opponents are not modelled and the combat session has nowhere to hold a modifier that expires (ADR-0011)
- `CriticalSuccessFlowTests` — the critical table end to end on a scripted die, for both the attack table and the melee defence table withholding the Passierschlag on a low roll. A confirmed critical is a ~1-in-20 event, so it cannot be rolled for in a test
- Three new screenshots: the basic-rule-or-table choice, the basic rule taken, and the table with its category, its refinement and the resulting `×2`
- `-uitest-fokus` launch argument, switching further Fokus-Regeln on for a UI test instead of driving twenty taps of the settings screen first

### Changed

- `Color.dsaCritical` replaces `0x00c853` written out longhand in three combat files, and `Color.dsaPositive` replaces six more copies of `0x2E7D32` — the same consolidation `dsaSchipGold` already had. The last two text-sizing `.font(.system(…))` calls became `.dsaHeading`, so the type scale now governs every piece of text in the app
- Every settled dice roll now goes through `DiceRoller`, and every tumbling animation frame deliberately does not. Both halves were wrong somewhere: settled rolls on `Int.random` (the AT and FK rolls and their confirmations, all damage dice, both Schip rerolls, the initiative W6, the Passierschlag's AT, the fumble table's 2W6) could not be reached by `ScriptedDice` at all, which is why the wound-effect screenshot test retries its attack up to five times

### Fixed

- **No skill check could be driven to its Kritischer Erfolg or Patzer from a test.** `SkillCheckModal` drew its three *tumbling* dice from `DiceRoller` in an animation loop, emptying a `dice_script` long before the settled roll reached it — and every talent, spell, liturgy and Reiten check goes through that modal. Its Schip reroll had the inverse fault and used `Int.random`, so the branch after spending a Schip was unreachable too
- The published `Schwerer betäubender Treffer` sub-table skips 15–18 entirely; the app treats that band as "nochmal würfeln", which is what its neighbour does and the only reading that leaves every 1W20 resolvable. Found by asserting that all 33 sub-tables tile 1…20

## [0.4.0-rc.1] - 2026-09-12

### Added

- The attack side reports the total it dealt (`9 TP + 4 WE = 13 TP`), and the wound effect is settled before the button that leaves the screen rather than after it
- A screenshot of the skill-check modal and of the attack execution screen, so both can be reviewed as a diff like the rest
- Neobrutalism style layer — `DSABox` (the app's one surface: flat fill, 2pt border, square corners, hard offset shadow), `DSAStepper` (the `[−][value][+]` control), `DSAToggleRow`, `DSAModal`, `DSADiceRevealModal` and `DSAType`. The border idiom previously existed as 202 byte-identical copies of `.overlay(Rectangle().stroke(…))`, and the app had exactly one custom `ViewModifier` (ADR-0007 … ADR-0010)
- The hard offset shadow is back — the reference's signature element, absent from the app entirely. 5pt offset, zero blur, drawn in the border colour so it stays visible on the near-black dark surface. Carried by containers and primary actions only, so it marks importance rather than tappability (ADR-0008, ADR-0009)
- Press feedback on every button — a pressed surface moves into its own shadow and the shadow disappears, so it lands flush; segments inside a shared control flip background and label colour instead. 192 of 211 buttons were `.buttonStyle(.plain)` with nothing put back, and so were visually inert
- Selbstbeherrschung probe and Wundeffekt damage on the take-damage screen, settled by roll **or** by hand — at the table the number is as often spoken to you as rolled, and the app cannot tell which. The same control appears on the attack side, where the figure is informational because the opponent is not modelled (ADR-0005)
- Confirmed damage can be taken back — tapping a locked input offers to undo the entry, reversing the LP write, a dropped weapon and both log entries, so a mis-press no longer forces "Neue Aktion" and leaves wrong damage on the sheet
- The Trefferzone 1W20 is rolled in a reveal modal that shows the die and holds it until dismissed, instead of resolving silently
- `TakeDamageFlowTests` — end-to-end cover for the one combat flow with a branch in it (TP → Trefferzone → probe → both outcomes → Wundeffekt damage → apply), driven by a debug-only `dice_script` launch argument so both probe branches are reachable
- 17 numbered screenshots of the core surfaces, regenerated by `make screenshots`, including the take-damage flow as states

- Trefferzonen (DSA 5 Fokus-Regeln) — optional hit-zone rules, off by default and switchable per hero. Attacking: a zone picker feeds the Zonenaufschlag (Kopf −10, Torso −4, Gliedmaßen −8, halved by Gezielter Angriff/Schuss, eased by 2 against a surprised target) into the attack roll, and a read-only card states the zone's wound effect for the GM. Taking damage: the zone is tapped or rolled on 1W20, damage is compared against the Wundschwelle, and a failed Selbstbeherrschung check applies Betäubung (Kopf), Liegend (Beine) or an extra 1W3+1 SP (Torso). All ten published zone tables are implemented — humanoid, vierbeinig, sechsbeinig mit Schwanz, Fangarme, and creatures without distinct zones
- Per-rule Fokus-Regeln toggles in the hero settings screen — the optional rules are a table's house rules, so they are a per-hero setting that persists across combats, and a group can adopt individual rules rather than all or nothing
- The Optolith `raceId` is now persisted as `PersonalData.speciesId`, making species-dependent derived values recomputable in future
- `HesindionUITests` XCUITest target — the repo's first end-to-end UI tests. Four tests drive the Trefferzonen surfaces on the simulator and attach screenshots (`docs/screenshots/01-fokus-settings.png` … `04-wound-effect-panel.png`)
- `make screenshots` — runs the UI tests on the single named simulator and exports the attachments to `docs/screenshots/` via `xcresulttool export attachments` (`scripts/export_screenshots.py` renames the exports to the attachment names)
- Debug-only `-uitest-seed-hero` launch argument — seeds a throwaway store with the bundled sample hero, the Trefferzonen Fokus-Regel on and an open combat session, so UI tests start from the same state every run. Compiled out of Release builds and inert without the argument

- Zustände & Status tracking per hero — a static catalog of 8 DSA 5 Zustände (leveled I–IV) and 17 binary Status with localized effects, cause, and removal rules; managed via a "Zustände & Status" section on hero detail (swipe-to-remove rows, add picker, detail sheet with prominent removal rules) and a shared `StatesStrip` of chips in combat
- Automatic modifier integration for states: active Zustände feed penalties into the ModifierEngine with the DSA −5 Zustand-penalty cap; combat root shows a states strip, a Handlungsunfähig/Bewegungsunfähig warning banner, and per-round reminders
- Entrückung "gottgefällig" toggle in spell and liturgy casting
- Command palette (Cmd+K) entries for states — "Zustand: …" / "Status: …" set a level (0 removes), covering add/level/remove from the keyboard
- Drag-to-reveal (swipe) removal of states in hero detail, matching the app's `SwipeActionRow` edit style; the reusable `SwipeActionRow` was extracted to its own file
- Schip (fate point) reroll option on failed skill and spell checks — on a regular failure, the locked 3W20 dice become reroll-selectable (all selected by default) and a "Schip: Neuer Wurf" button spends one Schip to reroll the chosen dice
- UI snapshot testing infrastructure using swift-snapshot-testing
- Snapshot tests for 7 views (HeroList, HeroDetail, Combat, CombatRoot, Adventure, DiceRoll, WeatherDay) across 12 iPad/color/dynamic-type variants
- `make test-ui` and `make test-ui-record` Makefile targets
- TestData factory for creating fake SwiftData models in tests
- `DiceRoller` engine — pure, testable dice rolling with an injectable `RandomNumberGenerator`
- Statistical tests for dice fairness (`DiceRollerTests`): chi-square uniformity for W3/W6/W20, mean, serial-independence, and end-to-end 3d20 → SkillCheckEngine critical-rate checks
- Success-probability tests verifying sampled pass rates for realistic ability profiles match exact enumeration of all 8000 outcomes
- Per-ability **theoretical success rate** on each talent row — traffic-light dot + % computed by exact enumeration (`SkillCheckEngine.successProbability`)
- Per-ability **recorded success rate** (overall %, number of Proben, sessions, and best session), revealed under every talent row at once via the Talents section's **"Aufgezeichnete Werte"** toggle
- **Session grouping** of the action log into play sessions separated by ≥ 8h gaps (`SessionGrouper`), with per-session success-rate headers in the Log panel
- `TalentStatistics` engine for aggregating recorded checks, plus tests (`SessionGrouperTests`, `TalentStatisticsTests`, `SuccessProbabilityTests`)

### Changed

- A modal owns its own depth: `SkillCheckModal`'s panel casts, and nothing inside it does. The panel was flat on the scrim while three controls within it cast shadows onto their own neighbours — the modifier row printed one across the hint box beneath it
- The calculation breakdown on the attack execution screen is one box with dividers, ending in the effective value. Every row used to stroke its own rectangle, so each boundary was a doubled border, and the total was the only unbordered surface in the app
- The `Mod` caption sits clear of its stepper's shadow, which had been drawn over it
- The sidebar marks the active hero once. `List(selection:)` drew a second marker in the system accent on top of the hero's own, so the row was highlighted twice in two colours
- Equipping armour is shown by the fill like every other option; the Plattenrüstung row was the last `checkmark.circle` left, beside a "Beritten" toggle that already used the fill
- Every gap on the adventure screen accounts for the offset its shadows spend outside their own bounds, so the actions no longer sit under each other's shadow
- A critical result is announced by its colour, not by "!!! Kritischer Erfolg!"
- Type scale is two weights — 700 for headings, 500 for body, the reference's own pair. `.black` (900) at 201 sites and `.semibold` at 52 retired, along with 551 inline `.system(…)` fonts (ADR-0007)
- One border weight (2pt) everywhere. The 1pt and 3pt tiers are retired: emphasis is now shadow-or-not rather than a heavier line (ADR-0007, ADR-0008)
- Corners are square, recorded as `DSALayout.cornerRadius = 0`. Ten rounded outliers — avatar badges, the hero image, two adventure `Circle()`s and a `Capsule()` in the weather row — are squared to match (ADR-0009)
- A disabled or settled control loses its depth and its colour but never its contrast: page fill, full-strength border, full-strength label, no shadow. It was `tertiarySystemFill` paired with a white label, which made a confirmed entry unreadable exactly when you want to read it back (ADR-0010)
- One way of showing an option is on — the accent fill. The tickbox row is gone from Ziel ist überrascht, Vorteilhafte Position, Plänkler-Formation, Beritten, Beengte Umgebung, Kampfgetümmel, Waffe ablegen and the Fokus-Regeln (ADR-0010)
- Confirmations use the app's own modal rather than `.alert`, which brought rounded corners, blurred material and tinted system text onto screens built without any of them (ADR-0010)
- Combat root: the actions are one container with flat options, matching the Manöver and Trefferzone groups. Schicksalspunkte is no longer a section — both its buttons are actions and sit with the actions, carrying a printed `1 Schip` cost, and the count is a badge beside RS. The section used to split the action list in two and strand "Kampf beenden" after it (ADR-0010)
- The round row and the LP bar are single controls with one border and one shadow, built like `DSAStepper`. They were strips of separately bordered segments — the round row casting from its middle segment only, the LP bar drawing no border at all
- Sidebar rows are styled surfaces rather than stock `List` rows with a tinted background and system hairlines, which had made the sidebar read as a different app
- Weather days sit in one bordered box with inner dividers instead of a bordered card each, which read as a stack of heavy black bands
- The six copies of the `[−][value][+]` control are one `DSAStepper` with equal thirds; `DiceRollSheet`'s version had a fixed-width value segment, so its thirds came out visibly unequal

- `DiceRollSheet` and `SkillCheckModal` now route all rolls through `DiceRoller` instead of calling `Int.random(in:)` inline
- Recorded talent stats moved from per-row tap-to-expand to a single section-level toggle, keeping rows uncluttered while still showing the theoretical % inline
- Schmerz now flows through the new states system rather than a standalone computation, with Belastung counting toward the −5 Zustand cap
- The Beengte-Umgebung combat toggle now persists as the `eingeengt` status (its single source of truth) and survives combat exit

### Fixed

- Take damage shows the total it actually writes (`12 TP − 0 RS + 4 WE = 16`). The display stopped at `TP − RS`, so on a failed probe the screen showed 12 while the confirm wrote 16
- "Keine Zone" is no longer offered when the hero *takes* a hit — under the Fokus-Regel the zone is either named or rolled; declining to aim is an offence-side choice
- The Selbstbeherrschung probe modal no longer stays open behind the take-damage screen after the result is confirmed

- **Wundschwelle, Ausweichen and Initiative rounded down instead of up.** DSA 5 rounds derived values up — the Regelwiki's own example is KO 11 → Wundschwelle 6, which the app computed as 5. Every hero with an odd KO had a Wundschwelle one point too low; odd GE cost a point of Ausweichen and odd MU+GE a point of Initiative. Ausweichen and Initiative affect defence and turn order, so this is a visible change at the table. Existing heroes are corrected automatically at next launch
- The Wundschwelle modifiers Eisern (`ADV_54`, +1) and Gläsern (`DISADV_56`, −1) were never applied — the bonus was hardcoded to 0, unlike the neighbouring Seelenkraft and Zähigkeit traits
- Trefferzonen: the Fokus-Regeln activation was stored in the combat-session block and wiped by "Kampf beenden", so a group's house rules had to be re-enabled at the start of every fight. Activation is now a persistent per-hero setting on the hero settings screen and is no longer part of the combat flow
- Trefferzonen: a hero without a Selbstbeherrschung talent row had the Wundeffekt applied automatically, with no probe offered. Selbstbeherrschung is a DSA 5 basic ability every hero has, so that case was never a rules outcome — the probe is now always offered (falling back to Fertigkeitswert 0 if the row is missing), and a wound effect is applied only on a rolled, failed probe. Not rolling now means "the GM has not adjudicated" and applies nothing, removing the asymmetry where declining to roll was better than rolling
- Trefferzonen: the Arme Wundeffekt's "Waffe ablegen" button cleared the hero's equipped weapon immediately instead of participating in the confirm transaction, so navigating away from an unconfirmed take-damage flow left the hero disarmed with no LP change and no log entry. The action is now staged and only applied on confirm, alongside the single LP write and the log entry
- `make test`/`test-ui`/`test-ui-record` no longer clone the simulator per test worker (`-parallel-testing-enabled NO`, `-maximum-concurrent-test-simulator-destinations 1`); `test-ui-record` uses the correct `SNAPSHOT_TESTING_RECORD=all` value

## [0.3.0] - 2026-03-28

### Added

- General-purpose dice roller ("Würfeln") command with configurable count and sides, tumble animation, and action log integration

## [0.2.0] - 2026-03-23

### Added

- Generic ModifierEngine for unified modifier calculation across melee, ranged, defense, magic, liturgy, and talent checks
- Magic casting flow — standalone SpellProbeModal with expandable modifications section
- Combat spell casting — "Zaubern" action with spell selection, setup, multi-round casting with round tracker, and 3d20 execution
- Magic & Karma section in hero detail showing spells, liturgies, cantrips, and blessings with swipe-to-roll
- SkillCheckModal — unified 3d20 skill check UI shared by talents and spells
- Magic-specific modifiers: maintained spells, foreign tradition, gestures/formula, Bann des Eisens, distraction, spell modifications
- Effects scraper for populating rule effects from ulisses-regelwiki.de
- DB-sourced rule effect modifiers via RuleEffectModifiers loader

### Changed

- Melee attack, defense, and ranged modifiers now use ModifierEngine instead of hardcoded logic
- TalentProbeModal refactored to delegate to generic SkillCheckModal
- CheckDomain split: meleeParry and meleeDodge replace single meleeDefense for cleaner modifier targeting
- RulesDatabase.lookupEffects() made internal for engine access
- build_db.py now accepts both dict and flat list YAML formats for effects import

### Added (prior)

- Abenteuer (Adventure) system with weather generation
- Aventurian calendar with 12 months + Namenlose Tage
- Weather generator porting DSA 4.1 WdE p.156ff tables
- 13 climate regions from Ewiges Eis to Südmeer
- Day-by-day and bulk weather generation
- Date jumping with time-jump markers in timeline
- Plain-text weather export via share sheet
- Hero ↔ Adventure linking via hero settings
- New sidebar section for adventures

- Fernkampf (ranged) execution view: W20 FK roll with animated dice, modifier breakdown, critical/fumble confirmation, Schip reroll, and distance-adjusted damage formula
- Fernkampf criticals and fumbles mirror melee: roll 1 confirms critical hit (halved defense + double damage), roll 20 confirms fumble using the dedicated FK fumble table
- Opponent defense view now shows "Keine Parade mit Waffe möglich" and defense penalty hint for ranged attacks
- `CombatAction.fernkampf` added so FK fumbles route to the correct `FumbleTableType.fernkampf` table

- Passierschlag (free strike) view: AT-4 attack with no maneuvers, no critical successes or fumbles, with animated dice rolling and damage calculation
- Passierschlag button on critical parry success in defense outcome
- Per-profession color schemes for hero detail views (19 palettes: priests by deity, warriors, mages, mundane)
- Hero settings view accessible via command palette ("Einstellungen für <Hero>")
- Color scheme picker with visual swatch previews and automatic profession-based detection
- Combat execution rolls (AT/PA/AW) now logged automatically with outcome and effective value
- Schip reroll usage logged as dedicated combat action entry

### Changed

- Combat log descriptions enriched: critical/fumble markers on attacks, TP instead of "Schaden ausgeteilt", structured schip/fumble/flucht/opponent-defense text

- Mount pre-check (Galopp + Reiten) redesigned as single-screen vertical flowchart with collapsing steps and connector arrow
- Talent probe modal: enlarged modifier buttons (44pt tap targets) for easier use
- Talent probe modal: constrained max width to 400pt on wide screens
- Sidebar title centered via toolbar principal item
- Panel toggle buttons now have filled backgrounds with white icons (no borders)
- Redesigned landscape sidebar panel buttons — bold 48×48 squares flush to screen edge with distinct amber/teal/purple colors, dark mode adaptive

### Fixed

- LP (Lebenspunkte) calculation now includes species base value (e.g., +5 for humans, +8 for dwarves) — previously only used KO × 2
- "Held importieren" button text readability (black text on gold background)
- Selected hero row visibility in sidebar (increased highlight opacity)
- Removed unnecessary trailing border from attributes column

### Added

- Action log (Protokoll) with event sourcing — all talent checks, combat damage, healing, and resting are recorded as reversible log entries
- Log panel (Protokoll) viewable in split-screen with combat grouping, swipe-to-delete with automatic state reversal
- Split-screen layout — Notes, Protokoll, and Regelwerk panels available in 50/50 split (landscape) or full-screen overlay (portrait)
- Heilung command — heal hero with source tracking and logging
- Reittier: Heilung command — heal mount with logging
- SchemaV3 migration with LogEntry model
- Adaptive content width modifier for iPad: proportional margins (~6% per side) with 700pt max-width cap, standard 16pt padding on iPhone
- Notes panel ("Notizen") sidebar toggleable via toolbar button on iPad in both hero detail and combat views
- Hero.notes property persisted via SwiftData with SchemaV2 lightweight migration
- ContentWithNotesLayout wrapper for consistent notes panel integration across views
- Adaptive attributes column fixed to left side in iPad landscape mode
- Inline probe attribute abbreviations (e.g., KL, CH, GE) in talent rows
- Personal data fields display in responsive grid layout (2-3 columns)
- Ctrl+K keyboard shortcut to open command palette
- LP (Lebenspunkte) bar for all pets in hero detail view
- Mount LP bar in combat view when mounted combat is active
- Mount damage with automatic Reiten (Kampfmanöver) check — penalty scales +1 per 5 SP; Sturz warning on failure
- "Reittier: Schaden" command in command palette for normal mode
- TalentProbeModal now accepts an initial modifier for pre-applied penalties

### Changed

- Replaced notes-only right sidebar (ContentWithNotesLayout) with flexible SplitContentLayout supporting Notes, Protokoll, and Regelwerk panels
- Panel toggle buttons now built into layout instead of toolbar
- Combat view: replaced per-element horizontal padding with adaptive content width modifier for consistent iPad margins
- Mount combat: Reiten check now uses the full talent probe modal with dice rolls instead of a simple Yes/No dialog
- Moved mount attacks from combat root view to attack selection screen
- "Ausruestung wechseln" button restyled with teal accent for better visual distinction
- Weapon and shield selection merged into single loadout step
- Renamed project from iDSACompanion to Hesindion (after Hesinde, DSA goddess of wisdom)

### Added

- Niederreiten and Sturmangriff zu Pferd as selectable attacks in the attack choice screen
- Galopp confirmation and Reiten (Kampfmanöver) check flow before mounted charge attacks
- Mount attacks (regular, Niederreiten, Sturmangriff zu Pferd) grouped in attack choice view alongside hero attacks
- Mächtiger Schlag reminder for mount attacks: when the mount has "Mächtiger Schlag" in its special skills, an info banner shows during attack execution explaining the Kraftakt check rule, including the calculated penalty from the mount's KK
- SwiftData VersionedSchema and SchemaMigrationPlan for safe schema migrations
- Modifier breakdown for defense actions: Parieren and Ausweichen now compute and display labeled modifier lines (Belastung, Schmerz, Golgariten-Stil PA bonus, Plänkler-Formation AW bonus, mounted dodge penalty, dual-attack penalty) with an effective total, matching the attack announcement breakdown
- Vorstoß defense lock: Parieren and Ausweichen buttons disabled (grey) when Vorstoß active this round, with warning note below
- Schmerz indicator in combat root view: badge showing pain level and penalty when effectiveSchmerzLevel > 0
- Mount attacks section in combat root: when mounted, show pet attack list with AT values; each attack skips the announcement step
- Two-handed weapon selection disabled when mounted (greyed out with "Beritten" note in loadout view)
- Auto-select mount INI base on initiative screen when mounted mode is active
- Modifier breakdown in combat execution view: labeled rows show base AT/PA/AW, each situational modifier (Belastung, Schmerz, Vorteilhafte Position, maneuver, dual-wield, off-hand) and manual zusätzlich adjustment, with a dark "Effektiv" total bar; falls back to simple value box for defense paths without a full breakdown
- Announcement step between weapon selection and execution: maneuver selection (Normal, Finte, Wuchtschlag, Vorstoß, Schildspalter, Sturmangriff) with Vorteilhafte Position toggle and full AT/damage modifier pre-calculation
- Combat setup step between armor selection and initiative: Plänkler-Formation toggle (AT or AW bonus) and mounted toggle for eligible heroes
- Vorstoß and active maneuver state reset on round advance
- Schmerz penalty warning and modifier applied to talent probe results in TalentProbeModal
- Aufmerksamkeit (SA_40) contextual hint shown in talent probe for Sinnenschärfe (TAL_8)
- Schmerz (pain) tracking: raw level from LP thresholds, Zäher Hund (ADV_49) reduction, penalty computation
- Combat ability detection helpers: Aufmerksamkeit, Golgariten-Stil, Berittener Kampf, Finte, Wuchtschlag, Vorstoß, Schildspalter, Plänkler-Formation
- Mount detection and Sturmangriff damage bonus computation
- Combat setup screen flag (needsCombatSetup) for Plänkler-Formation and mounted heroes
- Combined equipment loadout view (weapons + shields in one screen with checkboxes)
- Dual-wielding support for heroes with Beidhaendig (ADV_5) advantage
- Pre-attack choice: "Eine Waffe" vs "Beide Waffen" for dual-wield heroes
- Two-handed grip option (+1 TP, -1 PA) for eligible one-handed weapons
- Vorteilhafte Position per-roll toggle (+2 AT/PA/AW) on combat execution screen
- Off-hand penalty display and calculation for dual-wield combat
- Dual-attack penalty tracking per combat round (resets on round advance)
- Dual-attack second strike flow with fumble handling (Patzer cancels second attack)
- Combat loadout system: select main weapon + shield at combat start, persists across sessions
- Passive shield PA bonus on main weapon parade (single modifier per DSA 5 rules)
- Active shield parry with doubled PA bonus
- Shield-specific combat notes (e.g., Großschild "+1 PA vs. Fernkampf")
- Loadout-aware Angriff/Parieren: skip weapon list when no shield, simplified choice when shield equipped
- "Ausrüstung wechseln" button to change loadout mid-combat
- Armor equip/unequip system with `isEquipped` toggle (swipe-left in hero detail, toggle in combat)
- Belastung (encumbrance) system: effective BE, Belastungsgewöhnung support, penalties on AT/PA/AW/INI/GS
- Belastung penalty display as separate modifiers on combat stats (e.g., "AT 12 (-1)")
- Combat flow: armor selection → initiative roll → combat root (replaces direct-to-root)
- "Schaden nehmen" combat action: TP input → RS calculation → LP reduction with confirm
- Armor management during combat via shield button and modal sheet
- INI/GS direct modifiers on armor model (parsed from Optolith `iniMod`/`movMod`)
- 17 new DE/EN localization strings for damage and armor system
- Adaptive border colors and combat technique AT/PA design docs
- Ranged weapons UI with combat technique ID-to-name resolution
- RangedWeapon model and ranged weapons import
- Attribute-by-ID resolver to Attributes model
- Combat technique detail lookup in RulesDatabase
- Full set of 59 standard talents included on import (missing ones default)
- Hero avatar display in sidebar list rows
- Direct Optolith export import (replacing custom hero JSON import)
- Rule lookup sheet, app icon variants, and UI polish
- Rules system with spells, liturgies, and rulebook UI
- Regenerieren command to restore Lebensenergie via 1W6 roll
- Combat section labels, step transitions, and expanded combat spec

### Fixed

- PA rounding: use ceil(KtW/2) instead of floor per DSA 5 rules
- Initiative re-roll sheet now includes Belastung penalty in base INI
- Weapon AT/PA calculations to use DSA 5 formulas
- AT/PA calculation and listing of all combat techniques
- Numeric select-option IDs resolved to names during hero import
- Button heights in combat root view
- LP bar display at zero value

### Changed

- Parieren/Ausweichen moved to own rows
- LP bar pattern reused in hero view Lebensenergie modal
- INI row height reduced by halving vertical padding
- Added Makefile, fixed UIFileSharingEnabled, and simplified command palette
