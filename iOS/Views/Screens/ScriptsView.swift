import SwiftUI

struct Screen1: View {
    @ObservedObject var viewModel: Screen2ViewModel
    // @AppStorage("betashit") private var isBeta: Bool = false // COMMENTED OUT: beta flag not used
    @State private var selectedID: ScriptItem.ID? = nil
    @State private var pastReviewsTarget: ScriptItem.ID? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    if viewModel.scriptItems.isEmpty {
                        ContentUnavailableView {
                            Label("No Scripts", systemImage: "list.bullet")
                        } description: {
                            Text("Select 'New Script' to add a new script")
                        }
                       
                    } else {
                        Form {
                            ForEach($viewModel.scriptItems) { $item in
                                NavigationLink(tag: item.id, selection: $selectedID) {
                                    // Always show the main editor; beta/keywords disabled
                                    Screen22(scriptItemID: item.id, title: $item.title, script: $item.scriptText)
                                        .onAppear { viewModel.markAccessed(id: item.id) }
                                } label: {
                                    Text(item.title)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        pastReviewsTarget = item.id
                                    } label: {
                                        Label("Past Reviews", systemImage: "clock.arrow.circlepath")
                                    }
                                    .tint(.sec)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        if let idx = viewModel.scriptItems.firstIndex(where: { $0.id == item.id }) {
                                            deleteItems(at: IndexSet(integer: idx))
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .background(
                                    NavigationLink(
                                        "",
                                        destination: PastReviewsView(scriptID: item.id)
                                            .environmentObject(viewModel),
                                        isActive: Binding(
                                            get: { pastReviewsTarget == item.id },
                                            set: { active in
                                                pastReviewsTarget = active ? item.id : nil
                                            }
                                        )
                                    )
                                    .hidden()
                                )
                            }
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
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding()
                                .background(
                                    Capsule()
                                        .fill(Color.pri)
                                )
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

    private func deleteItems(at index: Int) {
        guard index < viewModel.scriptItems.count else { return }
        viewModel.scriptItems.remove(at: index)
    }
}
