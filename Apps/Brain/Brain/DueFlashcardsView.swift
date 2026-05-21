import BrainCore
import SwiftUI

struct DueFlashcardsView: View {
    @Environment(BrainAppStore.self) private var appStore
    @State private var reviewedMessage: String?
    @State private var currentCardID: KnowledgeCard.ID?

    private var currentCard: KnowledgeCard? {
        if let currentCardID, let card = appStore.dueCards.first(where: { $0.id == currentCardID }) {
            return card
        }
        return appStore.dueCards.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if appStore.dueCards.isEmpty {
                    ContentUnavailableView(
                        "No Cards Due",
                        systemImage: "checkmark.circle",
                        description: Text("Create a card or come back when your scheduled cards are due.")
                    )
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        DueHeader(count: appStore.dueCards.count)

                        if let currentCard {
                            DueFlashcard(
                                card: currentCard,
                                remainingCount: appStore.dueCards.count
                            ) { message in
                                reviewedMessage = message
                                currentCardID = nextCardID(after: currentCard.id)
                            }
                            .id(currentCard.id)
                            .transition(.asymmetric(insertion: .opacity, removal: .scale(scale: 0.98).combined(with: .opacity)))
                        }

                        ReviewRatingGuide()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 28)
                    .padding(.bottom, 16)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(Color.black.opacity(0.92))
                    .darkReviewNavigationBar()
                    .preferredColorScheme(.dark)
                    .onAppear {
                        currentCardID = currentCard?.id
                    }
                }
            }
            .navigationTitle("")
            .platformHiddenNavigationBar()
            .animation(.snappy, value: appStore.dueCards.map(\.id))
            .safeAreaInset(edge: .bottom) {
                if let reviewedMessage {
                    Text(reviewedMessage)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onChange(of: reviewedMessage) { _, newValue in
                guard newValue != nil else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation(.snappy) {
                        reviewedMessage = nil
                    }
                }
            }
        }
    }

    private func nextCardID(after reviewedCardID: KnowledgeCard.ID) -> KnowledgeCard.ID? {
        let remainingCards = appStore.dueCards.filter { $0.id != reviewedCardID }
        return remainingCards.first?.id ?? appStore.dueCards.first?.id
    }
}

private extension View {
    @ViewBuilder
    func darkReviewNavigationBar() -> some View {
#if os(iOS)
        self
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
#else
        self
#endif
    }
}

private struct DueHeader: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Due Today")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            HStack(spacing: 10) {
                Label("\(count) Due", systemImage: "rectangle.stack")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(BrainTheme.accent)

                Spacer()

                Text(count == 1 ? "1 card" : "\(count) cards")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.10))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DueFlashcard: View {
    @Environment(BrainAppStore.self) private var appStore
    let card: KnowledgeCard
    let remainingCount: Int
    let onReviewed: (String) -> Void
    @State private var isRevealed = false

    var body: some View {
        VStack(spacing: 22) {
            ProgressView(value: 1, total: Double(max(remainingCount, 1)))
                .tint(.blue)

            Spacer(minLength: 30)

            VStack(spacing: 18) {
                Text(card.deckName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(BrainTheme.accent)

                Text(card.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.72)

                ReviewStateBadge(state: appStore.reviewState(for: card))

                if isRevealed {
                    Divider()
                    Text(card.body)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)

            Spacer(minLength: 30)

            if isRevealed {
                HStack(spacing: 10) {
                    ReviewButton(title: "Again", rating: .again, card: card, onReviewed: onReviewed)
                    ReviewButton(title: "Hard", rating: .hard, card: card, onReviewed: onReviewed)
                    ReviewButton(title: "Good", rating: .good, card: card, onReviewed: onReviewed)
                    ReviewButton(title: "Easy", rating: .easy, card: card, onReviewed: onReviewed)
                }
            } else {
                Button {
                    withAnimation(.snappy) {
                        isRevealed = true
                    }
                } label: {
                    Text("Show Answer")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 480)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12))
        )
    }
}

private struct ReviewButton: View {
    @Environment(BrainAppStore.self) private var appStore
    let title: String
    let rating: ReviewRating
    let card: KnowledgeCard
    let onReviewed: (String) -> Void

    var body: some View {
        Button {
            withAnimation(.snappy) {
                appStore.review(card, rating: rating)
                onReviewed(message)
            }
        } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }

    private var tint: Color {
        switch rating {
        case .again:
            .red
        case .hard:
            .orange
        case .good:
            .blue
        case .easy:
            .green
        }
    }

    private var message: String {
        switch rating {
        case .again:
            "\"\(card.title)\" is still due."
        case .hard, .good, .easy:
            "\"\(card.title)\" was scheduled for later."
        }
    }
}

private struct ReviewRatingGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("What the buttons mean", systemImage: "questionmark.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 5) {
                Text("Again means you missed it, so it stays due now.")
                Text("Hard means you barely remembered it, so FSRS grows the interval cautiously.")
                Text("Good means you recalled it, so FSRS schedules the normal next interval.")
                Text("Easy means it felt automatic, so FSRS gives the interval a larger boost.")
                Text("Mastery is derived from the next interval: 365 days equals 100%.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
