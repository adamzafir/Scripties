import AVFoundation
import Accelerate
import Foundation

enum AudioAnalysisService {
    static func analyze(
        recordingURL: URL?,
        transcript: String,
        lineAlignment: LineAlignmentState,
        renderedLines: [RenderedScriptLine],
        elapsedTime: TimeInterval,
        wordCount: Int,
        silenceDurations: [TimeInterval]
    ) -> DeliveryAnalysis {
        let transcriptTokens = ScriptRenderService.normalizeTokens(transcript, droppingFillers: false)
        let wordsPerMinute = elapsedTime > 0
            ? Int(round(Double(max(wordCount, transcriptTokens.count)) / (elapsedTime / 60)))
            : 0
        let pauseAnalysis = makePauseAnalysis(
            silenceDurations: silenceDurations,
            elapsedTime: elapsedTime
        )
        let adherence = makeAdherenceAnalysis(
            lineAlignment: lineAlignment,
            totalLines: renderedLines.count
        )

        let signal = loadSignal(from: recordingURL)
        let windows = makeProsodyWindows(signal: signal)
        let smoothedWindows = smooth(windows: windows)
        let pitch = makePitchAnalysis(windows: smoothedWindows)
        let energy = makeEnergyAnalysis(windows: smoothedWindows)
        let pace = makePaceAnalysis(
            wordsPerMinute: wordsPerMinute,
            transitions: lineAlignment.transitions,
            renderedLines: renderedLines
        )

        let consistency = max(
            0,
            min(
                100,
                (pitch.pitchVariationScore * 0.2) +
                ((100 - pitch.monotonyRiskScore) * 0.15) +
                (energy.energyVariationScore * 0.2) +
                (pace.paceStabilityScore * 0.2) +
                (pauseAnalysis.pauseControlScore * 0.1) +
                (adherence.scriptAdherenceScore * 0.15)
            )
        )

        let summary = makeSummary(
            pitch: pitch,
            energy: energy,
            pace: pace,
            pauses: pauseAnalysis,
            adherence: adherence
        )

        return DeliveryAnalysis(
            pace: pace,
            pauses: pauseAnalysis,
            pitch: pitch,
            energy: energy,
            adherence: adherence,
            deliveryConsistencyScore: consistency,
            summary: summary,
            confidenceByMetric: [
                "pitch": pitch.confidence,
                "energy": energy.confidence,
                "pace": pace.confidence,
                "pauses": pauseAnalysis.confidence,
                "adherence": adherence.confidence
            ]
        )
    }

