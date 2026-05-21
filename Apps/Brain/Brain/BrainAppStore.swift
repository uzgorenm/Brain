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
            
            // Try to initialize the LLM if the model exists in the app's Documents or Support directory
            Task {
                await initializeLLM()
            }
            
            NotificationCenter.default.addObserver(forName: NSNotification.Name("ModelDownloaded"), object: nil, queue: .main) { [weak self] _ in
                Task {
                    await self?.initializeLLM()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func initializeLLM() async {
        // Look for the .litertlm file
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let possibleModelURLs = [
            appSupportURL?.appendingPathComponent("model.litertlm"),
            appSupportURL?.appendingPathComponent("gemma-4-E2B-it.litertlm"),
            documentsURL?.appendingPathComponent("model.litertlm"),
            documentsURL?.appendingPathComponent("gemma-4-E2B-it.litertlm")
        ].compactMap { $0 }
        
        for modelURL in possibleModelURLs {
            if FileManager.default.fileExists(atPath: modelURL.path) {
                do {
                    try await LLMManager.shared.initialize(modelPath: modelURL.path)
                    print("LLM successfully initialized from \(modelURL.path)")
                    return
                } catch {
                    print("Failed to initialize LLM with \(modelURL.path): \(error)")
                }
            }
        }
        print("No LLM model found. AI features will be disabled.")
    }

    var selectedCard: KnowledgeCard? {
        guard let selectedCardID else { return nil }
        return cards.first { $0.id == selectedCardID }
    }

    var dueCards: [KnowledgeCard] {
        cards.filter { card in
            let state = reviewState(for: card)
            if case .new = state.status {
                return true
            }
            return state.dueAt.map { $0 <= Date() } ?? false
        }
    }

    var decks: [String] {
        let deckNames = cards.map(\.deckName)
        return Array(Set([Self.defaultDeckName] + deckNames)).sorted { lhs, rhs in
            if lhs == Self.defaultDeckName { return true }
            if rhs == Self.defaultDeckName { return false }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    func cards(in deckName: String) -> [KnowledgeCard] {
        cards.filter { $0.deckName == deckName }
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

    func createCard(title: String, body: String, deckName: String, imagePaths: [String] = [], audioPath: String? = nil) {
        let normalizedDeckName = Self.normalizedDeckName(deckName)
        var metadata = [KnowledgeCard.deckMetadataKey: normalizedDeckName]
        if let audioPath {
            metadata[KnowledgeCard.audioMetadataKey] = storedMediaPath(for: audioPath)
        }

        do {
            let card = try requireStore().createCard(
                title: title,
                body: body,
                tags: [normalizedDeckName],
                imagePaths: imagePaths.map(storedMediaPath),
                metadata: metadata
            )
            try loadCards()
            selectedDeckName = normalizedDeckName
            selectedCardID = card.id
        } catch {
            errorMessage = error.localizedDescription
        }
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

    func review(_ card: KnowledgeCard, rating: ReviewRating) {
        do {
            _ = try requireStore().applyReview(cardID: card.id, rating: rating)
            try loadCards()
        } catch {
            errorMessage = error.localizedDescription
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

extension KnowledgeCard {
    static let deckMetadataKey = "deck"
    static let audioMetadataKey = "audioPath"

    var deckName: String {
        BrainAppStore.normalizedDeckName(metadata[Self.deckMetadataKey] ?? BrainAppStore.defaultDeckName)
    }

    var audioPath: String? {
        metadata[Self.audioMetadataKey]
    }
}

private enum BrainAppStoreError: LocalizedError {
    case storeUnavailable

    var errorDescription: String? {
        "The local Brain database is unavailable."
    }
}
