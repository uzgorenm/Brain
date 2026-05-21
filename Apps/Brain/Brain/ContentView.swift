import BrainCore
import SwiftUI

struct ContentView: View {
    @Environment(BrainAppStore.self) private var appStore
    @State private var selectedTab: BrainTab = .due

    var body: some View {
        TabView(selection: $selectedTab) {
            DueFlashcardsView()
                .tabItem {
                    Label("Cards", systemImage: "rectangle.stack.fill")
                }
                .tag(BrainTab.due)

            CreateCardTabView()
                .tabItem {
                    Label("Create", systemImage: "plus")
                }
                .tag(BrainTab.create)

            GraphTabView()
                .tabItem {
                    Label("Graph", systemImage: "chart.bar.xaxis")
                }
                .tag(BrainTab.graph)

            ProgressTabView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar.fill")
                }
                .tag(BrainTab.progress)
            
            QuestionTabView()
                .tabItem {
                    Label("Ask AI", systemImage: "sparkles.rectangle.stack")
                }
                .tag(BrainTab.question)
                
            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(BrainTab.settings)
        }
        .tint(BrainTheme.accent)
        .preferredColorScheme(.dark)
        .alert("Brain Error", isPresented: errorBinding) {
            Button("OK") {
                appStore.errorMessage = nil
            }
        } message: {
            Text(appStore.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { appStore.errorMessage != nil },
            set: { if $0 == false { appStore.errorMessage = nil } }
        )
    }
}

private enum BrainTab {
    case due
    case create
    case graph
    case progress
    case question
    case settings
}

#Preview {
    ContentView()
        .environment(BrainAppStore())
}
