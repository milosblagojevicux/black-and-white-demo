import Foundation
import SwiftUI
import Testing
import UIKit
@testable import BlackAndWhite

@Suite(.serialized)
@MainActor
struct DecisionFlowModelTests {
    @Test
    func startAskingBridgesThroughRestingThenRequestsFocusedInput() async throws {
        let model = DecisionFlowModel(
            service: MockDecisionService(),
            splashBridgeDuration: .milliseconds(1)
        )

        model.startAsking()

        #expect(model.phase == .asking(.resting))
        #expect(model.focusGeneration == 0)

        try await Task.sleep(for: .milliseconds(20))

        #expect(model.phase == .asking(.focused))
        #expect(model.focusGeneration == 1)
    }

    @Test
    func emptyQuestionFailsWithoutCallingService() {
        let model = DecisionFlowModel(service: MockDecisionService())
        model.startAsking()
        model.question = "   "

        model.submit()

        #expect(model.phase == .error(.invalidQuestion))
    }

    @Test
    func successfulDecisionReachesVerdict() async throws {
        let model = DecisionFlowModel(
            service: MockDecisionService(scenario: .fixed(.previewBlack), delay: .zero)
        )
        model.startAsking()
        model.question = "Should every product have AI?"

        model.submit()
        try await Task.sleep(for: .seconds(1))

        #expect(model.phase == .verdict(.previewBlack))
    }

    @Test
    func instantDecisionDoesNotWaitForStandardDecidingBeat() async throws {
        let service = ControllableDecisionService()
        let model = DecisionFlowModel(
            service: service,
            dailyContextStore: TransientContextStore(),
            initialPhase: .asking(.focused),
            // Keep a wide margin below the standard path's delay: this verifies
            // the instant path without relying on a 40 ms CI scheduling window.
            standardDecisionBeat: .seconds(1)
        )
        model.question = "Is water wet?"

        model.submit()
        #expect(model.phase == .submitting)
        await service.resolve(.success(.verdict(.previewWhite)))
        try await Task.sleep(for: .milliseconds(250))

        #expect(model.phase == .verdict(.previewWhite))
    }

    @Test
    func standardDecisionStartsVerdictTakeoverAsSoonAsTheResponseArrives() async throws {
        let service = ControllableDecisionService()
        let model = DecisionFlowModel(
            service: service,
            dailyContextStore: TransientContextStore(),
            initialPhase: .asking(.focused),
            standardDecisionBeat: .milliseconds(120)
        )
        model.question = "Should every product have AI?"

        model.submit()
        #expect(model.phase == .submitting)
        await service.resolve(.success(.verdict(.previewBlack)))
        try await Task.sleep(for: .milliseconds(30))
        #expect(model.phase == .verdict(.previewBlack))
    }

    @Test
    func fakeoutHandsTheDecisionToVerdictViewWithoutADuplicateModelDelay() async throws {
        let fakeout = Decision(
            id: UUID(),
            verdict: .black,
            category: .subjective,
            reactionId: nil,
            motionProfile: .tension,
            fakeout: true,
            responseLanguage: .en,
            usage: Usage(remainingToday: 24, state: .normal, resetsAt: .distantFuture)
        )
        let service = ControllableDecisionService()
        let model = DecisionFlowModel(
            service: service,
            dailyContextStore: TransientContextStore(),
            initialPhase: .asking(.focused),
            standardDecisionBeat: .milliseconds(500)
        )
        model.question = "Should I flip a coin?"

        model.submit()
        #expect(model.phase == .submitting)
        await service.resolve(.success(.verdict(fakeout)))
        try await Task.sleep(for: .milliseconds(80))
        #expect(model.phase == .verdict(fakeout))
    }

    @Test
    func failureLeavesSubmittingWithoutStartingDecisionMotion() async throws {
        let service = ControllableDecisionService()
        let model = DecisionFlowModel(
            service: service,
            dailyContextStore: TransientContextStore(),
            initialPhase: .asking(.focused)
        )
        model.question = "Should every product have AI?"

        model.submit()
        #expect(model.phase == .submitting)

        await service.resolve(.failure(.unavailable))
        try await Task.sleep(for: .milliseconds(40))

        #expect(model.phase == .error(.connection))
    }

