import SwiftUI

/// Rolls dice in front of the player and holds the result until they close it.
///
/// Every other roll in the app is *shown*: the skill check has its dice, the
/// dice sheet has its animation. The Trefferzone 1W20 was the exception — it
/// resolved silently on tap and the value was reported afterwards as a line of
/// text underneath ("7: Torso"), duplicating what the highlighted chip already
/// said and putting the one thing the chip could not show, the die, in the
/// quietest place on the screen. The roll now happens where the player is
/// looking.
///
/// The result is applied on `onConfirm`, not on reveal, for the same reason
/// `SkillCheckModal` closes deliberately: a modal that dismisses itself takes
/// the number away before it has been read.
struct DSADiceRevealModal: View {
    let title: String
    let sides: Int
    var count: Int = 1
    var accent: Color = .groupCombat
    /// Renders the settled roll as the sentence the player actually wants —
    /// "7: Torso (rechts)" — beneath the dice. `nil` shows nothing.
    var caption: ([Int]) -> String? = { _ in nil }
    /// A settled roll shown as a view rather than a line of text: the table it
    /// was rolled against, with the row it hit lit. Takes precedence over
    /// `caption`, which cannot show where in a table the number landed.
    var result: (([Int]) -> AnyView)? = nil
    let onConfirm: ([Int]) -> Void
    let onCancel: () -> Void

    @State private var results: [Int]? = nil
    @State private var tumbling: [Int]
    @State private var tumbleTask: Task<Void, Never>? = nil

    init(
        title: String,
        sides: Int,
        count: Int = 1,
        accent: Color = .groupCombat,
        caption: @escaping ([Int]) -> String? = { _ in nil },
        result: (([Int]) -> AnyView)? = nil,
        onConfirm: @escaping ([Int]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.sides = sides
        self.count = count
        self.accent = accent
        self.caption = caption
        self.result = result
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _tumbling = State(initialValue: Array(repeating: 1, count: count))
    }

    private var isSettled: Bool { results != nil }

    var body: some View {
        DSAModal(title: title, accent: accent, onScrimTap: isSettled ? nil : onCancel) {
            HStack(spacing: 12) {
                ForEach(Array((results ?? tumbling).enumerated()), id: \.offset) { _, value in
                    Text("\(value)")
                        .font(.dsaHeading(.largeTitle))
                        .fontDesign(.monospaced)
                        .frame(minWidth: 72)
                        .padding(.vertical, 16)
                        .background(isSettled ? Color(UIColor.systemBackground) : accent.opacity(0.1))
                        .dsaBox(.flush)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("dice.reveal.value")

            if let results {
                if let result {
                    // No identifier of our own: the content carries its own, and
                    // an identifier on this wrapper takes that identity over.
                    result(results)
                } else if let caption = caption(results) {
                    Text(caption)
                        .font(.dsaMono(.caption, emphasis: true))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("dice.reveal.caption")
                }
            }

            if isSettled {
                DSAModalButton(
                    title: L("confirm"),
                    accent: accent,
                    identifier: "dice.reveal.confirm"
                ) {
                    onConfirm(results ?? [])
                }
            } else {
                DSAModalButton(
                    title: L("cancel"),
                    accent: accent,
                    filled: false,
                    identifier: "dice.reveal.cancel",
                    action: onCancel
                )
            }
        }
        .task { await roll() }
        .onDisappear { tumbleTask?.cancel() }
    }

    /// The real roll is taken up front — from `DiceRoller`, so `ScriptedDice`
    /// still governs it under test — and the tumble is only a reveal. Rolling at
    /// the end of the animation would make the result depend on the animation
    /// finishing.
    private func roll() async {
        let settled = (0..<count).map { _ in DiceRoller.roll(sides: sides) }
        for _ in 0..<8 {
            try? await Task.sleep(nanoseconds: 55_000_000)
            if Task.isCancelled { return }
            tumbling = (0..<count).map { _ in Int.random(in: 1...sides) }
        }
        if Task.isCancelled { return }
        withAnimation(DSAAnimation.press) { results = settled }
    }
}
