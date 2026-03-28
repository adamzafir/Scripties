import Foundation

final class PracticeSessionRepository {
    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("practiceSessions.json")
    }

    func load() -> [PracticeSession] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([PracticeSession].self, from: data)) ?? []
    }

    func save(_ sessions: [PracticeSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    func append(_ session: PracticeSession) {
        var existing = load()
        existing.insert(session, at: 0)
        save(existing)
    }
}