    @Test
    func usageExhaustionErrorRetainsTheServerResetInstant() async throws {
        let service = ControllableDecisionService()
        let reset = Date(timeIntervalSince1970: 1_800_000_000)
        let model = DecisionFlowModel(
            service: service,
            dailyContextStore: TransientContextStore(),
            now: { Date(timeIntervalSince1970: 1_700_000_000) },
            initialPhase: .asking(.focused)
        )
        model.question = "Should I wait?"

        model.submit()
        await service.resolve(.failure(.usageExhausted(resetsAt: reset)))
        try await Task.sleep(for: .milliseconds(30))

        #expect(model.phase == DecisionFlowPhase.limitReached(
            Usage(remainingToday: 0, state: .exhausted, resetsAt: reset)
        ))
    }

    @Test(arguments: [
        ("2026-08-19T22:00:00Z", "2026-08-20T00:00:00Z", "Europe/Belgrade", "Back today at 2:00\u{202F}AM."),
        ("2026-08-19T20:00:00Z", "2026-08-19T22:00:00Z", "Europe/Belgrade", "Back tomorrow at 12:00\u{202F}AM.")
    ])
    func usageLimitCopyUsesAuthoritativeLocalResetTime(
        nowString: String,
        resetString: String,
        timeZoneIdentifier: String,
        expected: String
    ) throws {
        let formatter = ISO8601DateFormatter()
        let now = try #require(formatter.date(from: nowString))
        let reset = try #require(formatter.date(from: resetString))
        let timeZone = try #require(TimeZone(identifier: timeZoneIdentifier))

        #expect(UsageLimitCopy.resetLine(
            resetsAt: reset,
            now: now,
            timeZone: timeZone,
            locale: Locale(identifier: "en_US")
        ) == expected)
    }

    @Test
    func askAgainClearsQuestionAndRequestsFocus() async throws {
        let model = DecisionFlowModel(
            service: MockDecisionService(scenario: .fixed(.previewBlack), delay: .zero)
        )
        model.startAsking()
        model.question = "Will this clear?"
        model.submit()

        try await Task.sleep(for: .seconds(1))
        let previousFocusGeneration = model.focusGeneration
        model.askAgain()

        #expect(model.phase == .asking(.focused))
        #expect(model.question.isEmpty)
        #expect(model.focusGeneration == previousFocusGeneration + 1)
    }

    @Test
    func dismissingFocusedAskReturnsToRestingWithoutClearingQuestion() {
        let model = DecisionFlowModel(
            service: MockDecisionService(),
            initialPhase: .asking(.focused)
        )
        model.question = "Should I keep this question?"

        model.dismissFocusedAsk()

        #expect(model.phase == .asking(.resting))
        #expect(model.question == "Should I keep this question?")
        #expect(model.focusGeneration == 0)

        model.focusRestingAsk()

        #expect(model.phase == .asking(.focused))
        #expect(model.question == "Should I keep this question?")
        #expect(model.focusGeneration == 1)
        #expect(model.focusDelay == .zero)
    }

    @Test
    func requestUsesAtMostFiveRelevantItemsFromCompleteDailyContext() async throws {
        let store = DailyDecisionContextStore()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let resetsAt = now.addingTimeInterval(86_400)

        for index in 0..<7 {
            try await store.record(
                question: "Is Djokovic better than Nadal version \(index)?",
                verdict: .white,
                resetsAt: resetsAt,
                now: now
            )
        }
        try await store.record(
            question: "Is water wet?",
            verdict: .white,
            resetsAt: resetsAt,
            now: now
        )

        let recorder = DecisionRequestRecorder()
        let model = DecisionFlowModel(
            service: RecordingDecisionService(recorder: recorder),
            dailyContextStore: store,
            now: { now }
        )
        model.startAsking()
        model.question = "Would you say Djokovic is superior to Nadal?"

        model.submit()
        try await Task.sleep(for: .seconds(1))

        let request = await recorder.request
        #expect(request?.recent.count == 5)
        #expect(request?.recent.allSatisfy { $0.question.contains("Djokovic") } == true)
    }

    @Test
    func requestCarriesCompactReactionContextAndRecordsBackendSelection() async throws {
        let recorder = DecisionRequestRecorder()
        let reactionStore = InspectableReactionContextStore(
            context: ReactionRequestContext(
                recentIds: [.comeOn, .obviously],
                previousDecisionHadReaction: false,
                hasReceivedReaction: true
            )
        )
        let model = DecisionFlowModel(
            service: RecordingDecisionService(recorder: recorder),
            dailyContextStore: TransientContextStore(),
            reactionContextStore: reactionStore,
            initialPhase: .asking(.focused),
            standardDecisionBeat: .zero
        )
        model.question = "Should every product have AI?"

        model.submit()
        try await Task.sleep(for: .milliseconds(80))

        #expect(await recorder.request?.reactionContext == ReactionRequestContext(
            recentIds: [.comeOn, .obviously],
            previousDecisionHadReaction: false,
            hasReceivedReaction: true
        ))
        #expect(await reactionStore.recordedIds == [.pleaseStop])
    }

    @Test
    func unsupportedFormatReturnsToOriginalFocusedQuestionWithoutRecordingVerdict() async throws {
        let store = DailyDecisionContextStore()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let model = DecisionFlowModel(
            service: MockDecisionService(
                scenario: .unsupportedQuestionFormat,
                delay: .zero
            ),
            dailyContextStore: store,
            now: { now }
        )
        model.startAsking()
        model.question = "Who is better, Nadal or Djokovic?"

        model.submit()
        try await Task.sleep(for: .seconds(1))

        #expect(model.phase == .asking(.focused))
        #expect(model.question == "Who is better, Nadal or Djokovic?")
        #expect(model.unsupportedFormat == UnsupportedQuestionFormat(responseLanguage: .en))

        let stored = try await store.relevantHistory(
            for: model.question,
            limit: 5,
            now: now
        )
        #expect(stored.isEmpty)

        model.question.append(" ")
        model.questionDidChange()
        #expect(model.unsupportedFormat == nil)
    }

    @Test
    func unsupportedFormatNeverProvidesAnAutomaticReplacement() async throws {
        let store = DailyDecisionContextStore()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let model = DecisionFlowModel(
            service: MockDecisionService(
                scenario: .unsupportedQuestionFormat,
                delay: .zero
            ),
            dailyContextStore: store,
            now: { now }
        )
        model.startAsking()
        model.question = "Who is better, Nadal or Djokovic?"

        model.submit()
        try await Task.sleep(for: .seconds(1))
        #expect(model.phase == .asking(.focused))
        #expect(model.question == "Who is better, Nadal or Djokovic?")
        #expect(model.unsupportedFormat == UnsupportedQuestionFormat(responseLanguage: .en))

        let stored = try await store.relevantHistory(for: model.question, limit: 5, now: now)
        #expect(stored.isEmpty)
    }

    @Test(arguments: [
        "Who is better, Nadal or Djokovic?",
        "Where should I travel?",
        "What should I eat?",
        "Explain quantum physics.",
        "What is the capital of France?",
        "Choose a movie for me.",
        "Tell me about Rome."
    ])
    func deterministicMockCoversConfirmedUnsupportedExamples(_ question: String) async throws {
        let outcome = try await MockDecisionService(delay: .zero).decide(
            DecisionRequest(question: question, recent: [])
        )

        #expect(outcome == .unsupportedQuestionFormat(
            UnsupportedQuestionFormat(responseLanguage: .en)
        ))
    }
}

