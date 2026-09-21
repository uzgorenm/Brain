import AVFoundation
import BrainCore
import Observation
import Speech
import SwiftUI

@MainActor @Observable
final class CaptureSession: NSObject, AVAudioRecorderDelegate {
    enum Phase { case idle, requestingPermission, recording, transcribing }
    var draft = NoteDraft()
    var phase: Phase = .idle
    var errorMessage: String?
    var needsSettings = false
    var startedAt: Date?
    var isEditing = false
    private var recorder: AVAudioRecorder?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var timeout: Task<Void, Never>?
    private var recognitionID = UUID()
    private var interruptionObserver: NSObjectProtocol?

    private var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Brain/Capture", isDirectory: true)
    }
    private var storage: CaptureDraftStorage { CaptureDraftStorage(directory: directory) }
    var audioURL: URL? { draft.audioFilename.map { directory.appendingPathComponent($0) } }
    var isBusy: Bool { phase != .idle }

    override init() {
        super.init()
        do {
            draft = try storage.load()
            isEditing = draft.hasContent
            if draft.audioFilename != nil && !draft.transcriptComplete {
                errorMessage = "Your recording is safe. Tap Retry transcription to finish your note."
            }
        } catch {
            errorMessage = "Couldn't restore your draft: \(error.localizedDescription)"
        }
#if os(iOS)
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let session = self else { return }
            Task { @MainActor in
                guard session.phase == .recording else { return }
                session.stopRecording()
            }
        }
#endif
    }

    func persist() {
        do { try persistDraft() }
        catch { errorMessage = "Couldn't keep your draft on this device. Keep this screen open and try saving again. \(error.localizedDescription)" }
    }

    private func persistDraft() throws {
        try storage.save(draft)
    }

    func startRecording() async {
        guard phase == .idle, draft.audioFilename == nil else { return }
        phase = .requestingPermission
        errorMessage = nil
        needsSettings = false
#if os(iOS)
        let allowed = await AVAudioApplication.requestRecordPermission()
#else
        let allowed = await AVCaptureDevice.requestAccess(for: .audio)
#endif
        guard allowed else {
            needsSettings = true
            phase = .idle
            errorMessage = "Microphone access is off. Allow it in Settings to record, or write your note below."
            isEditing = true
            return
        }
        do {
#if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
#endif
            draft.audioFilename = "\(draft.id.uuidString).m4a"
            draft.transcriptComplete = false
            try persistDraft()
            guard let audioURL else { throw CaptureError.recordingFailed }
            let recorder = try AVAudioRecorder(url: audioURL, settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ])
            recorder.delegate = self
            guard recorder.record(forDuration: 300) else { throw CaptureError.recordingFailed }
            self.recorder = recorder
            startedAt = Date()
            phase = .recording
            isEditing = true
        } catch {
            draft.audioFilename = nil
            phase = .idle
            deactivateAudio()
            errorMessage = "Couldn't start recording. \(error.localizedDescription) You can still write your note."
            persist()
        }
    }

    func stopRecording() {
        guard phase == .recording else { return }
        recorder?.stop()
        recorder = nil
        phase = .idle
        deactivateAudio()
        persist()
        transcribe()
    }

    func transcribe() {
        guard phase == .idle, let audioURL else { return }
        phase = .transcribing
        errorMessage = nil
        needsSettings = false
        let attempt = UUID()
        recognitionID = attempt
        Task {
            let authorization = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
            guard recognitionID == attempt else { return }
            guard authorization == .authorized else {
                needsSettings = true
                failTranscription("Speech recognition is off. Allow it in Settings, then retry. Your recording is still on this device.")
                return
            }
            guard let recognizer = SFSpeechRecognizer(locale: .current), recognizer.supportsOnDeviceRecognition else {
                failTranscription("On-device transcription isn't available for this device or language. Your recording is safe. You can listen and type the note below, then choose Use this text.")
                return
            }
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = false
            request.addsPunctuation = true
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let transcript = result?.isFinal == true ? result?.bestTranscription.formattedString : nil
                let failure = error?.localizedDescription
                Task { @MainActor in
                    guard let self, self.recognitionID == attempt, self.phase == .transcribing else { return }
                    if let transcript, !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.draft.body += (self.draft.body.isEmpty ? "" : "\n\n") + transcript
                        self.draft.transcriptComplete = true
                        self.finishTranscription()
                        self.persist()
                    } else if failure != nil || result?.isFinal == true {
                        self.failTranscription("Couldn't transcribe this recording. Retry, or listen and type your note below. Your audio is safe.")
                    }
                }
            }
            timeout = Task { [weak self] in
                try? await Task.sleep(for: .seconds(120))
                guard !Task.isCancelled, let self, self.recognitionID == attempt else { return }
                self.failTranscription("Transcription took too long. Your recording is safe; try again.")
            }
        }
    }

    func cancelTranscription() {
        failTranscription("Transcription paused. Your recording is safe; retry whenever you're ready.")
    }

    private func finishTranscription() {
        recognitionID = UUID()
        timeout?.cancel()
        timeout = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        phase = .idle
    }

    private func failTranscription(_ message: String) {
        finishTranscription()
        errorMessage = message
    }

    func clearDraft() throws {
        guard !isBusy else { return }
        try storage.remove(draft)
        draft = NoteDraft()
        isEditing = false
        errorMessage = nil
        needsSettings = false
        startedAt = nil
    }

    private func deactivateAudio() {
#if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
#endif
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            guard phase == .recording else { return }
            self.recorder = nil
            phase = .idle
            deactivateAudio()
            persist()
            if flag { transcribe() }
            else { errorMessage = "Recording stopped unexpectedly. Your audio is saved; retry transcription." }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            guard phase == .recording else { return }
            stopRecording()
        }
    }
}

private enum CaptureError: LocalizedError {
    case recordingFailed
    var errorDescription: String? { "The microphone couldn't start. Try again." }
}
