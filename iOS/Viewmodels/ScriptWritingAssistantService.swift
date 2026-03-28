import Foundation
import FoundationModels

@Generable
struct CueSuggestionPayload {
    @Guide(description: "Suggested speaking cues tied to specific short phrases from the script.")
    var cues: [CueSuggestionItem]
}

@Generable
struct CueSuggestionItem {
    @Guide(description: "One of: emphasis, pause, slowDown, speedUp, smile")
    var kind: String
    @Guide(description: "Exact short phrase from the script to attach the cue to.")
    var phrase: String
    @Guide(description: "Why this cue helps delivery.")
    var rationale: String
}

enum ScriptWritingAssistantService {
    static func rewrite(script: String, prompt: String) async throws -> String {
        let session = LanguageModelSession()
        let response = try await session.respond(to: """
        Rewrite this speech script using the following instructions:
        \(prompt)

        Reply with only the rewritten script text.

        Original script:
        \(script)
        """)
        return response.content
    }

    static func generateOutline(from script: String) async throws -> String {
        let session = LanguageModelSession()
        let response = try await session.respond(to: """
        Convert the following speech script into a clean speaking outline.
        Keep it concise.
        Use short bullet points.
        Reply only with the outline.

        Script:
        \(script)
        """)
        return response.content
    }

    static func generateCoachComment(from script: String) async throws -> String {
        let session = LanguageModelSession()
        let response = try await session.respond(to: """
        Read the following speech script and give one focused coach comment.
        The comment should improve delivery, structure, or clarity.
        Reply with only the comment.

        Script:
        \(script)
        """)
        return response.content
    }

    static func suggestCues(from script: String) async throws -> [DerivedCue] {
        let session = LanguageModelSession()
        let response = try await session.respond(
            to: """
            Suggest delivery cues for this speech script.
            Use only phrases that already appear in the script.
            Return a mix of emphasis, pause, slowDown, speedUp, and smile when appropriate.
            Keep phrases short.
            
            Script:
            \(script)
            """,
            generating: CueSuggestionPayload.self
        )

        return response.content.cues.compactMap { item in
            guard let kind = AnnotationKind(rawValue: item.kind.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return nil
            }
            let phrase = item.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !phrase.isEmpty else { return nil }
            return DerivedCue(
                kind: kind,
                phrase: phrase,
                rationale: item.rationale.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }
}