struct DecisionMotionPathTests {
    @Test
    func routesInstantStandardFakeoutAndGrayPaths() {
        #expect(makeDecision(verdict: .white, profile: .instant).motionPath == .instant)
        #expect(makeDecision(verdict: .black, profile: .tension).motionPath == .standard)
        #expect(makeDecision(verdict: .black, profile: .tension, fakeout: true).motionPath == .fakeout)
        #expect(makeDecision(verdict: .gray, profile: .gray).motionPath == .gray)
    }

    @Test
    func fakeoutTimingUsesACompleteDecidingCycleThenAFullSideSwitch() {
        #expect(BWMotion.decidingPullCycleBeat == .milliseconds(420))
        #expect(BWMotion.fakeoutMisdirectionBeat == .milliseconds(600))
        #expect(BWMotion.fakeoutMisdirectionProgress == 0.8)
        #expect(BWMotion.fakeoutSwitchBeat == .milliseconds(200))
    }

    @Test
    func signedFakeoutGeometryShowsTheLosingSurfaceBeforeTheWinningSurface() {
        let rect = CGRect(x: 0, y: 0, width: 402, height: 874)
        let center = CGPoint(x: rect.midX, y: rect.midY)

        let blackLosingStage = DecisionTensionBackdrop(
            pull: -0.72,
            resolution: .black,
            resolutionProgress: -BWMotion.fakeoutMisdirectionProgress
        ).path(in: rect)
        let blackWinningStage = DecisionTensionBackdrop(
            pull: -0.72,
            resolution: .black,
            resolutionProgress: BWMotion.fakeoutMisdirectionProgress
        ).path(in: rect)
        let whiteLosingStage = DecisionTensionBackdrop(
            pull: 0.72,
            resolution: .white,
            resolutionProgress: -BWMotion.fakeoutMisdirectionProgress
        ).path(in: rect)
        let whiteWinningStage = DecisionTensionBackdrop(
            pull: -0.72,
            resolution: .white,
            resolutionProgress: BWMotion.fakeoutMisdirectionProgress
        ).path(in: rect)

        #expect(!blackLosingStage.contains(center))
        #expect(blackWinningStage.contains(center))
        #expect(whiteLosingStage.contains(center))
        #expect(!whiteWinningStage.contains(center))
    }

    @Test
    func committedGeometryRetainsIndependentElasticCurvatureThroughEightyPercent() {
        let rect = CGRect(x: 0, y: 0, width: 402, height: 874)
        let pull = CGFloat(BWMotion.decidingDownRightPull)
        let zero = DecisionTensionBackdrop(
            pull: pull,
            resolution: .black,
            resolutionProgress: 0
        ).geometry(in: rect)
        let intermediate = DecisionTensionBackdrop(
            pull: pull,
            resolution: .black,
            resolutionProgress: 0.4
        ).geometry(in: rect)
        let committed = DecisionTensionBackdrop(
            pull: pull,
            resolution: .black,
            resolutionProgress: 0.8
        ).geometry(in: rect)

        let zeroCurvature = curvature(of: zero)
        let intermediateCurvature = curvature(of: intermediate)
        let committedCurvature = curvature(of: committed)

        #expect(zeroCurvature > 1)
        #expect(abs((intermediateCurvature / zeroCurvature) - 0.6) < 0.001)
        #expect(abs((committedCurvature / zeroCurvature) - 0.2) < 0.001)
    }

    @Test
    func fakeoutCommitmentGeometryMirrorsPullAndLosingSurfaceForBothVerdicts() {
        let rect = CGRect(x: 0, y: 0, width: 402, height: 874)
        let blackFinal = DecisionTensionBackdrop(
            pull: CGFloat(BWMotion.decidingUpLeftSettledPull),
            resolution: .black,
            resolutionProgress: -0.8
        ).geometry(in: rect)
        let whiteFinal = DecisionTensionBackdrop(
            pull: CGFloat(BWMotion.decidingDownRightPull),
            resolution: .white,
            resolutionProgress: -0.8
        ).geometry(in: rect)

        #expect(blackFinal.effectiveResolution == .white)
        #expect(whiteFinal.effectiveResolution == .black)
        #expect(signedCurvature(of: blackFinal) > 0)
        #expect(signedCurvature(of: whiteFinal) < 0)
        #expect(abs(curvature(of: blackFinal) - curvature(of: whiteFinal)) < 0.001)
    }

