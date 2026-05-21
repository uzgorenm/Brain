import AVFoundation
import BrainCore
import Foundation
import Observation
import SwiftUI

struct GraphTabView: View {
    @Environment(BrainAppStore.self) private var appStore

    var body: some View {
        NavigationStack {
            if appStore.cards.isEmpty {
                ContentUnavailableView(
                    "No Graph Yet",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("Create cards to begin mapping your knowledge.")
                )
            } else {
                GraphWorkspaceView()
            }
        }
    }
}

private struct GraphWorkspaceView: View {
    @Environment(BrainAppStore.self) private var appStore
    @State private var scale = 1.0
    @State private var offset = CGSize.zero
    @State private var showingConnectedCard = false
    @State private var showingReviewSession = false
    @State private var showingSelectedCardDetails = false

    var body: some View {
        GeometryReader { proxy in
            let showInspector = proxy.size.width > 820

            HStack(spacing: 0) {
                ZStack {
                    KnowledgeGraphCanvas(scale: $scale, offset: $offset)

                    VStack(alignment: .leading, spacing: 24) {
                        GraphHeader(showingReviewSession: $showingReviewSession)

                        Spacer()

                        if showInspector == false, let card = appStore.selectedCard {
                            GraphCardDetailSummary(card: card) {
                                showingSelectedCardDetails = true
                            }
                        }

                        HStack(spacing: 14) {
                            Button {
                                showingConnectedCard = true
                            } label: {
                                Label("Connect Manually", systemImage: "link")
                                    .font(.headline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                            .background(BrainTheme.surface)
                            .clipShape(Capsule())

                            Button {} label: {
                                Label("AI Map Decks", systemImage: "sparkles")
                                    .font(.headline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.black.opacity(0.80))
                            .background(BrainTheme.mastered)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(28)

#if os(macOS)
                    GraphToolbar(scale: $scale, offset: $offset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .padding(.trailing, 30)
#endif
                }

                if showInspector {
                    GraphInspectorView(showingConnectedCard: $showingConnectedCard)
                        .frame(minWidth: 300, idealWidth: 340, maxWidth: 380)
                        .background(BrainTheme.background)
                }
            }
        }
        .brainDarkScreen()
        .platformNavigationBarStyle()
        .navigationTitle("")
        .onAppear {
            appStore.selectedCardID = nil
            scale = 1
            offset = .zero
        }
        .sheet(isPresented: $showingConnectedCard) {
            if let selectedCard = appStore.selectedCard {
                ConnectExistingCardView(sourceCard: selectedCard)
            }
        }
        .sheet(isPresented: $showingReviewSession) {
            DueFlashcardsView()
        }
        .sheet(isPresented: $showingSelectedCardDetails) {
            if let selectedCard = appStore.selectedCard {
                GraphCardMoreView(card: selectedCard)
            }
        }
    }
}

private struct GraphHeader: View {
    @Binding var showingReviewSession: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                headerContent

                Spacer(minLength: 12)

                reviewButton
            }

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Connections")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Spacer(minLength: 8)

                    reviewButton
                }

                GraphLegend()
            }
        }
    }

    private var headerContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            Text("Connections")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            GraphLegend()
        }
    }

    private var reviewButton: some View {
        Button {
            showingReviewSession = true
        } label: {
            Label("Review", systemImage: "play")
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.17))
        .clipShape(Capsule())
    }
}

private struct GraphToolbar: View {
    @Binding var scale: Double
    @Binding var offset: CGSize

    var body: some View {
        VStack(spacing: 6) {
            ToolbarIconButton(systemName: "plus.magnifyingglass", title: "Zoom in") {
                scale = min(1.8, scale + 0.15)
            }

            Divider()
                .background(Color.white.opacity(0.14))

            ToolbarIconButton(systemName: "minus.magnifyingglass", title: "Zoom out") {
                scale = max(0.65, scale - 0.15)
            }

            Divider()
                .background(Color.white.opacity(0.14))

            ToolbarIconButton(systemName: "arrow.counterclockwise", title: "Reset view") {
                scale = 1
                offset = .zero
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12)))
    }
}

private struct ToolbarIconButton: View {
    let systemName: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline.weight(.semibold))
                .frame(width: 38, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}

