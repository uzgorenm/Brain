import BrainCore
import SwiftUI

struct EditCardView: View {
    @Environment(BrainAppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss

    let card: KnowledgeCard
    @State private var title: String
    @State private var bodyText: String
    @State private var deckName: String

    init(card: KnowledgeCard) {
        self.card = card
        _title = State(initialValue: card.title)
        _bodyText = State(initialValue: card.body)
        _deckName = State(initialValue: card.deckName)
    }

    private var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Card") {
                    TextField("Question", text: $title, axis: .vertical)
                        .lineLimit(2...6)

                    TextField("Answer", text: $bodyText, axis: .vertical)
                        .lineLimit(4...12)
                }

                Section("Deck") {
                    TextField("Deck name", text: $deckName)
                }
            }
            .brainDarkScreen()
            .navigationTitle("Edit Card")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if appStore.updateCard(card, title: title, body: bodyText, deckName: deckName) {
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
        .frame(minWidth: 320, minHeight: 420)
#if os(iOS)
        .presentationDetents([.medium, .large])
#endif
    }
}
