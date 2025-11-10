import SwiftUI

struct Screen1: View {
    @StateObject private var viewModel = Screen2ViewModel()

    var body: some View {
        NavigationStack {
            Form {
                ForEach($viewModel.scriptItems) { $item in
                    NavigationLink {
                        Screen2(title: $item.title, script: $item.scriptText)
                    } label: {
                        Text(item.title)
                    }
                }
                .onDelete(perform: deleteItems) // ← swipe-to-delete
            }
            .navigationTitle("Scripts")
           
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        viewModel.scriptItems.remove(atOffsets: offsets)
    }
}



#Preview {
    Screen1()
}

