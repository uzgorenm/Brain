import Foundation
import Testing
@testable import BrainCore

@Test func sqliteStorePersistsTheCoreLearningLoop() throws {
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("brain-core-tests-\(UUID().uuidString).sqlite")
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let store = try SQLiteStore(path: databaseURL.path)
    let first = try store.createCard(
        title: "SwiftUI",
        body: "A declarative UI framework.",
        tags: ["swift"],
        imagePaths: ["Media/swiftui.jpg"],
        metadata: ["deck": "Apple"]
    )
    let second = try store.createCard(
        title: "Knowledge Graph",
        body: "Cards connected by explicit edges."
    )
    _ = try store.addEdge(from: first.id, to: second.id, label: "can visualize")

    #expect(try store.neighbors(of: first.id).map(\.id) == [second.id])
    #expect(try store.images(for: first.id).map(\.localPath) == ["Media/swiftui.jpg"])

    let reviewedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let nextState = try store.applyReview(cardID: first.id, rating: .good, reviewedAt: reviewedAt)

    #expect(nextState.status == .mastered(20))
    #expect(nextState.reviewCount == 1)
    #expect(try store.dueCards(now: reviewedAt).map(\.id) == [second.id])

    let events = try store.allReviewEvents()
    #expect(events.count == 1)
    #expect(events.first?.cardID == first.id)
    #expect(events.first?.nextMasteryPercent == 20)

    var edited = first
    edited.title = "SwiftUI Framework"
    edited.body = "Apple's declarative interface framework."
    try store.updateCard(edited)

    #expect(try store.searchCards("declarative").map(\.id) == [first.id])

    try store.deleteCard(second.id)

    #expect(try store.allCards().map(\.id) == [first.id])
    #expect(try store.neighbors(of: first.id).isEmpty)

    let reopenedStore = try SQLiteStore(path: databaseURL.path)
    #expect(try reopenedStore.allCards().map(\.title) == ["SwiftUI Framework"])
    #expect(try reopenedStore.allReviewEvents().count == 1)
}
