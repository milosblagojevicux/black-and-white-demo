import Foundation

struct MockDecisionService: DecisionService {
    enum Scenario: Sendable {
        case cycle
        case fixed(Decision)
        case unsupportedQuestionFormat
        case failure(DecisionServiceError)
    }

    let scenario: Scenario
    let delay: Duration

    init(scenario: Scenario = .cycle, delay: Duration = .milliseconds(450)) {
        self.scenario = scenario
        self.delay = delay
    }

    func decide(_ request: DecisionRequest) async throws -> DecisionOutcome {
        try await Task.sleep(for: delay)

        switch scenario {
        case .failure(let error):
            throw error
        case .fixed(let decision):
            return .verdict(decision)
        case .unsupportedQuestionFormat:
            return .unsupportedQuestionFormat(
                UnsupportedQuestionFormat(responseLanguage: .en)
            )
        case .cycle:
            let normalized = request.question.lowercased()
            if Self.isUnsupportedSample(normalized) {
                return .unsupportedQuestionFormat(
                    UnsupportedQuestionFormat(responseLanguage: .en)
                )
            }
            if normalized.contains("gray") || normalized.contains("dose") {
                return .verdict(.previewGray)
            }
            if normalized.contains("yes") || normalized.contains("water") {
                return .verdict(.previewWhite)
            }
            return .verdict(.previewBlack)
        }
    }

    private static func isUnsupportedSample(_ normalized: String) -> Bool {
        [
            "who is better",
            "where should i travel",
            "what should i eat",
            "explain quantum physics",
            "what is the capital of france",
            "choose a movie for me",
            "tell me about rome"
        ].contains { normalized.contains($0) }
    }
}

extension Decision {
    static let previewWhite = Decision(
        id: UUID(uuidString: "9E12642A-6DEE-4D3A-8B95-4B2236C3885D")!,
        verdict: .white,
        category: .factual,
        reactionId: .easyOne,
        motionProfile: .instant,
        fakeout: false,
        responseLanguage: .en,
        usage: Usage(remainingToday: 24, state: .normal, resetsAt: .distantFuture)
    )

    static let previewBlack = Decision(
        id: UUID(uuidString: "6C1897B1-1F00-4CC4-B5F0-2E7E641C0B56")!,
        verdict: .black,
        category: .subjective,
        reactionId: .pleaseStop,
        motionProfile: .tension,
        fakeout: false,
        responseLanguage: .en,
        usage: Usage(remainingToday: 23, state: .normal, resetsAt: .distantFuture)
    )

    static let previewFakeout = Decision(
        id: UUID(uuidString: "97EA129E-92B3-46CE-B689-A253181DEEAA")!,
        verdict: .black,
        category: .subjective,
        reactionId: nil,
        motionProfile: .tension,
        fakeout: true,
        responseLanguage: .en,
        usage: Usage(remainingToday: 23, state: .normal, resetsAt: .distantFuture)
    )

    static let previewGray = Decision(
        id: UUID(uuidString: "4629DE50-39D5-475D-9E37-68163B89708C")!,
        verdict: .gray,
        category: .highStakes,
        reactionId: nil,
        motionProfile: .gray,
        fakeout: false,
        responseLanguage: .en,
        usage: Usage(remainingToday: 22, state: .normal, resetsAt: .distantFuture)
    )

    static let previewWarning = Decision(
        id: UUID(uuidString: "DB20D103-B2EF-4504-A111-B90167D84D87")!,
        verdict: .white,
        category: .factual,
        reactionId: .easyOne,
        motionProfile: .instant,
        fakeout: false,
        responseLanguage: .en,
        usage: Usage(remainingToday: 5, state: .warning, resetsAt: .distantFuture)
    )

    static let previewLast = Decision(
        id: UUID(uuidString: "3E4D5F06-55D0-4C71-89B1-EFD36E43C834")!,
        verdict: .black,
        category: .subjective,
        reactionId: .pleaseStop,
        motionProfile: .tension,
        fakeout: false,
        responseLanguage: .en,
        usage: Usage(remainingToday: 1, state: .last, resetsAt: .distantFuture)
    )
}
