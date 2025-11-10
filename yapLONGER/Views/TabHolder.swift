import SwiftUI


enum Tabs {
    case scripts
    case settings
    case add
}

struct TabHolder: View {
    @State private var selectedTab: Tabs = .scripts
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Scripts", systemImage: "swirl.circle.righthalf.filled", value: Tabs.scripts) {
                Screen1()
            }
            
            Tab("Settings", systemImage: "gear", value: Tabs.settings) {
                Settings()
            }
            
            Tab("Add", systemImage: "plus", value: Tabs.add, role: .search) {
                Text("Hi")
            }
        }}}
            
            
#Preview {
    TabHolder()
}