    private static func loadSignal(from url: URL?) -> (samples: [Float], sampleRate: Double)? {
        guard let url else { return nil }
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: 1, interleaved: false) else {
            return nil
        }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
            return nil
        }
        do {
            try file.read(into: buffer)
        } catch {
            return nil
        }

        guard let channelData = buffer.floatChannelData?.pointee else { return nil }
        let count = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: count))
        return (samples, format.sampleRate)
    }

    private static func makeProsodyWindows(signal: (samples: [Float], sampleRate: Double)?) -> [ProsodyWindow] {
        guard let signal, !signal.samples.isEmpty else { return [] }
        let sampleRate = signal.sampleRate
        let frameSize = max(1024, Int(sampleRate * 0.04))
        let hopSize = max(512, Int(sampleRate * 0.02))
        let minLag = Int(sampleRate / 320)
        let maxLag = max(minLag + 1, Int(sampleRate / 75))

        var windows: [ProsodyWindow] = []
        var start = 0
        while start + frameSize < signal.samples.count {
            let frame = Array(signal.samples[start..<(start + frameSize)])
            let rms = rootMeanSquare(frame)
            let zeroCrossingRate = zeroCrossings(frame)
            let pitchEstimate = estimatePitch(frame, sampleRate: sampleRate, minLag: minLag, maxLag: maxLag)
            let voiced = rms > 0.008 && zeroCrossingRate < 0.22 && pitchEstimate.pitch != nil
            let voicedRatio = voiced ? 1.0 : 0.0
            windows.append(
                ProsodyWindow(
                    startTime: Double(start) / sampleRate,
                    endTime: Double(start + frameSize) / sampleRate,
                    voicedRatio: voicedRatio,
                    rmsEnergy: Double(rms),
                    pitchHz: voiced ? pitchEstimate.pitch : nil,
                    pitchConfidence: voiced ? pitchEstimate.confidence : 0
                )
            )
            start += hopSize
        }
        return windows
    }

    private static func smooth(windows: [ProsodyWindow]) -> [ProsodyWindow] {
        guard windows.count > 2 else { return windows }
        return windows.enumerated().map { index, window in
            let neighbors = windows[max(0, index - 1)...min(windows.count - 1, index + 1)]
            let pitches = neighbors.compactMap(\.pitchHz)
            let energies = neighbors.map(\.rmsEnergy)
            let smoothedPitch = pitches.isEmpty ? nil : pitches.reduce(0, +) / Double(pitches.count)
            let smoothedEnergy = energies.reduce(0, +) / Double(energies.count)
            let confidence = neighbors.map(\.pitchConfidence).reduce(0, +) / Double(neighbors.count)
            return ProsodyWindow(
                startTime: window.startTime,
                endTime: window.endTime,
                voicedRatio: neighbors.map(\.voicedRatio).reduce(0, +) / Double(neighbors.count),
                rmsEnergy: smoothedEnergy,
                pitchHz: smoothedPitch,
                pitchConfidence: confidence
            )
        }
    }

    private static func makePauseAnalysis(
        silenceDurations: [TimeInterval],
        elapsedTime: TimeInterval
    ) -> PauseAnalysis {
        let totalSilence = silenceDurations.reduce(0, +)
        let meanPause = silenceDurations.isEmpty ? 0 : totalSilence / Double(silenceDurations.count)
        let largestGap = silenceDurations.max() ?? 0
        let silentRatio = elapsedTime > 0 ? totalSilence / elapsedTime : 0
        let pauseVariance = varianceOfTimeIntervals(silenceDurations)
        let irregularPenalty = min(40.0, pauseVariance * 25)
        let longPausePenalty = max(0, (largestGap - 1.2) * 18)
        let score = max(0, 100 - irregularPenalty - longPausePenalty)
        let confidence = AnalysisConfidence(silenceDurations.isEmpty ? 0.5 : 0.9)
        return PauseAnalysis(
            silenceDurations: silenceDurations,
            largestGapBetweenWords: largestGap,
            silentTimeRatio: silentRatio,
            meanPauseDuration: meanPause,
            pauseControlScore: score,
            confidence: confidence
        )
    }

    private static func makePitchAnalysis(windows: [ProsodyWindow]) -> PitchAnalysis {
        let pitched = windows.compactMap(\.pitchHz)
        let voicedRatio = windows.isEmpty ? 0 : windows.map(\.voicedRatio).reduce(0, +) / Double(windows.count)
        guard pitched.count >= 8 else {
            return PitchAnalysis(
                voicedRatio: voicedRatio,
                medianHz: nil,
                iqrHz: nil,
                spanHz: nil,
                movementRate: 0,
                monotoneSegments: [],
                pitchVariationScore: 0,
                monotonyRiskScore: 100,
                confidence: AnalysisConfidence(voicedRatio * 0.4)
            )
        }

        let sorted = pitched.sorted()
        let median = percentile(sorted, 0.5)
        let q1 = percentile(sorted, 0.25)
        let q3 = percentile(sorted, 0.75)
        let iqr = q3 - q1
        let span = (sorted.last ?? 0) - (sorted.first ?? 0)
        let semitones = sorted.map { 12 * log2(max($0, 1) / max(median, 1)) }
        let semitoneSpread = (percentile(semitones.sorted(), 0.75) - percentile(semitones.sorted(), 0.25))
        let movementRate = adjacentMeanDifference(pitched)
        let monotoneSegments = detectMonotoneSegments(windows: windows, medianPitch: median)
        let flatPenalty = max(0, 3.5 - semitoneSpread) * 18
        let erraticPenalty = max(0, movementRate - 18) * 1.3
        let variationScore = max(0, min(100, 100 - flatPenalty - erraticPenalty))
        let monotonyRisk = min(100, Double(monotoneSegments.count) * 18 + max(0, 45 - variationScore) * 0.9)
        let confidence = AnalysisConfidence(min(1, voicedRatio * 0.9))
        return PitchAnalysis(
            voicedRatio: voicedRatio,
            medianHz: median,
            iqrHz: iqr,
            spanHz: span,
            movementRate: movementRate,
            monotoneSegments: monotoneSegments,
            pitchVariationScore: variationScore,
            monotonyRiskScore: monotonyRisk,
            confidence: confidence
        )
    }

    private static func makeEnergyAnalysis(windows: [ProsodyWindow]) -> EnergyAnalysis {
        guard !windows.isEmpty else {
            return EnergyAnalysis(
                averageRMS: 0,
                rmsVariation: 0,
                energyVariationScore: 0,
                highlightedSegments: [],
                confidence: AnalysisConfidence(0)
            )
        }
        let energies = windows.map(\.rmsEnergy)
        let avg = energies.reduce(0, +) / Double(energies.count)
        let deviation = sqrt(variance(energies))
        let score = max(0, min(100, 100 - max(0, 0.045 - deviation) * 900 - max(0, deviation - 0.14) * 180))
        let threshold = avg + deviation
        let segments = windows.compactMap { window -> ClosedRange<Double>? in
            guard window.rmsEnergy > threshold else { return nil }
            return window.startTime...window.endTime
        }
        let confidence = AnalysisConfidence(avg > 0.002 ? 0.85 : 0.45)
        return EnergyAnalysis(
            averageRMS: avg,
            rmsVariation: deviation,
            energyVariationScore: score,
            highlightedSegments: segments,
            confidence: confidence
        )
    }

    private static func makePaceAnalysis(
        wordsPerMinute: Int,
        transitions: [LineTransitionRecord],
        renderedLines: [RenderedScriptLine]
    ) -> PaceAnalysis {
        let ordered = transitions.sorted { $0.timestamp < $1.timestamp }
        let segmentRates: [Int] = zip(ordered, ordered.dropFirst()).compactMap { current, next in
            let duration = max(next.timestamp - current.timestamp, 0.1)
            let lineWordCount = renderedLines
                .filter { $0.index >= current.toLineIndex && $0.index < next.toLineIndex }
                .flatMap(\.normalizedTokens)
                .count
            guard lineWordCount > 0 else { return nil }
            return Int(round(Double(lineWordCount) / (duration / 60)))
        }
        let sections = segmentRates.isEmpty ? [wordsPerMinute] : segmentRates
        let stabilityPenalty = sqrt(variance(sections.map(Double.init))) * 0.45
        let paceStability = max(0, min(100, 100 - stabilityPenalty))
        let confidence = AnalysisConfidence(segmentRates.count >= 2 ? 0.9 : 0.6)
        return PaceAnalysis(
            wordsPerMinute: wordsPerMinute,
            perSectionWordsPerMinute: sections,
            paceStabilityScore: paceStability,
            confidence: confidence
        )
    }

    private static func makeAdherenceAnalysis(
        lineAlignment: LineAlignmentState,
        totalLines: Int
    ) -> AdherenceAnalysis {
        let completed = lineAlignment.completedLines.sorted()
        let partial = lineAlignment.partialLines.subtracting(lineAlignment.completedLines).sorted()
        let skipped = lineAlignment.skippedLines.sorted()
        let weak = Array(Set(partial + skipped)).sorted()
        let completionRatio = totalLines > 0 ? Double(completed.count) / Double(totalLines) : 0
        let partialRatio = totalLines > 0 ? Double(partial.count) / Double(totalLines) : 0
        let skipRatio = totalLines > 0 ? Double(skipped.count) / Double(totalLines) : 0
        let score = max(0, min(100, completionRatio * 100 - partialRatio * 18 - skipRatio * 55))
        return AdherenceAnalysis(
            scriptAdherenceScore: score,
            weaklyMatchedLines: weak,
            skippedLines: skipped,
            completedLines: completed,
            partialLines: partial,
            confidence: AnalysisConfidence(totalLines > 0 ? 0.9 : 0.2)
        )
    }

    private static func makeSummary(
        pitch: PitchAnalysis,
        energy: EnergyAnalysis,
        pace: PaceAnalysis,
        pauses: PauseAnalysis,
        adherence: AdherenceAnalysis
    ) -> [String] {
        var output: [String] = []

        if pitch.confidence.value < 0.45 || pitch.medianHz == nil {
            output.append("Pitch analysis had low confidence, so the app prioritized pace, pause, and energy feedback.")
        } else if pitch.monotonyRiskScore >= 60 {
            let share = Int(round(min(1, Double(pitch.monotoneSegments.count) / 5) * 100))
            output.append("Pitch variation stayed narrow through \(share)% of tracked voiced segments, suggesting a monotone delivery.")
        } else if pitch.pitchVariationScore >= 70 {
            output.append("Pitch variation stayed in a healthy range without becoming erratic.")
        }

        if pace.perSectionWordsPerMinute.count >= 2 {
            let minRate = pace.perSectionWordsPerMinute.min() ?? pace.wordsPerMinute
            let maxRate = pace.perSectionWordsPerMinute.max() ?? pace.wordsPerMinute
            if maxRate - minRate >= 25 {
                output.append("Speaking rate shifted noticeably across sections, from about \(minRate) to \(maxRate) WPM.")
            }
        }

        if pauses.largestGapBetweenWords >= 1.5 {
            output.append("At least one pause stretched to \(String(format: "%.1f", pauses.largestGapBetweenWords)) seconds, which may feel hesitant.")
        } else if pauses.pauseControlScore >= 75 {
            output.append("Pause placement was relatively controlled, without many long gaps.")
        }

        if adherence.skippedLines.count >= 2 {
            let first = adherence.skippedLines.first ?? 0
            let last = adherence.skippedLines.last ?? 0
            output.append("Lines \(first + 1) to \(last + 1) showed weak script adherence and were likely paraphrased or skipped.")
        } else if adherence.scriptAdherenceScore >= 80 {
            output.append("Script adherence was strong, with most lines completed cleanly.")
        }

        if energy.energyVariationScore < 45 {
            output.append("Energy variation was limited, so emphasis may not be landing consistently.")
        }

        return output
    }

    private static func rootMeanSquare(_ frame: [Float]) -> Float {
        guard !frame.isEmpty else { return 0 }
        var result: Float = 0
        vDSP_measqv(frame, 1, &result, vDSP_Length(frame.count))
        return sqrtf(result)
    }

    private static func zeroCrossings(_ frame: [Float]) -> Double {
        guard frame.count > 1 else { return 1 }
        let crossings = zip(frame, frame.dropFirst()).filter { pair in
            let (lhs, rhs) = pair
            return (lhs >= 0 && rhs < 0) || (lhs < 0 && rhs >= 0)
        }.count
        return Double(crossings) / Double(frame.count - 1)
    }

    private static func estimatePitch(
        _ frame: [Float],
        sampleRate: Double,
        minLag: Int,
        maxLag: Int
    ) -> (pitch: Double?, confidence: Double) {
        guard frame.count > maxLag + 2 else { return (nil, 0) }
        var bestLag: Int?
        var bestScore: Float = -.infinity
        for lag in minLag...maxLag {
            let count = frame.count - lag
            guard count > 0 else { continue }
            var correlation: Float = 0
            vDSP_dotpr(Array(frame[0..<count]), 1, Array(frame[lag..<(lag + count)]), 1, &correlation, vDSP_Length(count))
            if correlation > bestScore {
                bestScore = correlation
                bestLag = lag
            }
        }

        guard let lag = bestLag, bestScore.isFinite, bestScore > 0 else {
            return (nil, 0)
        }
        let normalized = min(1, Double(bestScore) / Double(frame.count))
        let pitch = sampleRate / Double(lag)
        guard pitch.isFinite, pitch >= 75, pitch <= 320 else {
            return (nil, normalized * 0.2)
        }
        return (pitch, normalized)
    }

    private static func detectMonotoneSegments(
        windows: [ProsodyWindow],
        medianPitch: Double
    ) -> [ClosedRange<Double>] {
        guard medianPitch > 0 else { return [] }
        var segments: [ClosedRange<Double>] = []
        var currentStart: Double?
        var lastEnd: Double?

        for window in windows {
            guard let pitch = window.pitchHz else {
                if let currentStart, let lastEnd, lastEnd - currentStart >= 1.2 {
                    segments.append(currentStart...lastEnd)
                }
                currentStart = nil
                lastEnd = nil
                continue
            }

            let semitoneDistance = abs(12 * log2(pitch / medianPitch))
            if semitoneDistance < 1.4 {
                currentStart = currentStart ?? window.startTime
                lastEnd = window.endTime
            } else {
                if let currentStart, let lastEnd, lastEnd - currentStart >= 1.2 {
                    segments.append(currentStart...lastEnd)
                }
                currentStart = nil
                lastEnd = nil
            }
        }

        if let currentStart, let lastEnd, lastEnd - currentStart >= 1.2 {
            segments.append(currentStart...lastEnd)
        }

        return segments
    }

    private static func percentile(_ sorted: [Double], _ percentile: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let position = max(0, min(Double(sorted.count - 1), percentile * Double(sorted.count - 1)))
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        if lower == upper { return sorted[lower] }
        let weight = position - Double(lower)
        return sorted[lower] * (1 - weight) + sorted[upper] * weight
    }

    private static func adjacentMeanDifference(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let differences = zip(values, values.dropFirst()).map { abs($1 - $0) }
        return differences.reduce(0, +) / Double(differences.count)
    }

    private static func varianceOfTimeIntervals(_ values: [TimeInterval]) -> Double {
        return variance(values.map { Double($0) })
    }

    private static func variance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        return values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
    }
}
