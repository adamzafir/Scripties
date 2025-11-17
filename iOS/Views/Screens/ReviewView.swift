import SwiftUI
import AVFoundation

struct ReviewView: View {
    // Optional URL to a specific recording to review
    var recordingURL: URL? = nil
    @EnvironmentObject private var recordingStore: RecordingStore

    // MARK: - Audio playback state
    @State private var audioPlayer: AVAudioPlayer?
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var progressTimer: Timer?
    @State private var isScrubbing = false
    @State private var audios: [URL] = []
    @State private var selectedURL: URL? = nil
    @State private var lastPreparedURL: URL? = nil
    @State private var isPlaying = false

    // MARK: - Scoring state
    @State var WPM = 120
    @Binding var LGBW: Int
    @State private var CIS = 70
    @State private var score: Int = 2
    @State private var scoreTwo: Double = 67
    @State private var showInfo: Bool = false
    @State private var isWPMExpanded: Bool = false
    @State private var isConsistencyExpanded: Bool = false
    @Binding var elapsedTime: Int
    @Binding var wordCount: Int
    @Binding var deriative: Double
    @Binding var isCoverPresented: Bool
    @Environment(\.dismiss) private var dismiss

    // MARK: - Audio helpers
    private func configureAudioSessionForPlayback() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed:", error)
        }
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard let player = audioPlayer, !isScrubbing else { return }
            currentTime = player.currentTime
            if !player.isPlaying || currentTime >= duration {
                progressTimer?.invalidate()
                progressTimer = nil
            }
        }
        progressTimer = timer
        RunLoop.current.add(timer, forMode: .common)
    }

    private func fileSizeString(for url: URL) -> String {
        let path = url.path
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
           let size = attrs[.size] as? NSNumber {
            return "\(size.intValue) bytes"
        }
        return "unknown size"
    }

    private func prepare(url: URL) {
        audioPlayer?.stop()
        audioPlayer = nil
        duration = 0
        currentTime = 0

        configureAudioSessionForPlayback()

        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Prepare failed: file does not exist at \(url)")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            audioPlayer = player
            duration = player.duration
            selectedURL = url
            lastPreparedURL = url

            currentTime = 0
            audioPlayer?.currentTime = 0

            print("Prepared URL:", url.lastPathComponent, "size:", fileSizeString(for: url), "duration:", duration)
        } catch {
            print("Failed to prepare recording:", error, "URL:", url)
            audioPlayer = nil
            duration = 0
            currentTime = 0
        }
    }

    private func getBestCandidateURL() -> URL? {
        if let u = recordingURL { return u }
        if let u = recordingStore.latestRecordingURL { return u }
        return audios.first
    }

    private func refreshAndPrepareBest() {
        getAudios()
        if let candidate = getBestCandidateURL() {
            prepare(url: candidate)
        } else {
            print("No candidate URL available to prepare.")
        }
    }

    // Avoid heavy audio/session work when running in SwiftUI previews
    private var isRunningInPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    // MARK: - Scoring helpers
    private func wpmPercentage(_ wpm: Int) -> Double {
        if wpm <= 120 {
            let pct = 100 + (wpm - 120)
            return Double(max(0, min(100, pct)))
        } else {
            let pct = 100 + (wpm - 120)
            return Double(max(0, min(200, pct)))
        }
    }

    private func lgbwPercentage(_ lgbw: Int) -> Double {
        if lgbw <= 5 { return 100 }
        let over = min(10, max(6, lgbw))
        let stepsAbove5 = over - 5
        let pct = 100 - stepsAbove5 * 20
        return Double(max(0, pct))
    }

    private func cisPercentage(_ cis: Int) -> Double {
        if cis >= 80 && cis <= 85 { return 100 }
        if cis > 85 {
            let over = cis - 85
            let pct = 100 - over * 6
            return Double(max(0, min(100, pct)))
        }
        return Double(max(0, min(100, cis)))
    }

    private func computeScoreThreePoint(wpmPct: Double, lgbwPct: Double, cisPct: Double) -> Int {
        let wpmIsIdeal = Int(round(wpmPct)) == 100
        let lgbwIsIdeal = Int(round(lgbwPct)) == 100
        let cisIsIdeal = CIS >= 80 && CIS <= 85
        return (wpmIsIdeal && lgbwIsIdeal && cisIsIdeal) ? 3 : 2
    }

    private func updateScores() {
        let wpmPct = wpmPercentage(WPM)
        let lgbwPct = lgbwPercentage(LGBW)
        let cisPct = cisPercentage(CIS)
        let overall = (wpmPct + lgbwPct + cisPct) / 3.0
        scoreTwo = max(0, min(100, overall))
        score = computeScoreThreePoint(wpmPct: wpmPct, lgbwPct: lgbwPct, cisPct: cisPct)
    }

    private func updateWPMFromBindings() {
        guard elapsedTime > 0 else {
            WPM = 0
            return
        }
        let minutes = Double(elapsedTime) / 60.0
        let computed = Int(round(Double(wordCount) / minutes))
        WPM = max(0, computed)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        guard t.isFinite && !t.isNaN else { return "0:00" }
        let total = Int(t.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func getAudios() {
        do {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let result = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey], options: [])
            self.audios = result
                .filter { $0.pathExtension.lowercased() == "m4a" }
                .sorted(by: { lhs, rhs in
                    let lDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let rDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return lDate > rDate
                })
        } catch {
            print("List audios error: \(error.localizedDescription)")
            self.audios = []
        }
    }

    // MARK: - View
    var body: some View {
        NavigationStack {
            Form {
#if DEBUG
                
                    Text("DEBUG: Elapsed Time: \(elapsedTime)")
                        .font(.caption)
                        .foregroundColor(.red)
            
#endif
                Form {
                    Section("Result") {
                        DisclosureGroup(isExpanded: $isWPMExpanded) {
                            SemiCircleGauge(
                                progress: max(0.0, min(1.0, Double(WPM) / 180.0)),
                                highlight: (100.0/180.0)...(120.0/180.0),
                                minLabel: "0",
                                maxLabel: "180 wpm",
                                valueLabel: "\(WPM)"
                            )
                            .frame(height: 80)
                            .padding(.top, 8)

                            Text("Best WPM is 120. The green band shows the ideal range.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        } label: {
                            HStack {
                                Text("Words per minute")
                                Spacer()
                                Text("\(WPM)")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        DisclosureGroup(isExpanded: $isConsistencyExpanded) {
                            SemiCircleGauge(
                                progress: max(0.0, min(1.0, Double(CIS) / 100.0)),
                                highlight: (75.0/100.0)...(85.0/100.0),
                                minLabel: "0%",
                                maxLabel: "100%",
                                valueLabel: "\(CIS)%"
                            )
                            .frame(height: 80)
                            .padding(.top, 8)

                            Text("Best consistency (CIS) is 80–85%. The green band shows the ideal range.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        } label: {
                            HStack {
                                Text("Consistency in speech (%)")
                                Spacer()
                                Text("\(CIS)%")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Screen5()
                }

                Button {
                    dismiss()
                    DispatchQueue.main.async {
                        isCoverPresented = false
                    }
                } label: {
                    ZStack {
                        Rectangle()
                            .frame(height: 55)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(25)
                            .foregroundStyle(Color.accentColor)
                            .glassEffect()
                            .padding(.horizontal)
                        Text("Done")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.white)
                    }
                    .padding()
                }
                .onAppear {
                    updateWPMFromBindings()
                    updateScores()
                    CIS = Int(deriative.rounded())
                }
                .onChange(of: WPM) { _, _ in updateScores() }
                .onChange(of: LGBW) { _, _ in updateScores() }
                .onChange(of: CIS) { _, _ in updateScores() }
                .onChange(of: elapsedTime) { _, _ in updateWPMFromBindings(); updateScores() }
                .onChange(of: wordCount) { _, _ in updateWPMFromBindings(); updateScores() }
                .onChange(of: deriative) { _, newValue in CIS = Int(newValue.rounded()); updateScores() }
                .navigationTitle("Review")
            }
            .navigationBarBackButtonHidden(true)
        }
    }

    // MARK: - Gauge
    struct SemiCircleGauge: View {
        var progress: Double
        var lineWidth: CGFloat = 16
        var label: String? = nil
        var highlight: ClosedRange<Double>? = nil
        var minLabel: String? = nil
        var maxLabel: String? = nil
        var valueLabel: String? = nil

        var body: some View {
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let totalHeight = geo.size.height
                let lineThickness = max(10, min(16, geo.size.height * 2))
                let clamped = max(0.0, min(1.0, progress))
                let indicatorX = clamped * totalWidth
                let isRight = clamped >= 0.5

                let highlightFrame: (x: CGFloat, width: CGFloat)? = {
                    guard let r = highlight else { return nil }
                    let start = CGFloat(r.lowerBound) * totalWidth
                    let end = CGFloat(r.upperBound) * totalWidth
                    let w = end - start
                    return (x: start + w/2, width: w)
                }()

                ZStack {
                    if let hf = highlightFrame, hf.width > 0 {
                        Capsule()
                            .fill(Color.green.opacity(0.25))
                            .frame(width: hf.width, height: lineThickness)
                            .position(x: hf.x, y: totalHeight/2)
                    }

                    Capsule()
                        .fill(Color.gray.opacity(0.25))
                        .frame(width: totalWidth, height: lineThickness)
                        .position(x: totalWidth/2, y: totalHeight/2)

                    Capsule()
                        .fill(isRight ? Color.blue : Color.orange)
                        .frame(width: 3, height: max(lineThickness, 20))
                        .position(x: indicatorX, y: totalHeight/2)
                        .animation(.easeInOut(duration: 0.4), value: clamped)

                    if let minLabel {
                        Text(minLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .position(x: 8, y: totalHeight/2 + lineThickness/2 + 10)
                    }
                    if let maxLabel {
                        Text(maxLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .position(x: totalWidth - 8, y: totalHeight/2 + lineThickness/2 + 10)
                    }

                    if let valueLabel {
                        Text(valueLabel)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .position(x: min(max(12, indicatorX), totalWidth - 12),
                                      y: max(0, totalHeight/2 - lineThickness/2 - 10))
                    }

                    if let label {
                        VStack {
                            HStack {
                                Spacer()
                                Text(label)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ReviewView(
        LGBW: .constant(5),
        elapsedTime: .constant(120),
        wordCount: .constant(240),
        deriative: .constant(70.0)
    )
    .environmentObject(RecordingStore())
}
