import Foundation

enum ResponseLanguage: String, Codable, Sendable, CaseIterable {
    case en
    case srLatn = "sr-Latn"
    case srCyrl = "sr-Cyrl"

    static func orderedSupportedPreferences(
        from preferredLanguageTags: [String] = Locale.preferredLanguages
    ) -> [ResponseLanguage] {
        let supported = preferredLanguageTags.compactMap(normalizedSupportedTag)
        let ordered = supported.reduce(into: [ResponseLanguage]()) { result, language in
            if !result.contains(language) {
                result.append(language)
            }
        }
        return ordered.isEmpty ? [.en] : ordered
    }

    private static func normalizedSupportedTag(_ tag: String) -> ResponseLanguage? {
        let parts = tag.replacingOccurrences(of: "_", with: "-").split(separator: "-")
        guard let language = parts.first?.lowercased() else { return nil }
        if language == "en" { return .en }
        guard language == "sr" else { return nil }
        let script = parts.dropFirst().first(where: { $0.count == 4 })?.lowercased()
        switch script {
        case "latn": return .srLatn
        case "cyrl": return .srCyrl
        default: return nil
        }
    }
}

enum Verdict: String, Codable, Sendable, CaseIterable {
    case white
    case black
    case gray

    func displayText(in language: ResponseLanguage) -> String {
        switch self {
        case .white:
            switch language { case .en: "Yes."; case .srLatn: "Da."; case .srCyrl: "Да." }
        case .black:
            switch language { case .en: "No."; case .srLatn: "Ne."; case .srCyrl: "Не." }
        case .gray:
            switch language { case .en: "Not that simple."; case .srLatn: "Nije baš tako jednostavno."; case .srCyrl: "Није баш тако једноставно." }
        }
    }
}

enum DecisionCategory: String, Codable, Sendable {
    case factual
    case correctness
    case subjective
    case personal
    case absurd
    case systemBait = "system_bait"
    case repeated
    case highStakes = "high_stakes"
}

enum MotionProfile: String, Codable, Sendable {
    case instant
    case brief
    case tension
    case dramatic
    case gray
}

enum DecisionMotionPath: Equatable, Sendable {
    case instant
    case standard
    case fakeout
    case gray
}

enum UsageState: String, Codable, Sendable {
    case normal
    case warning
    case last
    case exhausted
}

enum ReactionID: String, Codable, Sendable, CaseIterable {
    case obviously = "reaction.obviously", easyOne = "reaction.easy_one", notEvenClose = "reaction.not_even_close", noContest = "reaction.no_contest", youKnewThat = "reaction.you_knew_that"
    case comeOn = "reaction.come_on", niceTry = "reaction.nice_try", pleaseStop = "reaction.please_stop", beSerious = "reaction.be_serious", dontPushIt = "reaction.dont_push_it"
    case iSaidWhatISaid = "reaction.i_said_what_i_said", thatsFinal = "reaction.thats_final", settled = "reaction.settled", caseClosed = "reaction.case_closed", endOfDiscussion = "reaction.end_of_discussion"
    case stillNo = "reaction.still_no", sameAnswer = "reaction.same_answer", nothingChanged = "reaction.nothing_changed", askedAndAnswered = "reaction.asked_and_answered", weCoveredThis = "reaction.we_covered_this"
    case goodCall = "reaction.good_call", thatsMoreLikeIt = "reaction.thats_more_like_it", finally = "reaction.finally", asYouShould = "reaction.as_you_should", illAllowIt = "reaction.ill_allow_it"
    case really = "reaction.really", ofCourseYouAsked = "reaction.of_course_you_asked", boldOfYou = "reaction.bold_of_you", youActuallyAsked = "reaction.you_actually_asked", hereWeGo = "reaction.here_we_go"

