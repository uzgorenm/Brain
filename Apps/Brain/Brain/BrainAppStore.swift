import BrainCore
import Foundation
import Observation

@Observable
final class BrainAppStore {
    static let defaultDeckName = "Brain Cards"

    var cards: [KnowledgeCard] = []
    var edges: [CardEdge] = []
    var reviewEvents: [ReviewEvent] = []
    var selectedDeckName = BrainAppStore.defaultDeckName
    var selectedCardID: KnowledgeCard.ID?
    var errorMessage: String?
    var isLocalAIReady = LLMManager.shared.isInitialized

    private var store: SQLiteStore?
    private var appSupportURL: URL?
    private let scheduler = ReviewScheduler()

    init() {
        do {
            let supportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let appURL = supportURL.appendingPathComponent("Brain", isDirectory: true)
            try FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)
            appSupportURL = appURL
            store = try SQLiteStore(path: appURL.appendingPathComponent("brain.sqlite").path)
            try loadCards()
            
            // Expose the Documents folder to the Files app by writing a dummy file
            if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
                let dummyFileURL = documentsURL.appendingPathComponent(".brain_workspace")
                if !FileManager.default.fileExists(atPath: dummyFileURL.path) {
                    try? "Brain Workspace".write(to: dummyFileURL, atomically: true, encoding: .utf8)
                }
            }
            
            // Try to initialize the LLM if the MLX model has already been downloaded.
            Task { @MainActor [weak self] in
                await self?.initializeLLM()
            }
            
