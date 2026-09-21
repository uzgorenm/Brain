import BrainCore
import SwiftUI

struct NotesTabView: View {
    @Environment(BrainAppStore.self) private var appStore
    @Environment(BrainNavigation.self) private var navigation
    @State private var search = ""
    @State private var showingAI = false

    private var results: [KnowledgeCard] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? appStore.notes : appStore.notes.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if appStore.notes.isEmpty {
                        ContentUnavailableView {
                            Label("A place for your thoughts", systemImage: "note.text")
                        } description: {
                            Text("Write or record a note to start your library.")
                        } actions: {
                            Button("Write a note") { navigation.writeNote() }
                                .buttonStyle(.borderedProminent)
                        }
                    } else if results.isEmpty {
                        ContentUnavailableView.search(text: search)
                    } else {
                        Text("\(results.count) \(results.count == 1 ? "note" : "notes")")
                            .font(.subheadline).foregroundStyle(BrainTheme.mutedText).padding(.vertical, 12)
                        ForEach(results) { card in
                            NavigationLink { NoteDetailView(card: card) } label: { NoteRow(card: card) }
                                .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, BrainTheme.pagePadding)
                .frame(maxWidth: BrainTheme.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .searchable(text: $search, prompt: "Search notes")
            .navigationTitle("Notes")
            .brainScreen()
            .platformNavigationBarStyle()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Ask AI") { showingAI = true }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Write a note", systemImage: "square.and.pencil") { navigation.writeNote() }
                        Button("Record a thought", systemImage: "mic") { navigation.record() }
                    } label: { Text("Add") }
                }
            }
            .sheet(isPresented: $showingAI) { QuestionTabView() }
        }
    }
}

struct NoteRow: View {
    let card: KnowledgeCard
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: card.metadata["source"] == "voice" ? "waveform" : "note.text")
                .font(.body).foregroundStyle(BrainTheme.accent)
                .frame(width: 26).padding(.top, 3).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                Text(card.title).font(.headline).foregroundStyle(.primary).lineLimit(2)
                Text(card.body).font(.subheadline).foregroundStyle(BrainTheme.mutedText).lineLimit(2)
                HStack(spacing: 8) {
                    Text(card.updatedAt, style: .date)
                }
                .font(.caption).foregroundStyle(BrainTheme.mutedText)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(BrainTheme.mutedText).accessibilityHidden(true)
        }
        .padding(.vertical, 18)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct NoteDetailView: View {
    @Environment(BrainAppStore.self) private var appStore
    @Environment(BrainNavigation.self) private var navigation
    @Environment(\.dismiss) private var dismiss
    let card: KnowledgeCard
    @State private var showingDiscardEdits = false
    @State private var title = ""
    @State private var bodyText = ""
    @State private var error: String?
    @State private var saved = false
    @State private var loaded = false
    @State private var showingAttachments = false
    @State private var showingRewrite = false

    private var current: KnowledgeCard { appStore.cards.first { $0.id == card.id } ?? card }
    private var changed: Bool {
        title != current.title || bodyText != current.body
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(current.updatedAt, format: .dateTime.month().day().year())
                    .font(.subheadline).foregroundStyle(BrainTheme.mutedText)
                TextField("Title", text: $title, axis: .vertical)
                    .font(.title2.weight(.semibold)).accessibilityLabel("Title")
                TextField("Note text", text: $bodyText, axis: .vertical)
                    .lineLimit(3...50).accessibilityLabel("Note text")
                Divider()
                NoteRewriteButton(
                    isEnabled: !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    showingRewrite = true
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                if !appStore.images(for: card).isEmpty || card.audioPath != nil {
                    Button("View attachments", systemImage: "paperclip") { showingAttachments = true }.frame(minHeight: 44)
                }
                if let error { BrainInlineMessage(message: error, systemImage: "exclamationmark.circle") }
                if saved && !changed { Label("Changes saved", systemImage: "checkmark.circle").foregroundStyle(.green) }
                if changed { Text("Unsaved changes").font(.caption).foregroundStyle(BrainTheme.mutedText) }
            }
            .padding(BrainTheme.pagePadding)
            .frame(maxWidth: BrainTheme.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .brainScreen()
        .navigationTitle("Note")
        .platformNavigationBarStyle()
        .navigationBarBackButtonHidden(changed)
        .confirmationDialog("Discard your changes?", isPresented: $showingDiscardEdits, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { dismiss() }
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            if changed {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back", systemImage: "chevron.left") { showingDiscardEdits = true }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if changed {
                HStack {
                    Button("Cancel changes") { showingDiscardEdits = true }
                    Spacer()
                    Button("Save changes") { saveChanges() }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut("s", modifiers: .command)
                }
                .padding(16).background(BrainTheme.background)
            }
        }
        .onAppear {
            guard !loaded else { return }
            title = current.title
            bodyText = current.body
            loaded = true
        }
        .sheet(isPresented: $showingAttachments) { GraphCardMoreView(card: current) }
        .sheet(isPresented: $showingRewrite) {
            NoteRewritePreviewView(
                title: title,
                originalText: bodyText
            ) { suggestion in
                bodyText = suggestion
                saved = false
                error = nil
            }
        }
    }

    private func saveChanges() {
        do {
            try appStore.updateNote(current, title: title, body: bodyText)
            title = current.title
            bodyText = current.body
            error = nil
            saved = true
        } catch { self.error = "Couldn't save. Your edits are still here. \(error.localizedDescription)" }
    }

}
