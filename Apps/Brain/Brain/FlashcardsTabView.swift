import BrainCore
import SwiftUI

struct FlashcardsTabView: View {
    @Environment(BrainAppStore.self) private var appStore
    @State private var search = ""
    @State private var showingComposer = false
    @State private var showingReview = false
    @State private var showingActivity = false

    private var results: [KnowledgeCard] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? appStore.flashcards : appStore.flashcards.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.body.localizedCaseInsensitiveContains(query) ||
            $0.deckName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if appStore.flashcards.isEmpty {
                        ContentUnavailableView {
                            Label("No flashcards yet", systemImage: "rectangle.stack")
                        } description: {
                            Text("Create a question and answer when you want to study something. Your notes stay in Notes.")
                        } actions: {
                            Button("Create a flashcard") { showingComposer = true }
                                .buttonStyle(.borderedProminent)
                        }
                    } else {
                        reviewSummary
                            .padding(.vertical, 16)

                        if results.isEmpty {
                            ContentUnavailableView.search(text: search)
                        } else {
                            Text("\(results.count) \(results.count == 1 ? "flashcard" : "flashcards")")
                                .font(.subheadline)
                                .foregroundStyle(BrainTheme.mutedText)
                                .padding(.vertical, 8)

                            ForEach(results) { card in
                                NavigationLink {
                                    FlashcardDetailView(card: card)
                                } label: {
                                    FlashcardRow(card: card)
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                    }
                }
                .padding(.horizontal, BrainTheme.pagePadding)
                .frame(maxWidth: BrainTheme.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .searchable(text: $search, prompt: "Search flashcards")
            .navigationTitle("Cards")
            .brainScreen()
            .platformNavigationBarStyle()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Activity") { showingActivity = true }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New card", systemImage: "plus") { showingComposer = true }
                }
            }
            .sheet(isPresented: $showingComposer) { CreateCardTabView() }
            .sheet(isPresented: $showingReview) { DueFlashcardsView() }
            .sheet(isPresented: $showingActivity) { ProgressTabView() }
        }
    }

    private var reviewSummary: some View {
        BrainSurface {
            ViewThatFits {
                HStack(spacing: 16) { reviewSummaryContent }
                VStack(alignment: .leading, spacing: 16) { reviewSummaryContent }
            }
        }
    }

    @ViewBuilder private var reviewSummaryContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(appStore.dueCards.isEmpty ? "You're caught up" : "\(appStore.dueCards.count) ready to review")
                .font(.headline)
            Text(appStore.dueCards.isEmpty ? "New reviews will appear here when they are due." : "Work through the cards scheduled for today.")
                .font(.subheadline)
                .foregroundStyle(BrainTheme.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Button("Review now", systemImage: "play.fill") { showingReview = true }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(appStore.dueCards.isEmpty)
    }
}

private struct FlashcardRow: View {
    @Environment(BrainAppStore.self) private var appStore
    let card: KnowledgeCard

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "rectangle.stack")
                .font(.body)
                .foregroundStyle(BrainTheme.accent)
                .frame(width: 26)
                .padding(.top, 3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 7) {
                Text(card.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(card.body)
                    .font(.subheadline)
                    .foregroundStyle(BrainTheme.mutedText)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(card.deckName)
                    Text("·")
                    Text(reviewLabel)
                }
                .font(.caption)
                .foregroundStyle(BrainTheme.mutedText)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(BrainTheme.mutedText)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 18)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var reviewLabel: String {
        let state = appStore.reviewState(for: card)
        return switch state.status {
        case .new: "New"
        case .due: "Due"
        case .mastered(let percent): "\(percent)% mastered"
        }
    }
}

private struct FlashcardDetailView: View {
    @Environment(BrainAppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss
    let card: KnowledgeCard

    @State private var question = ""
    @State private var answer = ""
    @State private var errorMessage: String?
    @State private var saved = false
    @State private var loaded = false
    @State private var showingDiscardEdits = false
    @State private var showingAttachments = false

    private var current: KnowledgeCard {
        appStore.flashcards.first { $0.id == card.id } ?? card
    }

    private var changed: Bool {
        question != current.title || answer != current.body
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text(current.deckName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrainTheme.accent)
                    Spacer()
                    ReviewStateBadge(state: appStore.reviewState(for: current))
                }

                BrainSurface {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Question").font(.headline)
                        TextField("Question", text: $question, axis: .vertical)
                            .lineLimit(2...10)
                            .accessibilityLabel("Flashcard question")
                        Divider()
                        Text("Answer").font(.headline)
                        TextField("Answer", text: $answer, axis: .vertical)
                            .lineLimit(4...30)
                            .accessibilityLabel("Flashcard answer")
                    }
                }

                if !appStore.images(for: current).isEmpty || current.audioPath != nil {
                    Button("View attachments", systemImage: "paperclip") {
                        showingAttachments = true
                    }
                    .frame(minHeight: 44)
                }

                if let errorMessage {
                    BrainInlineMessage(message: errorMessage, systemImage: "exclamationmark.circle")
                }
                if saved && !changed {
                    Label("Changes saved", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
                if changed {
                    Text("Unsaved changes")
                        .font(.caption)
                        .foregroundStyle(BrainTheme.mutedText)
                }
            }
            .padding(BrainTheme.pagePadding)
            .frame(maxWidth: BrainTheme.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .brainScreen()
        .navigationTitle("Flashcard")
        .navigationBarBackButtonHidden(changed)
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
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(
                            question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                        .keyboardShortcut("s", modifiers: .command)
                }
                .padding(16)
                .background(BrainTheme.background)
            }
        }
        .confirmationDialog("Discard your changes?", isPresented: $showingDiscardEdits, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { dismiss() }
        }
        .onAppear {
            guard !loaded else { return }
            question = current.title
            answer = current.body
            loaded = true
        }
        .sheet(isPresented: $showingAttachments) { GraphCardMoreView(card: current) }
    }

    private func saveChanges() {
        do {
            try appStore.updateFlashcard(current, question: question, answer: answer)
            question = current.title
            answer = current.body
            errorMessage = nil
            saved = true
        } catch {
            errorMessage = "Brain couldn't save this card. Your edits are still here. \(error.localizedDescription)"
        }
    }
}
