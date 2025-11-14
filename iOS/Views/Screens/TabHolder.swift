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
        
        #if os(macOS)
        NavigationSplitView {

            List(selection: $selectedTab) {
                Label("Scripts", systemImage: "text.document")
                    .tag(Tabs.scripts)

                Label("Settings", systemImage: "gear")
                    .tag(Tabs.settings)

                Label("Add", systemImage: "plus")
                    .tag(Tabs.add)
            }
            .navigationTitle("Sections")

        } detail: {
            switch selectedTab {
            case .scripts:
                NavigationStack {
                    Screen1(viewModel: viewModel)
                        .navigationTitle("Scripts")
                }

            case .settings:
                NavigationStack {
                    Settings()
                        .navigationTitle("Settings")
                }

            case .add:
                Color.clear
                    .onAppear {
                        let newItem = ScriptItem(
                            id: UUID(),
                            title: "Untitled Script",
                            scriptText: "Type something..."
                        )
                        viewModel.scriptItems.append(newItem)
                        selectedTab = .scripts
                    }
            }
        }

        #else
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

            Tab("Add", systemImage: "plus", value: Tabs.add, role: .search) {
                Color.clear
                    .onAppear {
                        let newItem = ScriptItem(
                            id: UUID(),
                            title: "Untitled Script",
                            scriptText: "Type something..."
                        )
                        viewModel.scriptItems.append(newItem)
                        selectedTab = .scripts
                    }
            }
        }
        .navigationBarBackButtonHidden(true)
        #endif
    }
}

#Preview {
    TabHolder()
}
