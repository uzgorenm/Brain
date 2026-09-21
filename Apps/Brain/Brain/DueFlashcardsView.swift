import BrainCore
import SwiftUI

struct DueFlashcardsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented
    @Environment(BrainAppStore.self) private var appStore
    @Environment(BrainNavigation.self) private var navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentCardID: KnowledgeCard.ID?
    @State private var isRevealed = false
    @State private var reviewedCount = 0
    @State private var showingActivity = false
    @State private var feedback: String?

    private var currentCard: KnowledgeCard? {
        appStore.dueCards.first { $0.id == currentCardID } ?? appStore.dueCards.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let card = currentCard {
                        HStack {
                            Text("\(appStore.dueCards.count) to review")
                            Spacer()
                            Text("\(reviewedCount) reviewed")
                        }
                        .font(.subheadline).foregroundStyle(BrainTheme.mutedText)
                        BrainSurface(padding: 24) {
                            VStack(alignment: .leading, spacing: 24) {
                                Text(card.deckName).font(.subheadline.weight(.medium)).foregroundStyle(BrainTheme.accent)
                                Text(card.title).font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                                ReviewStateBadge(state: appStore.reviewState(for: card))
                                if isRevealed {
                                    Divider()
                                    Text(card.body).font(.body).textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    Button {
                                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { isRevealed = true }
                                    } label: {
                                        Text("Show answer").frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent).controlSize(.large)
                                    .keyboardShortcut(.space, modifiers: [])
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if isRevealed {
                            Text("How well did you remember?").font(.headline)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                                ratingButton("Again", detail: "I didn't remember", rating: .again, card: card)
                                ratingButton("Hard", detail: "With some effort", rating: .hard, card: card)
                                ratingButton("Good", detail: "I remembered", rating: .good, card: card)
                                ratingButton("Easy", detail: "Without effort", rating: .easy, card: card)
                            }
                        }
                        if let feedback {
                            Label(feedback, systemImage: "checkmark.circle").font(.subheadline).foregroundStyle(BrainTheme.mutedText)
                        }
                        DisclosureGroup("How review works") {
                            Text("Again keeps a card due. Hard, Good, and Easy schedule it for later based on your previous reviews. Mastery reflects the next review interval, reaching 100% at a year.")
                                .font(.subheadline).foregroundStyle(BrainTheme.mutedText).padding(.top, 8)
                        }
                    } else {
                        ContentUnavailableView {
                            Label(reviewedCount > 0 ? "Review complete" : "You're caught up", systemImage: "checkmark.circle")
                        } description: {
                            Text(reviewedCount > 0 ? "You reviewed \(reviewedCount) \(reviewedCount == 1 ? "card" : "cards"). Your next reviews are scheduled." : "Flashcards appear here when they're due.")
                        } actions: {
                            Button("Browse cards") { dismiss(); navigation.tab = .cards }.buttonStyle(.bordered)
                        }
                    }
                }
                .padding(BrainTheme.pagePadding)
                .frame(maxWidth: BrainTheme.readableWidth).frame(maxWidth: .infinity)
            }
            .navigationTitle("Review")
            .brainScreen()
            .platformNavigationBarStyle()
            .toolbar {
                if isPresented {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Activity") { showingActivity = true }
                }
            }
            .sheet(isPresented: $showingActivity) { ProgressTabView() }
            .onChange(of: currentCard?.id) { _, _ in isRevealed = false }
        }
    }

    private func ratingButton(_ title: String, detail: String, rating: ReviewRating, card: KnowledgeCard) -> some View {
        Button {
            guard appStore.review(card, rating: rating) else { return }
            reviewedCount += 1
            feedback = rating == .again ? "Kept in today's review." : "Next review scheduled."
            currentCardID = appStore.dueCards.first { $0.id != card.id }?.id ?? appStore.dueCards.first?.id
            isRevealed = false
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(BrainTheme.mutedText)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(12)
            .background(BrainTheme.surface, in: RoundedRectangle(cornerRadius: BrainTheme.cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(detail)")
    }
}
