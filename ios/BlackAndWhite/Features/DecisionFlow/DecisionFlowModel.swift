import Foundation
import Observation

enum AskPresentation: Equatable, Sendable {
    case resting
    case focused
}

enum DecisionFlowPhase: Equatable, Sendable {
    case splash
    case asking(AskPresentation)
    case submitting
    case deciding
    case verdict(Decision)
    case error(DecisionFlowError)
    case limitReached(Usage)
}

enum DecisionFlowError: Equatable, Sendable {
    case invalidQuestion
    case connection
    case paused
    case unavailable

    var message: String {
        switch self {
        case .invalidQuestion: "Give me a real question."
        case .connection: "Couldn't reach the judge."
        case .paused: "I've stopped judging for a moment."
        case .unavailable: "No decision right now."
        }
    }
}

@MainActor
@Observable
final class DecisionFlowModel {
    private(set) var phase: DecisionFlowPhase = .splash
    var question = ""
    private(set) var unsupportedFormat: UnsupportedQuestionFormat?
    private(set) var focusGeneration = 0
    private(set) var focusDelay: Duration = .milliseconds(250)

    private let service: any DecisionService
    private let dailyContextStore: any DailyDecisionContextStoring
    private let reactionContextStore: any ReactionContextStoring
    private let contextBudget: Int
    private let now: @Sendable () -> Date
    private let splashBridgeDuration: Duration
    private let standardDecisionBeat: Duration
    private var submissionTask: Task<Void, Never>?
    private var splashTransitionTask: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?

    init(
        service: any DecisionService,
        dailyContextStore: any DailyDecisionContextStoring = DailyDecisionContextStore(),
        reactionContextStore: any ReactionContextStoring = ReactionContextStore(),
        contextBudget: Int = 5,
        now: @escaping @Sendable () -> Date = Date.init,
        initialPhase: DecisionFlowPhase = .splash,
        splashBridgeDuration: Duration = .milliseconds(100),
        standardDecisionBeat: Duration = .milliseconds(350)
    ) {
        self.service = service
        self.dailyContextStore = dailyContextStore
        self.reactionContextStore = reactionContextStore
        self.contextBudget = max(0, contextBudget)
        self.now = now
        self.splashBridgeDuration = splashBridgeDuration
        self.standardDecisionBeat = standardDecisionBeat
        phase = initialPhase
    }

    func startAsking() {
        guard phase == .splash else { return }
        splashTransitionTask?.cancel()
        phase = .asking(.resting)
        splashTransitionTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: splashBridgeDuration)
            } catch {
                return
            }
            guard phase == .asking(.resting) else { return }
            transitionToFocusedAsk()
        }
    }

    func setAskPresentation(_ presentation: AskPresentation) {
        guard case .asking = phase else { return }
        phase = .asking(presentation)
    }

    func dismissFocusedAsk() {
        guard phase == .asking(.focused) else { return }
        phase = .asking(.resting)
    }

    func focusRestingAsk() {
        guard phase == .asking(.resting) else { return }
        transitionToFocusedAsk(focusDelay: .zero)
    }

    func submit() {
        guard case .asking = phase else { return }
        let normalized = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 500 else {
            phase = .error(.invalidQuestion)
            return
        }

        submissionTask?.cancel()
        unsupportedFormat = nil
        phase = .submitting
        submissionTask = Task { [weak self] in
            guard let self else { return }
            await self.performDecision(question: normalized)
        }
    }

    func askAgain() {
        guard case .verdict = phase else { return }
        question = ""
        transitionToFocusedAsk()
    }

    func recover() {
        guard case .error = phase else { return }
        transitionToFocusedAsk()
    }

    func questionDidChange() {
        guard unsupportedFormat != nil else { return }
        unsupportedFormat = nil
    }

    func refreshUsageLimitState() {
        guard case .limitReached(let usage) = phase else { return }
        guard now() >= usage.resetsAt else { return }
        resetTask?.cancel()
        Task { [dailyContextStore, now] in
            try? await dailyContextStore.discardExpiredContext(now: now())
        }
        question = ""
        unsupportedFormat = nil
        transitionToFocusedAsk(focusDelay: .zero)
    }

    private func transitionToFocusedAsk(focusDelay: Duration = .milliseconds(250)) {
        self.focusDelay = focusDelay
        phase = .asking(.focused)
        focusGeneration += 1
    }

    private func performDecision(question: String) async {
        do {
            let requestDate = now()
            let relevantHistory = (try? await dailyContextStore.relevantHistory(
                for: question,
                limit: contextBudget,
                now: requestDate
            )) ?? []
            let reactionContext = (try? await reactionContextStore.context()) ?? .empty
            let outcome = try await service.decide(
                DecisionRequest(
                    question: question,
                    recent: relevantHistory,
                    reactionContext: reactionContext
                )
            )
            guard !Task.isCancelled else { return }

            switch outcome {
            case .verdict(let decision):
                try? await reactionContextStore.record(reactionId: decision.reactionId)
                try? await dailyContextStore.record(
                    question: question,
                    verdict: decision.verdict,
                    resetsAt: decision.usage.resetsAt,
                    now: now()
                )
                if decision.usage.state == .exhausted {
                    enterUsageLimit(with: decision.usage)
                } else {
                    phase = .verdict(decision)
                }
            case .unsupportedQuestionFormat(let unsupportedFormat):
                self.unsupportedFormat = unsupportedFormat
                transitionToFocusedAsk()
            }
        } catch is CancellationError {
            return
        } catch let error as DecisionServiceError {
            switch error {
            case .invalidRequest: phase = .error(.invalidQuestion)
            case .usageExhausted(let resetsAt):
                enterUsageLimit(with: Usage(remainingToday: 0, state: .exhausted, resetsAt: resetsAt))
            case .servicePaused: phase = .error(.paused)
            case .rateLimited, .unavailable: phase = .error(.connection)
            case .invalidResponse: phase = .error(.unavailable)
            }
        } catch {
            phase = .error(.unavailable)
        }
    }

    private func enterUsageLimit(with usage: Usage) {
        resetTask?.cancel()
        phase = .limitReached(usage)
        let delay = max(0, usage.resetsAt.timeIntervalSince(now()))
        resetTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.refreshUsageLimitState()
        }
    }

}
