import SwiftUI
import AVFoundation
import Speech
import Accelerate

func splitIntoLinesByWidth(_ text: String, font: UIFont, maxWidth: CGFloat) -> [String] {
    let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    var lines: [String] = []
    var currentLine = ""

    for word in words {
        let testLine = currentLine.isEmpty ? word : "\(currentLine) \(word)"
        let size = (testLine as NSString).size(withAttributes: [.font: font])

        if size.width <= maxWidth {
            currentLine = testLine
        } else {
            if !currentLine.isEmpty {
                lines.append(currentLine)
            }
            currentLine = word
        }
    }

    if !currentLine.isEmpty {
        lines.append(currentLine)
    }

    return lines
}

private func normalizeAndTokenize(_ text: String) -> [String] {
    let lowered = text.lowercased()
    let stripped = lowered.unicodeScalars.map { CharacterSet.punctuationCharacters.contains($0) ? " " : String($0) }.joined()
    return stripped
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
}

private func isSubsequence(_ small: [String], in big: [String]) -> Bool {
    guard !small.isEmpty else { return true }
    var i = 0
    for token in big {
        if token == small[i] {
            i += 1
            if i == small.count { return true }
        }
    }
    return false
}

struct Screen3Teleprompter: View {
    @EnvironmentObject private var recordingStore: RecordingStore
    @State private var showAccessory = false
    let synthesiser = AVSpeechSynthesizer()
    let audioEngine = AVAudioEngine()
    let speechRecogniser = SFSpeechRecognizer(locale: .current)
    @State var transcription = ""
    @State var isRecording = false
    @Environment(\.dismiss) private var dismiss

    @Binding var title: String
    @Binding var script: String
    @State var scriptLines: [String] = []
    @State private var isLoading = true
    @AppStorage("fontSize") var fontSize: Double = 28
    @Binding var WPM :Int

    @State private var tokensPerLine: [[String]] = []
    @State private var currentLineIndex: Int = 0
    @State private var lastAdvanceTime: Date = .distantPast
    @State private var navigateToScreen4 = false

    @State var secondsPerWord: [Double] = []
    @State var scriptWords: [String] = []
    @State var timer: TimerManager
    @State var transscriptionChangeCount: Int = 0

    @State private var elapsedTime: Int = 0
    @State private var wordCount: Int = 0
    @State private var LGBW: Int = 0

    @State private var LGBWSeconds: TimeInterval = 0
    @State private var meteringTimer: Timer? = nil
    @State private var isCurrentlySilent: Bool = true
    @State private var lastSilenceStartTime: Date? = nil
    @State private var silenceDurations: [TimeInterval] = []
    @State private var wallTimer: Timer? = nil

    @State var deviation: Double = 0

    private let silenceThreshold: Float = -40.0
    private let minSilenceDuration: TimeInterval = 0.25
    private let meteringInterval: TimeInterval = 0.05

    @Binding var isPresented: Bool

    private func recomputeLines() {
        let font = UIFont.systemFont(ofSize: CGFloat(fontSize))
        let maxWidth = UIScreen.main.bounds.width - 32
        scriptLines = splitIntoLinesByWidth(script, font: font, maxWidth: maxWidth)
        tokensPerLine = scriptLines.map { normalizeAndTokenize($0) }
        currentLineIndex = min(currentLineIndex, max(0, scriptLines.count - 1))
    }
    private func tryAdvance(using recognizedTokens: [String], scrollProxy: ScrollViewProxy) {
        guard currentLineIndex < tokensPerLine.count else { return }
        let now = Date()
        if now.timeIntervalSince(lastAdvanceTime) < 0.3 { return }

        let expected = tokensPerLine[currentLineIndex]
        if let last = expected.last, recognizedTokens.contains(last) {
            let nextIndex = currentLineIndex + 1
            if nextIndex <= scriptLines.count {
                currentLineIndex = min(nextIndex, scriptLines.count - 1)
                lastAdvanceTime = now
                withAnimation(.easeInOut) {
                    scrollProxy.scrollTo(currentLineIndex, anchor: .top)
                }
            }
        }
    }

