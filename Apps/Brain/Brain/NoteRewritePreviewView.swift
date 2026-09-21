import BrainCore
import SwiftUI

struct NoteRewritePreviewView: View {
    @Environment(BrainAppStore.self) private var appStore
    @Environment(BrainNavigation.self) private var navigation
    @Environment(\.dismiss) private var dismiss

    let title: String
    let originalText: String
    let onUse: (String) -> Void

    @State private var suggestion = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?

    init(
        title: String,
        originalText: String,
        onUse: @escaping (String) -> Void
    ) {
        self.title = title
        self.originalText = originalText
        self.onUse = onUse
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !appStore.isLocalAIReady {
                        BrainInlineMessage(
                            message: "Download the local model in Settings to rewrite notes. Your note stays on this device.",
                            systemImage: "arrow.down.circle"
                        )
                        Button("Open Settings") {
                            dismiss()
                            navigation.tab = .settings
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else if isGenerating {
                        BrainSurface {
                            HStack(spacing: 12) {
                                ProgressView()
                                Text("Rewriting on this device…")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else if let errorMessage {
                        BrainInlineMessage(message: errorMessage, systemImage: "exclamationmark.circle")
                        Button("Try again") {
                            Task { await generate() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    } else if !suggestion.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Suggested version")
                                .font(.headline)
                            TextEditor(text: $suggestion)
                                .scrollContentBackground(.hidden)
                                .padding(12)
                                .frame(minHeight: 220)
                                .background(BrainTheme.surface, in: RoundedRectangle(cornerRadius: BrainTheme.cornerRadius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: BrainTheme.cornerRadius)
                                        .stroke(BrainTheme.border)
                                )
                                .accessibilityLabel("Suggested note text")
                            Text("You can edit the suggestion before using it.")
                                .font(.footnote)
                                .foregroundStyle(BrainTheme.mutedText)
                        }
                    }

                    DisclosureGroup("Original note") {
                        Text(originalText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 10)
                            .textSelection(.enabled)
                    }
                    .padding(16)
                    .background(BrainTheme.surface, in: RoundedRectangle(cornerRadius: BrainTheme.cornerRadius))

                    Text("The local model can make mistakes. Check names, dates, and other details before using the suggestion.")
                        .font(.footnote)
                        .foregroundStyle(BrainTheme.mutedText)
                }
                .padding(BrainTheme.pagePadding)
                .frame(maxWidth: BrainTheme.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .brainScreen()
            .platformNavigationBarStyle()
            .navigationTitle("Rewrite note")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use this version") {
                        onUse(suggestion.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(suggestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                }
            }
            .task(id: appStore.isLocalAIReady) {
                guard appStore.isLocalAIReady else { return }
                await generate()
            }
        }
    }

    private func generate() async {
        guard appStore.isLocalAIReady else { return }
        isGenerating = true
        suggestion = ""
        errorMessage = nil
        defer { isGenerating = false }

        do {
            let result = try await LLMManager.shared.rewriteNote(
                title: title,
                body: originalText
            )
            guard !Task.isCancelled else { return }
            suggestion = result
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "Brain couldn't finish this version. \(error.localizedDescription)"
        }
    }
}

struct NoteRewriteButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button("Rewrite for clarity", systemImage: "pencil.line", action: action)
            .disabled(!isEnabled)
    }
}
