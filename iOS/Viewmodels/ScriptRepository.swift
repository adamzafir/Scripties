import Foundation

final class ScriptRepository {
    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("scripts.json")
    }

    func save(_ items: [ScriptItem]) throws {
        let data = try JSONEncoder().encode(items)
        try data.write(to: fileURL, options: [.atomic])
    }

    func load() throws -> [ScriptItem] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        if let decoded = try? JSONDecoder().decode([ScriptItem].self, from: data) {
            return decoded
        }

        struct OldScriptItem: Identifiable, Codable {
            var id: UUID
            var title: String
            var scriptText: String
        }

        let old = try JSONDecoder().decode([OldScriptItem].self, from: data)
        return old.map {
            ScriptItem(
                id: $0.id,
                title: $0.title,
                scriptText: $0.scriptText,
                lastAccessed: Date.distantPast
            )
        }
    }
}
