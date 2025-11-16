import Foundation
import SwiftUI
import Combine

struct ScriptItem: Identifiable {
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

    func addNewScriptAtFront(title: String? = nil, scriptText: String = "Type something...") {
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
}
