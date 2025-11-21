import SwiftUI

struct Screen1: View {
    @ObservedObject var viewModel: Screen2ViewModel
    // @AppStorage("betashit") private var isBeta: Bool = false // COMMENTED OUT: beta flag not used
    @State private var selectedID: ScriptItem.ID? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    if viewModel.scriptItems.isEmpty {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "list.bullet")
                                Text("No Scripts")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Select “Add Script” to create your first script.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Form {
                            ForEach($viewModel.scriptItems) { $item in
                                NavigationLink(tag: item.id, selection: $selectedID) {
                                    // Always show the main editor; beta/keywords disabled
                                    Screen22(title: $item.title, script: $item.scriptText)
                                        .onAppear { viewModel.markAccessed(id: item.id) }
                                } label: {
                                    Text(item.title)
                                }
                            }
                            .onDelete(perform: deleteItems)
                        }
                    }
                }
                
                VStack {
                    Spacer()
                    Button {
                        viewModel.addNewScriptAtFront()
                        selectedID = viewModel.scriptItems.first?.id
                    } label: {
                        VStack {
                            Text("New Script")
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
