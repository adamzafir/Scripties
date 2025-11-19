import SwiftUI

enum Tabs: Hashable {
    case scripts
    case settings
    case add
}

struct TabHolder: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var selectedTab: Tabs = .scripts
    @StateObject private var viewModel = Screen2ViewModel()
    var body: some View {
        Group {
            if hasCompletedOnboarding {
                TabView(selection: $selectedTab) {
                    Tab("Scripts", systemImage: "text.document", value: Tabs.scripts) {
                        NavigationStack {
                            Screen1(viewModel: viewModel)
                                .navigationTitle("Scripts")
                        }
                    }
                    
                    Tab("Settings", systemImage: "gear", value: Tabs.settings) {
                        NavigationStack {
                            Settings()
                                .navigationTitle("Settings")
                        }
                    }
                }
                .navigationBarBackButtonHidden(true)
            } else {
                OnboardingView()
            }
        }
    }
}
#Preview{
    TabHolder()
}
