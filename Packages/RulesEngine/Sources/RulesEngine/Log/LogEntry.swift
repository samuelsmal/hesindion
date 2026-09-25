import Foundation

// The log (spec §8): the record of what the engine computed, detailed enough to improve the app
// from. One entry per query or action, with the full situation it ran against, the full
// breakdowns, the dice, the events, and where it ran (app, rules, vocabulary, hero).

/// One query or action, as it ran.
public struct LogEntry: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable, CaseIterable { case query, action }

    public var id: UUID
    /// When it ran, to the second (the ISO-8601 export carries no more).
    public var date: Date
    public var kind: Kind
    /// The query asked (`kind == .query`): the first of `breakdowns`.
    public var query: Query?
    /// The action performed (`kind == .action`).
    public var action: Action?
    /// The situation it ran against, complete (extra 1): the facts with their owners, the owned
    /// rules (level, option, option2), the base values, the pools, the processes, the items, the
    /// clock, the timed Stufen and the hero id. Not the evaluator's own `unstated` and
    /// `inForce`, which no JSON carries.
    public var situation: Situation
    /// Every breakdown shown: the queries asked, or the action's (its amounts' targets, its
    /// procedure's stages). Each with its lines (origin, `via`, rulings, facts), `notApplied`,
    /// offers, questions, texts and legality.
    public var breakdowns: [Breakdown]
    /// The offered choices the player took (their choice ids).
    public var offersTaken: [String]
    /// The questions answered: fact name → the answer.
    public var answers: [String: JSONValue]
    /// The dice as rolled, in order.
    public var rolls: [Int]
    /// The rerolls taken (a check's).
    public var rerolls: [RerolledDie]
    /// The events applied.
    public var events: [Event]
    public var appVersion: String
    /// `RuleBook.sha256`: the SHA-256 of the `rules.json` it ran on.
    public var rulesSha256: String
    public var vocabularyVersion: Int
    /// The hero file id.
    public var heroId: String?
    /// The player's note ("das war falsch: …").
    public var note: String?
    /// "This looks wrong."
    public var flagged: Bool

    /// `rolls` defaults to the situation's dice and `heroId` to the situation's hero. The date is
    /// kept to the second.
    public init(id: UUID = UUID(), date: Date = Date(), kind: Kind, query: Query? = nil, action: Action? = nil,
                situation: Situation, breakdowns: [Breakdown], offersTaken: [String] = [], answers: [String: JSONValue] = [:],
                rolls: [Int]? = nil, rerolls: [RerolledDie] = [], events: [Event] = [], appVersion: String, rulesSha256: String,
                vocabularyVersion: Int = Vocabulary.version, heroId: String? = nil, note: String? = nil, flagged: Bool = false) {
        var logged = situation
        logged.unstated = []
        logged.inForce = []
        self.id = id
        self.date = Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
        self.kind = kind; self.query = query; self.action = action; self.situation = logged
        self.breakdowns = breakdowns; self.offersTaken = offersTaken; self.answers = answers
        self.rolls = rolls ?? situation.rolls; self.rerolls = rerolls; self.events = events
        self.appVersion = appVersion; self.rulesSha256 = rulesSha256; self.vocabularyVersion = vocabularyVersion
        self.heroId = heroId ?? situation.heroId; self.note = note; self.flagged = flagged
    }

    /// Asks `queries` in `situation` and records them: `query` is the first, `breakdowns` all of
    /// them in order.
    public static func query(_ queries: [Query], in situation: Situation, engine: Engine, appVersion: String,
                             offersTaken: [String] = [], answers: [String: JSONValue] = [:], note: String? = nil,
                             flagged: Bool = false, id: UUID = UUID(), date: Date = Date()) -> LogEntry {
        LogEntry(id: id, date: date, kind: .query, query: queries.first, situation: situation,
                 breakdowns: queries.map { engine.evaluate($0, in: situation) }, offersTaken: offersTaken, answers: answers,
                 appVersion: appVersion, rulesSha256: engine.book.sha256, note: note, flagged: flagged)
    }

    /// Records `action` as it ran from `before` to `result`: its events and breakdowns. Taking a
    /// choice (`.take`) records it as taken.
    public static func action(_ action: Action, before: Situation, result: ActionResult, book: RuleBook, appVersion: String,
                              rerolls: [RerolledDie] = [], offersTaken: [String] = [], answers: [String: JSONValue] = [:],
                              note: String? = nil, flagged: Bool = false, id: UUID = UUID(), date: Date = Date()) -> LogEntry {
        var taken = offersTaken
        if case .take(let choice) = action, !taken.contains(choice) { taken.append(choice) }
        return LogEntry(id: id, date: date, kind: .action, action: action, situation: before, breakdowns: result.breakdowns,
                        offersTaken: taken, answers: answers, rerolls: rerolls, events: result.events, appVersion: appVersion,
                        rulesSha256: book.sha256, vocabularyVersion: book.vocabularyVersion, note: note, flagged: flagged)
    }
}
