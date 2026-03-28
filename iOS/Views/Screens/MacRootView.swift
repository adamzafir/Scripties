#if os(macOS)
import SwiftUI
import Combine

@MainActor
final class MacSessionState: ObservableObject {
    @Published var isSessionActive: Bool = false
}

struct MacRootView: View {
    @EnvironmentObject private var recordingStore: RecordingStore
    @EnvironmentObject private var scriptsViewModel: Screen2ViewModel
    @StateObject private var sessionState = MacSessionState()
    @State private var selection: ScriptItem.ID?
    @State private var pastReviewsTarget: ScriptItem.ID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var lastUnlockedVisibility: NavigationSplitViewVisibility = .all

    private var isSidebarLocked: Bool {
        sessionState.isSessionActive || recordingStore.isRecording
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detailContent
        }
        .environmentObject(sessionState)
        .onAppear {
            lastUnlockedVisibility = columnVisibility
            ensureSelection()
        }
        .onChange(of: scriptsViewModel.scriptItems.map(\.id)) { _, _ in
              ensureSelection()
          }
        .onChange(of: selection) { _, newValue in
            if let id = newValue {
                scriptsViewModel.markAccessed(id: id)
            }
        }
        .onChange(of: isSidebarLocked) { _, locked in
            if locked {
                lastUnlockedVisibility = columnVisibility
                columnVisibility = .detailOnly
            } else {
                columnVisibility = lastUnlockedVisibility
            }
        }
        .onChange(of: columnVisibility) { _, newValue in
            if isSidebarLocked && newValue != .detailOnly {
                columnVisibility = .detailOnly
            } else if !isSidebarLocked {
                lastUnlockedVisibility = newValue
            }
        }
        .sheet(isPresented: pastReviewsPresented) {
            if let target = pastReviewsTarget {
                NavigationStack {
                    PastReviewsView(scriptID: target)
                }
                .environmentObject(scriptsViewModel)
            }
        }
    }

    private var pastReviewsPresented: Binding<Bool> {
        Binding(
            get: { pastReviewsTarget != nil },
            set: { if !$0 { pastReviewsTarget = nil } }
        )
    }

    @ViewBuilder
    private var sidebar: some View {
        List(selection: $selection) {
            ForEach(scriptsViewModel.scriptItems) { item in
                ScriptRow(
                    item: item,
                    onPastReviews: { pastReviewsTarget = item.id },
                    onDelete: { deleteScript(id: item.id) }
                )
                .tag(item.id)
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addNewScript()
                } label: {
                    Label("New Script", systemImage: "plus")
                }
                .disabled(isSidebarLocked)
            }
        }
    }

    private struct ScriptRow: View {
        let item: ScriptItem
        let onPastReviews: () -> Void
        let onDelete: () -> Void

        var body: some View {
            HStack(spacing: 8) {
                Text(item.title.isEmpty ? "Untitled Script" : item.title)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Menu {
                    Button(action: onPastReviews) {
                        Label("Past Reviews", systemImage: "clock.arrow.circlepath")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if scriptsViewModel.scriptItems.isEmpty {
            VStack(spacing: 16) {
                ContentUnavailableView {
                    Label("No Scripts", systemImage: "list.bullet")
                } description: {
                    Text("Select 'New Script' to add a new script")
                }

                Button {
                    addNewScript()
                } label: {
                    Label("New Script", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSidebarLocked)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let selection, let itemBinding = binding(for: selection) {
            Screen22(
                scriptItemID: itemBinding.wrappedValue.id,
                title: itemBinding.title,
                script: itemBinding.scriptText
            )
        } else {
            ContentUnavailableView {
                Label("No Script Selected", systemImage: "text.document")
            } description: {
                Text("Choose a script from the sidebar.")
            }
        }
    }

    private func binding(for id: ScriptItem.ID) -> Binding<ScriptItem>? {
        guard let index = scriptsViewModel.scriptItems.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        return $scriptsViewModel.scriptItems[index]
    }

    private func ensureSelection() {
        guard !scriptsViewModel.scriptItems.isEmpty else {
            selection = nil
            return
        }
        if let selection, scriptsViewModel.scriptItems.contains(where: { $0.id == selection }) {
            return
        }
        selection = scriptsViewModel.scriptItems.first?.id
    }

    private func addNewScript() {
        scriptsViewModel.addNewScriptAtFront()
        selection = scriptsViewModel.scriptItems.first?.id
    }

    private func deleteScript(id: ScriptItem.ID) {
        guard let index = scriptsViewModel.scriptItems.firstIndex(where: { $0.id == id }) else {
            return
        }
        scriptsViewModel.scriptItems.remove(at: index)
    }
}
#endif
