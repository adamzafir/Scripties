import Foundation

final class TeleprompterAlignmentEngine {
    private let debounceWindow: TimeInterval = 0.32
    private let driftResetThreshold = 0.08

    private(set) var state: LineAlignmentState = .initial

    private var lines: [RenderedScriptLine] = []
    private var candidateAdvanceTimestamp: TimeInterval?
    private var candidateTargetLine: Int?
    private var lastTranscriptTokens: [String] = []

    func configure(lines: [RenderedScriptLine]) {
        self.lines = lines
        self.state = .initial
        self.candidateAdvanceTimestamp = nil
        self.candidateTargetLine = nil
        self.lastTranscriptTokens = []
    }

    func processTranscript(_ transcript: String, at timestamp: TimeInterval) {
        guard !lines.isEmpty else { return }
        let tokens = ScriptRenderService.normalizeTokens(transcript)
        guard !tokens.isEmpty else { return }
        if tokens == lastTranscriptTokens {
            state.repeatedLineDetections += 1
        }
        lastTranscriptTokens = tokens

        let currentIndex = min(max(state.activeLineIndex, 0), lines.count - 1)
        let currentEvidence = evidence(for: tokens, in: lines[currentIndex].normalizedTokens)
        let nextEvidence = currentIndex + 1 < lines.count
            ? evidence(for: tokens, in: lines[currentIndex + 1].normalizedTokens)
            : .empty

        let currentScore = currentEvidence.score
        let nextScore = nextEvidence.score

        state.currentScore = currentScore
        state.nextScore = nextScore
        state.snapshots.append(
            LineAlignmentSnapshot(
                timestamp: timestamp,
                activeLineIndex: currentIndex,
                currentScore: currentScore,
                nextScore: nextScore,
                driftState: driftState(for: currentScore, nextScore: nextScore)
            )
        )

        let currentCompleted = currentEvidence.canAdvanceCurrentLine
        let nextCompleted = nextEvidence.canAutoAdvanceToNextLine

        if currentCompleted {
            state.completedLines.insert(currentIndex)
        } else if currentEvidence.hasAnchorWord || currentEvidence.hasEndingEvidence {
            state.partialLines.insert(currentIndex)
        }

        state.scoreHistory.append(
            LineMatchRecord(
                lineIndex: currentIndex,
                score: currentScore,
                isCompleted: currentCompleted,
                isSkipped: false,
                timestamp: timestamp
            )
        )

        if currentIndex + 1 < lines.count {
            if nextCompleted || nextEvidence.meaningfulMatchCount > 0 {
                state.partialLines.insert(currentIndex + 1)
            }
            state.scoreHistory.append(
                LineMatchRecord(
                    lineIndex: currentIndex + 1,
                    score: nextScore,
                    isCompleted: nextCompleted,
                    isSkipped: false,
                    timestamp: timestamp
                )
            )
        }

        let drift = driftState(for: currentScore, nextScore: nextScore)
        state.driftState = drift
        if drift == .drifting {
            candidateAdvanceTimestamp = nil
            candidateTargetLine = nil
            return
        }

        let targetLine = decideTargetLine(
            currentIndex: currentIndex,
            currentEvidence: currentEvidence,
            nextEvidence: nextEvidence
        )
        guard let targetLine else {
            candidateAdvanceTimestamp = nil
            candidateTargetLine = nil
            return
        }

        if candidateTargetLine != targetLine {
            candidateTargetLine = targetLine
            candidateAdvanceTimestamp = timestamp
            return
        }

        guard let started = candidateAdvanceTimestamp, timestamp - started >= debounceWindow else {
            return
        }

        advance(
            to: targetLine,
            timestamp: timestamp,
            score: targetLine == currentIndex + 1 ? currentScore : nextScore
        )
        candidateAdvanceTimestamp = nil
        candidateTargetLine = nil
    }

