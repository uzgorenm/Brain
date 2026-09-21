import SwiftUI

enum BrainTheme {
    static let pagePadding: CGFloat = 20
    static let cornerRadius: CGFloat = 16
    static let readableWidth: CGFloat = 720
    static let background = Color(red: 0.96, green: 0.95, blue: 0.92)
    static let surface = Color(red: 0.995, green: 0.99, blue: 0.975)
    static let elevatedSurface = Color(red: 0.91, green: 0.90, blue: 0.86)
    static let accent = Color(red: 0.16, green: 0.34, blue: 0.29)
    static let mutedText = Color(red: 0.35, green: 0.38, blue: 0.36)
    static let border = Color(red: 0.80, green: 0.79, blue: 0.74)
    static let subtleFill = Color(red: 0.88, green: 0.87, blue: 0.82)
    static let mastered = Color(red: 0.20, green: 0.43, blue: 0.35)
    static let learning = Color(red: 0.66, green: 0.42, blue: 0.20)
    static let unseen = Color(red: 0.45, green: 0.47, blue: 0.44)
}

extension View {
    func brainScreen() -> some View {
        self
            .background(BrainTheme.background)
            .scrollContentBackground(.hidden)
            .preferredColorScheme(.light)
    }

    @ViewBuilder
    func platformNavigationBarStyle() -> some View {
#if os(iOS)
        self
            .toolbar(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(BrainTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
#else
        self
#endif
    }

    @ViewBuilder
    func platformTabBarStyle() -> some View {
#if os(iOS)
        self
            .toolbarBackground(BrainTheme.surface, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarColorScheme(.light, for: .tabBar)
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
            .clipShape(RoundedRectangle(cornerRadius: BrainTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: BrainTheme.cornerRadius)
                    .stroke(BrainTheme.border)
            )
    }
}

struct BrainInlineMessage: View {
    let message: String
    let systemImage: String

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(BrainTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: BrainTheme.cornerRadius))
            .accessibilityElement(children: .combine)
    }
}