            NotificationCenter.default.addObserver(forName: NSNotification.Name("ModelDownloaded"), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    await self?.initializeLLM()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    public func initializeLLM() async {
        guard ModelDownloadManager.shared.checkModelExists() else {
            isLocalAIReady = false
            print("No MLX model found. AI features will be disabled.")
            return
        }

        do {
            try await LLMManager.shared.initialize()
            isLocalAIReady = true
            print("MLX LLM successfully initialized")
        } catch {
            isLocalAIReady = false
            print("Failed to initialize MLX LLM: \(error)")
        }
    }

    var selectedCard: KnowledgeCard? {
        guard let selectedCardID else { return nil }
        return cards.first { $0.id == selectedCardID }
    }

    var notes: [KnowledgeCard] {
        cards.filter(\.isNote)
    }

    var flashcards: [KnowledgeCard] {
        cards.filter(\.isFlashcard)
    }

    var dueCards: [KnowledgeCard] {
        flashcards.filter { card in
            let state = reviewState(for: card)
            if case .new = state.status {
                return true
            }
            return state.dueAt.map { $0 <= Date() } ?? false
        }
    }

    var decks: [String] {
        let deckNames = flashcards.map(\.deckName)
        return Array(Set([Self.defaultDeckName] + deckNames)).sorted { lhs, rhs in
            if lhs == Self.defaultDeckName { return true }
            if rhs == Self.defaultDeckName { return false }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    func cards(in deckName: String) -> [KnowledgeCard] {
        flashcards.filter { $0.deckName == deckName }
    }

    func dueCards(in deckName: String) -> [KnowledgeCard] {
        dueCards.filter { $0.deckName == deckName }
    }

    func loadCards() throws {
        guard let store else { return }
        cards = try store.allCards()
        edges = try store.allEdges()
        reviewEvents = try store.allReviewEvents()
        if let selectedCardID, cards.contains(where: { $0.id == selectedCardID }) == false {
            self.selectedCardID = nil
        }
    }

    @discardableResult
    func createCard(title: String, body: String, deckName: String, imagePaths: [String] = [], audioPath: String? = nil, shortTitle: String? = nil) -> Bool {
        let normalizedDeckName = Self.normalizedDeckName(deckName)
        var metadata = [KnowledgeCard.deckMetadataKey: normalizedDeckName]
        if let audioPath {
            metadata[KnowledgeCard.audioMetadataKey] = storedMediaPath(for: audioPath)
        }
        if let shortTitle, !shortTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            metadata[KnowledgeCard.shortTitleMetadataKey] = shortTitle
        }

        do {
            let card = try requireStore().createCard(
                title: title,
                body: body,
                tags: [normalizedDeckName],
                imagePaths: imagePaths.map(storedMediaPath),
                metadata: metadata
            )
            cards.insert(card, at: 0)
            selectedDeckName = normalizedDeckName
            selectedCardID = card.id
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func saveNote(_ draft: NoteDraft) throws -> KnowledgeCard {
        guard draft.canSave else { throw CaptureValidationError.emptyNote }
        // A crash during draft cleanup must not create a second copy on retry.
        if let saved = cards.first(where: { $0.metadata["captureID"] == draft.id.uuidString }) {
            return saved
        }
        let card = try requireStore().createCard(
            title: draft.resolvedTitle, body: draft.body.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: ["Notes"], metadata: draft.metadata
        )
        cards.insert(card, at: 0)
        return card
    }

    func updateNote(_ card: KnowledgeCard, title: String, body: String) throws {
        guard cards.contains(where: { $0.id == card.id }) else { throw CaptureValidationError.missingCard }
        guard card.isNote else { throw CaptureValidationError.wrongContentType }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CaptureValidationError.emptyNote
        }
        var updated = card
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.updatedAt = Date()
        updated.metadata.removeValue(forKey: "reviewEnabled")
        try requireStore().updateCard(updated)
        cards.removeAll { $0.id == card.id }
        cards.insert(updated, at: 0)
    }

    func updateFlashcard(_ card: KnowledgeCard, question: String, answer: String) throws {
        guard cards.contains(where: { $0.id == card.id }) else { throw CaptureValidationError.missingCard }
        guard card.isFlashcard else { throw CaptureValidationError.wrongContentType }
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CaptureValidationError.emptyFlashcard
        }

        var updated = card
        updated.title = question.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.body = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.updatedAt = Date()
        try requireStore().updateCard(updated)
        cards.removeAll { $0.id == card.id }
        cards.insert(updated, at: 0)
    }

    func makeMediaFileURL(fileExtension: String) throws -> URL {
        guard let appSupportURL else {
            throw BrainStoreError.openFailed("Application support folder is unavailable.")
        }
        let mediaURL = appSupportURL.appendingPathComponent("Media", isDirectory: true)
        try FileManager.default.createDirectory(at: mediaURL, withIntermediateDirectories: true)
        return mediaURL.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
    }

    func resolvedMediaURL(for path: String) -> URL {
        if path.hasPrefix("/") {
            let fileURL = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }

            if let appSupportURL {
                let fallback = appSupportURL
                    .appendingPathComponent("Media", isDirectory: true)
                    .appendingPathComponent(fileURL.lastPathComponent)
                if FileManager.default.fileExists(atPath: fallback.path) {
                    return fallback
                }
            }

            return fileURL
        }

        guard let appSupportURL else {
            return URL(fileURLWithPath: path)
        }

        return appSupportURL.appendingPathComponent(path)
    }

    static func normalizedDeckName(_ rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultDeckName : trimmed
    }

    func connectCard(_ target: KnowledgeCard, to source: KnowledgeCard) {
        do {
            _ = try requireStore().addEdge(from: source.id, to: target.id)
            try loadCards()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnectCard(_ target: KnowledgeCard, from source: KnowledgeCard) {
        do {
            try requireStore().deleteEdge(between: source.id, and: target.id)
            try loadCards()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCard(_ card: KnowledgeCard) {
        do {
            try requireStore().deleteCard(card.id)
            try loadCards()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func neighbors(of card: KnowledgeCard) -> [KnowledgeCard] {
        do {
            return try requireStore().neighbors(of: card.id)
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    func images(for card: KnowledgeCard) -> [CardImage] {
        do {
            return try requireStore().images(for: card.id).map { image in
                CardImage(
                    id: image.id,
                    cardID: image.cardID,
                    localPath: resolvedMediaURL(for: image.localPath).path,
                    remoteURL: image.remoteURL,
                    createdAt: image.createdAt
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    func audioURL(for card: KnowledgeCard) -> URL? {
        card.audioPath.map(resolvedMediaURL)
    }

    func reviewState(for card: KnowledgeCard) -> ReviewState {
        do {
            return try requireStore().reviewState(for: card.id) ?? ReviewState(cardID: card.id)
        } catch {
            errorMessage = error.localizedDescription
            return ReviewState(cardID: card.id)
        }
    }

    func isDue(_ state: ReviewState) -> Bool {
        if case .new = state.status {
            return true
        }
        return state.dueAt.map { $0 <= Date() } ?? false
    }

    @discardableResult
    func review(_ card: KnowledgeCard, rating: ReviewRating) -> Bool {
        guard card.isFlashcard else {
            errorMessage = "Only flashcards are part of scheduled review."
            return false
        }
        do {
            _ = try requireStore().applyReview(cardID: card.id, rating: rating)
            try loadCards()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func requireStore() throws -> SQLiteStore {
        if let store { return store }
        throw BrainAppStoreError.storeUnavailable
    }

    private func storedMediaPath(for path: String) -> String {
        guard let appSupportURL else {
            return path
        }

        let url = URL(fileURLWithPath: path)
        let appSupportPath = appSupportURL.path
        guard url.path.hasPrefix(appSupportPath) else {
            return path
        }

        let relativePath = String(url.path.dropFirst(appSupportPath.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return relativePath.isEmpty ? path : relativePath
    }
}

private enum CaptureValidationError: LocalizedError {
    case emptyNote
    case emptyFlashcard
    case missingCard
    case wrongContentType
    var errorDescription: String? {
        switch self {
        case .emptyNote: "Add some text before saving your note."
        case .emptyFlashcard: "Add both a question and an answer before saving the card."
        case .missingCard: "This item has been deleted. Return to the library to continue."
        case .wrongContentType: "This item belongs in a different part of the library."
        }
    }
}

extension KnowledgeCard {
    static let deckMetadataKey = "deck"
    static let audioMetadataKey = "audioPath"
    static let shortTitleMetadataKey = "shortTitle"

    var deckName: String {
        BrainAppStore.normalizedDeckName(metadata[Self.deckMetadataKey] ?? BrainAppStore.defaultDeckName)
    }

    var audioPath: String? {
        metadata[Self.audioMetadataKey]
    }

    var shortTitle: String {
        metadata[Self.shortTitleMetadataKey] ?? title
    }
}

private enum BrainAppStoreError: LocalizedError {
    case storeUnavailable

    var errorDescription: String? {
        "The local Brain database is unavailable."
    }
}
