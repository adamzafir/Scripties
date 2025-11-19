import Foundation
import SwiftUI
import Combine

struct ScriptItem: Identifiable, Codable {
    var id: UUID
    var title: String
    var scriptText: String
    var lastAccessed: Date

    // Backward-compatible init if needed elsewhere
    init(id: UUID = UUID(), title: String, scriptText: String, lastAccessed: Date = Date()) {
        self.id = id
        self.title = title
        self.scriptText = scriptText
        self.lastAccessed = lastAccessed
    }
}

class Screen2ViewModel: ObservableObject {
    @Published var scriptItems: [ScriptItem] = [
        ScriptItem(
            id: UUID(),
            title: "Demo Script",
            scriptText: "Progress begins when people unite with purpose. By listening carefully, acting responsibly, and supporting one another, we create space for real improvement. Let us commit to steady effort and shared accountability so each choice we make builds a stronger tomorrow.",
            lastAccessed: Date()
        )
    ]
    
    private var untitledCount: Int = 0
    private var cancellables = Set<AnyCancellable>()
    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("scripts.json")
        
        load()
        sortByRecency()
        
        $scriptItems
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.sortByRecency()
                self?.save()
            }
            .store(in: &cancellables)
    }

    func addNewScriptAtFront(title: String? = nil, scriptText: String = "") {
        let providedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle: String
        if let t = providedTitle, !t.isEmpty {
            finalTitle = t
        } else {
            if untitledCount == 0 {
                finalTitle = "Untitled Script"
            } else {
                finalTitle = "Untitled Script \(untitledCount + 1)"
            }
            untitledCount += 1
        }

        let newItem = ScriptItem(
            id: UUID(),
            title: finalTitle,
            scriptText: scriptText,
            lastAccessed: Date()
        )
        scriptItems.insert(newItem, at: 0)
        sortByRecency()
        save()
    }
    
    func markAccessed(id: UUID) {
        guard let idx = scriptItems.firstIndex(where: { $0.id == id }) else { return }
        scriptItems[idx].lastAccessed = Date()
        sortByRecency()
        save()
    }
    
    func updateScript(id: UUID, title: String? = nil, scriptText: String? = nil) {
        guard let idx = scriptItems.firstIndex(where: { $0.id == id }) else { return }
        if let title { scriptItems[idx].title = title }
        if let scriptText { scriptItems[idx].scriptText = scriptText }
        scriptItems[idx].lastAccessed = Date()
        sortByRecency()
        save()
    }
    
    private func sortByRecency() {
        scriptItems.sort { $0.lastAccessed > $1.lastAccessed }
    }
    
    // MARK: - Persistence
    
    func save() {
        do {
            let data = try JSONEncoder().encode(scriptItems)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("Failed to save scripts: \(error.localizedDescription)")
        }
    }
    
    func load() {
        do {
            let fm = FileManager.default
            guard fm.fileExists(atPath: fileURL.path) else { return }
            let data = try Data(contentsOf: fileURL)
            // Try decoding with lastAccessed. If it fails (older file), migrate.
            if let decoded = try? JSONDecoder().decode([ScriptItem].self, from: data) {
                self.scriptItems = decoded
            } else {
                // Migration path: older JSON without lastAccessed
                struct OldScriptItem: Identifiable, Codable {
                    var id: UUID
                    var title: String
                    var scriptText: String
                }
                let old = try JSONDecoder().decode([OldScriptItem].self, from: data)
                self.scriptItems = old.map { ScriptItem(id: $0.id, title: $0.title, scriptText: $0.scriptText, lastAccessed: Date.distantPast) }
                save() // write new schema
            }
            sortByRecency()
            // Recompute untitledCount
            let untitledBase = "Untitled Script"
            let maxSuffix = scriptItems.compactMap { item -> Int? in
                if item.title == untitledBase { return 1 }
                if item.title.hasPrefix(untitledBase + " ") {
                    let suffix = item.title.dropFirst((untitledBase + " ").count)
                    return Int(suffix)
                }
                return nil
            }.max() ?? 0
            self.untitledCount = max(0, maxSuffix)
        } catch {
            print("Failed to load scripts: \(error.localizedDescription)")
        }
    }
}
