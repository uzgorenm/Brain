import BrainCore
import SwiftUI

struct CardRow: View {
    let card: KnowledgeCard
    let state: ReviewState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.title)
                .font(.headline)
                .lineLimit(1)
            Text(card.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            ReviewStateBadge(state: state)
        }
        .padding(.vertical, 4)
    }
}

struct ReviewStateBadge: View {
    let state: ReviewState

    var body: some View {
        Label(label, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var label: String {
        switch state.status {
        case .new:
            "New"
        case .due:
            "Due"
        case .mastered(let percent):
            if isDue {
                "Due · \(percent)% mastered"
            } else {
                "\(percent)% mastered"
            }
        }
    }

    private var icon: String {
        switch state.status {
        case .new:
            "sparkle"
        case .due:
            "clock"
        case .mastered:
            isDue ? "clock.badge" : "chart.line.uptrend.xyaxis"
        }
    }

    private var isDue: Bool {
        state.dueAt.map { $0 <= Date() } ?? false
    }
}
