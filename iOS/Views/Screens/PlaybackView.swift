import SwiftUI
import AVFoundation

struct Screen5: View {
    var recordingURL: URL? = nil
    @State private var audioPlayer: AVAudioPlayer?
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var progressTimer: Timer?
    @State private var isScrubbing = false
    // Keep recordings internally to detect the most recent, but do not show them
    @State private var audios: [URL] = []
    @State private var selectedURL: URL? = nil

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
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard let player = audioPlayer, !isScrubbing else { return }
            currentTime = player.currentTime
            if !player.isPlaying || currentTime >= duration {
                progressTimer?.invalidate()
                progressTimer = nil
            }
        }
    }

    private func prepare(url: URL) {
        configureAudioSessionForPlayback()
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            audioPlayer = player
            duration = player.duration
            selectedURL = url
            player.prepareToPlay()
            // do not auto-play
        } catch {
            print("Failed to prepare recording:", error)
        }
    }

    // Decide which URL to play when Play is pressed
    private func bestURLToPlay() -> URL? {
        if let selectedURL { return selectedURL }
        if let newest = audios.first { return newest }
        if let recordingURL { return recordingURL }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Gauge
                
                    

                // Progress slider & timestamps
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

                    HStack {
                        Text(formatTime(currentTime))
                        Spacer()
                        Text(formatTime(duration))
                    }
                    .font(.caption)
                    .monospacedDigit()
                }

                // Playback controls
                HStack(spacing: 24) {
                    // Back 15s
                    Button {
                        let newTime = max(0, currentTime - 15)
                        currentTime = newTime
                        audioPlayer?.currentTime = newTime
                    } label: {
                        Label("", systemImage: "gobackward.15")
                    }

                    // Play/Pause
                    Button {
                        configureAudioSessionForPlayback()

                        if let player = audioPlayer {
                            if player.isPlaying {
                                player.pause()
                                progressTimer?.invalidate()
                                progressTimer = nil
                            } else {
                                player.currentTime = currentTime
                                player.play()
                                startProgressTimer()
                            }
                        } else if let urlToUse = bestURLToPlay() {
                            // Prepare then play on this button press
                            prepare(url: urlToUse)
                            audioPlayer?.currentTime = currentTime
                            audioPlayer?.play()
                            startProgressTimer()
                        } else {
                            print("No recording available to play.")
                        }
                    } label: {
                        let isPlaying = audioPlayer?.isPlaying == true
                        Label(isPlaying ? "" : "", systemImage: isPlaying ? "pause.fill" : "play.fill")
                            .font(.headline)
                    }

                    // Forward 15s
                    Button {
                        let newTime = min(duration, currentTime + 15)
                        currentTime = newTime
                        audioPlayer?.currentTime = newTime
                    } label: {
                        Label("", systemImage: "goforward.15")
                    }
                }
                .padding(.bottom, 8)

                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .navigationTitle("Review")
            .onAppear {
                configureAudioSessionForPlayback()
                getAudios()
                // No auto-play or UI for recordings
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
                // Sort by modification date descending (latest first)
                .sorted(by: { lhs, rhs in
                    let lDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let rDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return lDate > rDate
                })
        } catch {
            print("List audios error: \(error.localizedDescription)")
        }
    }
}

extension Screen5 {
    struct SemiCircleGauge: View {
        var progress: Double
        var lineWidth: CGFloat = 16

        var body: some View {
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                ZStack {
                    Arc(startAngle: .degrees(180), endAngle: .degrees(360))
                        .stroke(Color.gray.opacity(0.25), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                    Arc(startAngle: .degrees(180), endAngle: .degrees(180 + 180 * progress))
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .animation(.easeInOut(duration: 0.4), value: progress)

                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.primary)
                        .offset(y: size * 0.15)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    struct Arc: Shape {
        var startAngle: Angle
        var endAngle: Angle

        func path(in rect: CGRect) -> Path {
            var path = Path()
            let radius = min(rect.width, rect.height)
            let center = CGPoint(x: rect.midX, y: rect.maxY)
            path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            return path
        }
    }
}

#Preview {
    Screen5(recordingURL: nil)
}