    func displayText(in language: ResponseLanguage) -> String {
        switch self {
        case .obviously: localized("Obviously.", "Naravno.", "Наравно.", language)
        case .easyOne: localized("Easy one.", "Lako.", "Лако.", language)
        case .notEvenClose: localized("Not even close.", "Nije ni blizu.", "Није ни близу.", language)
        case .noContest: localized("No contest.", "Nema dileme.", "Нема дилеме.", language)
        case .youKnewThat: localized("You knew that.", "Pa to već znaš.", "Па то већ знаш.", language)
        case .comeOn: localized("Come on.", "Daj, molim te.", "Дај, молим те.", language)
        case .niceTry: localized("Nice try.", "Dobar pokušaj.", "Добар покушај.", language)
        case .pleaseStop: localized("Please stop.", "Prekini.", "Прекини.", language)
        case .beSerious: localized("Be serious.", "Ajde ozbiljno.", "Ајде озбиљно.", language)
        case .dontPushIt: localized("Don’t push it.", "Ne preteruj.", "Не претеруј.", language)
        case .iSaidWhatISaid: localized("I said what I said.", "Rečeno i gotovo.", "Речено и готово.", language)
        case .thatsFinal: localized("That’s final.", "Tako ostaje.", "Тако остаје.", language)
        case .settled: localized("Settled.", "Rešeno.", "Решено.", language)
        case .caseClosed: localized("Case closed.", "Slučaj zatvoren.", "Случај затворен.", language)
        case .endOfDiscussion: localized("End of discussion.", "Kraj rasprave.", "Крај расправе.", language)
        case .stillNo: localized("Still no.", "I dalje ne.", "И даље не.", language)
        case .sameAnswer: localized("Same answer.", "Isti odgovor.", "Исти одговор.", language)
        case .nothingChanged: localized("Nothing changed.", "Ništa se nije promenilo.", "Ништа се није променило.", language)
        case .askedAndAnswered: localized("Asked and answered.", "Već pitano.", "Већ питано.", language)
        case .weCoveredThis: localized("We covered this.", "Ovo smo već prošli.", "Ово смо већ прошли.", language)
        case .goodCall: localized("Good call.", "Dobar izbor.", "Добар избор.", language)
        case .thatsMoreLikeIt: localized("That’s more like it.", "E, tako već može.", "Е, тако већ може.", language)
        case .finally: localized("Finally.", "Konačno.", "Коначно.", language)
        case .asYouShould: localized("As you should.", "Tako i treba.", "Тако и треба.", language)
        case .illAllowIt: localized("I’ll allow it.", "Može da prođe.", "Може да прође.", language)
        case .really: localized("Really.", "Stvarno.", "Стварно.", language)
        case .ofCourseYouAsked: localized("Of course you asked.", "Naravno da pitaš.", "Наравно да питаш.", language)
        case .boldOfYou: localized("Bold of you.", "Hrabro.", "Храбро.", language)
        case .youActuallyAsked: localized("You actually asked.", "To je stvarno pitanje?", "То је стварно питање?", language)
        case .hereWeGo: localized("Here we go.", "Evo nas.", "Ево нас.", language)
        }
    }

    private func localized(_ english: String, _ latin: String, _ cyrillic: String, _ language: ResponseLanguage) -> String {
        switch language { case .en: english; case .srLatn: latin; case .srCyrl: cyrillic }
    }
}

struct ReactionRequestContext: Codable, Equatable, Sendable {
    let recentIds: [ReactionID]
    let previousDecisionHadReaction: Bool
    let hasReceivedReaction: Bool

    static let empty = ReactionRequestContext(
        recentIds: [],
        previousDecisionHadReaction: false,
        hasReceivedReaction: false
    )
}

struct Usage: Codable, Equatable, Sendable {
    let remainingToday: Int
    let state: UsageState
    let resetsAt: Date
}

struct Decision: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let verdict: Verdict
    let category: DecisionCategory
    let reactionId: ReactionID?
    let motionProfile: MotionProfile
    let fakeout: Bool
    let responseLanguage: ResponseLanguage
    let usage: Usage

    var verdictText: String { verdict.displayText(in: responseLanguage) }
    var reaction: String? { reactionId?.displayText(in: responseLanguage) }

    var motionPath: DecisionMotionPath {
        if verdict == .gray {
            return .gray
        }
        if fakeout {
            return .fakeout
        }
        if motionProfile == .instant {
            return .instant
        }
        return .standard
    }
}

struct RecentDecision: Codable, Equatable, Sendable {
    let question: String
    let verdict: Verdict
}

struct DecisionRequest: Equatable, Sendable {
    let question: String
    let recent: [RecentDecision]
    let reactionContext: ReactionRequestContext
    let languagePreferences: [ResponseLanguage]

    init(
        question: String,
        recent: [RecentDecision],
        reactionContext: ReactionRequestContext = .empty,
        languagePreferences: [ResponseLanguage] = ResponseLanguage.orderedSupportedPreferences()
    ) {
        self.question = question
        self.recent = recent
        self.reactionContext = reactionContext
        self.languagePreferences = languagePreferences.isEmpty ? [.en] : languagePreferences
    }
}

struct UnsupportedQuestionFormat: Equatable, Sendable {
    let responseLanguage: ResponseLanguage
}

enum DecisionOutcome: Equatable, Sendable {
    case verdict(Decision)
    case unsupportedQuestionFormat(UnsupportedQuestionFormat)
}
