# Example 16 — Kampfwerte, Schaden und Schilde

**Status: draft.** Pages read 2026-09-24. Rulings: see [`RULINGS.md`](./RULINGS.md).

How Boronmir's AT, PA, AW and INI come about (from his 2026-09-24 sheet), what his weapons hit for, and how his Großschild
parries. These rules sit under every other example: each one's `base_hero` numbers come from here.

## Rules covered

| Id | Name | Page | Book |
|---|---|---|---|
| kampfwerte | Kampfwerte (AT, PA, AW, FK, INI) | <https://dsa.ulisses-regelwiki.de/Nahkampf.html>, plus [Schritt 9](https://dsa.ulisses-regelwiki.de/Heldenerschaffung/schritt-9-kampftechniken-berechnen.html), [Leiteigenschaften](https://dsa.ulisses-regelwiki.de/Heldenerschaffung/leiteigenschaften.html), [Kampftechniken](https://dsa.ulisses-regelwiki.de/Spezielle_Nahkampfregeln/kampftechniken.html), [Schritt 12](https://dsa.ulisses-regelwiki.de/Heldenerschaffung/schritt-12-basiswerte-berechnen.html), [Initiative](https://dsa.ulisses-regelwiki.de/Nah-_und_Fernkampf/initiative.html) | Regelwerk pp. 51, 56, 226, 229, 234; Kodex der Helden p. 21 |
| schaden | Schaden (TP, Schadensbonus, RS, SP) | <https://dsa.ulisses-regelwiki.de/Nahkampf.html>, plus [Kampftechniken](https://dsa.ulisses-regelwiki.de/Spezielle_Nahkampfregeln/kampftechniken.html), [Grundbegriffe](https://dsa.ulisses-regelwiki.de/Kampf_Grundbegriffe-des-Kampfes.html) | Regelwerk pp. 227, 229, 234 |
| schilde | Parierwaffen und Schilde | <https://dsa.ulisses-regelwiki.de/Nahkampf/parierwaffen-und-schilde.html>, plus [Schilde](https://dsa.ulisses-regelwiki.de/kampftechnik.html?kampftechnik=Schilde), [Grundbegriffe](https://dsa.ulisses-regelwiki.de/Kampf_Grundbegriffe-des-Kampfes.html) | Regelwerk pp. 227, 231, 236 |
| at-pa-modifikatoren | AT- und PA-Modifikatoren | <https://dsa.ulisses-regelwiki.de/GR_Kampf-AT-PA_Modifikatoren.html> | Regelwerk p. 366 |

The weapons themselves (Rabenschnabel, Langschwert, Großschild — their table rows, the Großschild's
−1 AT on the main weapon, its Waffenvorteil and -nachteil) are `rules/equipment/` and
[example 18](./kupperus-und-waffen.yaml). Each of the three core rules is assembled from several
pages; each clause from another page names it (`page:`). That is a format question in itself
(the `# FORMAT:` note at the top of `kampfwerte.yaml`).

## Clauses

**Kampfwerte**

- **KW1** AT = KtW + 1 per 3 full points of MU over 8.
- **KW2** PA = half the KtW + 1 per 3 full points of the technique's Leiteigenschaft over 8.
- **KW3** AW = GE / 2.
- **KW4** (Schritt 9) KW1 and KW2 again: the halved KtW is rounded **up**.
- **KW5** FK = KtW + 1 per 3 full points of FF over 8.
- **KW6** (Leiteigenschaften) The table: AT is MU for every technique **except Peitschen (FF)**; PA
  is GE or KK for Raufen, Schwerter, Stangenwaffen; GE for Dolche, Fächer, Fechtwaffen; KK for the
  rest.
- **KW7** (Kampftechniken) Where two Leiteigenschaften are listed, the hero takes the higher. A
  weapon's own Leiteigenschaft changes its Schadensbonus, never the PA.
