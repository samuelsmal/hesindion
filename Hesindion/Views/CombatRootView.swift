import SwiftUI
import SwiftData

// MARK: - CombatRootView

struct CombatRootView: View {
    let hero: Hero
    @Binding var step: CombatStep
    @Binding var rolledInitiative: Int?
    @Binding var roundNumber: Int
    @Binding var dualAttackPenaltyActive: Bool
    @Binding var twoHandedGripActive: Bool
    @Binding var vorstossActiveThisRound: Bool
    @Binding var beengteUmgebungActive: Bool
    @Binding var parriesThisRound: Int
    @Binding var dodgesThisRound: Int
    @Binding var schipDefenseBoostActive: Bool
    @Binding var schipIgnoreZustandThisRound: Bool
    @Binding var mountedActive: Bool
    let plaenklerActive: Bool
    let plaenklerBonus: PlaenklerBonus
    /// The other side, for the defences rolled straight from this screen. A
    /// plain value, not a binding: the root reads the opponent, it never states
    /// anything about them — the announcement screen is where that is done.
    let opponent: OpponentProfile
    var onDismiss: () -> Void
    var castingSpell: (spell: HeroSpell, startRound: Int, totalRounds: Int, modifierLines: [ModifierLine])? = nil

    @State private var showInitiativeSheet = false
    @State private var showArmorSheet = false

    /// The flags this round is in, as one value — the same one the weapon list
    /// gets, so both ways into a defence are modified alike.
    private var situation: CombatSituation {
        CombatSituation(
            mounted: mountedActive,
            schipIgnoreZustand: schipIgnoreZustandThisRound,
            dualAttackActive: dualAttackPenaltyActive,
            beengteUmgebung: beengteUmgebungActive,
            twoHandedGrip: twoHandedGripActive,
            parriesThisRound: parriesThisRound,
            dodgesThisRound: dodgesThisRound,
            schipDefenseBoost: schipDefenseBoostActive,
            plaenklerActive: plaenklerActive,
            plaenklerBonus: plaenklerBonus
        )
    }

    private func buildDefenseModifiers(isAusweichen: Bool) -> [ModifierLine] {
        situation.defenseModifiers(hero: hero, isAusweichen: isAusweichen, opponents: OpponentRoster([opponent]))
    }

    /// Whether a defence can be made at all this moment. Vorstoß gives it up for
    /// the round; the Fernkampf-Patzer *Zu konzentriert* gives it up until the
    /// hero's next own action. Two rules, one button state — and each says which
    /// of them it is, underneath.
    private var defenseBlocked: Bool {
        vorstossActiveThisRound || hero.activeCombatNoDefense
    }

    /// "2. Parade · −3" under the button that charges it, so the cost of
    /// defending again is known before the next screen. Each button counts its
    /// own kind: parries and dodges are tracked apart.
    ///
    /// Read off `buildDefenseModifiers(isAusweichen:)` — the same lines the
    /// button's own tap hands to the roll (`GRW_mehrfacheVerteidigung`), built
    /// from the round's counters as they stand right now, before the defence
    /// being offered increments them. A style that changes the step (Vinsalt,
    /// SA_923) is a `modifyRule` on that same line, so the button can no longer
    /// print a number the roll does not charge.
    private func defenseCostSubtitle(isAusweichen: Bool) -> String? {
        let made = situation.defensesSoFar(isAusweichen: isAusweichen)
        guard made > 0 else { return nil }
        return String(
            format: L(isAusweichen ? "defense.nthDodge" : "defense.nthParry"),
            made + 1,
            Self.pendingDefensePenalty(in: buildDefenseModifiers(isAusweichen: isAusweichen))
        )
    }

