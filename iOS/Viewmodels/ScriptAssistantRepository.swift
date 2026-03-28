import Foundation

struct ScriptAssistantState: Codable, Hashable {
    var annotations: [ScriptAnnotation]
    var derivedCues: [DerivedCue]
    var generatedOutline: String
    var coachComment: String

    static let empty = ScriptAssistantState(
        annotations: [],
        derivedCues: [],
        generatedOutline: "",
        coachComment: ""
    )
}

final class ScriptAssistantRepository {
    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("scriptAssistantState.json")
    }

    func load(scriptID: UUID) -> ScriptAssistantState {
        guard
            let data = try? Data(contentsOf: fileURL),
            let stateMap = try? JSONDecoder().decode([UUID: ScriptAssistantState].self, from: data)
        else {
            return .empty
        }
        return stateMap[scriptID] ?? .empty
    }

    func save(_ state: ScriptAssistantState, for scriptID: UUID) {
        var stateMap: [UUID: ScriptAssistantState] = [:]
        if
            let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode([UUID: ScriptAssistantState].self, from: data) {
            stateMap = decoded
        }
        stateMap[scriptID] = state
        guard let data = try? JSONEncoder().encode(stateMap) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