    private func startWallClockTimer() {
        wallTimer?.invalidate()
        elapsedTime = 0
        wallTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in elapsedTime += 1 }
        RunLoop.current.add(wallTimer!, forMode: .common)
    }

    private func stopWallClockTimer() {
        wallTimer?.invalidate()
        wallTimer = nil
    }

    private func startSilenceTracking() {
        isCurrentlySilent = true
        lastSilenceStartTime = Date()
        silenceDurations.removeAll()
        LGBWSeconds = 0

        meteringTimer?.invalidate()
        meteringTimer = Timer.scheduledTimer(withTimeInterval: meteringInterval, repeats: true) { _ in }
        RunLoop.current.add(meteringTimer!, forMode: .common)
    }

    private func stopSilenceTracking() {
        meteringTimer?.invalidate()
        meteringTimer = nil
    }

    private func handleLevel(_ levelDB: Float) {
        let now = Date()
        if levelDB <= silenceThreshold {
            if !isCurrentlySilent {
                isCurrentlySilent = true
                lastSilenceStartTime = now
            }
        } else {
            if isCurrentlySilent {
                isCurrentlySilent = false
                if let silenceStart = lastSilenceStartTime {
                    let duration = now.timeIntervalSince(silenceStart)
                    if duration >= minSilenceDuration {
                        silenceDurations.append(duration)
                        if duration > LGBWSeconds { LGBWSeconds = duration }
                    }
                }
                lastSilenceStartTime = nil
            }
        }
    }

    private func finalizeSilenceIfNeeded() {
        if isCurrentlySilent, let silenceStart = lastSilenceStartTime {
            let duration = Date().timeIntervalSince(silenceStart)
            if duration >= minSilenceDuration {
                silenceDurations.append(duration)
                if duration > LGBWSeconds { LGBWSeconds = duration }
            }
        }
    }

    private func dBLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return -120.0 }
        let channel = channelData[0]
        let frameLength = Int(buffer.frameLength)
        if frameLength == 0 { return -120.0 }
        var sum: Float = 0.0
        vDSP_measqv(channel, 1, &sum, vDSP_Length(frameLength))
        let rms = sqrtf(sum)
        let db = 20.0 * log10f(max(rms, 1e-7))
        return db.isFinite ? db : -120.0
    }

    var body: some View {
        NavigationStack {
            NavigationLink(isActive: $navigateToScreen4) {
                ReviewView(
                    LGBW: $LGBW,
                    elapsedTime: $elapsedTime,
                    wordCount: $wordCount,
                    deriative: $deviation,
                    isCoverPresented: $isPresented
                )
            } label: {
                EmptyView()
            }

            VStack {
                if isLoading {
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(scriptLines.enumerated()), id: \.offset) { index, line in
                                    Text(line)
                                        .font(.system(size: CGFloat(fontSize)))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id(index)
                                        .background(index == currentLineIndex ? Color.primary.opacity(0.08) : Color.clear)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .onChange(of: currentLineIndex) { _, n in
                            withAnimation(.easeInOut) {
                                proxy.scrollTo(n, anchor: .top)
                            }
                        }
                        .onAppear {
                            if !scriptLines.isEmpty {
                                proxy.scrollTo(0, anchor: .top)
                            }
                        }
                        .onChange(of: transcription) { _, newValue in
                            let tokens = normalizeAndTokenize(newValue)
                            tryAdvance(using: tokens, scrollProxy: proxy)

                            if !scriptWords.isEmpty && transcription.contains(scriptWords[0]) {
                                transscriptionChangeCount += 1
                                scriptWords.remove(at: 0)

                                if transscriptionChangeCount % 5 == 0 {
                                    let t = timer.elapsedSeconds
                                    secondsPerWord.append(t)
                                    timer.reset()
                                    timer.start()
                                }
                            }
                        }
                    }
                }

                Spacer()

                HStack {
#if DEBUG
                    Text("DEBUG: \(secondsPerWord.description)")
                        .font(.caption)
                        .foregroundColor(.red)
#endif
                    Button {
                        isRecording.toggle()
                        showAccessory.toggle()
                    } label: {
                        RecordButtonView(isRecording: $isRecording)
                    }
                    .sensoryFeedback(.selection, trigger: showAccessory)
                }

                Text(transcription.isEmpty ? "..." : transcription)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            .onAppear {
                Task {
                    scriptWords = script.components(separatedBy: .whitespacesAndNewlines)
                        .filter { !$0.isEmpty }
                    wordCount = script.split { $0.isWhitespace }.count
                    recomputeLines()
                    isLoading = false
                }
            }

            .onChange(of: fontSize) { _, _ in recomputeLines() }
            .onChange(of: script) { _, _ in
                recomputeLines()
                wordCount = script.split { $0.isWhitespace }.count
            }

            .navigationTitle(title)
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }

            .navigationBarBackButtonHidden(true)

            .onChange(of: isRecording) { _, recording in
                if recording {
                    recordingStore.startRecording()

                    startWallClockTimer()
                    secondsPerWord.removeAll()
                    silenceDurations.removeAll()
                    LGBWSeconds = 0
                    transscriptionChangeCount = 0

                    scriptWords = script.components(separatedBy: .whitespacesAndNewlines)
                        .filter { !$0.isEmpty }

                    timer.reset()
                    timer.start()

                    SFSpeechRecognizer.requestAuthorization { _ in }
                    Task { _ = await AVAudioApplication.requestRecordPermission() }
                    guard let recogniser = speechRecogniser, recogniser.isAvailable else { return }

                    let audioSession = AVAudioSession.sharedInstance()
                    try? audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                    try? audioSession.setActive(true)

                    let request = SFSpeechAudioBufferRecognitionRequest()
                    request.shouldReportPartialResults = true

                    let inputNode = audioEngine.inputNode
                    let format = inputNode.outputFormat(forBus: 0)
                    inputNode.removeTap(onBus: 0)

                    startSilenceTracking()

                    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                        request.append(buffer)
                        let level = dBLevel(from: buffer)
                        handleLevel(level)
                    }

                    audioEngine.prepare()
                    try? audioEngine.start()

                    recogniser.recognitionTask(with: request) { result, _ in
                        if let result {
                            transcription = result.bestTranscription.formattedString
                        }
                    }

                } else {
                    recordingStore.stopRecording()
                    audioEngine.stop()
                    audioEngine.inputNode.removeTap(onBus: 0)

                    stopWallClockTimer()
                    finalizeSilenceIfNeeded()
                    stopSilenceTracking()

                    timer.stop()

                    if timer.elapsedSeconds > 0 {
                        secondsPerWord.append(timer.elapsedSeconds)
                    }

                    if !secondsPerWord.isEmpty {
                        deviation = secondsPerWord.standardDeviation(from: Double(WPM))
                    } else {
                        deviation = 0
                    }

                    let computedCIS = max(0, min(100, 100 - (deviation * 2.2)))
                    deviation = computedCIS

                    let longest = max(LGBWSeconds, silenceDurations.max() ?? 0)
                    LGBW = Int(longest.rounded())

                    navigateToScreen4 = true
                }
            }
        }
    }
}