    /// The `GRW_mehrfacheVerteidigung` line's value among a defence's modifier
    /// lines, or `0` if the round has none yet. Pure, so the number the button
    /// prints can be asserted straight from the lines the roll would use.
    static func pendingDefensePenalty(in lines: [ModifierLine]) -> Int {
        lines.first { $0.ruleId == "GRW_mehrfacheVerteidigung" }?.value ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L("combat"))
                    .font(.dsaHeading(.headline))
                    .foregroundStyle(.white)
                Spacer()
                Text(hero.name)
                    .font(.dsaHeading(.headline))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.dsaBody(.body))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.dsaMotion)
                .accessibilityLabel("Kampf schließen")
                .accessibilityIdentifier("combat.close")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(combatAccent)
            .dsaBox(.raised)

            ScrollView {
            VStack(spacing: 0) {
            // RUNDE section
            combatSectionLabel(L("round.label"))

            // INI + round counter + Neu button — one control, like `DSAStepper`:
            // the row owns the border and the shadow, its four segments are
            // divided by rules. Previously each segment drew its own box and
            // only the round counter was `.raised`, so the row read as a shadow
            // stuck to the middle of a strip of joined boxes.
            HStack(spacing: 0) {
                // INI box
                VStack(spacing: 2) {
                    Text("INI")
                        .font(.dsaBody(.caption))
                        .foregroundStyle(.white)
                    Text("\(rolledInitiative ?? hero.derivedValues?.initiative.value ?? 0)")
                        .font(.dsaHeading(.title3))
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .frame(minWidth: 64)
                .frame(maxHeight: .infinity)
                .background(Color.dsaDark)

                roundRowRule

                // Round counter
                Text("\(L("roundPrefix")) \(roundNumber)")
                    .font(.dsaHeading(.title3))
                    .fontDesign(.monospaced)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))

                roundRowRule

                // Next round button
                Button { roundNumber += 1 } label: {
                    Image(systemName: "arrow.right")
                        .font(.dsaBody(.body))
                        .frame(width: 52)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(DSASegmentPressStyle(tint: combatAccent, foreground: .white))
                .accessibilityIdentifier("combat.nextRound")

                roundRowRule

                // Neuer Kampf compact button
                Button { showInitiativeSheet = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "dice.fill")
                            .font(.dsaBody(.caption))
                        Text(L("new"))
                            .font(.dsaHeading(.caption))
                    }
                    .padding(.horizontal, 8)
                    .frame(minWidth: 64)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(DSASegmentPressStyle(tint: Color.dsaDark, foreground: .white))
            }
            .fixedSize(horizontal: false, vertical: true)
            .dsaBox(.raised)
            .sheet(isPresented: $showInitiativeSheet) {
                CombatInitiativeSheet(
                    heroBaseINI: (hero.derivedValues?.initiative.value ?? 0) + hero.totalIniPenalty,
                    mountBaseINI: hero.pets.first.flatMap { pet in
                        Int(pet.initiative.split(separator: "+").first ?? "")
                    },
                    mountName: hero.pets.first?.name
                ) { result in
                    rolledInitiative = result
                    // The round count starts over, and the Patzer clocks are
                    // absolute round numbers: rebase them first, while the old
                    // count is still readable, or a Zerrung from round 6 would
                    // keep running until round 8 of the *new* count.
                    hero.rebaseCombatClocks(fromRound: roundNumber, toRound: 1)
                    roundNumber = 1
                    showInitiativeSheet = false
                }
                .presentationCornerRadius(0)
            }

            if hero.derivedValues != nil {
                // LEBENSPUNKTE section
                combatSectionLabel(L("lifePoints.label"))

                // Only worth printing when the mount's bar follows it: the label
                // exists to tell the two bars apart, and on foot there is one bar
                // under a heading that already says LEBENSPUNKTE.
                if mountedActive, hero.pets.first != nil {
                    Text(L("hero"))
                        .font(.dsaMono(.caption, emphasis: true))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }

                lpBar

                if mountedActive, let mount = hero.pets.first {
                    Text(mount.name)
                        .font(.dsaMono(.caption, emphasis: true))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    LPBarView(
                        current: mount.currentLifeEnergy,
                        max: mount.lifeEnergy,
                        accent: Color(red: 0x0d / 255, green: 0x96 / 255, blue: 0x88 / 255)
                    ) {
                        guard mount.currentLifeEnergy > 0 else { return }
                        mount.currentLifeEnergy -= 1
                    } onIncrement: {
                        guard mount.currentLifeEnergy < mount.lifeEnergy else { return }
                        mount.currentLifeEnergy += 1
                    }
                }

                // STATUS section
                combatSectionLabel(L("status.label"))

                // Incapacitation warning banner — impossible to miss, top of STATUS.
                if hero.isHandlungsunfaehig {
                    combatWarningBanner(
                        icon: "hand.raised.slash.fill",
                        text: L("states.handlungsunfaehig.banner")
                    )
                }
                if hero.isBewegungsunfaehig {
                    combatWarningBanner(
                        icon: "figure.stand",
                        text: L("states.bewegungsunfaehig.banner")
                    )
                }

                // Active player states strip (Schmerz, Belastung, Furcht, Liegend, …),
                // addable mid-combat via the picker, tappable to the detail sheet.
                StatesStrip(hero: hero, accent: combatAccent)
                    .padding(.top, 4)

                // Per-round reminders for timed effects (Blutend, Brennend, …).
                let perRoundReminders = hero.activeStates.compactMap { entry -> (StateDefinition, String)? in
                    guard let key = entry.def.perRoundReminderKey else { return nil }
                    return (entry.def, L(key))
                }
                if !perRoundReminders.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(perRoundReminders, id: \.0.id) { def, reminder in
                            HStack(spacing: 6) {
                                Image(systemName: def.iconSystemName)
                                    .font(.dsaBody(.caption2))
                                Text("\(L(def.nameKey)): \(reminder)")
                                    .font(.dsaMono(.caption2, emphasis: true))
                            }
                            .foregroundStyle(combatAccent)
                        }
                    }
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Beengte Umgebung toggle — a quick shortcut bound to the `eingeengt`
                // status (so it also appears as a chip above and persists like other states).
                Button { beengteUmgebungActive.toggle() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: beengteUmgebungActive ? "square.split.bottomrightquarter.fill" : "square.split.bottomrightquarter")
                            .font(.dsaBody(.caption))
                        Text(L("beengteUmgebung"))
                            .font(.dsaMono(.caption, emphasis: true))
                    }
                    .foregroundStyle(beengteUmgebungActive ? .white : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(beengteUmgebungActive ? combatAccent : Color(UIColor.secondarySystemBackground))
                    .dsaBox(.flush, stroke: beengteUmgebungActive ? combatAccent : Color.dsaBorder)
                }
                .buttonStyle(.dsaMotion)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Beritten/Zu Fuß toggle — only when the hero brought a mount into
                // this fight. Flipping it feeds every later roll through
                // `situation.mounted`, not just the setup-time flag; the LP bar for
                // the mount and the mount attack section above already read
                // `mountedActive` and follow along.
                if hero.hasMount, let mount = hero.pets.first {
                    Button { mountedActive.toggle() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mountedActive ? "figure.equestrian.sports" : "figure.walk")
                                .font(.dsaBody(.caption))
                            Text(mountedActive ? String(format: L("combat.mounted.on"), mount.name) : L("combat.mounted.off"))
                                .font(.dsaMono(.caption, emphasis: true))
                        }
                        .foregroundStyle(mountedActive ? .white : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(mountedActive ? combatAccent : Color(UIColor.secondarySystemBackground))
                        .dsaBox(.flush, stroke: mountedActive ? combatAccent : Color.dsaBorder)
                    }
                    .buttonStyle(.dsaMotion)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("combat.mounted.toggle")
                }

                // A spent Schip is a state of this round, not an action, so it
                // is reported here rather than left as a dead button among live
                // ones.
                if schipDefenseBoostActive {
                    schipSpentChip(icon: "shield.checkered", title: L("schip.defenseBoost"))
                }
                if schipIgnoreZustandThisRound {
                    schipSpentChip(icon: "bandage", title: L("schip.ignoreZustand"))
                }

                // Loadout + Armor in one row
                HStack(spacing: 8) {
                    if let weaponName = hero.selectedWeaponName {
                        WeaponIconView(hero.loadoutIcon(for: weaponName))
                            .font(.dsaBody(.caption))
                        Text(weaponName)
                            .font(.dsaMono(.caption, emphasis: true))
                        if let offHandName = hero.selectedOffHandName {
                            Text("+")
                                .font(.dsaBody(.caption))
                                .foregroundStyle(.secondary)
                            WeaponIconView(hero.loadoutIcon(for: offHandName))
                                .font(.dsaBody(.caption))
                            Text(offHandName)
                                .font(.dsaMono(.caption, emphasis: true))
                        }
                    }

                    Spacer()

                    // Schicksalspunkte, beside RS. Both are at-a-glance
                    // resources and this row is already where the eye goes for
                    // them; the SCHICKSALSPUNKTE section that used to carry this
                    // count existed only to hold two buttons that are now
                    // actions among the actions.
                    if let schips = hero.derivedValues?.schicksalspunkte, schips.max > 0 {
                        resourceChip(
                            icon: "sparkles",
                            text: "\(schips.current)/\(schips.max)",
                            fill: Color.dsaSchipGold
                        )
                        .accessibilityIdentifier("combat.schip.count")
                    }

                    Button { showArmorSheet = true } label: {
                        resourceChip(
                            icon: "shield.fill",
                            text: "\(L("rs")) \(hero.totalRS)",
                            fill: Color.dsaDark
                        )
                    }
                    .buttonStyle(.dsaMotion)
                }
                .foregroundStyle(.primary)
                .padding(.top, 4)
                .sheet(isPresented: $showArmorSheet) {
                    CombatArmorManagementSheet(hero: hero)
                        .presentationCornerRadius(0)
                }
            }

            // Casting-in-progress banner
            if let casting = castingSpell {
                let currentRound = roundNumber - casting.startRound + 1
                HStack {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(.white)
                    Text(String(format: L("spellCasting.banner"), casting.spell.name, currentRound, casting.totalRounds))
                        .font(.dsaBody(.caption))
                        .foregroundStyle(.white)
                    Spacer()
                    if currentRound >= casting.totalRounds {
                        Button(L("continue")) {
                            step = .spellExecution(spell: casting.spell, modifierLines: casting.modifierLines)
                        }
                        .font(.dsaHeading(.caption))
                        .foregroundStyle(Color.groupMagic)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(UIColor.secondarySystemBackground))
                    }
                    Button(L("spellCasting.abort")) {
                        step = .root
                    }
                    .font(.dsaBody(.caption))
                    .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.groupMagic)
                .dsaBox(.flush)
            }

            // AKTION section
            combatSectionLabel(L("action.label"))

            // Not a button: delaying is something the player *says*, to the
            // table, and the app has no turn order to reorder. It is here
            // because the option is easy to forget and there is no other place
            // the rules would be read from.
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .font(.dsaBody(.caption))
                    .foregroundStyle(.secondary)
                Text(L("action.delayHint"))
                    .font(.dsaBody(.caption2))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, DSALayout.contentPadding)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemBackground))
            .dsaBox(.flush)
            .padding(.bottom, 8)
            .accessibilityIdentifier("combat.action.delayHint")

            VStack(spacing: 8) {
                // Angriff -- primary (filled)
                Button {
                    let isDualWield = hero.isDualWielding
                    let hasShield = hero.selectedShield != nil
                    let canTwoHand: Bool = {
                        guard !isDualWield, !hasShield else { return false }
                        guard let w = hero.selectedWeapon else { return false }
                        return CombatTechniqueID(rawValue: w.combatTechniqueId)?.allowsTwoHandedGrip ?? true
                    }()

                    if isDualWield || canTwoHand || mountedActive {
                        step = .attackChoice
                    } else if hasShield {
                        step = .weaponSelection(.angriff)
                    } else if let w = hero.selectedWeapon {
                        step = .announcement(.angriff, name: w.name, baseAT: w.at, damageFormula: w.damage, isOffHand: false, secondAttack: nil, isMountCharge: false)
                    } else if hero.selectedWeaponName == "Raufen" {
                        let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
                        step = .announcement(.angriff, name: "Raufen", baseAT: raufen?.at ?? 0, damageFormula: "1W6", isOffHand: false, secondAttack: nil, isMountCharge: false)
                    } else {
                        step = .loadoutEquipment
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                        Text(L("attack"))
                    }
                    .font(.dsaHeading(.title3))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(combatAccent)
                    .dsaBox(.flush)
                }
                .buttonStyle(.dsaMotion)

                // Fernkampf. A Ladehemmung (Fernkampf-Patzer 9) costs two
                // complete Kampfrunden, so the entry point itself is shut and
                // says until when — a shot that simply rolled worse would hide
                // the rule the player is actually paying.
                if hero.selectedRangedWeaponName != nil {
                    let jammed = hero.isRangedWeaponJammed
                    Button {
                        step = .fernkampfSetup
                    } label: {
                        VStack(spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: "scope")
                                Text(L("rangedAttack"))
                            }
                            .font(.dsaHeading(.title3))
                            if jammed {
                                Text(String(format: L("fumble.jam.reason"), hero.activeCombatJamUntilRound))
                                    .font(.dsaBody(.caption2))
                                    .opacity(0.85)
                            }
                        }
                        .foregroundStyle(jammed ? .white : combatAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(jammed ? Color.dsaDisabled : Color(UIColor.systemBackground))
                        .dsaBox(.flush, stroke: jammed ? Color.dsaDisabled : combatAccent)
                    }
                    .buttonStyle(.dsaMotion)
                    .disabled(jammed)
                    .accessibilityIdentifier("combat.rangedAttack")
                }

                // Zaubern (only if hero has AE)
                if let ae = hero.derivedValues?.astralenergie, ae.max > 0 {
                    Button {
                        step = .spellSelection
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                            Text(L("castSpell"))
                        }
                        .font(.dsaHeading(.title3))
                        .foregroundStyle(Color.groupMagic)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(UIColor.systemBackground))
                        .dsaBox(.flush, stroke: Color.groupMagic)
                    }
                    .buttonStyle(.dsaMotion)
                }

                // Flucht is an action like any other, and was stranded between
                // the bookkeeping buttons.
                Button { step = .flucht } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.run")
                        Text(L("flucht"))
                    }
                    .font(.dsaHeading(.title3))
                    .foregroundStyle(combatAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(UIColor.systemBackground))
                    .dsaBox(.flush, stroke: combatAccent)
                }
                .buttonStyle(.dsaMotion)

            }
            .dsaOptionGroup()

            // Reactions: what the hero does on someone else's turn. They used to
            // sit in one undifferentiated list with the actions, the bookkeeping
            // and the Schip buys, so "Schaden nehmen" — which is not a rules
            // action at all — sat between the two defences.
            combatSectionLabel(L("reaction.label"))

            VStack(spacing: 8) {
                // Parieren -- secondary (outline)
                Button {
                    let isDualWield = hero.isDualWielding
                    if isDualWield || hero.selectedShield != nil {
                        step = .weaponSelection(.parieren)
                    } else if let w = hero.selectedWeapon {
                        let mods = buildDefenseModifiers(isAusweichen: false)
                        // The grip's -1 is a modifier line now, so the base must
                        // not carry it too.
                        let basePA = w.pa + hero.passiveShieldPABonus
                        let effectivePA = basePA + mods.reduce(0) { $0 + $1.value }
                        step = .execution(.parieren, name: w.name, attributeValue: effectivePA, damageFormula: nil, note: nil, modifierLines: mods)
                    } else if hero.selectedWeaponName == "Raufen" {
                        let raufen = hero.combatTechniques.first { $0.name == "Raufen" }
                        let mods = buildDefenseModifiers(isAusweichen: false)
                        let basePA = raufen?.pa ?? 0
                        let effectivePA = basePA + mods.reduce(0) { $0 + $1.value }
                        step = .execution(.parieren, name: "Raufen", attributeValue: effectivePA, damageFormula: nil, note: nil, modifierLines: mods)
                    } else {
                        step = .weaponSelection(.parieren)
                    }
                } label: {
                    VStack(spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.fill")
                            Text(L("parry"))
                        }
                        .font(.dsaHeading(.title3))
                        if let cost = defenseCostSubtitle(isAusweichen: false) {
                            Text(cost)
                                .font(.dsaBody(.caption2))
                                .opacity(0.85)
                        }
                    }
                    .foregroundStyle(defenseBlocked ? .white : combatAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(defenseBlocked ? Color.dsaDisabled : Color(UIColor.systemBackground))
                    .dsaBox(.flush, stroke: defenseBlocked ? Color.dsaDisabled : combatAccent)
                }
                .buttonStyle(.dsaMotion)
                .disabled(defenseBlocked)
                .accessibilityIdentifier("combat.parry")

                // Ausweichen -- tertiary (outline)
                Button {
                    let mods = buildDefenseModifiers(isAusweichen: true)
                    let baseAW = hero.derivedValues?.ausweichen.value ?? 0
                    let effectiveAW = baseAW + mods.reduce(0) { $0 + $1.value }
                    step = .execution(.ausweichen, name: "Ausweichen", attributeValue: effectiveAW, damageFormula: nil, note: nil, modifierLines: mods)
                } label: {
                    VStack(spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk")
                            Text(L("dodge"))
                        }
                        .font(.dsaHeading(.title3))
                        if let cost = defenseCostSubtitle(isAusweichen: true) {
                            Text(cost)
                                .font(.dsaBody(.caption2))
                                .opacity(0.85)
                        }
                    }
                    .foregroundStyle(defenseBlocked ? .white : combatAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(defenseBlocked ? Color.dsaDisabled : Color(UIColor.systemBackground))
                    .dsaBox(.flush, stroke: defenseBlocked ? Color.dsaDisabled : combatAccent)
                }
                .buttonStyle(.dsaMotion)
                .disabled(defenseBlocked)
                .accessibilityIdentifier("combat.dodge")

                // Vorstoß warning
                if vorstossActiveThisRound {
                    defenseBlockedReason(L("noDefenseWarning"))
                }

                // …and the Fernkampf-Patzer's own. A disabled button with no
                // reason under it reads as a bug, and the two rules end at
                // different moments, so each says which one it is.
                if hero.activeCombatNoDefense {
                    defenseBlockedReason(L("fumble.noDefense.reason"))
                        .accessibilityIdentifier("combat.noDefense.fumble")
                }
            }
            // One raised group with flat options inside — the same container the
            // Manöver and Trefferzone lists use on the announcement screen. This
            // is ADR-0009's "containers" half, which that decision recorded as
            // undelivered: nine full-width actions each casting their own shadow
            // was the stack of shadows it set out to remove.
            .dsaOptionGroup()

            // What a Schicksalspunkt buys. Grouped because the cost is the thing
            // they have in common — the gold fill says it too, but a player
            // deciding whether to spend one wants them in one place.
            if schipsAvailable > 0,
               !schipDefenseBoostActive || (!schipIgnoreZustandThisRound && hero.hasIgnorableZustand) {
                combatSectionLabel(L("fateAction.label"))

                VStack(spacing: 8) {
                    if !schipDefenseBoostActive {
                        schipActionButton(icon: "shield.checkered", title: L("schip.defenseBoost")) {
                            hero.derivedValues?.schicksalspunkte.current -= 1
                            schipDefenseBoostActive = true
                        }
                    }

                    if !schipIgnoreZustandThisRound && hero.hasIgnorableZustand {
                        schipActionButton(icon: "bandage", title: L("schip.ignoreZustand")) {
                            hero.derivedValues?.schicksalspunkte.current -= 1
                            schipIgnoreZustandThisRound = true
                        }
                    }
                }
                .dsaOptionGroup()
            }

            // Neither an action nor a reaction: writing down what happened, and
            // swapping kit. Dark, because nothing here is rolled — the teal on
            // "Ausrüstung wechseln" was a colour used nowhere else in the app.
            combatSectionLabel(L("recordAction.label"))

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button { step = .takeDamage() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.slash.fill")
                            Text(L("takeDamage"))
                        }
                        .font(.dsaHeading(.title3))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.dsaDark)
                        .dsaBox(.flush)
                    }
                    .buttonStyle(.dsaMotion)

                    if mountedActive {
                        Button { step = .mountDamage } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "heart.slash.fill")
                                Text(L("mountTakesDamage"))
                            }
                            .font(.dsaHeading(.title3))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Color.dsaDark)
                            .dsaBox(.flush)
                        }
                        .buttonStyle(.dsaMotion)
                    }
                }

                Button { step = .loadoutEquipment } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(L("changeLoadout"))
                    }
                    .font(.dsaHeading(.body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.dsaDark)
                    .dsaBox(.flush)
                }
                .buttonStyle(.dsaMotion)
            }
            .dsaOptionGroup()

            // End combat — not an action in the round, it leaves the screen, so
            // it stays outside the group and keeps its own shadow.
            //
            // It clears the session, but not before the player has had the one
            // chance the app ever gave them to switch the fight's states off
            // again: a failed Sturz check, a Beule, a Selbstbeherrschung probe
            // and the Beengte-Umgebung toggle all set states that nothing in the
            // flow ever took away, so Liegend walked out of the fight with the
            // hero. With nothing to switch off, the button behaves exactly as it
            // did — there is no point asking the player to confirm an empty
            // list.
            Button {
                if CombatAftermath(hero: hero).isEmpty {
                    hero.clearCombatSession()
                    onDismiss()
                } else {
                    step = .aftermath
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill")
                    Text(L("endCombat"))
                }
                .font(.dsaHeading(.body))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.dsaDark)
                .dsaBox(.raised)
            }
            .buttonStyle(.dsaMotion)
            .padding(.top, 16)

            } // inner VStack
            .adaptiveContentWidth()
            } // ScrollView
        }
    }

    /// Why the two defence buttons are dark. One builder, because Vorstoß and
    /// the Patzer say the same kind of thing in the same place.
    private func defenseBlockedReason(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.dsaBody(.caption2))
            Text(text)
                .font(.dsaBody(.caption2))
        }
        .foregroundStyle(combatAccent)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    /// The two at-a-glance resources beside each other: Schicksalspunkte and RS.
    ///
    /// One builder, because they were two copies of the same layout and came out
    /// a hair apart — SF Symbols have different bounding boxes, so `sparkles` and
    /// `shield.fill` gave the two chips different heights. The icon frame fixes
    /// the line height so the glyph cannot set it.
    private func resourceChip(icon: String, text: String, fill: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.dsaBody(.caption))
                .frame(height: DSALayout.chipIconHeight)
            Text(text)
                .font(.dsaMono(.caption, emphasis: true))
                .frame(height: DSALayout.chipIconHeight)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(fill)
        .dsaBox(.flush)
    }

    private var schipsAvailable: Int {
        hero.derivedValues?.schicksalspunkte.current ?? 0
    }

    /// A Schip-funded action, sitting in the AKTION group with the rest. The
    /// gold fill and the printed cost are what mark the Schip; nothing about its
    /// position does.
    private func schipActionButton(
        icon: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            // The label is centred like every other action in the group; the cost
            // rides in a trailing overlay so it cannot pull the label off centre.
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.dsaHeading(.body))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .overlay(alignment: .trailing) {
                Text(L("schip.cost"))
                    .font(.dsaMono(.caption, emphasis: true))
                    .foregroundStyle(.white)
                    .padding(.trailing, 14)
            }
            .background(Color.dsaSchipGold)
            .dsaBox(.flush)
        }
        .buttonStyle(.dsaMotion)
    }

    /// The counterpart statement once the Schip is spent.
    private func schipSpentChip(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
            Image(systemName: "checkmark")
        }
        .font(.dsaBody(.caption))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.dsaSchipGold)
        .dsaBox(.flush, stroke: Color.dsaSchipGold)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    /// A divider between two segments of the round row, at border weight.
    private var roundRowRule: some View {
        Rectangle()
            .fill(Color.dsaBorder)
            .frame(width: DSALayout.border)
    }

    /// Full-width, high-contrast incapacitation banner — `Color.groupCombat` fill, white
    /// bold uppercase text, thick `Color.dsaBorder` rectangle. Impossible to miss.
    private func combatWarningBanner(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.dsaHeading(.title3))
            Text(text)
                .font(.dsaHeading(.headline))
                .textCase(.uppercase)
            Spacer()
            Image(systemName: icon)
                .font(.dsaHeading(.title3))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.groupCombat)
        .dsaBox(.flush)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var lpBar: some View {
        if let dv = hero.derivedValues {
            LPBarView(
                current: dv.lebensenergie.current,
                max: dv.lebensenergie.max
            ) {
                guard dv.lebensenergie.current > 0 else { return }
                dv.lebensenergie.current -= 1
            } onIncrement: {
                guard dv.lebensenergie.current < dv.lebensenergie.max else { return }
                dv.lebensenergie.current += 1
            }
        }
    }

}

