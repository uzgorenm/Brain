import Foundation
import SQLite3

public enum BrainStoreError: Error, CustomStringConvertible {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case bindFailed(String)
    case invalidUUID(String)

    public var description: String {
        switch self {
        case .openFailed(let message): "Could not open SQLite database: \(message)"
        case .prepareFailed(let message): "Could not prepare SQLite statement: \(message)"
        case .stepFailed(let message): "Could not execute SQLite statement: \(message)"
        case .bindFailed(let message): "Could not bind SQLite value: \(message)"
        case .invalidUUID(let value): "Invalid UUID stored in database: \(value)"
        }
    }
}

public final class SQLiteStore: @unchecked Sendable {
    private var db: OpaquePointer?
    private let scheduler = ReviewScheduler()

    public init(path: String) throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            throw BrainStoreError.openFailed(Self.errorMessage(db))
        }
        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    public func createCard(title: String, body: String, tags: [String] = [], imagePaths: [String] = [], metadata: [String: String] = [:]) throws -> KnowledgeCard {
        let now = Date()
        let card = KnowledgeCard(title: title, body: body, metadata: metadata, createdAt: now, updatedAt: now)
        let metadataData = try JSONEncoder().encode(metadata)
        let metadataJSON = String(data: metadataData, encoding: .utf8) ?? "{}"

        try execute(
            """
            INSERT INTO cards (id, title, body, metadata_json, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            [.text(card.id.uuidString), .text(title), .text(body), .text(metadataJSON), .double(now.timeIntervalSince1970), .double(now.timeIntervalSince1970)]
        )

        for tag in tags {
            try addTag(tag, to: card.id)
        }

        for path in imagePaths {
            try addImage(path: path, to: card.id)
        }

        try saveReviewState(ReviewState(cardID: card.id, status: .new))
        return card
    }

    public func updateCard(_ card: KnowledgeCard) throws {
        let metadataData = try JSONEncoder().encode(card.metadata)
        let metadataJSON = String(data: metadataData, encoding: .utf8) ?? "{}"
        try execute(
            """
            UPDATE cards
            SET title = ?, body = ?, metadata_json = ?, updated_at = ?
            WHERE id = ?
            """,
            [.text(card.title), .text(card.body), .text(metadataJSON), .double(Date().timeIntervalSince1970), .text(card.id.uuidString)]
        )
    }

    public func deleteCard(_ cardID: UUID, deletedAt: Date = Date()) throws {
        try execute(
            """
            DELETE FROM edges
            WHERE source_card_id = ? OR target_card_id = ?
            """,
            [.text(cardID.uuidString), .text(cardID.uuidString)]
        )
        try execute(
            """
            UPDATE cards
            SET deleted_at = ?, updated_at = ?
            WHERE id = ?
            """,
            [.double(deletedAt.timeIntervalSince1970), .double(deletedAt.timeIntervalSince1970), .text(cardID.uuidString)]
        )
    }

    public func addEdge(from sourceCardID: UUID, to targetCardID: UUID, label: String = "related to", weight: Double = 1) throws -> CardEdge {
        let edge = CardEdge(sourceCardID: sourceCardID, targetCardID: targetCardID, label: label, weight: weight)
        try execute(
            """
            INSERT INTO edges (id, source_card_id, target_card_id, label, weight, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            [.text(edge.id.uuidString), .text(sourceCardID.uuidString), .text(targetCardID.uuidString), .text(label), .double(weight), .double(edge.createdAt.timeIntervalSince1970)]
        )
        return edge
    }

    public func deleteEdge(between firstCardID: UUID, and secondCardID: UUID) throws {
        try execute(
            """
            DELETE FROM edges
            WHERE (source_card_id = ? AND target_card_id = ?)
               OR (source_card_id = ? AND target_card_id = ?)
            """,
            [
                .text(firstCardID.uuidString),
                .text(secondCardID.uuidString),
                .text(secondCardID.uuidString),
                .text(firstCardID.uuidString)
            ]
        )
    }

    public func addTag(_ name: String, to cardID: UUID) throws {
        let tagID = UUID()
        try execute("INSERT OR IGNORE INTO tags (name) VALUES (?)", [.text(name)])
        try execute(
            """
            INSERT OR IGNORE INTO card_tags (card_id, tag_name)
            VALUES (?, ?)
            """,
            [.text(cardID.uuidString), .text(name)]
        )
        _ = tagID
    }

    public func addImage(path: String, to cardID: UUID) throws {
        let image = CardImage(cardID: cardID, localPath: path)
        try execute(
            """
            INSERT INTO card_images (id, card_id, local_path, remote_url, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            [.text(image.id.uuidString), .text(cardID.uuidString), .text(path), .null, .double(image.createdAt.timeIntervalSince1970)]
        )
    }

    public func images(for cardID: UUID) throws -> [CardImage] {
        try query(
            """
            SELECT id, card_id, local_path, remote_url, created_at
            FROM card_images
            WHERE card_id = ?
            ORDER BY created_at ASC
            """,
            [.text(cardID.uuidString)]
        ) { statement in
            try Self.cardImage(from: statement)
        }
    }

    public func allCards() throws -> [KnowledgeCard] {
        try query(
            """
            SELECT id, title, body, metadata_json, created_at, updated_at
            FROM cards
            WHERE deleted_at IS NULL
            ORDER BY updated_at DESC
            """,
            []
        ) { statement in
            try Self.card(from: statement)
        }
    }

    public func searchCards(_ text: String) throws -> [KnowledgeCard] {
        let pattern = "%\(text)%"
        return try query(
            """
            SELECT id, title, body, metadata_json, created_at, updated_at
            FROM cards
            WHERE deleted_at IS NULL AND (title LIKE ? OR body LIKE ?)
            ORDER BY updated_at DESC
            """,
            [.text(pattern), .text(pattern)]
        ) { statement in
            try Self.card(from: statement)
        }
    }

    public func neighbors(of cardID: UUID) throws -> [KnowledgeCard] {
        try query(
            """
            SELECT DISTINCT c.id, c.title, c.body, c.metadata_json, c.created_at, c.updated_at
            FROM cards c
            JOIN edges e ON (
                (e.source_card_id = ? AND e.target_card_id = c.id)
                OR (e.target_card_id = ? AND e.source_card_id = c.id)
            )
            WHERE c.deleted_at IS NULL
            ORDER BY c.title ASC
            """,
            [.text(cardID.uuidString), .text(cardID.uuidString)]
        ) { statement in
            try Self.card(from: statement)
        }
    }

    public func allEdges() throws -> [CardEdge] {
        try query(
            """
            SELECT id, source_card_id, target_card_id, label, weight, created_at
            FROM edges
            ORDER BY created_at ASC
            """,
            []
        ) { statement in
            try Self.edge(from: statement)
        }
    }

    public func dueCards(now: Date = Date()) throws -> [KnowledgeCard] {
        try query(
            """
            SELECT c.id, c.title, c.body, c.metadata_json, c.created_at, c.updated_at
            FROM cards c
            JOIN review_states r ON r.card_id = c.id
            WHERE c.deleted_at IS NULL
              AND (r.status = 'new' OR r.status = 'due' OR r.due_at <= ?)
            ORDER BY COALESCE(r.due_at, 0) ASC
            """,
            [.double(now.timeIntervalSince1970)]
        ) { statement in
            try Self.card(from: statement)
        }
    }

    public func reviewState(for cardID: UUID) throws -> ReviewState? {
        try query(
            """
            SELECT card_id, status, mastery_percent, difficulty, stability, interval_days, due_at, last_reviewed_at, review_count
            FROM review_states
            WHERE card_id = ?
            """,
            [.text(cardID.uuidString)]
        ) { statement in
            try Self.reviewState(from: statement)
        }.first
    }

    public func allReviewEvents() throws -> [ReviewEvent] {
        try query(
            """
            SELECT id, card_id, reviewed_at, rating, user_id, elapsed_days, scheduled_days, previous_mastery_percent, next_mastery_percent
            FROM review_events
            ORDER BY reviewed_at ASC
            """,
            []
        ) { statement in
            try Self.reviewEvent(from: statement)
        }
    }

    public func applyReview(cardID: UUID, rating: ReviewRating, reviewedAt: Date = Date()) throws -> ReviewState {
        let currentState = try reviewState(for: cardID) ?? ReviewState(cardID: cardID)
        let (nextState, event) = scheduler.apply(rating, to: currentState, reviewedAt: reviewedAt)
        try saveReviewState(nextState)
        try execute(
            """
            INSERT INTO review_events
            (id, card_id, user_id, reviewed_at, rating, elapsed_days, scheduled_days, previous_mastery_percent, next_mastery_percent)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                .text(event.id.uuidString),
                .text(cardID.uuidString),
                .text(event.userID),
                .double(event.reviewedAt.timeIntervalSince1970),
                .text(rating.rawValue),
                .int(event.elapsedDays),
                .int(event.scheduledDays),
                .int(event.previousMasteryPercent),
                .int(event.nextMasteryPercent)
            ]
        )
        return nextState
    }

    private func saveReviewState(_ state: ReviewState) throws {
        try execute(
            """
            INSERT INTO review_states
            (card_id, status, mastery_percent, difficulty, stability, interval_days, due_at, last_reviewed_at, review_count)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(card_id) DO UPDATE SET
                status = excluded.status,
                mastery_percent = excluded.mastery_percent,
                difficulty = excluded.difficulty,
                stability = excluded.stability,
                interval_days = excluded.interval_days,
                due_at = excluded.due_at,
                last_reviewed_at = excluded.last_reviewed_at,
                review_count = excluded.review_count
            """,
            [
                .text(state.cardID.uuidString),
                .text(state.status.storageValue == "mastered_\(state.status.masteryPercent)" ? "mastered" : state.status.storageValue),
                .int(state.status.masteryPercent),
                state.difficulty.map { .double($0) } ?? .null,
                state.stability.map { .double($0) } ?? .null,
                state.intervalDays.map { .int($0) } ?? .null,
                state.dueAt.map { .double($0.timeIntervalSince1970) } ?? .null,
                state.lastReviewedAt.map { .double($0.timeIntervalSince1970) } ?? .null,
                .int(state.reviewCount)
            ]
        )
    }

    private func migrate() throws {
        try execute("PRAGMA foreign_keys = ON", [])
        try execute(
            """
            CREATE TABLE IF NOT EXISTS cards (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                body TEXT NOT NULL,
                metadata_json TEXT NOT NULL DEFAULT '{}',
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                deleted_at REAL
            )
            """,
            []
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS edges (
                id TEXT PRIMARY KEY,
                source_card_id TEXT NOT NULL REFERENCES cards(id),
                target_card_id TEXT NOT NULL REFERENCES cards(id),
                label TEXT NOT NULL DEFAULT 'related to',
                weight REAL NOT NULL DEFAULT 1,
                created_at REAL NOT NULL
            )
            """,
            []
        )
        try execute("CREATE INDEX IF NOT EXISTS edges_source_idx ON edges(source_card_id)", [])
        try execute("CREATE INDEX IF NOT EXISTS edges_target_idx ON edges(target_card_id)", [])
        try execute("CREATE TABLE IF NOT EXISTS tags (name TEXT PRIMARY KEY)", [])
        try execute(
            """
            CREATE TABLE IF NOT EXISTS card_tags (
                card_id TEXT NOT NULL REFERENCES cards(id),
                tag_name TEXT NOT NULL REFERENCES tags(name),
                PRIMARY KEY (card_id, tag_name)
            )
            """,
            []
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS card_images (
                id TEXT PRIMARY KEY,
                card_id TEXT NOT NULL REFERENCES cards(id),
                local_path TEXT NOT NULL,
                remote_url TEXT,
                created_at REAL NOT NULL
            )
            """,
            []
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS review_states (
                card_id TEXT PRIMARY KEY REFERENCES cards(id),
                status TEXT NOT NULL,
                mastery_percent INTEGER NOT NULL,
                difficulty REAL,
                stability REAL,
                interval_days INTEGER,
                due_at REAL,
                last_reviewed_at REAL,
                review_count INTEGER NOT NULL DEFAULT 0
            )
            """,
            []
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS review_events (
                id TEXT PRIMARY KEY,
                card_id TEXT NOT NULL REFERENCES cards(id),
                user_id TEXT NOT NULL DEFAULT 'local',
                reviewed_at REAL NOT NULL,
                rating TEXT NOT NULL,
                elapsed_days INTEGER NOT NULL DEFAULT 0,
                scheduled_days INTEGER NOT NULL DEFAULT 0,
                previous_mastery_percent INTEGER NOT NULL,
                next_mastery_percent INTEGER NOT NULL
            )
            """,
            []
        )
        try addColumnIfMissing(table: "review_states", name: "difficulty", definition: "REAL")
        try addColumnIfMissing(table: "review_states", name: "stability", definition: "REAL")
        try addColumnIfMissing(table: "review_states", name: "interval_days", definition: "INTEGER")
        try addColumnIfMissing(table: "review_events", name: "user_id", definition: "TEXT NOT NULL DEFAULT 'local'")
        try addColumnIfMissing(table: "review_events", name: "elapsed_days", definition: "INTEGER NOT NULL DEFAULT 0")
        try addColumnIfMissing(table: "review_events", name: "scheduled_days", definition: "INTEGER NOT NULL DEFAULT 0")
    }
}

