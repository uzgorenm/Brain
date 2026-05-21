import SwiftUI

enum BrainTheme {
    static let background = Color.black
    static let surface = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let elevatedSurface = Color(red: 0.14, green: 0.14, blue: 0.15)
    static let accent = Color(red: 0.08, green: 0.55, blue: 1.0)
    static let mutedText = Color(red: 0.58, green: 0.58, blue: 0.62)
    static let mastered = Color(red: 0.62, green: 0.76, blue: 1.0)
    static let learning = Color(red: 1.0, green: 0.68, blue: 0.50)
    static let unseen = Color(red: 0.56, green: 0.60, blue: 0.66)
}

extension View {
    func brainDarkScreen() -> some View {
        self
            .background(BrainTheme.background)
            .scrollContentBackground(.hidden)
            .preferredColorScheme(.dark)
    }

    @ViewBuilder
    func platformNavigationBarStyle() -> some View {
#if os(iOS)
        self
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
#else
        self
#endif
    }

    @ViewBuilder
    func platformHiddenNavigationBar() -> some View {
#if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
#else
        self
#endif
    }
}

struct BrainSurface<Content: View>: View {
    let padding: CGFloat
    @ViewBuilder let content: Content

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(BrainTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.08))
            )
    }
}