// MARK: - CombatArmorManagementSheet

struct CombatArmorManagementSheet: View {
    let hero: Hero
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L("armorSelection"))
                    .font(.dsaHeading(.headline))
                    .foregroundStyle(.white)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.dsaBody(.body))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.dsaMotion)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(combatAccent)
            .dsaBox(.raised)

            if hero.armors.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "shield.slash")
                        .font(.dsaHeading(.largeTitle))
                        .foregroundStyle(.secondary)
                    Text(L("noArmor"))
                        .font(.dsaBody(.body))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(hero.armors, id: \.persistentModelID) { armor in
                            armorRow(armor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }

            // Summary bar
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text(L("rs"))
                        .font(.dsaBody(.caption))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(hero.totalRS)")
                        .font(.dsaHeading(.body))
                        .fontDesign(.monospaced)
                        .foregroundStyle(.white)
                }
                HStack(spacing: 4) {
                    Text(L("encumbrance"))
                        .font(.dsaBody(.caption))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(hero.effectiveBE)")
                        .font(.dsaHeading(.body))
                        .fontDesign(.monospaced)
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.dsaDark)
            .dsaBox(.flush)
        }
    }

    private func armorRow(_ armor: Armor) -> some View {
        Button {
            armor.isEquipped.toggle()
        } label: {
            // Equipped is the fill, like every other option (ADR-0010). This row
            // was the last `checkmark.circle` left, so on the setup screen the
            // Plattenrüstung showed a ring while "Beritten" two sections down
            // showed a fill.
            DSAToggleRowLabel(
                title: armor.name,
                isOn: armor.isEquipped,
                accent: combatAccent,
                subtitle: "\(L("rs")) \(armor.protectionValue)  \(L("encumbrance")) \(armor.encumbrance)"
            )
        }
        .buttonStyle(.dsaMotion)
    }
}

