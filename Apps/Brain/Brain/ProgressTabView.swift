import BrainCore
import SwiftUI

struct ProgressTabView: View {
    @Environment(BrainAppStore.self) private var appStore

    private var analytics: ProgressAnalytics {
        ProgressAnalytics(cards: appStore.cards, states: states, events: appStore.reviewEvents)
    }

    private var states: [ReviewState] {
        appStore.cards.map { appStore.reviewState(for: $0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Activity")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .padding(.top, 18)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                        ActivityMetricCard(title: "Current Streak", value: "\(analytics.currentStreakDays)", suffix: analytics.currentStreakDays == 1 ? "Day" : "Days")
                        ActivityMetricCard(title: "Cards Learned", value: "\(analytics.cardsLearned)", suffix: "")
                        ActivityMetricCard(title: "Retention %", value: "\(analytics.retentionPercent)", suffix: "%")
                        ActivityMetricCard(title: "Reviews", value: "\(analytics.totalReviews)", suffix: "")
                    }

                    BrainSurface {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Consistency")
                                    .font(.title2.bold())
                                Spacer()
                                Text("\(analytics.reviewsLast91Days) reviews in 13 weeks")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BrainTheme.mutedText)
                            }

                            ConsistencyGrid(days: analytics.consistencyDays)

                            HStack {
                                Text("Less")
                                Spacer()
                                HStack(spacing: 6) {
                                    ForEach(0..<5, id: \.self) { index in
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(ConsistencyDay.color(for: index))
                                            .frame(width: 16, height: 16)
                                    }
                                }
                                Spacer()
                                Text("More")
                            }
                            .font(.caption)
                            .foregroundStyle(BrainTheme.mutedText)
                        }
                    }

                    BrainSurface {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Retention Rate")
                                    .font(.title2.bold())
                                Spacer()
                                Text("\(analytics.retentionWindowLabel)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BrainTheme.mutedText)
                            }

                            RetentionChart(points: analytics.retentionTrend)
                                .frame(height: 190)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .brainDarkScreen()
            .platformNavigationBarStyle()
        }
    }
}

private struct ProgressAnalytics {
    let cards: [KnowledgeCard]
    let states: [ReviewState]
    let events: [ReviewEvent]
    private let calendar = Calendar.current

    var totalReviews: Int {
        events.count
    }

    var cardsLearned: Int {
        Set(events.map(\.cardID)).count
    }

    var retentionPercent: Int {
        successRate(for: events)
    }

    var currentStreakDays: Int {
        let activeDays = Set(events.map { calendar.startOfDay(for: $0.reviewedAt) })
        guard activeDays.isEmpty == false else { return 0 }

        var cursor = calendar.startOfDay(for: Date())
        if activeDays.contains(cursor) == false,
           let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
           activeDays.contains(yesterday) {
            cursor = yesterday
        }

        var streak = 0
        while activeDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    var reviewsLast91Days: Int {
        consistencyDays.map(\.reviewCount).reduce(0, +)
    }

    var consistencyDays: [ConsistencyDay] {
        let today = calendar.startOfDay(for: Date())
        let counts = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.reviewedAt)
        }.mapValues(\.count)

        return (0..<91).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 90, to: today) else { return nil }
            return ConsistencyDay(date: date, reviewCount: counts[date] ?? 0)
        }
    }

    var retentionTrend: [RetentionPoint] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset - 6, to: today) else { return nil }
            let dayEvents = events.filter { calendar.isDate($0.reviewedAt, inSameDayAs: day) }
            return RetentionPoint(date: day, percent: successRate(for: dayEvents), reviewCount: dayEvents.count)
        }
    }

    var retentionWindowLabel: String {
        guard totalReviews > 0 else { return "No reviews yet" }
        return "Last 7 days"
    }

    private func successRate(for events: [ReviewEvent]) -> Int {
        guard events.isEmpty == false else { return 0 }
        let successfulReviews = events.filter { $0.rating != .again }.count
        return Int((Double(successfulReviews) / Double(events.count) * 100).rounded())
    }
}

private struct ConsistencyDay: Identifiable {
    let date: Date
    let reviewCount: Int

    var id: Date { date }

    var intensity: Int {
        switch reviewCount {
        case 0:
            0
        case 1:
            1
        case 2...3:
            2
        case 4...7:
            3
        default:
            4
        }
    }

