import Foundation
import Testing
import SQLite3
@testable import BrainCore

@Test func noteTitleIsOptionalAndBodyIsRequired() {
    var draft = NoteDraft()
    draft.body = " \n "
    #expect(!draft.canSave)
    draft.body = "  An idea for the garden\nKeep the full details here."
    #expect(draft.canSave)
    #expect(draft.resolvedTitle == "An idea for the garden")
    draft.title = "  Weekend project  "
    #expect(draft.resolvedTitle == "Weekend project")
}

@Test func unfinishedTranscriptionBlocksSaveAndDraftRoundTrips() throws {
    var draft = NoteDraft()
    draft.audioFilename = "recording.m4a"
    draft.body = "An incomplete transcript"
    #expect(!draft.canSave)
    draft.transcriptComplete = true
    #expect(draft.canSave)
    let restored = try JSONDecoder().decode(NoteDraft.self, from: JSONEncoder().encode(draft))
    #expect(restored == draft)
}

@Test func notesStaySeparateFromReviewWithoutChangingLegacyCards() throws {
    let store = try SQLiteStore(path: ":memory:")
    var draft = NoteDraft()
    draft.body = "Try a weekend sketchbook."
    var note = try store.createCard(title: draft.resolvedTitle, body: draft.body, metadata: draft.metadata)
    let legacy = try store.createCard(title: "What is recall?", body: "Retrieving a memory.")
    #expect(note.isNote)
    #expect(!note.isIncludedInReview)
    #expect(legacy.isIncludedInReview)
    #expect(try store.dueCards().map(\.id) == [legacy.id])
    #expect(try store.searchCards("sketchbook").map(\.id) == [note.id])
    note.metadata["reviewEnabled"] = "true"
    try store.updateCard(note)
    #expect(try store.allCards().first(where: { $0.id == note.id })?.isIncludedInReview == false)
    #expect(try store.reviewState(for: note.id)?.status == .new)
    #expect(try !store.dueCards().contains(where: { $0.id == note.id }))
}

@Test func localNoteRewritePromptKeepsSourceFactsAndReturnsOnlyFinalText() {
    let prompt = LLMManager.noteRewritePrompt(
        title: "Trip",
        body: "Meet Ana on October 4 at 8:30."
    )

    #expect(prompt.contains("Meet Ana on October 4 at 8:30."))
    #expect(LLMManager.noteRewriteInstructions.contains("Do not add facts"))
    #expect(LLMManager.noteRewriteInstructions.contains("<brain_rewrite>"))

    let response = """
    I need to preserve the date and make the sentence clearer. The prompt said to return only the note.
    </think>
    <brain_rewrite>
    Meet Ana at 8:30 on October 4.
    </brain_rewrite><|im_end|>
    """
    #expect(LLMManager.cleanNoteRewriteResponse(response) == "Meet Ana at 8:30 on October 4.")
    #expect(LLMManager.cleanNoteRewriteResponse("Reasoning that never reached a final answer") == "")
    #expect(LLMManager.cleanNoteRewriteResponse("<think>Unfinished reasoning") == "")
    #expect(LLMManager.cleanNoteRewriteResponse("Analysis</think>\nRewrite:\nMeet Ana on October 4.") == "Meet Ana on October 4.")
    #expect(LLMManager.cleanNoteRewriteResponse("Use <brain_rewrite> and </brain_rewrite>.\n</think>\nMeet Ana on October 4.") == "Meet Ana on October 4.")
}

@Test func aFailedCaptureWriteRollsBackTheWholeCard() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("brain-test-\(UUID()).sqlite")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = try SQLiteStore(path: url.path)
    var db: OpaquePointer?
    #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
    defer { sqlite3_close(db) }
    // Force the last step of createCard to fail, after the note row was inserted.
    #expect(sqlite3_exec(db, "CREATE TRIGGER reject_review BEFORE INSERT ON review_states BEGIN SELECT RAISE(ABORT, 'test write failure'); END;", nil, nil, nil) == SQLITE_OK)
    var draft = NoteDraft()
    draft.body = "Keep this draft if the database write fails."
    #expect(throws: (any Error).self) {
        try store.createCard(title: draft.resolvedTitle, body: draft.body, metadata: draft.metadata)
    }
    #expect(try store.allCards().isEmpty)
    #expect(draft.canSave)
}

@Test func autoTitleDoesNotTruncateTheNoteBody() {
    var draft = NoteDraft()
    draft.body = String(repeating: "A detailed thought. ", count: 100)
    #expect(draft.resolvedTitle.count == 72)
    #expect(draft.body.count == 2000)
}

@Test func captureStorageRetainsAudioUntilExplicitCleanup() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = CaptureDraftStorage(directory: directory)
    var draft = NoteDraft()
    draft.body = "A recoverable draft"
    draft.audioFilename = "recording.m4a"
    try storage.save(draft)
    let audio = directory.appendingPathComponent("recording.m4a")
    try Data([1, 2, 3]).write(to: audio)
    #expect(try storage.load() == draft)
    draft.body = "An edited transcript"
    draft.transcriptComplete = true
    try storage.save(draft)
    #expect(FileManager.default.fileExists(atPath: audio.path))
    #expect(try storage.load().body == "An edited transcript")
    try storage.remove(draft)
    #expect(!FileManager.default.fileExists(atPath: audio.path))
    #expect(try !storage.load().hasContent)
}

@Test func aFailedDraftWriteLeavesThePreviousDraftReadable() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = CaptureDraftStorage(directory: directory)
    var draft = NoteDraft()
    draft.body = "Saved draft"
    try storage.save(draft)
    // A regular file cannot serve as the parent directory of a draft.
    let invalid = CaptureDraftStorage(directory: directory.appendingPathComponent("draft.json"))
    #expect(throws: (any Error).self) { try invalid.save(draft) }
    #expect(try storage.load() == draft)
}

@Test func aFailedReviewKeepsTheCardDueAndDoesNotRecordCompletion() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("brain-review-test-\(UUID()).sqlite")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = try SQLiteStore(path: url.path)
    let card = try store.createCard(title: "Review prompt", body: "Answer")
    var db: OpaquePointer?
    #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
    defer { sqlite3_close(db) }
    #expect(sqlite3_exec(db, "CREATE TRIGGER reject_event BEFORE INSERT ON review_events BEGIN SELECT RAISE(ABORT, 'test review failure'); END;", nil, nil, nil) == SQLITE_OK)
    #expect(throws: (any Error).self) { try store.applyReview(cardID: card.id, rating: .good) }
    #expect(try store.reviewState(for: card.id)?.status == .new)
    #expect(try store.allReviewEvents().isEmpty)
    #expect(try store.dueCards().map(\.id) == [card.id])
}
