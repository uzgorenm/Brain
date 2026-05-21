import Foundation

public struct ReviewScheduler: Sendable {
    public static let masteredIntervalDays = 365
    public static let desiredRetention = 0.90

    // FSRS-6 default parameters from open-spaced-repetition/fsrs-rs 5.2.0.
    public static let defaultParameters: [Double] = [
        0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194,
        0.001, 1.8722, 0.1666, 0.796, 1.4835, 0.0614, 0.2629,
        1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542
    ]

    private let parameters: [Double]
    private let desiredRetention: Double

    public init(parameters: [Double] = Self.defaultParameters, desiredRetention: Double = Self.desiredRetention) {
        self.parameters = parameters
        self.desiredRetention = desiredRetention
    }

    public func apply(_ rating: ReviewRating, to state: ReviewState, reviewedAt: Date = Date()) -> (ReviewState, ReviewEvent) {
        let previousMastery = state.status.masteryPercent
        let elapsedDays = elapsedDays(from: state, reviewedAt: reviewedAt)
        let nextMemory = nextMemoryState(rating: rating, state: state, elapsedDays: elapsedDays)
        let scheduledDays = scheduledDays(for: nextMemory.stability, rating: rating)
        let nextMastery = masteryPercent(forIntervalDays: scheduledDays)
        let nextDueAt = Calendar.current.date(byAdding: .day, value: scheduledDays, to: reviewedAt)
        let nextStatus: ReviewStatus = nextDueAt.map { $0 <= reviewedAt } == true ? .due : .mastered(nextMastery)

        let nextState = ReviewState(
            cardID: state.cardID,
            status: nextStatus,
            difficulty: nextMemory.difficulty,
            stability: nextMemory.stability,
            intervalDays: scheduledDays,
            dueAt: nextDueAt,
            lastReviewedAt: reviewedAt,
            reviewCount: state.reviewCount + 1
        )

        let event = ReviewEvent(
            cardID: state.cardID,
            reviewedAt: reviewedAt,
            rating: rating,
            elapsedDays: elapsedDays,
            scheduledDays: scheduledDays,
            previousMasteryPercent: previousMastery,
            nextMasteryPercent: nextMastery
        )

        return (nextState, event)
    }

    public func visibleStatus(for state: ReviewState, now: Date = Date()) -> ReviewStatus {
        if case .new = state.status {
            return .new
        }

        if let dueAt = state.dueAt, dueAt <= now {
            return .due
        }

        return state.status
    }

    public func masteryPercent(forIntervalDays intervalDays: Int) -> Int {
        guard intervalDays > 0 else { return 0 }
        let rawPercent = Int(ceil(Double(intervalDays) / Double(Self.masteredIntervalDays) * 100))
        return ReviewStatus.clampedMastery(rawPercent)
    }

    private func elapsedDays(from state: ReviewState, reviewedAt: Date) -> Int {
        guard let lastReviewedAt = state.lastReviewedAt else {
            return 0
        }

        let elapsed = Calendar.current.dateComponents([.day], from: lastReviewedAt, to: reviewedAt).day ?? 0
        return max(0, elapsed)
    }

    private func nextMemoryState(rating: ReviewRating, state: ReviewState, elapsedDays: Int) -> MemoryState {
        guard let difficulty = state.difficulty, let stability = state.stability else {
            return MemoryState(
                difficulty: initialDifficulty(for: rating),
                stability: initialStability(for: rating)
            )
        }

        let retrievability = retrievability(elapsedDays: elapsedDays, stability: stability)
        let nextDifficulty = nextDifficulty(current: difficulty, rating: rating)
        let nextStability: Double

        if rating == .again {
            nextStability = nextForgetStability(
                difficulty: nextDifficulty,
                stability: stability,
                retrievability: retrievability
            )
        } else if elapsedDays == 0 {
            nextStability = shortTermStability(stability: stability, rating: rating)
        } else {
            nextStability = nextRecallStability(
                difficulty: nextDifficulty,
                stability: stability,
                retrievability: retrievability,
                rating: rating
            )
        }

        return MemoryState(
            difficulty: nextDifficulty.clamped(to: 1...10),
            stability: max(0.01, nextStability)
        )
    }

    private func scheduledDays(for stability: Double, rating: ReviewRating) -> Int {
        guard rating != .again else { return 0 }
        let interval = stability * pow(log(desiredRetention) / log(0.9), 1 / parameters[20])
        return max(1, Int(round(interval)))
    }

    private func retrievability(elapsedDays: Int, stability: Double) -> Double {
        guard stability > 0 else { return 0 }
        let factor = pow(0.9, 1 / -parameters[20]) - 1
        return pow((Double(elapsedDays) / stability) * factor + 1, -parameters[20])
    }

    private func initialStability(for rating: ReviewRating) -> Double {
        parameters[rating.score - 1]
    }

    private func initialDifficulty(for rating: ReviewRating) -> Double {
        (parameters[4] - exp(parameters[5] * Double(rating.score - 1)) + 1).clamped(to: 1...10)
    }

    private func nextDifficulty(current: Double, rating: ReviewRating) -> Double {
        let nextDifficulty = current - parameters[6] * Double(rating.score - 3)
        let easyMean = initialDifficulty(for: .easy)
        return (parameters[7] * easyMean + (1 - parameters[7]) * nextDifficulty).clamped(to: 1...10)
    }

    private func shortTermStability(stability: Double, rating: ReviewRating) -> Double {
        stability * exp(parameters[17] * (Double(rating.score) - 3 + parameters[18]))
    }

    private func nextRecallStability(difficulty: Double, stability: Double, retrievability: Double, rating: ReviewRating) -> Double {
        let hardPenalty = rating == .hard ? parameters[15] : 1
        let easyBonus = rating == .easy ? parameters[16] : 1
        return stability * (
            1 + exp(parameters[8])
            * (11 - difficulty)
            * pow(stability, -parameters[9])
            * (exp((1 - retrievability) * parameters[10]) - 1)
            * hardPenalty
            * easyBonus
        )
    }

    private func nextForgetStability(difficulty: Double, stability: Double, retrievability: Double) -> Double {
        parameters[11]
            * pow(difficulty, -parameters[12])
            * (pow(stability + 1, parameters[13]) - 1)
            * exp((1 - retrievability) * parameters[14])
    }
}

private struct MemoryState {
    let difficulty: Double
    let stability: Double
}

private extension ReviewRating {
    var score: Int {
        switch self {
        case .again: 1
        case .hard: 2
        case .good: 3
        case .easy: 4
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
