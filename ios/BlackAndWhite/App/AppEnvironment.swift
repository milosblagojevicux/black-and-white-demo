import Foundation

struct AppEnvironment: Sendable {
    let decisionService: any DecisionService
    let dailyContextStore: any DailyDecisionContextStoring
    let reactionContextStore: any ReactionContextStoring

    init(
        decisionService: any DecisionService,
        dailyContextStore: any DailyDecisionContextStoring = DailyDecisionContextStore(),
        reactionContextStore: any ReactionContextStoring = ReactionContextStore()
    ) {
        self.decisionService = decisionService
        self.dailyContextStore = dailyContextStore
        self.reactionContextStore = reactionContextStore
    }

    static var configured: AppEnvironment {
        let contextStore = DailyDecisionContextStore()
        let reactionStore = ReactionContextStore()
        let decisionService: MockDecisionService
        if CommandLine.arguments.contains("--ui-test-pending-standard") {
            decisionService = MockDecisionService(
                scenario: .fixed(.previewBlack),
                // This scenario exists solely to make the pending UI state
                // observable to UI automation. The app is terminated at the
                // end of the test, which cancels the outstanding task.
                delay: .seconds(60)
            )
        } else if CommandLine.arguments.contains("--ui-test-pending-instant") {
            decisionService = MockDecisionService(
                scenario: .fixed(.previewWhite),
                delay: .milliseconds(900)
            )
        } else if CommandLine.arguments.contains("--ui-test-pending-fakeout") {
            decisionService = MockDecisionService(
                scenario: .fixed(.previewFakeout),
                // The pending fakeout test asserts that no authoritative
                // verdict animation begins before a response exists. Keep
                // the response pending for the whole UI-test lifetime so
                // that assertion cannot race the simulator scheduler.
                delay: .seconds(60)
            )
        } else if CommandLine.arguments.contains("--ui-test-loading-error") {
            decisionService = MockDecisionService(
                scenario: .failure(.unavailable),
                delay: .milliseconds(900)
            )
        } else if CommandLine.arguments.contains("--ui-test-verdict-fakeout") {
            decisionService = MockDecisionService(
                scenario: .fixed(.previewFakeout),
                delay: .zero
            )
        } else if CommandLine.arguments.contains("--ui-test-unsupported-suggestion") {
            decisionService = MockDecisionService(
                scenario: .unsupportedQuestionFormat
            )
        } else {
            decisionService = MockDecisionService()
        }

        return AppEnvironment(
            decisionService: decisionService,
            dailyContextStore: contextStore,
            reactionContextStore: reactionStore
        )
    }
}