private struct GraphLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LegendRow(color: BrainTheme.mastered, title: "Mastered")
            LegendRow(color: BrainTheme.learning, title: "Learning")
            LegendRow(color: BrainTheme.unseen, title: "Unseen")
        }
        .padding(18)
        .background(Color.black.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12)))
    }
}

private struct LegendRow: View {
    let color: Color
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(title)
                .font(.headline)
        }
    }
}

private struct KnowledgeGraphCanvas: View {
    @Environment(BrainAppStore.self) private var appStore
    @Binding var scale: Double
    @Binding var offset: CGSize
    @State private var dragStartOffset = CGSize.zero
    @State private var gestureStartScale = 1.0

    var body: some View {
        GeometryReader { proxy in
            let layout = GraphLayout(cards: appStore.cards, edges: appStore.edges, size: proxy.size)

            ZStack {
                GraphBackground()

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.snappy) {
                            appStore.selectedCardID = nil
                        }
                    }

                Canvas { context, _ in
                    for edge in appStore.edges {
                        guard let source = layout.positions[edge.sourceCardID],
                              let target = layout.positions[edge.targetCardID] else {
                            continue
                        }

                        var path = Path()
                        path.move(to: transformed(source))
                        path.addLine(to: transformed(target))
                        context.stroke(path, with: .color(.secondary.opacity(0.38)), lineWidth: 2)
                    }
                }
                .allowsHitTesting(false)

                ForEach(appStore.cards) { card in
                    let position = transformed(layout.positions[card.id] ?? CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2))
                    GraphCanvasNode(
                        card: card,
                        isSelected: appStore.selectedCardID == card.id,
                        state: appStore.reviewState(for: card)
                    )
                    .position(position)
                    .onTapGesture {
                        appStore.selectedCardID = card.id
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: dragStartOffset.width + value.translation.width,
                            height: dragStartOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        dragStartOffset = offset
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(1.8, max(0.65, gestureStartScale * value))
                    }
                    .onEnded { _ in
                        gestureStartScale = scale
                    }
            )
            .onChange(of: offset) { _, nextOffset in
                if nextOffset == .zero {
                    dragStartOffset = .zero
                }
            }
            .onChange(of: scale) { _, nextScale in
                if nextScale == 1 {
                    gestureStartScale = 1
                }
            }
        }
    }

    private func transformed(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: (point.x * scale) + offset.width,
            y: (point.y * scale) + offset.height
        )
    }
}

private struct GraphBackground: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(BrainTheme.background))

            for x in stride(from: CGFloat(4), through: size.width, by: 44) {
                for y in stride(from: CGFloat(4), through: size.height, by: 44) {
                    let dot = Path(ellipseIn: CGRect(x: x, y: y, width: 3, height: 3))
                    context.fill(dot, with: .color(Color.white.opacity(0.10)))
                }
            }
        }
    }
}

private struct GraphCanvasNode: View {
    let card: KnowledgeCard
    let isSelected: Bool
    let state: ReviewState

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: isSelected ? 38 : 24, height: isSelected ? 38 : 24)
                .overlay(Circle().stroke(isSelected ? BrainTheme.mastered : Color.clear, lineWidth: 4))
                .shadow(color: dotColor.opacity(isSelected ? 0.45 : 0.15), radius: isSelected ? 18 : 8)

            if isSelected {
                Text(card.title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.78))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(BrainTheme.mastered.opacity(0.55)))
            }
        }
        .frame(width: 150, height: 80)
    }

    private var label: String {
        switch state.status {
        case .new:
            "New"
        case .due:
            "Due"
        case .mastered(let percent):
            "\(percent)%"
        }
    }

    private var dotColor: Color {
        switch state.status {
        case .new:
            BrainTheme.unseen
        case .due:
            BrainTheme.learning
        case .mastered(let percent):
            percent >= 80 ? BrainTheme.mastered : BrainTheme.learning
        }
    }
}

