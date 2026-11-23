import Foundation

protocol DecisionService: Sendable {
    func decide(_ request: DecisionRequest) async throws -> DecisionOutcome
}

enum DecisionServiceError: Error, Equatable, Sendable {
    case invalidRequest
    case usageExhausted(resetsAt: Date)
    case rateLimited(retryAfter: TimeInterval?)
    case servicePaused
    case unavailable
    case invalidResponse
}
