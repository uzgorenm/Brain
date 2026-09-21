import AppIntents
import Observation
import SwiftUI

@MainActor @Observable
final class BrainNavigation {
    static let shared = BrainNavigation()
    enum Tab: Hashable { case capture, notes, cards, settings }
    var tab: Tab = .capture
    var recordRequested = false
    var writeRequested = false

    func record() {
        tab = .capture
        recordRequested = true
    }

    func writeNote() {
        tab = .capture
        writeRequested = true
    }
}

struct RecordThoughtIntent: AppIntent {
    static var title: LocalizedStringResource = "Record a thought"
    static var description = IntentDescription("Open Brain and record a thought for transcription. An unfinished draft is kept safe.")
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @MainActor
    func perform() async throws -> some IntentResult {
        BrainNavigation.shared.record()
        return .result()
    }
}

struct WriteNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Write a note"
    static var description = IntentDescription("Open Brain with the note editor ready. Any unfinished draft stays in place.")
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @MainActor
    func perform() async throws -> some IntentResult {
        BrainNavigation.shared.writeNote()
        return .result()
    }
}

struct BrainShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: RecordThoughtIntent(), phrases: [
            "Record a thought in \(.applicationName)",
            "Capture an idea in \(.applicationName)"
        ], shortTitle: "Record a thought", systemImageName: "mic")

        AppShortcut(intent: WriteNoteIntent(), phrases: [
            "Write a note in \(.applicationName)",
            "Take a note in \(.applicationName)"
        ], shortTitle: "Write a note", systemImageName: "square.and.pencil")
    }
}
