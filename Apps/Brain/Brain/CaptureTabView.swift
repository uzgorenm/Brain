import AVFoundation
import BrainCore
import SwiftUI

struct CaptureTabView: View {
    @Environment(BrainAppStore.self) private var appStore
    @Environment(CaptureSession.self) private var capture
    @Environment(BrainNavigation.self) private var navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var savedNote: KnowledgeCard?
    @State private var showingDiscard = false
    @State private var showingRewrite = false
    @State private var isSaving = false
    @State private var audioPlayer: AVAudioPlayer?
    @FocusState private var bodyFocused: Bool

    var body: some View {
        @Bindable var capture = capture
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        capturePage
                            .containerRelativeFrame(.vertical)
                            .id("capture")
                        latestNotesPage
                            .containerRelativeFrame(.vertical, alignment: .top)
                            .id("latest")
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .scrollTargetBehavior(.paging)
                .onChange(of: navigation.recordRequested) { _, requested in
                    guard requested else { return }
                    proxy.scrollTo("capture", anchor: .top)
                    handleRecordingRequest()
                }
                .onChange(of: navigation.writeRequested) { _, requested in
                    guard requested else { return }
                    navigation.writeRequested = false
                    capture.isEditing = true
                    proxy.scrollTo("capture", anchor: .top)
                    bodyFocused = true
                }
            }
            .brainScreen()
            .platformHiddenNavigationBar()
            .onAppear {
                handleRecordingRequest()
                if navigation.writeRequested {
                    navigation.writeRequested = false
                    capture.isEditing = true
                    bodyFocused = true
                }
            }
            .onChange(of: capture.draft) { _, _ in capture.persist() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background, capture.phase == .recording { capture.stopRecording() }
            }
            .onDisappear { audioPlayer?.stop() }
            .confirmationDialog("Discard this draft?", isPresented: $showingDiscard, titleVisibility: .visible) {
                Button("Discard draft and recording", role: .destructive) {
                    audioPlayer?.stop()
                    do { try capture.clearDraft() }
                    catch { capture.errorMessage = "Couldn't remove your draft. \(error.localizedDescription)" }
                }
            } message: { Text("This removes the unsaved text and its recording from this device.") }
            .sheet(isPresented: $showingRewrite) {
                NoteRewritePreviewView(
                    title: capture.draft.title,
                    originalText: capture.draft.body
                ) { suggestion in
                    capture.draft.body = suggestion
                    capture.errorMessage = nil
                }
            }
        }
    }

    private var capturePage: some View {
        VStack(spacing: 24) {
            captureArea

            if let savedNote {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Note saved").font(.headline)
                        Text(savedNote.title).font(.subheadline).lineLimit(2)
                    }
                    Spacer()
                    NavigationLink("Open") { NoteDetailView(card: savedNote) }
                        .frame(minHeight: 44)
                }
                .padding(16)
                .background(BrainTheme.surface, in: RoundedRectangle(cornerRadius: BrainTheme.cornerRadius))
                .accessibilityElement(children: .contain)
            }

            Spacer(minLength: 20)

            Image(systemName: "chevron.compact.down")
                .font(.title2.weight(.semibold))
                .foregroundStyle(BrainTheme.mutedText.opacity(0.65))
                .accessibilityLabel("More content below")
        }
        .padding(.horizontal, BrainTheme.pagePadding)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: BrainTheme.readableWidth)
        .frame(maxWidth: .infinity)
        .background(BrainTheme.background)
    }

    private var latestNotesPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            latestNotes
            Spacer(minLength: 0)
        }
        .padding(.horizontal, BrainTheme.pagePadding)
        .padding(.top, 120)
        .padding(.bottom, 28)
        .frame(maxWidth: BrainTheme.readableWidth)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(BrainTheme.background)
    }

    private var captureArea: some View {
        @Bindable var capture = capture
        return VStack(spacing: 24) {
            if !capture.isEditing && !capture.isBusy && !dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    Text("What's on your mind?").font(.title2.weight(.semibold))
                    Text("Give your next idea a place to stay.")
                        .font(.body).foregroundStyle(BrainTheme.mutedText)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 36)
            }

            VStack(spacing: 16) {
                Button {
                    savedNote = nil
                    if capture.phase == .recording { capture.stopRecording() }
                    else { Task { await capture.startRecording() } }
                } label: {
                    VStack(spacing: 16) {
                        Image(systemName: capture.phase == .recording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(capture.phase == .recording ? .white : BrainTheme.accent)
                            .frame(width: 100, height: 100)
                            .background(capture.phase == .recording ? Color.red.opacity(0.8) : BrainTheme.accent.opacity(0.12), in: Circle())
                            .overlay(Circle().stroke(BrainTheme.accent.opacity(0.18), lineWidth: 1))
                        Text(recordLabel).font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(capture.phase == .requestingPermission || capture.phase == .transcribing || (capture.audioURL != nil && capture.phase != .recording))
                .accessibilityLabel(recordLabel)
                .accessibilityHint("Record a thought, then review its transcript before saving.")

                if capture.phase == .recording, let startedAt = capture.startedAt {
                    HStack {
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Text(startedAt, style: .timer).monospacedDigit().fixedSize()
                        Text("of 5 minutes").foregroundStyle(BrainTheme.mutedText)
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .combine)
                } else if capture.phase == .transcribing {
                    HStack { ProgressView(); Text("Transcribing on this device…") }.font(.subheadline)
                    Button("Cancel transcription") { capture.cancelTranscription() }.frame(minHeight: 44)
                } else {
                    Text(capture.draft.transcriptComplete ? "Review your transcript before saving." : "Audio stays here until your note is saved.")
                        .font(.footnote).foregroundStyle(BrainTheme.mutedText)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, capture.isEditing ? 8 : 20)

            if let message = capture.errorMessage {
                BrainInlineMessage(message: message, systemImage: "exclamationmark.circle")
#if os(iOS)
                if capture.needsSettings, let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open system settings", destination: settingsURL).frame(minHeight: 44)
                }
#endif
                if capture.audioURL != nil && !capture.isBusy && !capture.draft.transcriptComplete {
                    ViewThatFits {
                        HStack { recoveryButtons }
                        VStack { recoveryButtons }
                    }
                }
            }

            if capture.isEditing {
                VStack(alignment: .leading, spacing: 16) {
                    Text(capture.draft.transcriptComplete ? "Your transcript" : "Your note").font(.headline)
                    TextField("Title (optional)", text: $capture.draft.title, axis: .vertical)
                        .font(.headline).accessibilityLabel("Note title, optional")
                    Divider()
                    TextField("Let the thought out…", text: $capture.draft.body, axis: .vertical)
                        .lineLimit(5...20).focused($bodyFocused)
                        .accessibilityLabel("Note text")
                    Divider()
                    NoteRewriteButton(
                        isEnabled: !capture.draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        bodyFocused = false
                        showingRewrite = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(20)
                .background(BrainTheme.surface, in: RoundedRectangle(cornerRadius: BrainTheme.cornerRadius))
                .disabled(capture.isBusy || isSaving)

                if capture.audioURL != nil, !capture.draft.transcriptComplete, !capture.isBusy,
                   !capture.draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("Use this text as the transcript") {
                        capture.draft.transcriptComplete = true
                        capture.errorMessage = nil
                    }
                    .frame(minHeight: 44)
                }
                HStack(spacing: 16) {
                    Button("Discard", role: .destructive) { showingDiscard = true }
                        .frame(minHeight: 44).disabled(capture.isBusy || isSaving)
                    Spacer()
                    Button { save() } label: {
                        Label(isSaving ? "Saving…" : "Save note", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(!capture.draft.canSave || capture.isBusy || isSaving)
                    .keyboardShortcut("s", modifiers: .command)
                }
            } else {
                Button {
                    savedNote = nil
                    capture.isEditing = true
                    bodyFocused = true
                } label: { Label("Write a note", systemImage: "square.and.pencil") }
                    .buttonStyle(.bordered).controlSize(.large)
                Text("Transcribed on device. Audio removed after saving.")
                    .font(.caption).foregroundStyle(BrainTheme.mutedText).multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder private var recoveryButtons: some View {
        Button("Retry transcription") { audioPlayer?.stop(); capture.transcribe() }
            .buttonStyle(.borderedProminent).controlSize(.large)
        Button("Listen to recording") {
            guard let url = capture.audioURL else { return }
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.play()
            } catch { capture.errorMessage = "Couldn't play this recording. \(error.localizedDescription)" }
        }
        .buttonStyle(.bordered).controlSize(.large)
    }

    private var recordLabel: String {
        switch capture.phase {
        case .recording: "Stop recording"
        case .requestingPermission: "Waiting for microphone…"
        case .transcribing: "Recording complete"
        case .idle: capture.audioURL == nil ? "Record a thought" : "Recording captured"
        }
    }

    private var latestNotes: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Latest notes").font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                Spacer()
                Button("See all") { navigation.tab = .notes }.frame(minHeight: 44)
            }
            if appStore.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your ideas start here").font(.headline)
                    Text("Record or write a thought. You'll find it here when you want to come back to it.")
                        .foregroundStyle(BrainTheme.mutedText)
                }
                .padding(.vertical, 20)
            } else {
                ForEach(appStore.notes.prefix(5)) { card in
                    NavigationLink { NoteDetailView(card: card) } label: { NoteRow(card: card) }
                        .buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }

    private func save() {
        guard !isSaving, capture.draft.canSave, !capture.isBusy else { return }
        isSaving = true
        defer { isSaving = false }
        audioPlayer?.stop()
        do {
            savedNote = try appStore.saveNote(capture.draft)
            bodyFocused = false
            do { try capture.clearDraft() }
            catch { capture.errorMessage = "Your note is saved, but its temporary audio couldn't be removed. Tap Save note to retry cleanup." }
        } catch { capture.errorMessage = "Couldn't save your note. Your draft is still here. \(error.localizedDescription)" }
    }

    private func handleRecordingRequest() {
        guard navigation.recordRequested else { return }
        navigation.recordRequested = false
        guard !capture.draft.hasContent, !capture.isBusy else {
            capture.isEditing = true
            return
        }
        Task { await capture.startRecording() }
    }
}
