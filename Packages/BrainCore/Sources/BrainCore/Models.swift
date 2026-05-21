import Foundation

public struct KnowledgeCard: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var body: String
    public var metadata: [String: String]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        body: String,
        metadata: [String: String] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct CardImage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let cardID: UUID
    public var localPath: String
    public var remoteURL: String?
    public var createdAt: Date

    public init(id: UUID = UUID(), cardID: UUID, localPath: String, remoteURL: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.cardID = cardID
        self.localPath = localPath
        self.remoteURL = remoteURL
        self.createdAt = createdAt
    }
}

public struct CardEdge: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let sourceCardID: UUID
    public let targetCardID: UUID
    public var label: String
    public var weight: Double
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        sourceCardID: UUID,
        targetCardID: UUID,
        label: String = "related to",
        weight: Double = 1,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceCardID = sourceCardID
        self.targetCardID = targetCardID
        self.label = label
        self.weight = weight
        self.createdAt = createdAt
    }
}

public enum ReviewRating: String, CaseIterable, Sendable {
    case again
    case hard
    case good
    case easy
}

public enum ReviewStatus: Equatable, Sendable {
    case new
    case due
    case mastered(Int)

    public var storageValue: String {
        switch self {
        case .new:
            "new"
        case .due:
            "due"
        case .mastered(let percent):
            "mastered_\(percent)"
        }
    }

    public var masteryPercent: Int {
        switch self {
        case .new, .due:
            0
        case .mastered(let percent):
            percent
        }
    }

    public static func fromStorage(_ value: String, masteryPercent: Int) -> ReviewStatus {
        if value == "new" { return .new }
        if value == "due" { return .due }
        return .mastered(Self.clampedMastery(masteryPercent))
    }

    public static func clampedMastery(_ value: Int) -> Int {
        min(100, max(0, value))
    }
}

public struct ReviewState: Equatable, Sendable {
    public let cardID: UUID
    public var status: ReviewStatus
    public var difficulty: Double?
    public var stability: Double?
    public var intervalDays: Int?
    public var dueAt: Date?
    public var lastReviewedAt: Date?
    public var reviewCount: Int

    public init(
        cardID: UUID,
        status: ReviewStatus = .new,
        difficulty: Double? = nil,
        stability: Double? = nil,
        intervalDays: Int? = nil,
        dueAt: Date? = nil,
        lastReviewedAt: Date? = nil,
        reviewCount: Int = 0
    ) {
        self.cardID = cardID
        self.status = status
        self.difficulty = difficulty
        self.stability = stability
        self.intervalDays = intervalDays
        self.dueAt = dueAt
        self.lastReviewedAt = lastReviewedAt
        self.reviewCount = reviewCount
    }
}

public struct ReviewEvent: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let cardID: UUID
    public let reviewedAt: Date
    public let rating: ReviewRating
    public let userID: String
    public let elapsedDays: Int
    public let scheduledDays: Int
    public let previousMasteryPercent: Int
    public let nextMasteryPercent: Int

    public init(
        id: UUID = UUID(),
        cardID: UUID,
        reviewedAt: Date = Date(),
        rating: ReviewRating,
        userID: String = "local",
        elapsedDays: Int,
        scheduledDays: Int,
        previousMasteryPercent: Int,
        nextMasteryPercent: Int
    ) {
        self.id = id
        self.cardID = cardID
        self.reviewedAt = reviewedAt
        self.rating = rating
        self.userID = userID
        self.elapsedDays = elapsedDays
        self.scheduledDays = scheduledDays
        self.previousMasteryPercent = previousMasteryPercent
        self.nextMasteryPercent = nextMasteryPercent
    }
}