    @Test(arguments: [Verdict.black, Verdict.white])
    func finalTakeoverFlattensElasticCurvature(_ verdict: Verdict) {
        let rect = CGRect(x: 0, y: 0, width: 402, height: 874)
        let pull = verdict == .black
            ? CGFloat(BWMotion.decidingDownRightPull)
            : CGFloat(BWMotion.decidingUpLeftSettledPull)
        let geometry = DecisionTensionBackdrop(
            pull: pull,
            resolution: verdict,
            resolutionProgress: 1
        ).geometry(in: rect)

        #expect(geometry.start == geometry.midpoint)
        #expect(geometry.midpoint == geometry.end)
        #expect(curvature(of: geometry) == 0)
    }

    @Test
    func fakeoutRoutingUsesTheBackendFlagWithoutClientEligibilityInference() {
        #expect(makeDecision(
            verdict: .black,
            category: .factual,
            profile: .instant,
            fakeout: true
        ).motionPath == .fakeout)
    }

    private func makeDecision(
        verdict: Verdict,
        category: DecisionCategory? = nil,
        profile: MotionProfile,
        fakeout: Bool = false
    ) -> Decision {
        Decision(
            id: UUID(),
            verdict: verdict,
            category: category ?? (verdict == .gray ? .highStakes : .subjective),
            reactionId: nil,
            motionProfile: profile,
            fakeout: fakeout,
            responseLanguage: .en,
            usage: Usage(remainingToday: 24, state: .normal, resetsAt: .distantFuture)
        )
    }

    private func curvature(of geometry: DecisionTensionGeometry) -> CGFloat {
        abs(signedCurvature(of: geometry))
    }

    private func signedCurvature(of geometry: DecisionTensionGeometry) -> CGFloat {
        let line = CGVector(
            dx: geometry.end.x - geometry.start.x,
            dy: geometry.end.y - geometry.start.y
        )
        let length = hypot(line.dx, line.dy)
        guard length > 0 else {
            return hypot(
                geometry.midpoint.x - geometry.start.x,
                geometry.midpoint.y - geometry.start.y
            )
        }
        let midpoint = CGVector(
            dx: geometry.midpoint.x - geometry.start.x,
            dy: geometry.midpoint.y - geometry.start.y
        )
        return ((line.dx * midpoint.dy) - (line.dy * midpoint.dx)) / length
    }
}

struct DailyDecisionContextStoreTests {
    @Test
    func contextPersistsAcrossStoreRecreationAndFindsEarlyParaphrase() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("context.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let resetsAt = now.addingTimeInterval(86_400)
        let initialStore = DailyDecisionContextStore(fileURL: fileURL)
        try await initialStore.record(
            question: "Is Djokovic better than Nadal?",
            verdict: .white,
            resetsAt: resetsAt,
            now: now
        )

        for index in 0..<20 {
            try await initialStore.record(
                question: "Unrelated daily question number \(index)?",
                verdict: .black,
                resetsAt: resetsAt,
                now: now
            )
        }

        let relaunchedStore = DailyDecisionContextStore(fileURL: fileURL)
        let matches = try await relaunchedStore.relevantHistory(
            for: "Would you say Djokovic is superior to Nadal?",
            limit: 5,
            now: now
        )

        #expect(matches == [RecentDecision(
            question: "Is Djokovic better than Nadal?",
            verdict: .white
        )])
    }

    @Test
    func expiredContextIsCleared() async throws {
        let store = DailyDecisionContextStore()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try await store.record(
            question: "Is Djokovic better than Nadal?",
            verdict: .white,
            resetsAt: now.addingTimeInterval(60),
            now: now
        )

        let matches = try await store.relevantHistory(
            for: "Is Djokovic better than Nadal?",
            limit: 5,
            now: now.addingTimeInterval(61)
        )

        #expect(matches.isEmpty)
    }

    @Test
    func unrelatedHistoryIsExcluded() async throws {
        let store = DailyDecisionContextStore()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try await store.record(
            question: "Is water wet?",
            verdict: .white,
            resetsAt: now.addingTimeInterval(60),
            now: now
        )

        let matches = try await store.relevantHistory(
            for: "Is Djokovic better than Nadal?",
            limit: 5,
            now: now
        )

        #expect(matches.isEmpty)
    }
}

struct ReactionContextStoreTests {
    @Test
    func persistsOnlyBoundedReactionMetadataAcrossStoreRecreation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("reaction-context.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let initialStore = ReactionContextStore(fileURL: fileURL)
        for reactionId in [ReactionID.comeOn, .stillNo, .niceTry, .obviously, .easyOne,
                           .youKnewThat, .pleaseStop, .iSaidWhatISaid, .comeOn] {
            try await initialStore.record(reactionId: reactionId)
            try await initialStore.record(reactionId: nil)
        }

        let relaunchedStore = ReactionContextStore(fileURL: fileURL)
        let context = try await relaunchedStore.context()

        #expect(context.recentIds == [
            .stillNo, .niceTry, .obviously, .easyOne,
            .youKnewThat, .pleaseStop, .iSaidWhatISaid, .comeOn
        ])
        #expect(context.previousDecisionHadReaction == false)
        #expect(context.hasReceivedReaction == true)
        let persisted = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(!persisted.contains("question"))
    }
}

private actor DecisionRequestRecorder {
    private(set) var request: DecisionRequest?

    func capture(_ request: DecisionRequest) {
        self.request = request
    }
}

