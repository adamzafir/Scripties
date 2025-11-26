import SwiftUI
import AVFoundation
#if os(watchOS)

struct WatchTeleprompterView: View {
    @ObservedObject var connectivity: WatchSessionManager
    var script: WatchScript

    @State private var isRecording = false
    @State private var elapsedSeconds: Int = 0
    @State private var cis: Int = 0
    @State private var wpm: Int = 0
    @State private var review = WatchReview(cis: 0, wpm: 0, audioURL: nil, date: Date())
    @State private var recorder: AVAudioRecorder?
    @State private var meterTimer: Timer?
    @State private var silenceDurations: [TimeInterval] = []
    @State private var longestSilence: TimeInterval = 0
    @State private var isSilent = true
    @State private var lastSilenceStart: Date?
    @State private var navigateToReview = false
    @State private var startDate: Date?
    @State private var hasSentReview = false

    private let silenceThreshold: Float = -35
    private let wordCount: Int

    init(connectivity: WatchSessionManager, script: WatchScript) {
        self.connectivity = connectivity
        self.script = script
        self.wordCount = script.scriptText.split(whereSeparator: \.isWhitespace).count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScrollView {
                    Text(script.scriptText)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 140)

                VStack {
                    Text("WPM \(wpm)")
                    Text("CIS \(cis)%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(action: toggleRecording) {
                    Label(isRecording ? "Stop" : "Start", systemImage: isRecording ? "stop.circle.fill" : "mic.fill")
                        .frame(maxWidth: .infinity)
                }
                .tint(isRecording ? .red : .green)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle(script.title)
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear { stopRecordingIfNeeded() }
            .background(
                NavigationLink(
                    "",
                    destination: ReviewView(connectivity: connectivity, script: script, review: $review, alreadySent: $hasSentReview),
                    isActive: $navigateToReview
                )
                .hidden()
            )
        }
    }

    private func toggleRecording() {
        isRecording.toggle()
        if isRecording {
            startRecording()
        } else {
            let audioURL = stopRecordingIfNeeded()
            finalizeReview(using: audioURL)
            connectivity.send(review: review, for: script)
            hasSentReview = true
            navigateToReview = true
        }
    }

    private func startRecording() {
        silenceDurations.removeAll()
        longestSilence = 0
        isSilent = true
        lastSilenceStart = Date()
        elapsedSeconds = 0
        startDate = Date()

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("watchReview-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.isMeteringEnabled = true
            rec.prepareToRecord()
            rec.record()
            recorder = rec
            startMetering()
        } catch {
            print("Watch recording error: \(error.localizedDescription)")
            isRecording = false
        }
    }

    private func startMetering() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            guard let recorder else { return }
            recorder.updateMeters()
            let db = recorder.averagePower(forChannel: 0)
            handleLevel(db)
            if let startDate {
                elapsedSeconds = max(0, Int(Date().timeIntervalSince(startDate)))
            }
        }
        RunLoop.current.add(meterTimer!, forMode: .common)
    }

    private func stopRecordingIfNeeded() -> URL? {
        meterTimer?.invalidate()
        meterTimer = nil
        let url = recorder?.url
        recorder?.stop()
        recorder = nil
        isRecording = false
        return url
    }

    private func handleLevel(_ db: Float) {
        let now = Date()
        if db <= silenceThreshold {
            if !isSilent {
                isSilent = true
                lastSilenceStart = now
            }
        } else if isSilent {
            isSilent = false
            if let start = lastSilenceStart {
                let duration = now.timeIntervalSince(start)
                silenceDurations.append(duration)
                longestSilence = max(longestSilence, duration)
            }
        }
    }

    private func finalizeSilence() {
        if isSilent, let start = lastSilenceStart {
            let duration = Date().timeIntervalSince(start)
            silenceDurations.append(duration)
            longestSilence = max(longestSilence, duration)
        }
    }

    private func computeCIS() -> Int {
        finalizeSilence()
        guard !silenceDurations.isEmpty else { return 100 }
        let average = silenceDurations.reduce(0, +) / Double(silenceDurations.count)
        let variance = silenceDurations.reduce(0) { $0 + pow($1 - average, 2) } / Double(silenceDurations.count)
        let sd = sqrt(variance)
        let base = 100 / (1 + sd)
        let penalty = longestSilence <= 0.5 ? 0 : min(40, (longestSilence - 0.5) * 25)
        return max(0, Int((base - penalty).rounded()))
    }

    private func finalizeReview(using audioURL: URL?) {
        cis = computeCIS()
        if elapsedSeconds > 0 {
            let minutes = Double(elapsedSeconds) / 60
            wpm = max(0, Int(round(Double(wordCount) / minutes)))
        } else {
            wpm = 0
        }

        review = WatchReview(
            cis: cis,
            wpm: wpm,
            audioURL: audioURL,
            date: Date()
        )
    }
}
#endif