private struct GraphInspectorView: View {
    @Environment(BrainAppStore.self) private var appStore
    @Binding var showingConnectedCard: Bool
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let card = appStore.selectedCard {
                let neighbors = appStore.neighbors(of: card)
                let state = appStore.reviewState(for: card)

                VStack(alignment: .leading, spacing: 12) {
                    Text(card.title)
                        .font(.title2.bold())
                    Text(card.deckName)
                        .font(.headline)
                        .foregroundStyle(BrainTheme.accent)
                    ReviewStateBadge(state: state)
                    Text(card.body)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(8)
                }

                GraphStudyStats(state: state)

                NavigationLink {
                    GraphCardMoreView(card: card)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    showingConnectedCard = true
                } label: {
                    Label("Connect Card", systemImage: "link")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Card", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Connections")
                        .font(.headline)

                    if neighbors.isEmpty {
                        Text("No connected cards yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(neighbors) { neighbor in
                            let neighborState = appStore.reviewState(for: neighbor)
                            HStack(spacing: 10) {
                                Button {
                                    appStore.selectedCardID = neighbor.id
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "point.3.connected.trianglepath.dotted")
                                            .foregroundStyle(.secondary)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(neighbor.title)
                                                .lineLimit(1)
                                            Text(connectionSubtitle(for: neighborState))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Text("\(neighborState.status.masteryPercent)%")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(BrainTheme.accent)
                                    }
                                }
                                .buttonStyle(.plain)

                                Button(role: .destructive) {
                                    appStore.disconnectCard(neighbor, from: card)
                                } label: {
                                    Image(systemName: "link.badge.minus")
                                        .imageScale(.medium)
                                }
                                .buttonStyle(.borderless)
                                .help("Delete connection to \(neighbor.title)")
                                .accessibilityLabel("Delete connection to \(neighbor.title)")
                            }
                            .padding(10)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                Spacer()
            } else {
                ContentUnavailableView(
                    "Select a Node",
                    systemImage: "cursorarrow.click",
                    description: Text("Choose a graph node to inspect and connect cards.")
                )
            }
        }
        .padding()
        .confirmationDialog("Delete this card?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            if let card = appStore.selectedCard {
                Button("Delete \"\(card.title)\"", role: .destructive) {
                    appStore.deleteCard(card)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the card from the graph and deletes its connections.")
        }
    }

    private func connectionSubtitle(for state: ReviewState) -> String {
        let interval = state.intervalDays.map { "\($0)d interval" } ?? "No interval yet"
        let reviewCount = state.reviewCount == 1 ? "1 review" : "\(state.reviewCount) reviews"
        return "\(interval) · \(reviewCount)"
    }
}

private struct GraphCardDetailSummary: View {
    @Environment(BrainAppStore.self) private var appStore
    let card: KnowledgeCard
    let showMore: () -> Void

    var body: some View {
        let state = appStore.reviewState(for: card)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.title)
                        .font(.headline.bold())
                        .lineLimit(1)
                    Text(card.deckName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrainTheme.accent)
                        .lineLimit(1)
                }

                Spacer()

                Text("\(state.status.masteryPercent)%")
                    .font(.title3.bold())
                    .foregroundStyle(BrainTheme.accent)
            }

            GraphStudyStats(state: state, compact: true)

            Text(card.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Button(action: showMore) {
                Label("More", systemImage: "ellipsis.circle")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(0.10))
            .clipShape(Capsule())
        }
        .padding(14)
        .background(BrainTheme.surface.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.10)))
    }
}

private struct GraphStudyStats: View {
    let state: ReviewState
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(spacing: 10) {
                StatPill(title: "Mastery", value: "\(state.status.masteryPercent)%")
                StatPill(title: "Interval", value: intervalText)
            }

            HStack(spacing: 10) {
                StatPill(title: "Reviews", value: "\(state.reviewCount)")
                StatPill(title: "Due", value: dueText)
            }

            if compact == false {
                if let lastReviewedText {
                    InfoRow(title: "Last reviewed", value: lastReviewedText)
                }
                if let difficulty = state.difficulty {
                    InfoRow(title: "Difficulty", value: difficulty.formatted(.number.precision(.fractionLength(1))))
                }
                if let stability = state.stability {
                    InfoRow(title: "Stability", value: stability.formatted(.number.precision(.fractionLength(1))))
                }
            }
        }
    }

    private var intervalText: String {
        guard let intervalDays = state.intervalDays else { return "New" }
        if intervalDays >= 365 { return "1y+" }
        return "\(intervalDays)d"
    }

    private var dueText: String {
        guard let dueAt = state.dueAt else { return "Now" }
        if dueAt <= Date() { return "Now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: dueAt, relativeTo: Date())
    }

    private var lastReviewedText: String? {
        state.lastReviewedAt?.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.caption)
    }
}

