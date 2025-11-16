import SwiftUI

enum Tabs: Hashable {
    case scripts
    case settings
    case add
}

struct TabHolder: View {
    @State private var selectedTab: Tabs = .scripts
    @StateObject private var viewModel = Screen2ViewModel()
    var body: some View {
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
    }
}

#Preview {
    TabHolder()
}
