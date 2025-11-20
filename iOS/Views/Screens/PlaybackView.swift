import SwiftUI
import AVFoundation

struct Screen5: View {
    var recordingURL: URL? = nil
    @EnvironmentObject private var recordingStore: RecordingStore

    @State private var audioPlayer: AVAudioPlayer?
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var progressTimer: Timer?
    @State private var isScrubbing = false
    @State private var audios: [URL] = []
    @State private var selectedURL: URL? = nil
    @State private var lastPreparedURL: URL? = nil
    @State private var isPlaying = false  // Track the play/pause state

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

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { duration > 0 ? currentTime : 0 },
                        set: { newValue in
                            currentTime = min(max(0, newValue), duration)
                        }
                    ), in: 0...max(duration, 0.001), onEditingChanged: { editing in
                        isScrubbing = editing
                        if !editing, let player = audioPlayer {
                            player.currentTime = currentTime
                            if player.isPlaying {
                                startProgressTimer()
                            }
                        }
                    })
                    .padding(.horizontal)
                    .sliderThumbVisibility(.hidden)

                    HStack {
                        Text(formatTime(currentTime))
                        Spacer()
                        Text(formatTime(duration))
                    }
                    .font(.caption)
                    .monospacedDigit()
                }

                HStack(spacing: 24) {
                    Button {
                        configureAudioSessionForPlayback()

                        if let player = audioPlayer {
                            if player.isPlaying {
                                player.pause()
                                progressTimer?.invalidate()
                                progressTimer = nil
                                isPlaying = false  // Update the play state
                            } else {
                                if lastPreparedURL == nil {
                                    refreshAndPrepareBest()
                                }
                                audioPlayer?.currentTime = currentTime
                                audioPlayer?.play()
                                startProgressTimer()
                                isPlaying = true  // Update the play state
                            }
                        } else {
                            refreshAndPrepareBest()
                            if audioPlayer != nil {
                                audioPlayer?.currentTime = currentTime
                                audioPlayer?.play()
                                startProgressTimer()
                                isPlaying = true  // Update the play state
                            } else {
                                print("No recording available to play.")
                            }
                        }
                    } label: {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.accentColor)
                                .accessibilityLabel(isPlaying ? "Pause" : "Play")
                    }
                    // .buttonStyle(.plain) // uncomment if you want a totally plain button
                }
                .padding(.bottom, 8)

                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .navigationTitle("Review")
            .onAppear {
                configureAudioSessionForPlayback()
                progressTimer?.invalidate()
                progressTimer = nil
                audioPlayer = nil
                currentTime = 0
                duration = 0
                lastPreparedURL = nil
                refreshAndPrepareBest()
            }
            .onDisappear {
                progressTimer?.invalidate()
                progressTimer = nil
            }
        }
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
}

#Preview {
    Screen5(recordingURL: nil)
        .environmentObject(RecordingStore())
}