    private func driftState(for currentScore: Double, nextScore: Double) -> AlignmentDriftState {
        if currentScore < driftResetThreshold && nextScore < driftResetThreshold {
            return .drifting
        }
        if nextScore > currentScore && nextScore >= 0.5 {
            return .recovering
        }
        return .aligned
    }

    private func decideTargetLine(
        currentIndex: Int,
        currentEvidence: LineEvidence,
        nextEvidence: LineEvidence
    ) -> Int? {
        if currentEvidence.canAdvanceCurrentLine {
            return min(currentIndex + 1, lines.count - 1)
        }
        if nextEvidence.canAutoAdvanceToNextLine {
            return min(currentIndex + 1, lines.count - 1)
        }
        return nil
    }

    private func advance(to newLineIndex: Int, timestamp: TimeInterval, score: Double) {
        let boundedTarget = min(max(newLineIndex, 0), lines.count - 1)
        let previous = state.activeLineIndex
        guard boundedTarget > previous else { return }

        let skipped = boundedTarget > previous + 1 ? Array((previous + 1)..<boundedTarget) : []
        skipped.forEach { state.skippedLines.insert($0) }
        state.transitions.append(
            LineTransitionRecord(
                fromLineIndex: previous,
                toLineIndex: boundedTarget,
                timestamp: timestamp,
                score: score,
                skippedLines: skipped
            )
        )
        state.activeLineIndex = boundedTarget
    }

    private func evidence(for transcriptTokens: [String], in lineTokens: [String]) -> LineEvidence {
        guard !transcriptTokens.isEmpty, !lineTokens.isEmpty else { return .empty }

        let transcriptWindow = Array(transcriptTokens.suffix(max(8, lineTokens.count + 3)))
        let transcriptSet = Set(transcriptWindow)
        let meaningfulLineTokens = lineTokens.filter { isMeaningful($0) }
        let meaningfulMatches = meaningfulLineTokens.filter { transcriptSet.contains($0) }
        let tailTokens = Array(meaningfulLineTokens.suffix(min(2, meaningfulLineTokens.count)))
        let endingMatchCount = tailTokens.filter { transcriptSet.contains($0) }.count
        let lastMeaningfulWord = tailTokens.last
        let lastWordMatched = lastMeaningfulWord.map(transcriptSet.contains) ?? false
        let hasAnchorWord = !meaningfulMatches.isEmpty
        let hasEndingEvidence = endingMatchCount > 0

        let lineLength = max(meaningfulLineTokens.count, 1)
        let anchorRatio = Double(meaningfulMatches.count) / Double(lineLength)
        let endingRatio = Double(endingMatchCount) / Double(max(tailTokens.count, 1))
        let score = min(1, anchorRatio * 0.55 + endingRatio * 0.45)

        let canAdvanceCurrentLine = hasAnchorWord && (lastWordMatched || endingMatchCount >= 1)
        let canAutoAdvanceToNextLine =
            meaningfulMatches.count >= 2 ||
            (meaningfulMatches.count == 1 && lastWordMatched)

        return LineEvidence(
            score: score,
            meaningfulMatchCount: meaningfulMatches.count,
            hasAnchorWord: hasAnchorWord,
            hasEndingEvidence: hasEndingEvidence,
            lastWordMatched: lastWordMatched,
            canAdvanceCurrentLine: canAdvanceCurrentLine,
            canAutoAdvanceToNextLine: canAutoAdvanceToNextLine
        )
    }

    private func isMeaningful(_ token: String) -> Bool {
        token.count > 2
    }
}

private struct LineEvidence {
    let score: Double
    let meaningfulMatchCount: Int
    let hasAnchorWord: Bool
    let hasEndingEvidence: Bool
    let lastWordMatched: Bool
    let canAdvanceCurrentLine: Bool
    let canAutoAdvanceToNextLine: Bool

    static let empty = LineEvidence(
        score: 0,
        meaningfulMatchCount: 0,
        hasAnchorWord: false,
        hasEndingEvidence: false,
        lastWordMatched: false,
        canAdvanceCurrentLine: false,
        canAutoAdvanceToNextLine: false
    )
}
