import SwiftUI

struct Screen1: View {
    @ObservedObject var viewModel: Screen2ViewModel
    @AppStorage("betashit") private var isBeta: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                Group {
                    if viewModel.scriptItems.isEmpty {
                        // Empty state centered
                        VStack(spacing: 8) {
                            Text("No Scripts")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Tap “Add Script” to create your first script.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Show scripts in a Form
                        Form {
                            ForEach($viewModel.scriptItems) { $item in
                                NavigationLink {
                                    if isBeta {
                                        Screen2(title: $item.title, script: $item.scriptText)
                                    } else {
                                        Screen22(title: $item.title, script: $item.scriptText)
                                    }
                                } label: {
                                    Text(item.title)
                                }
                            }
                            .onDelete(perform: deleteItems)
                        }
                    }
                }
                
                // Keep the floating Add Script button where it was
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
