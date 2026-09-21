import BrainCore
import SwiftUI

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(CaptureSession.self) private var capture
    @Environment(BrainAppStore.self) private var appStore
    @Environment(BrainNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.tab) {
            CaptureTabView()
                .tabItem { Label("Capture", systemImage: "mic") }
                .tag(BrainNavigation.Tab.capture)
            NotesTabView()
                .tabItem { Label("Notes", systemImage: "note.text") }
                .tag(BrainNavigation.Tab.notes)
            FlashcardsTabView()
                .tabItem { Label("Cards", systemImage: "rectangle.stack") }
                .tag(BrainNavigation.Tab.cards)
            SettingsTabView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(BrainNavigation.Tab.settings)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if capture.phase == .recording && navigation.tab != .capture {
                HStack {
                    Label("Recording in progress", systemImage: "waveform").font(.subheadline)
                    Spacer()
                    Button("Stop recording") {
                        navigation.tab = .capture
                        capture.stopRecording()
                    }
                    .frame(minHeight: 44)
                }
                .padding(.horizontal, 16)
                .background(BrainTheme.surface)
            }
        }
        .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
        .tint(BrainTheme.accent)
        .platformTabBarStyle()
        .preferredColorScheme(.light)
        .alert("Couldn't finish that action", isPresented: errorBinding) {
            Button("OK") { appStore.errorMessage = nil }
        } message: { Text(appStore.errorMessage ?? "") }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { appStore.errorMessage != nil }, set: { if !$0 { appStore.errorMessage = nil } })
    }
}

#Preview {
    ContentView()
        .environment(BrainAppStore())
        .environment(CaptureSession())
        .environment(BrainNavigation.shared)
}
