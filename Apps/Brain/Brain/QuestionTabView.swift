import BrainCore
import SwiftUI

struct QuestionTabView: View {
    @Environment(BrainAppStore.self) private var appStore
    @State private var question = ""
    @State private var answer: String?
    @State private var isAsking = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Ask AI")
                        .font(.largeTitle.bold())
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(BrainTheme.surface)
                
                Divider()
                    .overlay(Color.white.opacity(0.08))
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            // "Current Deck" label removed since AI uses all flashcards globally
                            VStack(spacing: 0) {
                                TextField("Ask a question about your flashcards...", text: $question, axis: .vertical)
                                    .font(.title3)
                                    .lineLimit(4...8)
                                    .padding(18)
                                    .disabled(isAsking)
                                
                                Divider()
                                    .overlay(Color.white.opacity(0.10))
                                
                                Button(action: askQuestion) {
                                    HStack {
                                        if isAsking {
                                            ProgressView()
                                                .controlSize(.small)
                                                .tint(BrainTheme.accent)
                                        } else {
                                            Image(systemName: "paperplane.fill")
                                        }
                                        Text(isAsking ? "Thinking..." : "Ask AI")
                                            .font(.headline)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(!question.isEmpty && !isAsking ? BrainTheme.accent.opacity(0.15) : Color.clear)
                                    .foregroundStyle(!question.isEmpty && !isAsking ? BrainTheme.accent : BrainTheme.mutedText)
                                }
                                .buttonStyle(.plain)
                                .disabled(question.isEmpty || isAsking)
                            }
                            .background(BrainTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.16))
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        if let answer = answer {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("AI Answer")
                                    .font(.headline)
                                    .foregroundStyle(BrainTheme.accent)
                                
                                Text(answer)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(20)
                            .background(BrainTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.16))
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 24)
                }
            }
            .brainDarkScreen()
            .platformNavigationBarStyle()
            .platformHiddenNavigationBar()
        }
    }
    
    private func askQuestion() {
        let currentQuestion = question
        // Use ALL flashcards in the app for context, regardless of the selected deck
        let deckCards = appStore.cards
        let context = deckCards.map { "Q: \($0.title)\nA: \($0.body)" }
        
        Task {
            isAsking = true
            defer { isAsking = false }
            
            if context.isEmpty {
                await MainActor.run {
                    self.answer = "You haven't created any flashcards yet! Please create some flashcards so I have knowledge to pull from."
                }
                return
            }
            
            do {
                let generatedAnswer = try await BrainCore.LLMManager.shared.answerQuestion(question: currentQuestion, context: context)
                await MainActor.run {
                    self.answer = generatedAnswer
                }
            } catch {
                await MainActor.run {
                    appStore.errorMessage = "AI Request failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
