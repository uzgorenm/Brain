import Foundation

/// Capture uses the card's existing metadata so notes remain searchable and connectable.
public struct NoteDraft: Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var title = ""
    public var body = ""
    public var audioFilename: String?
    public var transcriptComplete = false

    public init() {}

    public var hasContent: Bool {
        !title.isEmpty || !body.isEmpty || audioFilename != nil
    }

    public var canSave: Bool {
        !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (audioFilename == nil || transcriptComplete)
    }

    public var resolvedTitle: String {
        let explicit = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty { return explicit }
        let firstLine = body.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Note"
        return String(firstLine.trimmingCharacters(in: .whitespacesAndNewlines).prefix(72))
    }

    public var metadata: [String: String] {
        ["kind": "note", "captureID": id.uuidString,
         "source": audioFilename == nil ? "text" : "voice",
         "deck": "Notes"]
    }
}

public extension KnowledgeCard {
    var isNote: Bool { metadata["kind"] == "note" }
    var isFlashcard: Bool { !isNote }
    var isIncludedInReview: Bool { isFlashcard }
}
