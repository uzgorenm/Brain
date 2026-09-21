import AVFoundation
import BrainCore
import Observation
import PhotosUI
import SwiftUI

struct CreateCardTabView: View {
    @Environment(BrainAppStore.self) private var appStore
    @State private var title = ""
    @State private var bodyText = ""
    @State private var shortTitle: String? = nil
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

    @Environment(\.dismiss) private var dismiss
    @State private var showingDiscard = false
    @State private var isImporting = false
    @State private var isRequestingAudio = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    BrainSurface {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Question").font(.headline)
                            TextField("What do you want to remember?", text: $title, axis: .vertical)
                                .lineLimit(2...8).accessibilityLabel("Card question")
                            Divider()
                            Text("Answer").font(.headline)
                            TextField("Write the answer in your own words", text: $bodyText, axis: .vertical)
                                .lineLimit(4...12).accessibilityLabel("Card answer")
                        }
                    }
                    Button { showingDeckPicker = true } label: {
                        HStack {
                            Text("Deck")
                            Spacer()
                            Text(appStore.selectedDeckName).foregroundStyle(BrainTheme.mutedText)
                            Image(systemName: "chevron.right")
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)

                    DisclosureGroup("Generate from notes with AI") {
                        VStack(alignment: .leading, spacing: 14) {
                            TextField("Paste your source notes", text: $detailedInformation, axis: .vertical)
                                .lineLimit(4...10).disabled(isGenerating)
                            Text("Generation replaces the question and answer above. Review them before saving.")
                                .font(.footnote).foregroundStyle(BrainTheme.mutedText)
                            Button(action: generateFlashcard) {
                                HStack {
                                    if isGenerating { ProgressView() }
                                    Text(isGenerating ? "Generating…" : "Generate card")
                                }
                            }
                            .buttonStyle(.bordered).controlSize(.large)
                            .disabled(!canGenerate || !appStore.isLocalAIReady)
                            if !appStore.isLocalAIReady {
                                Text("Download the optional AI model in Settings to generate cards.")
                                    .font(.footnote).foregroundStyle(BrainTheme.mutedText)
                            }
                        }
                        .padding(.top, 16)
                    }
                    .padding(18).background(BrainTheme.surface, in: RoundedRectangle(cornerRadius: BrainTheme.cornerRadius))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Attachments").font(.headline)
                        ViewThatFits {
                            HStack(spacing: 16) { attachmentButtons }
                            VStack(alignment: .leading) { attachmentButtons }
                        }
                        if imagePaths.isEmpty == false || audioPath != nil {
                            AttachmentSummary(imageCount: imagePaths.count, hasAudio: audioPath != nil)
                        }
                        if isImporting { ProgressView("Adding photos…") }
                        Text("Attached audio stays with this card. Use Capture for a transcribed note.")
                            .font(.footnote).foregroundStyle(BrainTheme.mutedText)
                    }
                    if saveConfirmation {
                        Label("Card saved", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                .padding(BrainTheme.pagePadding)
                .frame(maxWidth: BrainTheme.readableWidth).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .brainScreen()
            .platformNavigationBarStyle()
            .navigationTitle("New card")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if !title.isEmpty || !bodyText.isEmpty || !detailedInformation.isEmpty || !imagePaths.isEmpty || audioPath != nil || audioRecorder.isRecording {
                            showingDiscard = true
                        } else { dismiss() }
                    }
                    .disabled(isGenerating || isImporting || isRequestingAudio)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save card") {
                        guard appStore.createCard(title: title, body: bodyText, deckName: appStore.selectedDeckName,
                                                  imagePaths: imagePaths, audioPath: audioPath, shortTitle: shortTitle) else { return }
                        audioRecorder.keepRecording()
                        resetComposer()
                        hideKeyboard()
                        saveConfirmation = true
                        dismiss()
                    }
                    .disabled(!canSave || isGenerating || isImporting || isRequestingAudio || audioRecorder.isRecording)
                    .keyboardShortcut("s", modifiers: .command)
                }
            }
            .interactiveDismissDisabled(!title.isEmpty || !bodyText.isEmpty || !detailedInformation.isEmpty || !imagePaths.isEmpty || audioPath != nil || audioRecorder.isRecording)
            .confirmationDialog("Discard this card?", isPresented: $showingDiscard, titleVisibility: .visible) {
                Button("Discard card", role: .destructive) {
                    for path in imagePaths { try? FileManager.default.removeItem(atPath: path) }
                    resetComposer()
                    dismiss()
                }
            }
            .sheet(isPresented: $showingDeckPicker) { DeckPickerView(newDeckName: $newDeckName) }
            .task(id: selectedPhotoItems) { await importSelectedPhotos() }
        }
    }

    @ViewBuilder private var attachmentButtons: some View {
        PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 4, matching: .images) {
            Label("Add photos", systemImage: "photo")
        }
        .buttonStyle(.bordered).controlSize(.large).disabled(isImporting)
        Button { toggleRecording() } label: {
            Label(audioRecorder.isRecording ? "Stop audio" : "Record audio", systemImage: audioRecorder.isRecording ? "stop.fill" : "mic")
        }
        .buttonStyle(.bordered).controlSize(.large)
        .disabled(isRequestingAudio || (audioPath != nil && !audioRecorder.isRecording))
    }

    private func generateFlashcard() {
        guard canGenerate else { return }
        isGenerating = true
        Task {
            defer { isGenerating = false }
            do {
                let (generatedTitle, generatedBody, generatedShortTitle) = try await BrainCore.LLMManager.shared.generateFlashcard(from: detailedInformation)
                await MainActor.run {
                    self.title = generatedTitle
                    self.bodyText = generatedBody
                    self.shortTitle = generatedShortTitle
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
        detailedInformation = ""
        title = ""
        bodyText = ""
        shortTitle = nil
        imagePaths = []
        audioPath = nil
        selectedPhotoItems = []
        newDeckName = ""
        audioRecorder.cancel()
    }

    private func importSelectedPhotos() async {
        guard selectedPhotoItems.isEmpty == false else { return }

        isImporting = true
        defer { isImporting = false }
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

        guard !isRequestingAudio else { return }
        isRequestingAudio = true
        Task {
            defer { isRequestingAudio = false }
#if os(iOS)
            let allowed = await AVAudioApplication.requestRecordPermission()
#else
            let allowed = await AVCaptureDevice.requestAccess(for: .audio)
#endif
            guard allowed else {
                appStore.errorMessage = "Microphone access is off. Allow it in system Settings to record audio."
                return
            }
            do {
                let destination = try appStore.makeMediaFileURL(fileExtension: "m4a")
                try audioRecorder.start(url: destination)
            } catch { appStore.errorMessage = error.localizedDescription }
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
            .brainScreen()
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
            .background(BrainTheme.subtleFill)
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
        guard recorder.record() else { throw NSError(domain: "BrainAudio", code: 1, userInfo: [NSLocalizedDescriptionKey: "Couldn’t start the microphone. Check microphone access in Settings and try again."]) }
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

    func keepRecording() {
        recordingURL = nil
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
