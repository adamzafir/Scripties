import Foundation
import SwiftUI
import Combine

struct ScriptItem: Identifiable, Codable {
    var id: UUID
    var title: String
    var scriptText: String
}

class Screen2ViewModel: ObservableObject {
    @Published var scriptItems: [ScriptItem] = [
        ScriptItem(
            id: UUID(),
            title: "Demo Script",
            scriptText: "Progress begins when people unite with purpose. By listening carefully, acting responsibly, and supporting one another, we create space for real improvement. Let us commit to steady effort and shared accountability so each choice we make builds a stronger tomorrow."
        )
    ]
    
    private var untitledCount: Int = 0
    private var cancellables = Set<AnyCancellable>()
    private let fileURL: URL

    init() {
        // Decide on file location in Documents directory
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("scripts.json")
        
        // Load from disk if available
        load()
        
        // Autosave on any changes
        $scriptItems
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
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

        let newItem = ScriptItem(id: UUID(), title: finalTitle, scriptText: scriptText)
        scriptItems.insert(newItem, at: 0)
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
            let decoded = try JSONDecoder().decode([ScriptItem].self, from: data)
            self.scriptItems = decoded
            // Recompute untitledCount based on existing items
            let untitledBase = "Untitled Script"
            let maxSuffix = decoded.compactMap { item -> Int? in
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