- **KW8** (Schritt 12) AW again, with examples that round up (GE 15 → 8); advantages add.
- **KW9** (Schritt 12) INI-Basiswert = (MU + GE) / 2, rounded up per its example.
- **KW10** (Initiative) INI = Basiswert + 1W6 ± modifiers, rolled once for the fight.
- **KW11** Only special situations change it, "wie der Zustand Belastung": the W6 stays, the
  modifiers are live.
- **KW12–KW14** Order of acting, delaying, a Schip to act first — the GM's, or other rules'.

**Schaden**

- **S1** On a failed defence the attacker rolls TP; the target's RS comes off; the rest is SP, off
  the LE. (**S2**, **S6** say it again; S6 as TP − RS = SP.)
- **S3** Schadensbonus: +1 TP per point of the Leiteigenschaft above the weapon's Schadensschwelle.
- **S4** A weapon may name its own Leiteigenschaft for that.
- **S5** Some attacks (spells, some animals) ignore RS.
- **S7** Schmerz from lost LE → COND_6. **S8** At 0 LE the hero is dying.

**Parierwaffen und Schilde**

- **SCH1** A Parierwaffe or shield in the other hand adds its PA bonus to the main weapon's parry
  (passive); with several, only the highest.
- **SCH2** Both can also be used as weapons, with their own technique.
- **SCH3** A shield can instead parry actively with the Schilde PA and the bonus **doubled**.
- **SCH5** The shield parry takes no off-hand penalty.
- **SCH6** A shield can block ranged attacks and large attackers; a second shield adds nothing.
- **SCH8** (Schilde) Against ranged attacks only the **active** shield parry works, not the main
  weapon. **SCH9** (Grundbegriffe) No parry against ranged attacks, except with a shield.
- **SCH10–SCH11** The page's example (Carolan and Arbosch): 16.13–16.15.

**AT- und PA-Modifikatoren**

- **M1** A weapon's AT/PA-Mod applies after the base values.

## Boronmir's numbers

From the 2026-09-24 export: MU 14, GE 14, KK 14 (each +2); Hiebwaffen 14, Schwerter 12,
Schilde 10.

| | AT | PA (weapon) | PA (shield, active) | TP |
|---|---|---|---|---|
| Rabenschnabel | 16 | 9 − 1 = **8** | — | 1W6+4 (KK 14 is not above 14) |
| Langschwert | 14 | **8** (max(GE, KK) → +2) | — | 1W6+4 (14 is not above 15) |
| Rabenschnabel + Großschild | 16 − 1 = **15** | 8 + 3 = **11** | 7 + 2 × 3 = **13** | 1W6+4 |
| Langschwert + Großschild | **13** | 8 + 3 = **11** | **13** | 1W6+4 |
| Großschild as a weapon | 12 − 6 = **6** | — | — | 1W6+1 (KK 14 < 16) |

AW 14 / 2 = **7**; INI-Basiswert (14 + 14) / 2 = **14**. In his Plattenrüstung (Belastung I after
Belastungsgewöhnung II) every AT, PA and AW is 1 lower, and INI is 13 + 1W6.

None of his weapons gets a Schadensbonus any more: at KK 14 he is not above any of their
thresholds. The rule is kept with a hero who is (16.22).

## Situations

In [`situations/kampfwerte.yaml`](./situations/kampfwerte.yaml), 16.1–16.22. The rules as draft YAML:
[`kampfwerte`](./rules/core/kampfwerte.yaml), [`schaden`](./rules/core/schaden.yaml),
[`schilde`](./rules/core/schilde.yaml), [`at-pa-modifikatoren`](./rules/core/at-pa-modifikatoren.yaml).

## What the app gets wrong

Checked against `OptolithImportService` (parseCombatTechniques, parseItems, computeDerivedValues),
`DerivedValueFormulas`, `Hero`, `CombatAttackViews`, `DefenseRoute`, `CombatInitiativeRollView`,
`CombatDamageViews`.