private struct GraphCardMoreView: View {
    @Environment(BrainAppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss
    let card: KnowledgeCard
    @State private var audioPlayer = CardAudioPlayer()
    @State private var isCardInfoExpanded = true
    @State private var shouldIgnoreNextOutsideTap = false

    var body: some View {
        let images = appStore.images(for: card)
        let state = appStore.reviewState(for: card)
        let audioURL = appStore.audioURL(for: card)

        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        BrainSurface {
                            Button {
                                shouldIgnoreNextOutsideTap = true
                                withAnimation(.snappy) {
                                    isCardInfoExpanded.toggle()
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(card.title)
                                                .font(.title2.bold())
                                                .lineLimit(isCardInfoExpanded ? nil : 1)
                                            Text(card.deckName)
                                                .font(.headline)
                                                .foregroundStyle(BrainTheme.accent)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.down")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(BrainTheme.mutedText)
                                            .rotationEffect(.degrees(isCardInfoExpanded ? 180 : 0))
                                    }

                                    ReviewStateBadge(state: state)

                                    if isCardInfoExpanded {
                                        Text(card.body)
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                            .textSelection(.enabled)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }

                        BrainSurface {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Label("Photos", systemImage: "photo.on.rectangle")
                                        .font(.headline.bold())
                                    Spacer()
                                    Text("\(images.count)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(BrainTheme.mutedText)
                                }

                                if images.isEmpty {
                                    AttachmentDetailDisclosureRow(
                                        title: "No photos attached",
                                        systemImage: "photo",
                                        detail: "This card does not have any saved photos yet. Add images from the New Card screen with the photo button before saving."
                                    )
                                } else {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                                        ForEach(images) { image in
                                            CardAttachmentImage(path: image.localPath)
                                        }
                                    }
                                }
                            }
                        }
                        .onTapGesture(perform: collapseCardInfo)

                        BrainSurface {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Label("Audio Recording", systemImage: "waveform")
                                        .font(.headline.bold())
                                    Spacer()
                                    if audioURL != nil {
                                        Text("1")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(BrainTheme.mutedText)
                                    }
                                }

                                if let audioURL {
                                    AudioAttachmentRow(url: audioURL, audioPlayer: audioPlayer)
                                } else {
                                    AttachmentDetailDisclosureRow(
                                        title: "No audio recording attached",
                                        systemImage: "waveform",
                                        detail: "This card does not have a saved recording yet. Add audio from the New Card screen with the mic button before saving."
                                    )
                                }
                            }
                        }
                        .onTapGesture(perform: collapseCardInfo)
                    }
                    .padding(18)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: collapseCardInfo)
                }
            }
            .brainDarkScreen()
            .navigationTitle("Card Details")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        audioPlayer.stop()
                        dismiss()
                    }
                }
            }
            .onDisappear {
                audioPlayer.stop()
            }
        }
    }

    private func collapseCardInfo() {
        if shouldIgnoreNextOutsideTap {
            shouldIgnoreNextOutsideTap = false
            return
        }

        guard isCardInfoExpanded else { return }
        withAnimation(.snappy) {
            isCardInfoExpanded = false
        }
    }
}

private struct CardAttachmentImage: View {
    let path: String

    var body: some View {
        Group {
            if let image = PlatformImage.load(from: URL(fileURLWithPath: path)) {
                PlatformImageView(image: image)
                    .scaledToFill()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.title2)
                    Text(FileManager.default.fileExists(atPath: path) ? "Can't preview" : "Missing file")
                        .font(.caption.weight(.semibold))
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .font(.caption2)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: 130)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.10)))
    }
}

private struct AudioAttachmentRow: View {
    let url: URL
    let audioPlayer: CardAudioPlayer

