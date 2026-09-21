import Foundation

/// Keeps unfinished text and audio separate from the saved card library.
public struct CaptureDraftStorage: Sendable {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }
    private var file: URL { directory.appendingPathComponent("draft.json") }

    public func load() throws -> NoteDraft {
        guard FileManager.default.fileExists(atPath: file.path) else { return NoteDraft() }
        return try JSONDecoder().decode(NoteDraft.self, from: Data(contentsOf: file))
    }

    public func save(_ draft: NoteDraft) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(draft).write(to: file, options: .atomic)
    }

    /// Call only after saving the card, or after the user explicitly discards the draft.
    public func remove(_ draft: NoteDraft) throws {
        if let filename = draft.audioFilename {
            let audio = directory.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: audio.path) {
                try FileManager.default.removeItem(at: audio)
            }
        }
        if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
    }
}
