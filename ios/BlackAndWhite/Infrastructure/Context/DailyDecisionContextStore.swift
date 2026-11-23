import Foundation

protocol DailyDecisionContextStoring: Sendable {
    func discardExpiredContext(now: Date) async throws

    func relevantHistory(
        for question: String,
        limit: Int,
        now: Date
    ) async throws -> [RecentDecision]

    func record(
        question: String,
        verdict: Verdict,
        resetsAt: Date,
        now: Date
    ) async throws
}

protocol ReactionContextStoring: Sendable {
    func context() async throws -> ReactionRequestContext
    func record(reactionId: ReactionID?) async throws
}

actor ReactionContextStore: ReactionContextStoring {
    private struct Snapshot: Codable, Equatable {
        var recentIds: [ReactionID]
        var previousDecisionHadReaction: Bool
        var hasReceivedReaction: Bool
    }

    private let fileURL: URL?
    private var snapshot: Snapshot?
    private var hasLoaded = false

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL
    }

    func context() throws -> ReactionRequestContext {
        try loadIfNeeded()
        return ReactionRequestContext(
            recentIds: Array((snapshot?.recentIds ?? []).suffix(8)),
            previousDecisionHadReaction: snapshot?.previousDecisionHadReaction ?? false,
            hasReceivedReaction: snapshot?.hasReceivedReaction ?? false
        )
    }

    func record(reactionId: ReactionID?) throws {
        try loadIfNeeded()
        var recentIds = snapshot?.recentIds ?? []
        if let reactionId {
            recentIds.append(reactionId)
            recentIds = Array(recentIds.suffix(8))
        }
        snapshot = Snapshot(
            recentIds: recentIds,
            previousDecisionHadReaction: reactionId != nil,
            hasReceivedReaction: (snapshot?.hasReceivedReaction ?? false) || reactionId != nil
        )
        try persist()
    }

    private func loadIfNeeded() throws {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: fileURL))
        } catch {
            snapshot = nil
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private func persist() throws {
        guard let fileURL, let snapshot else { return }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(snapshot).write(
            to: fileURL,
            options: [.atomic, .completeFileProtection]
        )
    }
}

actor DailyDecisionContextStore: DailyDecisionContextStoring {
    private struct Snapshot: Codable, Equatable {
        var resetsAt: Date
        var decisions: [RecentDecision]
    }

    private let fileURL: URL?
    private var snapshot: Snapshot?
    private var hasLoaded = false

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL
    }

    func discardExpiredContext(now: Date) throws {
        try loadIfNeeded()
        try discardExpiredContext(at: now)
    }

    func relevantHistory(
        for question: String,
        limit: Int,
        now: Date
    ) throws -> [RecentDecision] {
        try loadIfNeeded()
        try discardExpiredContext(at: now)

        guard let snapshot else { return [] }
        return QuestionContextSelector.select(
            from: snapshot.decisions,
            relevantTo: question,
            limit: limit
        )
    }

    func record(
        question: String,
        verdict: Verdict,
        resetsAt: Date,
        now: Date
    ) throws {
        try loadIfNeeded()
        try discardExpiredContext(at: now)

        guard resetsAt > now else {
            snapshot = nil
            try persist()
            return
        }

        if snapshot?.resetsAt != resetsAt {
            snapshot = Snapshot(resetsAt: resetsAt, decisions: [])
        }

        snapshot?.decisions.append(RecentDecision(question: question, verdict: verdict))
        try persist()
    }

    private func loadIfNeeded() throws {
        guard !hasLoaded else { return }
        hasLoaded = true

        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
        } catch {
            snapshot = nil
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private func discardExpiredContext(at now: Date) throws {
        guard let snapshot, snapshot.resetsAt <= now else { return }
        self.snapshot = nil
        try persist()
    }

    private func persist() throws {
        guard let fileURL else { return }

        if let snapshot {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } else if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}

enum QuestionContextSelector {
    private struct Candidate {
        let decision: RecentDecision
        let score: Double
        let index: Int
    }

    static func select(
        from decisions: [RecentDecision],
        relevantTo question: String,
        limit: Int
    ) -> [RecentDecision] {
        guard limit > 0 else { return [] }
        let queryTerms = semanticTerms(in: question)
        guard !queryTerms.isEmpty else { return [] }

        let selected = decisions.enumerated()
            .compactMap { index, decision -> Candidate? in
                let candidateTerms = semanticTerms(in: decision.question)
                let shared = queryTerms.intersection(candidateTerms)
                guard shared.count >= minimumSharedTermCount(
                    queryCount: queryTerms.count,
                    candidateCount: candidateTerms.count
                ) else {
                    return nil
                }

                let unionCount = queryTerms.union(candidateTerms).count
                let score = unionCount == 0 ? 0 : Double(shared.count) / Double(unionCount)
                return Candidate(decision: decision, score: score, index: index)
            }
            .sorted {
                if $0.score == $1.score {
                    return $0.index > $1.index
                }
                return $0.score > $1.score
            }
            .prefix(limit)

        return selected
            .sorted { $0.index < $1.index }
            .map(\.decision)
    }

    private static func minimumSharedTermCount(queryCount: Int, candidateCount: Int) -> Int {
        min(queryCount, candidateCount) <= 1 ? 1 : 2
    }

    private static func semanticTerms(in question: String) -> Set<String> {
        let folded = question
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()

        return Set(
            folded
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .compactMap(canonicalTerm)
        )
    }

    private static func canonicalTerm(_ term: String) -> String? {
        if stopTerms.contains(term) {
            return nil
        }
        return aliases[term] ?? term
    }

    private static let stopTerms: Set<String> = [
        "a", "an", "are", "be", "do", "does", "i", "is", "it", "me", "of", "or",
        "say", "should", "than", "that", "the", "to", "would", "you"
    ]

    private static let aliases: [String: String] = [
        "best": "better",
        "superior": "better",
        "greater": "better"
    ]
}