// MARK: - CombatInitiativeSheet

struct CombatInitiativeSheet: View {
    let heroBaseINI: Int
    let mountBaseINI: Int?
    let mountName: String?
    var onConfirm: (Int) -> Void

    @State private var selectedBase: Int? = nil
    @State private var d6Display: Int = 1
    @State private var d6Result: Int? = nil
    @State private var animTask: Task<Void, Never>? = nil

    private var total: Int? {
        guard let base = selectedBase, let d6 = d6Result else { return nil }
        return base + d6
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(L("newInitiative"))
                .font(.dsaHeading(.headline))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(combatAccent)
                .dsaBox(.flush)

            VStack(spacing: 0) {
                // Base selector
                combatSectionLabel(L("basis.label"))

                HStack(spacing: 8) {
                    baseButton(label: L("hero"), value: heroBaseINI)
                    if let mountINI = mountBaseINI {
                        baseButton(label: mountName ?? L("mount"), value: mountINI)
                    }
                }
                .padding(.horizontal, 16)

                // Dice + result
                if let base = selectedBase {
                    VStack(spacing: 8) {
                        // D6 box
                        VStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text("\(d6Result ?? d6Display)")
                                    .font(.dsaHeading(.largeTitle))
                                    .fontDesign(.monospaced)
                                if d6Result == nil {
                                    Text(L("rolling"))
                                        .font(.dsaBody(.caption2))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(d6Result == nil ? combatAccent.opacity(DSAAnimation.animatingBackgroundOpacity) : Color(UIColor.systemBackground))
                            .dsaBox(.flush)
                            Text("W6")
                                .font(.dsaBody(.caption2))
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }

                        // Calculation box
                        Text("\(base) + \(d6Result ?? d6Display) = \(base + (d6Result ?? d6Display))")
                            .font(.dsaHeading(.title3))
                            .fontDesign(.monospaced)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.systemBackground))
                            .dsaBox(.flush)
                            .opacity(d6Result == nil ? 0.4 : 1)

                        if let t = total {
                            Button {
                                animTask?.cancel()
                                onConfirm(t)
                            } label: {
                                Text("\(L("confirmIni")) \(t)")
                                    .font(.dsaHeading(.body))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(combatAccent)
                                    .dsaBox(.raised)
                            }
                            .buttonStyle(.dsaMotion)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                Spacer()
            }
            .padding(.bottom, 16)
        }
        .onDisappear { animTask?.cancel() }
    }

    private func baseButton(label: String, value: Int) -> some View {
        let isSelected = selectedBase == value
        return Button {
            selectedBase = value
            d6Result = nil
            startD6Animation()
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(.dsaBody(.caption))
                Text("\(value)")
                    .font(.dsaHeading(.title3))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? combatAccent : Color(UIColor.secondarySystemBackground))
            .dsaBox(.flush)
        }
        .buttonStyle(.dsaMotion)
    }

    private func startD6Animation() {
        animTask?.cancel()
        animTask = Task { @MainActor in
            var count = 0
            while !Task.isCancelled && count < 12 {
                d6Display = Int.random(in: 1...6)
                do {
                    try await Task.sleep(nanoseconds: DSAAnimation.diceTumbleInterval)
                } catch { return }
                count += 1
            }
            guard !Task.isCancelled else { return }
            d6Result = DiceRoller.roll(sides: 6)
        }
    }
}