private struct RecordingDecisionService: DecisionService {
    let recorder: DecisionRequestRecorder

    func decide(_ request: DecisionRequest) async throws -> DecisionOutcome {
        await recorder.capture(request)
        return .verdict(.previewBlack)
    }
}

private actor ControllableDecisionService: DecisionService {
    private var continuation: CheckedContinuation<DecisionOutcome, any Error>?
    private var pendingResult: Result<DecisionOutcome, DecisionServiceError>?

    func decide(_ request: DecisionRequest) async throws -> DecisionOutcome {
        if let pendingResult {
            self.pendingResult = nil
            return try pendingResult.get()
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resolve(_ result: Result<DecisionOutcome, DecisionServiceError>) {
        guard let continuation else {
            pendingResult = result
            return
        }

        self.continuation = nil
        continuation.resume(with: result.mapError { $0 as any Error })
    }
}

private actor TransientContextStore: DailyDecisionContextStoring {
    func discardExpiredContext(now: Date) {}

    func relevantHistory(for question: String, limit: Int, now: Date) -> [RecentDecision] {
        []
    }

    func record(question: String, verdict: Verdict, resetsAt: Date, now: Date) {}
}

private actor InspectableReactionContextStore: ReactionContextStoring {
    private let storedContext: ReactionRequestContext
    private(set) var recordedIds: [ReactionID?] = []

    init(context: ReactionRequestContext) {
        storedContext = context
    }

    func context() -> ReactionRequestContext { storedContext }

    func record(reactionId: ReactionID?) {
        recordedIds.append(reactionId)
    }
}

struct ColorTokenTests {
    @Test
    func canonicalMonochromeTokensUseExactSRGBValues() {
        expect(BWColor.black, red: 0, green: 0, blue: 0)
        expect(BWColor.white, red: 1, green: 1, blue: 1)

        let gray = 107.0 / 255.0
        expect(BWColor.gray, red: gray, green: gray, blue: gray)
    }

    @Test
    func canonicalGrayContrastSupportsApprovedPairings() {
        let grayLuminance = relativeLuminance(107.0 / 255.0)
        let whiteOnGray = 1.05 / (grayLuminance + 0.05)
        let blackAgainstGray = (grayLuminance + 0.05) / 0.05

        #expect(whiteOnGray >= 4.5)
        #expect(blackAgainstGray >= 3.0)
    }

    private func expect(
        _ color: Color,
        red expectedRed: CGFloat,
        green expectedGreen: CGFloat,
        blue expectedBlue: CGFloat
    ) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        #expect(UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        #expect(abs(red - expectedRed) < 0.0001)
        #expect(abs(green - expectedGreen) < 0.0001)
        #expect(abs(blue - expectedBlue) < 0.0001)
        #expect(abs(alpha - 1) < 0.0001)
    }

    private func relativeLuminance(_ component: Double) -> Double {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}

struct SpacingTokenTests {
    @Test
    func canonicalSpacingScaleUsesApprovedPointValues() {
        #expect(BWSpacing.small == 8)
        #expect(BWSpacing.medium == 16)
        #expect(BWSpacing.large == 24)
        #expect(BWSpacing.extraLarge == 40)
    }
}

struct LayoutTokenTests {
    @Test
    func canonicalLayoutValuesUseApprovedPointMeasurements() {
        #expect(BWLayout.bottomActionHeight == 56)
        #expect(BWLayout.focusedSubmitHeight == 48)
        #expect(BWLayout.submitWidth == 80)
        #expect(BWLayout.splashAndRestingLeading == 52)
        #expect(BWLayout.actionSlant == 24)
        #expect(BWLayout.restingDiagonalClearance == 16)
        #expect(BWLayout.composerTextLeading == 16)
        #expect(BWLayout.composerTextTrailing == 92)
        #expect(BWType.restingComposerSize == 19)
    }

    @Test
    func restingAskInputConvertsTheFullscreenDiagonalIntoComposerCoordinates() {
        let geometry = AskDiagonalGeometry(
            contentFrame: CGRect(x: 10, y: 79, width: 402, height: 781),
            safeAreaInsets: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
        )
        let composerFrame = CGRect(x: 62, y: 830, width: 326, height: 56)

        #expect(geometry.canvasFrame == CGRect(x: 10, y: 20, width: 402, height: 874))
        #expect(abs(
            geometry.localBoundaryX(atGlobalY: composerFrame.minY, in: composerFrame)
                - (412 - ((830 - 20) * 402 / 874.0) - 62)
        ) < 0.0001)
        #expect(abs(
            geometry.localBoundaryX(atGlobalY: composerFrame.maxY, in: composerFrame)
                - (412 - ((886 - 20) * 402 / 874.0) - 62)
        ) < 0.0001)
    }

    @Test
    func restingAskInputUsesTheMeasuredCanvasOriginAndAspectRatio() {
        let narrowCanvas = AskDiagonalGeometry(
            canvasFrame: CGRect(x: 0, y: 0, width: 375, height: 812)
        )
        let wideCanvas = AskDiagonalGeometry(
            canvasFrame: CGRect(x: 8, y: 12, width: 430, height: 932)
        )

        #expect(narrowCanvas.boundaryX(atGlobalY: 700) != wideCanvas.boundaryX(atGlobalY: 700))
    }

    @Test
    func restingAskInputMaintainsAConstantPerpendicularClearanceFromTheDiagonal() {
        let geometry = AskDiagonalGeometry(canvasFrame: CGRect(x: 0, y: 0, width: 402, height: 874))
        let frame = CGRect(x: 60, y: 810, width: 328, height: 56)
        let boundary = geometry.localBoundaryX(atGlobalY: frame.minY, in: frame)
        let clearedBoundary = geometry.localBoundaryX(
            atGlobalY: frame.minY,
            in: frame,
            perpendicularClearance: BWLayout.restingDiagonalClearance
        )
        let slope = 402 / 874.0
        let perpendicularDistance = (clearedBoundary - boundary) / sqrt(1 + (slope * slope))

        #expect(abs(perpendicularDistance - 16) < 0.0001)
    }
}