private extension SQLiteStore {
    enum BindValue {
        case text(String)
        case double(Double)
        case int(Int)
        case null
    }

    func execute(_ sql: String, _ values: [BindValue]) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw BrainStoreError.prepareFailed(Self.errorMessage(db))
        }
        defer { sqlite3_finalize(statement) }

        try bind(values, to: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw BrainStoreError.stepFailed(Self.errorMessage(db))
        }
    }

    func query<T>(_ sql: String, _ values: [BindValue], map: (OpaquePointer?) throws -> T) throws -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw BrainStoreError.prepareFailed(Self.errorMessage(db))
        }
        defer { sqlite3_finalize(statement) }

        try bind(values, to: statement)

        var results: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(try map(statement))
        }
        return results
    }

    func addColumnIfMissing(table: String, name: String, definition: String) throws {
        let existingColumns = try query("PRAGMA table_info(\(table))", []) { statement in
            Self.columnText(statement, 1)
        }

        guard existingColumns.contains(name) == false else {
            return
        }

        try execute("ALTER TABLE \(table) ADD COLUMN \(name) \(definition)", [])
    }

    func bind(_ values: [BindValue], to statement: OpaquePointer?) throws {
        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            let result = switch value {
            case .text(let text):
                sqlite3_bind_text(statement, position, text, -1, SQLITE_TRANSIENT)
            case .double(let double):
                sqlite3_bind_double(statement, position, double)
            case .int(let int):
                sqlite3_bind_int(statement, position, Int32(int))
            case .null:
                sqlite3_bind_null(statement, position)
            }

            guard result == SQLITE_OK else {
                throw BrainStoreError.bindFailed(Self.errorMessage(db))
            }
        }
    }

    static func card(from statement: OpaquePointer?) throws -> KnowledgeCard {
        let id = try uuid(columnText(statement, 0))
        let title = columnText(statement, 1)
        let body = columnText(statement, 2)
        let metadataJSON = columnText(statement, 3)
        let metadata = (try? JSONDecoder().decode([String: String].self, from: Data(metadataJSON.utf8))) ?? [:]
        return KnowledgeCard(
            id: id,
            title: title,
            body: body,
            metadata: metadata,
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 4)),
            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))
        )
    }

    static func reviewState(from statement: OpaquePointer?) throws -> ReviewState {
        let cardID = try uuid(columnText(statement, 0))
        let status = columnText(statement, 1)
        let masteryPercent = Int(sqlite3_column_int(statement, 2))
        let difficulty = sqlite3_column_type(statement, 3) == SQLITE_NULL ? nil : sqlite3_column_double(statement, 3)
        let stability = sqlite3_column_type(statement, 4) == SQLITE_NULL ? nil : sqlite3_column_double(statement, 4)
        let intervalDays = sqlite3_column_type(statement, 5) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 5))
        let dueAt = sqlite3_column_type(statement, 6) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(statement, 6))
        let lastReviewedAt = sqlite3_column_type(statement, 7) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(statement, 7))
        let reviewCount = Int(sqlite3_column_int(statement, 8))
        return ReviewState(
            cardID: cardID,
            status: ReviewStatus.fromStorage(status, masteryPercent: masteryPercent),
            difficulty: difficulty,
            stability: stability,
            intervalDays: intervalDays,
            dueAt: dueAt,
            lastReviewedAt: lastReviewedAt,
            reviewCount: reviewCount
        )
    }

    static func edge(from statement: OpaquePointer?) throws -> CardEdge {
        try CardEdge(
            id: uuid(columnText(statement, 0)),
            sourceCardID: uuid(columnText(statement, 1)),
            targetCardID: uuid(columnText(statement, 2)),
            label: columnText(statement, 3),
            weight: sqlite3_column_double(statement, 4),
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))
        )
    }

    static func cardImage(from statement: OpaquePointer?) throws -> CardImage {
        try CardImage(
            id: uuid(columnText(statement, 0)),
            cardID: uuid(columnText(statement, 1)),
            localPath: columnText(statement, 2),
            remoteURL: sqlite3_column_type(statement, 3) == SQLITE_NULL ? nil : columnText(statement, 3),
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))
        )
    }

    static func reviewEvent(from statement: OpaquePointer?) throws -> ReviewEvent {
        guard let rating = ReviewRating(rawValue: columnText(statement, 3)) else {
            throw BrainStoreError.prepareFailed("Unknown review rating: \(columnText(statement, 3))")
        }

        return try ReviewEvent(
            id: uuid(columnText(statement, 0)),
            cardID: uuid(columnText(statement, 1)),
            reviewedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
            rating: rating,
            userID: columnText(statement, 4),
            elapsedDays: Int(sqlite3_column_int(statement, 5)),
            scheduledDays: Int(sqlite3_column_int(statement, 6)),
            previousMasteryPercent: Int(sqlite3_column_int(statement, 7)),
            nextMasteryPercent: Int(sqlite3_column_int(statement, 8))
        )
    }

    static func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, index) else {
            return ""
        }
        return String(cString: pointer)
    }

    static func uuid(_ value: String) throws -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            throw BrainStoreError.invalidUUID(value)
        }
        return uuid
    }

    static func errorMessage(_ db: OpaquePointer?) -> String {
        guard let message = sqlite3_errmsg(db) else {
            return "unknown error"
        }
        return String(cString: message)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
