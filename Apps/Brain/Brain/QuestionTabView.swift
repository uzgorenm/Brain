import BrainCore
import SwiftUI

struct QuestionTabView: View {
    @Environment(BrainAppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss
    @State private var question = ""
    @State private var answer: String?
    @State private var isAsking = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Ask about your saved notes.")
                        .foregroundStyle(BrainTheme.mutedText)
                    if !appStore.isLocalAIReady {
                        BrainInlineMessage(message: "Download the optional AI model in Settings to ask questions. Your notes stay on this device.", systemImage: "arrow.down.circle")
                    }
                    if appStore.notes.isEmpty {
                        BrainInlineMessage(message: "Save a note first so there's something to ask about.", systemImage: "note.text")
                    }
                    BrainSurface {
                        TextField("What would you like to know?", text: $question, axis: .vertical)
                            .lineLimit(3...10).disabled(isAsking).accessibilityLabel("Question about your notes")
                    }
                    Button(action: askQuestion) {
                        HStack {
                            if isAsking { ProgressView() }
                            Text(isAsking ? "Thinking…" : "Ask AI")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAsking || appStore.notes.isEmpty || !appStore.isLocalAIReady)
                    if let error { BrainInlineMessage(message: error, systemImage: "exclamationmark.circle") }
                    if let answer {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Answer").font(.headline)
                            Text(answer).textSelection(.enabled)
                            Text("AI can make mistakes. Check details against your original notes.")
                                .font(.footnote).foregroundStyle(BrainTheme.mutedText)
                        }
                    }
                }
                .padding(BrainTheme.pagePadding)
                .frame(maxWidth: BrainTheme.readableWidth).frame(maxWidth: .infinity)
            }
            .brainScreen().platformNavigationBarStyle()
            .navigationTitle("Ask AI")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func askQuestion() {
        guard !isAsking else { return }
        isAsking = true
        error = nil
        let currentQuestion = question
        let context = appStore.notes.map { "Title: \($0.title)\nContent: \($0.body)" }
        Task {
            defer { isAsking = false }
            do { answer = try await LLMManager.shared.answerQuestion(question: currentQuestion, context: context) }
            catch { self.error = "Couldn't get an answer. Your question is still here; try again. \(error.localizedDescription)" }
        }
    }
}