- **No Schadensbonus, ever** (16.22). The import reads the TP dice and flat bonus
  (`formatDamage`) and drops `primaryThreshold`; nothing adds it later (`DamageModifiers.lines`).
  A Rabenschnabel in KK 16 hands hits for 1W6+4 instead of 1W6+6. Boronmir's own TP are right
  only because his KK 14 is not above any threshold (16.3, 16.7), and the app never says that
  no bonus applies. The Patzer table's "Eigener Waffenschaden (mit Schadensbonus)"
  (`FumbleTable`) names a bonus the app never computes. Basis: page (S3).
- **The weapon parry is offered against arrows** (16.9). The defence screen never asks whether the
  attack is ranged (`CombatDefenseSetupView`, `OpponentProfile`), so Boronmir can "parry" an arrow
  with his Langschwert at 11 instead of only with the shield at 13 or AW 7 — and without a shield,
  with a sword alone. Basis: page (SCH8, SCH9).
- **A Parierwaffe gives no passive bonus** (16.15). `Hero.passiveShieldPABonus` reads the shield
  only; the import drops `isParryingWeapon`; a Linkhand in the off hand makes the loadout a
  dual-wield (`Hero.isDualWielding`). Carolan's PA is 8, the page says 9. Basis: page (SCH1).
- **Peitschen attack with MU** (16.21). The import adds the MU bonus to every technique's AT; the
  table says FF for Peitschen. Basis: page (KW6).
- **INI is stored as a total** (16.12). `Hero.activeCombatInitiative` keeps the sum, so a change of
  Belastung mid-fight does not reach it. Basis: page (KW11).
- **No "ignores RS"** (16.19). The take-damage screen always subtracts the RS. Basis: page (S5).
- **LE stops at 0 and nothing says "im Sterben"** (16.20). `CombatDamageViews` clamps at 0 and
  there is no such state. Basis: page (S8).
- **No number says where it comes from.** AT and PA are single numbers written at import
  (`CombatTechnique.at/pa`, `MeleeWeapon.at/pa`, `Shield.pa`), with the MU and Leiteigenschaft
  bonuses, the weapon's AT/PA-Mod and the doubled shield bonus inside; the passive shield bonus is
  added to the parry's base value (`w.pa + hero.passiveShieldPABonus`) and the Belastung to the INI
  base (`CombatInitiativeRollView.heroBaseINI`), with no line. Basis: the requirement (every number
  says which rule it came from) and M1 (the mod is applied *after* the base value).

The Großschild's −1 AT on the main weapon is missing too (16.6, 16.7, 16.10); it is example 18's
finding (ITEMTPL_29.GR1), not repeated here.

Confirmed correct: AT = KtW + MU bonus; PA = ⌈KtW/2⌉ + Leiteigenschaft bonus, the higher of GE and
KK where both are listed; AW and INI rounded up; the passive shield bonus = the shield's PA-Mod; the
active shield parry = Schilde PA + 2 × PA-Mod, with no off-hand penalty; the shield attack at its
own AT-Mod; SP = max(0, TP − RS); INI = Basiswert + 1W6 − Belastung.

Aside, from the cross-check: the tests never assert Boronmir's derived combat values from his file
(`HeroImportTests` checks attributes, item counts, the shield's StP and the armour's RS/BE). The
hand-built fixtures that stand in for his gear (`CombatDefenseSetupTests`, `DamageModifiersTests`,
`RuleEvaluatorTests`, `WeaponInventoryTests`) use a Großschild of AT 6 / PA 11 and a Langschwert of
PA 7; the import gives AT 6 / PA 13 and PA 8. `Hesindion/Resources/UITestHero.json` is still his
earlier sheet (KO 13, KK 15, Hiebwaffen 12, Schilde 9).

## Rulings

- **`schilde.shield-bonus-raufen`** (decided, a) — the passive shield bonus reaches a Raufen parry:
  bare hands count as the Hauptwaffe. The app already adds it (16.16: PA 10).

The rounding of AW and INI rests on the decided `round-up` (and the page's own examples).
