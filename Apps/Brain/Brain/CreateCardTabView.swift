import AVFoundation
import BrainCore
import Observation
import PhotosUI
import SwiftUI

struct CreateCardTabView: View {
    @Environment(BrainAppStore.self) private var appStore
    @State private var title = ""
    @State private var bodyText = ""
    @State private var detailedInformation = ""
    @State private var isGenerating = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var imagePaths: [String] = []
    @State private var audioPath: String?
    @State private var showingDeckPicker = false
    @State private var newDeckName = ""
    @State private var saveConfirmation = false
    @State private var audioRecorder = CardAudioRecorder()

    private var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var canGenerate: Bool {
        detailedInformation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && !isGenerating
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") {
                        resetComposer()
                        hideKeyboard()
                    }
                    .font(.title3.weight(.semibold))

                    Spacer()

                    Text("New Card")
                        .font(.title2.bold())

                    Spacer()

                    Button("Save") {
                        appStore.createCard(
                            title: title,
                            body: bodyText,
                            deckName: appStore.selectedDeckName,
                            imagePaths: imagePaths,
                            audioPath: audioPath
                        )
                        resetComposer()
                        hideKeyboard()
                        saveConfirmation = true
                    }
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(canSave ? BrainTheme.accent : BrainTheme.mutedText)
                    .disabled(!canSave)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(BrainTheme.surface)

                Divider()
                    .overlay(Color.white.opacity(0.08))

                ScrollView {
                    VStack(spacing: 24) {
                        Button {
                            showingDeckPicker = true
                        } label: {
                            HStack {
                                Text("Deck")
                                    .font(.title3)
                                Spacer()
                                Text(appStore.selectedDeckName)
                                    .font(.title3)
                                    .foregroundStyle(BrainTheme.mutedText)
                                    .lineLimit(1)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(BrainTheme.mutedText)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .background(BrainTheme.surface)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("AI Flashcard Generation")
                                .font(.headline)
                                .foregroundStyle(BrainTheme.mutedText)
                                .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                TextField("Dump detailed information here...", text: $detailedInformation, axis: .vertical)
                                    .font(.title3)
                                    .lineLimit(4...10)
                                    .padding(18)
                                    .disabled(isGenerating)

                                Divider()
                                    .overlay(Color.white.opacity(0.10))

                                Button(action: generateFlashcard) {
                                    HStack {
                                        if isGenerating {
                                            ProgressView()
                                                .controlSize(.small)
                                                .tint(BrainTheme.accent)
                                        } else {
                                            Image(systemName: "sparkles")
                                        }
                                        Text(isGenerating ? "Generating..." : "Generate Flashcard")
                                            .font(.headline)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(canGenerate ? BrainTheme.accent.opacity(0.15) : Color.clear)
                                    .foregroundStyle(canGenerate ? BrainTheme.accent : BrainTheme.mutedText)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canGenerate)
                            }
                            .background(BrainTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.16))
                            )
                            .padding(.horizontal, 20)
                        }

                        VStack(spacing: 0) {
                            TextField("Question...", text: $title, axis: .vertical)
                                .font(.title3.weight(.semibold))
                                .lineLimit(4...8)
                                .padding(18)

                            Divider()
                                .overlay(Color.white.opacity(0.10))

                            TextField("Answer...", text: $bodyText, axis: .vertical)
                                .font(.title3)
                                .lineLimit(6...12)
                                .padding(18)
                        }
                        .textFieldStyle(.plain)
                        .frame(minHeight: 260, alignment: .top)
                        .background(BrainTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.16))
                        )
                        .padding(.horizontal, 20)

                        Text("Type both sides to save the card.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrainTheme.mutedText)

                        if imagePaths.isEmpty == false || audioPath != nil {
                            AttachmentSummary(imageCount: imagePaths.count, hasAudio: audioPath != nil)
                                .padding(.horizontal, 20)
                        }

                        HStack(spacing: 28) {
                            PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 4, matching: .images) {
                                ComposerToolButtonLabel(systemImage: "photo", title: "Image")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(BrainTheme.mutedText)

                            ComposerToolButton(systemImage: audioRecorder.isRecording ? "stop.fill" : "mic", title: audioRecorder.isRecording ? "Stop recording" : "Record audio") {
                                toggleRecording()
                            }
                            .foregroundStyle(audioRecorder.isRecording ? .red : BrainTheme.mutedText)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
            .brainDarkScreen()
            .platformNavigationBarStyle()
            .platformHiddenNavigationBar()
            .alert("Card Saved", isPresented: $saveConfirmation) {
                Button("OK") {}
            } message: {
                Text("The card was added to \(appStore.selectedDeckName).")
            }
            .sheet(isPresented: $showingDeckPicker) {
                DeckPickerView(newDeckName: $newDeckName)
            }
            .task(id: selectedPhotoItems) {
                await importSelectedPhotos()
            }
        }
    }

    private func generateFlashcard() {
        Task {
            isGenerating = true
            defer { isGenerating = false }
            do {
                let (generatedTitle, generatedBody) = try await BrainCore.LLMManager.shared.generateFlashcard(from: detailedInformation)
                await MainActor.run {
                    self.title = generatedTitle
                    self.bodyText = generatedBody
                    self.detailedInformation = ""
                }
            } catch {
                await MainActor.run {
                    appStore.errorMessage = "Generation failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func resetComposer() {
        title = ""
        bodyText = ""
        imagePaths = []
        audioPath = nil
        selectedPhotoItems = []
        newDeckName = ""
        audioRecorder.cancel()
    }

    private func importSelectedPhotos() async {
        guard selectedPhotoItems.isEmpty == false else { return }

        for item in selectedPhotoItems {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let destination = try appStore.makeMediaFileURL(fileExtension: "jpg")
                try data.write(to: destination, options: .atomic)
                if imagePaths.contains(destination.path) == false {
                    imagePaths.append(destination.path)
                }
            } catch {
                appStore.errorMessage = error.localizedDescription
            }
        }

        selectedPhotoItems = []
    }

    private func toggleRecording() {
        if audioRecorder.isRecording {
            audioPath = audioRecorder.stop()
            return
        }

        do {
            let destination = try appStore.makeMediaFileURL(fileExtension: "m4a")
            try audioRecorder.start(url: destination)
        } catch {
            appStore.errorMessage = error.localizedDescription
        }
    }

    private func hideKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }
}