    var body: some View {
        HStack(spacing: 12) {
            Button {
                audioPlayer.toggle(url: url)
            } label: {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.headline)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .background(BrainTheme.accent)
            .foregroundStyle(.white)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(audioTitle)
                    .font(.headline)
                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(BrainTheme.mutedText)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var audioTitle: String {
        if FileManager.default.fileExists(atPath: url.path) == false {
            return "Missing audio file"
        }

        return audioPlayer.isPlaying ? "Playing recording" : "Tap to play recording"
    }
}

private struct AttachmentDetailDisclosureRow: View {
    let title: String
    let systemImage: String
    let detail: String
    @State private var isExpanded = false

    var body: some View {
        Button {
            withAnimation(.snappy) {
                isExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: systemImage)
                    Text(title)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .font(.caption.weight(.bold))
                }

                if isExpanded {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(BrainTheme.mutedText)
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

@Observable
private final class CardAudioPlayer: NSObject, AVAudioPlayerDelegate {
    var isPlaying = false
    private var player: AVAudioPlayer?

    func toggle(url: URL) {
        if isPlaying {
            stop()
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            isPlaying = false
            return
        }

        do {
#if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
#endif
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stop()
    }
}

#if os(macOS)
private typealias PlatformImage = NSImage

private extension NSImage {
    static func load(from url: URL) -> NSImage? {
        NSImage(contentsOf: url)
    }
}

private struct PlatformImageView: View {
    let image: NSImage

    var body: some View {
        Image(nsImage: image)
            .resizable()
    }
}
#else
private typealias PlatformImage = UIImage

private extension UIImage {
    static func load(from url: URL) -> UIImage? {
        if let image = UIImage(contentsOfFile: url.path) {
            return image
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }
}

private struct PlatformImageView: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
    }
}
#endif

private struct ConnectExistingCardView: View {
    @Environment(BrainAppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss
    let sourceCard: KnowledgeCard
    @State private var searchText = ""

    var connectableCards: [KnowledgeCard] {
        let neighbors = Set(appStore.neighbors(of: sourceCard).map { $0.id })
        return appStore.cards.filter { card in
            card.id != sourceCard.id && !neighbors.contains(card.id) &&
            (searchText.isEmpty || card.title.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            List(connectableCards) { card in
                Button {
                    appStore.connectCard(card, to: sourceCard)
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(card.title)
                            .font(.headline)
                        Text(card.body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search by title")
            .navigationTitle("Connect to \(sourceCard.title)")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(minWidth: 300, minHeight: 400)
#if os(iOS)
        .presentationDetents([.medium, .large])
#endif
    }
}

private struct GraphLayout {
    let positions: [KnowledgeCard.ID: CGPoint]

    init(cards: [KnowledgeCard], edges: [CardEdge], size: CGSize) {
        guard cards.isEmpty == false else {
            positions = [:]
            return
        }

        let topInset = min(230, max(150, size.height * 0.24))
        let bottomInset = min(190, max(130, size.height * 0.18))
        let horizontalInset = min(72, max(34, size.width * 0.08))
        let usableWidth = max(180, size.width - (horizontalInset * 2))
        let usableHeight = max(180, size.height - topInset - bottomInset)
        let center = CGPoint(
            x: horizontalInset + usableWidth / 2,
            y: topInset + usableHeight / 2
        )
        let radius = max(70, min(usableWidth, usableHeight) * 0.42)
        let connectedIDs = Set(edges.flatMap { [$0.sourceCardID, $0.targetCardID] })
        let sortedCards = cards.sorted { lhs, rhs in
            if connectedIDs.contains(lhs.id) != connectedIDs.contains(rhs.id) {
                return connectedIDs.contains(lhs.id)
            }
            return lhs.updatedAt > rhs.updatedAt
        }

        var next: [KnowledgeCard.ID: CGPoint] = [:]

        if sortedCards.count == 1 {
            next[sortedCards[0].id] = center
        } else {
            for (index, card) in sortedCards.enumerated() {
                let angle = CGFloat(Double(index) / Double(sortedCards.count) * 2 * Double.pi - Double.pi / 2)
                let ringOffset = CGFloat(index % 2) * 38
                next[card.id] = CGPoint(
                    x: center.x + cos(angle) * (radius + ringOffset),
                    y: center.y + sin(angle) * (radius + ringOffset)
                )
            }
        }

        positions = next
    }
}