struct MotionTokenTests {
    @Test
    func binaryImpactBeatMatchesTheCanonicalDropDuration() {
        #expect(BWMotion.verdictSlamDropBeat == .milliseconds(400))
        #expect(BWMotion.verdictSlamReboundBeat == .milliseconds(90))
        #expect(BWMotion.verdictSlamSettleBeat == .milliseconds(170))
    }

    @Test
    func slamHapticUsesOneImpactAndShortDecayingRumble() throws {
        #expect(VerdictSlamHapticPattern.rumbleDuration == 0.22)
        #expect(
            VerdictSlamHapticPattern.rumbleStartIntensity
                > VerdictSlamHapticPattern.rumbleMidIntensity
        )
        #expect(
            VerdictSlamHapticPattern.rumbleMidIntensity
                > VerdictSlamHapticPattern.rumbleEndIntensity
        )
        _ = try VerdictSlamHapticPattern.make()
    }

    @Test
    func productionFakeoutPresetRetainsCanonicalMotion() {
        let preset = FakeoutMotionPreset.production

        #expect(preset.misdirectionAmount == 0.8)
        #expect(preset.commitmentMilliseconds == 600)
        #expect(preset.holdMilliseconds == 0)
        #expect(preset.reversalMilliseconds == 200)
        #expect(preset.preSlamPauseMilliseconds == 0)
    }

    @Test
    func fakeoutPostCycleUsesTheNormalDecidingSpringCharacter() {
        #expect(BWMotion.fakeoutCommitmentBounce == BWMotion.decidingFirstPullBounce)
        #expect(BWMotion.fakeoutReversalBounce == BWMotion.decidingSecondPullBounce)
        #expect(FakeoutMotionPreset.production.commitmentMilliseconds == 600)
        #expect(FakeoutMotionPreset.production.reversalMilliseconds == 200)
    }

    @Test
    func fakeoutPlanUsesExplicitPhaseOrder() {
        let plan = FakeoutMotionPlan(
            preset: .experimentalLabInitial,
            finalVerdict: .black
        )

        #expect(plan.steps.map(\.phase) == [
            .preflightDownRight,
            .preflightUpLeft,
            .preflightSettle,
            .preflightDownRight,
            .preflightUpLeft,
            .preflightSettle,
            .commitment,
            .hold,
            .reversal,
            .preSlamPause,
            .slam
        ])
    }

    @Test(arguments: [Verdict.black, Verdict.white])
    func fakeoutPreflightIsTwoNormalFinalIndependentPullCycles(_ finalVerdict: Verdict) {
        let steps = FakeoutMotionPlan(
            preset: .production,
            finalVerdict: finalVerdict
        ).steps

        let normalCycle = Array(steps.prefix(3))
        #expect(BWMotion.fakeoutPreflightCycleCount == 2)
        #expect(normalCycle.map(\.phase) == [.preflightDownRight, .preflightUpLeft, .preflightSettle])
        #expect(normalCycle.map(\.targetVerdict) == [.black, .white, .white])
        #expect(normalCycle.map(\.tensionPull) == [BWMotion.decidingDownRightPull, BWMotion.decidingUpLeftOvershootPull, BWMotion.decidingUpLeftSettledPull])
        #expect(normalCycle.map(\.durationMilliseconds).reduce(0, +) == 420)
        #expect(normalCycle.allSatisfy { $0.resolutionProgress == 0 })
        #expect(Array(steps.prefix(6)) == normalCycle + normalCycle)
        #expect(steps.prefix(6).map(\.durationMilliseconds).reduce(0, +) == 840)
    }

    @Test(arguments: [Verdict.black, Verdict.white])
    func fakeoutCommitsToOppositeDirectionBeforeFinalVerdict(_ finalVerdict: Verdict) {
        let plan = FakeoutMotionPlan(
            preset: .experimentalLabInitial,
            finalVerdict: finalVerdict
        )

        let expectedWrongVerdict = finalVerdict == .black ? Verdict.white : Verdict.black
        #expect(plan.steps[6].targetVerdict == expectedWrongVerdict)
        #expect(plan.steps[6].tensionPull == expectedPull(toward: expectedWrongVerdict))
        #expect(plan.steps[6].resolutionProgress == -0.8)
        #expect(plan.steps[7].targetVerdict == expectedWrongVerdict)
        #expect(plan.steps[7].tensionPull == expectedPull(toward: expectedWrongVerdict))
        #expect(plan.steps[8].targetVerdict == finalVerdict)
        #expect(plan.steps[8].tensionPull == expectedPull(toward: finalVerdict))
        #expect(plan.steps[8].resolutionProgress == 1)
    }

    @Test
    func labPresetControlsOnlyPostCycleFakeoutPhases() {
        let production = FakeoutMotionPlan(preset: .production, finalVerdict: .white)
        let experimental = FakeoutMotionPlan(
            preset: .experimentalLabInitial,
            finalVerdict: .white
        )

        #expect(Array(production.steps.prefix(6)) == Array(experimental.steps.prefix(6)))
        #expect(production.steps[6].durationMilliseconds == 600)
        #expect(experimental.steps[6].durationMilliseconds == 280)
        #expect(production.steps[8].durationMilliseconds == 200)
        #expect(experimental.steps[8].durationMilliseconds == 140)
    }

    @Test
    func productionFakeoutPostCyclePresetIsUnchanged() {
        #expect(FakeoutMotionPreset.production == FakeoutMotionPreset(misdirectionAmount: 0.8, commitmentMilliseconds: 600, holdMilliseconds: 0, reversalMilliseconds: 200, preSlamPauseMilliseconds: 0))
    }

    @Test
    func pendingThinkingMarkDisablesAnimationForReduceMotion() {
        #expect(PendingDecisionThinkingMark.animationEnabled(reduceMotion: false))
        #expect(!PendingDecisionThinkingMark.animationEnabled(reduceMotion: true))
        #expect(
            PendingDecisionThinkingMark.animationTime(
                elapsed: 4,
                playbackSpeed: 0.25,
                reduceMotion: false
            ) == 1
        )
        #expect(
            PendingDecisionThinkingMark.animationTime(
                elapsed: 4,
                playbackSpeed: 1,
                reduceMotion: true
            ) == 0
        )
    }

    @Test
    func pendingThinkingMarkRenderPlanDrawsAllFillsThenAllOutlinesThenCenterCover() {
        #expect(LoadingMotionRenderPlan.operations == [
            .fill(blob: 0),
            .fill(blob: 1),
            .fill(blob: 2),
            .outline(blob: 0),
            .outline(blob: 1),
            .outline(blob: 2),
            .centerCover
        ])
    }

    @Test
    func loadingProductionDefaultsRemainSeparateFromExperimentalLabValues() {
        let production = LoadingMotionPreset.production
        let experimental = LoadingMotionPreset.experimentalLabInitial

        #expect(production != experimental)
        #expect(production.size >= 26 && production.size <= 38)
        #expect(production.size == 34)
        #expect(production.centerRatio == 0.68)
        #expect(production.outlineWidth == 0.9)
        #expect(production.firstBlob == LoadingMotionBlobPreset(deformationAmplitude: 0.13, speed: 0.55, phase: 0, slowRotation: 0.035))
        #expect(production.secondBlob == LoadingMotionBlobPreset(deformationAmplitude: 0.09, speed: 0.4, phase: 0.33, slowRotation: -0.025))
        #expect(production.thirdBlob == LoadingMotionBlobPreset(deformationAmplitude: 0.16, speed: 0.4, phase: 0.67, slowRotation: 0.018))
        #expect(production.centerBlob == LoadingMotionBlobPreset(deformationAmplitude: 0.09, speed: 0.2, phase: 0.21, slowRotation: 0.04))
        #expect(production.glowRadius == 0)
        #expect(production.glowOpacity == 0)
        #expect(production.centerRatio >= 0.50 && production.centerRatio <= 0.68)
        #expect(production.outlineWidth >= 0.5 && production.outlineWidth <= 1.5)
        // The owner-approved composition intentionally lets blobs share some
        // individual values; their complete motion profiles must remain distinct.
        #expect(production.firstBlob != production.secondBlob)
        #expect(production.secondBlob != production.thirdBlob)
        #expect(production.firstBlob != production.thirdBlob)
        #expect(Set(production.blobs.map(\.phase)).count == 3)
        #expect(Set(production.blobs.map(\.slowRotation)).count == 3)
    }

    @Test
    func loadingLabResetRestoresProductionDefaultsSpeedAndMotionPreview() {
        var settings = LoadingMotionLabSettings()
        settings.playbackSpeed = .quarter
        settings.reduceMotionPreview = true

        settings.resetToProductionDefaults()

        #expect(settings.preset == .production)
        #expect(settings.playbackSpeed == .full)
        #expect(!settings.reduceMotionPreview)
    }

    @Test
    func generatedLoadingPresetCopyIsReadableSwift() {
        let copy = LoadingMotionPreset.experimentalLabInitial.swiftInitializer

        #expect(copy.hasPrefix("LoadingMotionPreset("))
        #expect(copy.contains("size: 34"))
        #expect(copy.contains("centerRatio: 0.61"))
        #expect(copy.contains("firstBlob: LoadingMotionBlobPreset("))
        #expect(copy.contains("secondBlob: LoadingMotionBlobPreset("))
        #expect(copy.contains("thirdBlob: LoadingMotionBlobPreset("))
        #expect(copy.contains("centerBlob: LoadingMotionBlobPreset("))
        #expect(copy.contains("slowRotation:"))
        #expect(copy.hasSuffix("glowOpacity: 0.3\n)"))
    }

    @Test
    func loadingMotionLabLaunchRouteFollowsBuildConfiguration() {
        #expect(!LoadingMotionLabAvailability.shouldPresent(arguments: []))
#if DEBUG
        #expect(LoadingMotionLabAvailability.isAvailable)
        #expect(
            LoadingMotionLabAvailability.shouldPresent(
                arguments: ["BlackAndWhite", "--motion-lab-loading"]
            )
        )