private struct AttachmentSummary: View {
    let imageCount: Int
    let hasAudio: Bool

    var body: some View {
        HStack(spacing: 12) {
            if imageCount > 0 {
                Label("\(imageCount) image\(imageCount == 1 ? "" : "s")", systemImage: "photo")
            }

            if hasAudio {
                Label("Audio recorded", systemImage: "waveform")
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(BrainTheme.mutedText)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct DeckPickerView: View {
    @Environment(BrainAppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss
    @Binding var newDeckName: String

    private var normalizedNewDeckName: String {
        BrainAppStore.normalizedDeckName(newDeckName)
    }

    private var canCreateDeck: Bool {
        newDeckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        appStore.decks.contains { $0.localizedCaseInsensitiveCompare(normalizedNewDeckName) == .orderedSame } == false
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("New Deck")
                        .font(.headline)
                        .foregroundStyle(BrainTheme.mutedText)

                    HStack(spacing: 10) {
                        TextField("Deck name", text: $newDeckName)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(BrainTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            appStore.selectedDeckName = normalizedNewDeckName
                            newDeckName = ""
                            dismiss()
                        } label: {
                            Image(systemName: "plus")
                                .font(.headline)
                                .frame(width: 42, height: 42)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canCreateDeck)
                    }
                }

                List(appStore.decks, id: \.self) { deckName in
                    Button {
                        appStore.selectedDeckName = deckName
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: appStore.selectedDeckName == deckName ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(appStore.selectedDeckName == deckName ? BrainTheme.accent : BrainTheme.mutedText)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(deckName)
                                    .font(.headline)
                                Text(deckSummary(for: deckName))
                                    .font(.caption)
                                    .foregroundStyle(BrainTheme.mutedText)
                            }

                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(BrainTheme.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .padding()
            .brainDarkScreen()
            .navigationTitle("Choose Deck")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetentsIfAvailable()
    }

    private func deckSummary(for deckName: String) -> String {
        let cardCount = appStore.cards(in: deckName).count
        let dueCount = appStore.dueCards(in: deckName).count
        return "\(cardCount) cards · \(dueCount) due"
    }
}

private struct ComposerToolButton: View {
    let systemImage: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ComposerToolButtonLabel(systemImage: systemImage, title: title)
        }
        .buttonStyle(.plain)
        .foregroundStyle(BrainTheme.mutedText)
    }
}

private struct ComposerToolButtonLabel: View {
    let systemImage: String
    let title: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.title2.weight(.semibold))
            .frame(width: 58, height: 58)
            .background(Color.white.opacity(0.07))
            .clipShape(Circle())
            .contentShape(Circle())
            .help(title)
            .accessibilityLabel(title)
    }
}

@Observable
private final class CardAudioRecorder: NSObject, AVAudioRecorderDelegate {
    var isRecording = false
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    func start(url: URL) throws {
#if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)
#endif

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.record()
        self.recorder = recorder
        recordingURL = url
        isRecording = true
    }

    func stop() -> String? {
        recorder?.stop()
        recorder = nil
        isRecording = false
        return recordingURL?.path
    }

    func cancel() {
        recorder?.stop()
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recorder = nil
        recordingURL = nil
        isRecording = false
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        isRecording = false
    }
}

private extension View {
    @ViewBuilder
    func presentationDetentsIfAvailable() -> some View {
#if os(iOS)
        self.presentationDetents([.medium, .large])
#else
        self.frame(minWidth: 360, minHeight: 520)
#endif
    }
}
