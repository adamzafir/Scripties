import SwiftUI

struct Screen1: View {
    @ObservedObject var viewModel: Screen2ViewModel
    @AppStorage("betashit") private var isBeta: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    Form {
                        ForEach($viewModel.scriptItems) { $item in
                            NavigationLink {
                                if isBeta {
                                    // Navigate to Screen 2.5 when beta is enabled
                                    Screen2_5(title: $item.title, script: $item.scriptText)
                                } else {
                                    // Navigate to Screen 2 when beta is disabled
                                    Screen2(title: $item.title, script: $item.scriptText)
                                }
                            } label: {
                                Text(item.title)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
                VStack {
                    Spacer()
                    Button {
                        viewModel.addNewScriptAtFront()
                    } label: {
                        VStack {
                            Text("Add Script")
                                .frame(maxWidth: .infinity)
                                .font(.headline)
                                .padding(.horizontal, 16)
                                .padding()
                                .glassEffect()
                        }
                        .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Scripts")
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        viewModel.scriptItems.remove(atOffsets: offsets)
    }
}