    static func color(for intensity: Int) -> Color {
        switch intensity {
        case 0:
            Color.white.opacity(0.06)
        case 1:
            Color.green.opacity(0.35)
        case 2:
            Color.green.opacity(0.55)
        case 3:
            Color.green.opacity(0.75)
        default:
            Color.green
        }
    }
}

private struct RetentionPoint: Identifiable {
    let date: Date
    let percent: Int
    let reviewCount: Int

    var id: Date { date }
}

private struct ActivityMetricCard: View {
    let title: String
    let value: String
    let suffix: String

    var body: some View {
        BrainSurface {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(BrainTheme.mutedText)

                Spacer(minLength: 56)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                    if suffix.isEmpty == false {
                        Text(suffix)
                            .font(.title3.weight(.semibold))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        }
    }
}

private struct ConsistencyGrid: View {
    let days: [ConsistencyDay]
    private let columns = Array(repeating: GridItem(.fixed(16), spacing: 7), count: 13)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 7) {
            ForEach(days) { day in
                RoundedRectangle(cornerRadius: 3)
                    .fill(ConsistencyDay.color(for: day.intensity))
                    .frame(width: 16, height: 16)
                    .help("\(day.reviewCount) reviews")
            }
        }
    }
}

private struct RetentionChart: View {
    let points: [RetentionPoint]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let domain = RetentionChartDomain(points: points)
            let step = width / CGFloat(max(points.count - 1, 1))
            let mapped = points.enumerated().map { index, point in
                CGPoint(
                    x: CGFloat(index) * step,
                    y: domain.yPosition(for: point.percent, in: height)
                )
            }
            let baselineY = domain.yPosition(for: domain.lowerBound, in: height)

            ZStack {
                ChartGrid(labels: domain.gridLabels)

                Path { path in
                    guard let first = mapped.first else { return }
                    path.move(to: CGPoint(x: first.x, y: baselineY))
                    for point in mapped {
                        path.addLine(to: point)
                    }
                    if let last = mapped.last {
                        path.addLine(to: CGPoint(x: last.x, y: baselineY))
                    }
                    path.closeSubpath()
                }
                .fill(BrainTheme.accent.opacity(points.contains { $0.reviewCount > 0 } ? 0.20 : 0.05))

                Path { path in
                    guard let first = mapped.first else { return }
                    path.move(to: first)
                    for point in mapped.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(BrainTheme.accent.opacity(points.contains { $0.reviewCount > 0 } ? 1 : 0.25), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private struct RetentionChartDomain {
    let lowerBound: Int
    let upperBound: Int

    init(points: [RetentionPoint]) {
        let reviewedPercents = points
            .filter { $0.reviewCount > 0 }
            .map(\.percent)

        guard let minimum = reviewedPercents.min(),
              let maximum = reviewedPercents.max() else {
            lowerBound = 80
            upperBound = 100
            return
        }

        if minimum >= 80 && maximum <= 100 {
            lowerBound = 80
            upperBound = 100
            return
        }

        let paddedLower = max(0, minimum - 5)
        let paddedUpper = min(100, maximum + 5)
        let roundedLower = max(0, (paddedLower / 10) * 10)
        let roundedUpper = min(100, Int(ceil(Double(paddedUpper) / 10.0)) * 10)

        lowerBound = min(roundedLower, 80)
        upperBound = max(roundedUpper, 100)
    }

    var gridLabels: [Int] {
        guard upperBound >= lowerBound else { return [] }
        return stride(from: upperBound, through: lowerBound, by: -5).map { $0 }
    }

    func yPosition(for percent: Int, in height: CGFloat) -> CGFloat {
        let chartPadding: CGFloat = 10
        let drawableHeight = max(1, height - (chartPadding * 2))
        let clampedPercent = min(upperBound, max(lowerBound, percent))
        let progress = Double(clampedPercent - lowerBound) / Double(max(upperBound - lowerBound, 1))
        return height - chartPadding - CGFloat(progress) * drawableHeight
    }
}

private struct ChartGrid: View {
    let labels: [Int]

    var body: some View {
        VStack {
            ForEach(labels, id: \.self) { percent in
                HStack {
                    Text("\(percent)%")
                        .font(.caption)
                        .foregroundStyle(BrainTheme.mutedText)
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                }
                if percent != labels.last {
                    Spacer()
                }
            }
        }
    }
}