#else
        #expect(!LoadingMotionLabAvailability.isAvailable)
        #expect(
            !LoadingMotionLabAvailability.shouldPresent(
                arguments: ["BlackAndWhite", "--motion-lab-loading"]
            )
        )
#endif
    }

    @Test
    func fullWidthVerdictSizingUsesMeasuredGlyphWidthWithoutHorizontalScaling() {
        let metrics = FullWidthVerdictTextSizing.metrics(
            text: "Yes.",
            targetWidth: 320,
            availableHeight: 260
        )

        #expect(metrics.fontSize > 0)
        #expect(metrics.opticalWidth <= 322)
        #expect(metrics.measuredHeight <= 260)
    }

    @Test(arguments: ["Yes.", "No.", "Da.", "Ne.", "Да.", "Не."])
    func fullWidthVerdictSizingOpticallyFillsEdgesForEveryProductionBinaryLabel(text: String) {
        let targetWidth: CGFloat = 320
        let metrics = FullWidthVerdictTextSizing.metrics(
            text: text,
            targetWidth: targetWidth,
            availableHeight: 260
        )

        #expect(metrics.opticalWidth >= targetWidth)
        #expect(metrics.measuredHeight <= 260)
        #expect(metrics.fillsTargetWidth)
    }

    @Test
    func grayPresentationUsesTheApprovedSeparate32PointTypeSize() {
        #expect(BWType.grayVerdictSize == 32)
    }

    @Test
    func fullWidthVerdictSizingReportsHeightConflictForExtremeLabel() {
        let metrics = FullWidthVerdictTextSizing.metrics(
            text: "This verdict is deliberately too long.",
            targetWidth: 140,
            availableHeight: 20
        )

        #expect(metrics.constraintWarning != nil)
    }

    @Test(arguments: [
        "Nije baš tako jednostavno.",
        "Није баш тако једноставно.",
        "نعم.",
        "כן.",
        "はい。"
    ])
    func fullWidthVerdictSizingSupportsLocalizedAndDirectionalityFixtures(text: String) {
        let metrics = FullWidthVerdictTextSizing.metrics(
            text: text,
            targetWidth: 320,
            availableHeight: 260
        )

        #expect(metrics.fontSize >= 20)
        #expect(metrics.opticalWidth <= 322)
        #expect(metrics.measuredHeight <= 260)
    }

    @Test
    func verdictTypographyLabLaunchRouteFollowsBuildConfiguration() {
        #expect(!FullWidthVerdictLabAvailability.shouldPresent(arguments: []))
#if DEBUG
        #expect(FullWidthVerdictLabAvailability.isAvailable)
        #expect(FullWidthVerdictLabAvailability.shouldPresent(arguments: ["--verdict-typography-lab"]))
#else
        #expect(!FullWidthVerdictLabAvailability.isAvailable)
        #expect(!FullWidthVerdictLabAvailability.shouldPresent(arguments: ["--verdict-typography-lab"]))
#endif
    }

    @Test
    func labSpeedScalesEveryPlannedDuration() {
        let full = FakeoutMotionPlan(
            preset: .experimentalLabInitial,
            finalVerdict: .white,
            playbackSpeed: FakeoutMotionPlaybackSpeed.full.rawValue
        )
        let quarter = FakeoutMotionPlan(
            preset: .experimentalLabInitial,
            finalVerdict: .white,
            playbackSpeed: FakeoutMotionPlaybackSpeed.quarter.rawValue
        )

        #expect(zip(full.steps, quarter.steps).allSatisfy { fullStep, quarterStep in
            quarterStep.durationMilliseconds == fullStep.durationMilliseconds * 4
        })
    }

    @Test
    func labResetRestoresProductionPresetAndSpeed() {
        var settings = FakeoutMotionLabSettings()
        settings.playbackSpeed = .quarter

        settings.resetToProductionDefaults()

        #expect(settings.preset == .production)
        #expect(settings.playbackSpeed == .full)
    }

    @Test
    func generatedPresetCopyIsReadableSwift() {
        #expect(FakeoutMotionPreset.experimentalLabInitial.swiftInitializer == """
        FakeoutMotionPreset(
            misdirectionAmount: 0.8,
            commitmentMilliseconds: 280,
            holdMilliseconds: 220,
            reversalMilliseconds: 140,
            preSlamPauseMilliseconds: 40
        )
        """)
    }

    @Test
    func fakeoutMotionLabLaunchRouteFollowsBuildConfiguration() {
        #expect(!FakeoutMotionLabAvailability.shouldPresent(arguments: []))
#if DEBUG
        #expect(FakeoutMotionLabAvailability.isAvailable)
        #expect(
            FakeoutMotionLabAvailability.shouldPresent(
                arguments: ["BlackAndWhite", "--motion-lab-fakeout"]
            )
        )
#else
        #expect(!FakeoutMotionLabAvailability.isAvailable)
        #expect(
            !FakeoutMotionLabAvailability.shouldPresent(
                arguments: ["BlackAndWhite", "--motion-lab-fakeout"]
            )
        )
#endif
    }

    private func expectedPull(toward verdict: Verdict) -> Double {
        verdict == .black
            ? BWMotion.decidingDownRightPull
            : BWMotion.decidingUpLeftSettledPull
    }
}
