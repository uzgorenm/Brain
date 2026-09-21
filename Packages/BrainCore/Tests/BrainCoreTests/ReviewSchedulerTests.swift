import Foundation
import Testing
@testable import BrainCore

@Test func goodReviewSchedulesNewCardAndDerivesMasteryFromInterval() {
    let cardID = UUID()
    let scheduler = ReviewScheduler()
    let state = ReviewState(cardID: cardID, status: .new)
    let reviewedAt = Date(timeIntervalSince1970: 0)

    let (next, event) = scheduler.apply(.good, to: state, reviewedAt: reviewedAt)

    #expect(next.status == .mastered(20))
    #expect(next.difficulty != nil)
    #expect(next.stability == ReviewScheduler.defaultParameters[2])
    #expect(next.intervalDays == 2)
    #expect(next.dueAt == Calendar.current.date(byAdding: .day, value: 2, to: reviewedAt))
    #expect(event.scheduledDays == 2)
    #expect(event.elapsedDays == 0)
    #expect(event.previousMasteryPercent == 0)
    #expect(event.nextMasteryPercent == 20)
}

@Test func easyReviewUsesExistingFSRSMemoryState() {
    let cardID = UUID()
    let scheduler = ReviewScheduler()
    let reviewedAt = Date(timeIntervalSince1970: 0)
    let state = ReviewState(
        cardID: cardID,
        status: .mastered(8),
        difficulty: 5,
        stability: 30,
        dueAt: Calendar.current.date(byAdding: .day, value: 30, to: reviewedAt),
        lastReviewedAt: reviewedAt
    )

    let (next, _) = scheduler.apply(.easy, to: state, reviewedAt: reviewedAt)

    #expect(next.difficulty != state.difficulty)
    #expect((next.stability ?? 0) > 30)
    #expect(next.status.masteryPercent >= 0)
}

@Test func intervalsMapToSupportedMasteryBands() {
    let scheduler = ReviewScheduler()

    #expect(scheduler.masteryPercent(forIntervalDays: 1) == 20)
    #expect(scheduler.masteryPercent(forIntervalDays: 2) == 20)
    #expect(scheduler.masteryPercent(forIntervalDays: 60) == 20)
    #expect(scheduler.masteryPercent(forIntervalDays: 183) == 60)
    #expect(scheduler.masteryPercent(forIntervalDays: 365) == 100)
    #expect(scheduler.masteryPercent(forIntervalDays: 730) == 100)
}

@Test func legacyStoredMasteryNormalizesToSupportedBand() {
    #expect(ReviewStatus.fromStorage("mastered", masteryPercent: 1) == .mastered(20))
    #expect(ReviewStatus.fromStorage("mastered", masteryPercent: 51) == .mastered(60))
    #expect(ReviewStatus.fromStorage("mastered", masteryPercent: 100) == .mastered(100))
}
