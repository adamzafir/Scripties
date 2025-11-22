//
//import AVFoundation
//
//// Optional URL to a specific recording to review
//var recordingURL: URL? = nil
//@EnvironmentObject private var recordingStore: RecordingStore
//
//// MARK: - Audio playback state
//@State private var audioPlayer: AVAudioPlayer?
//@State private var currentTime: TimeInterval = 0
//@State private var duration: TimeInterval = 0
//@State private var progressTimer: Timer?
//@State private var isScrubbing = false
//@State private var audios: [URL] = []
//@State private var selectedURL: URL? = nil
//@State private var lastPreparedURL: URL? = nil
//@State private var isPlaying = false
//
//// MARK: - Scoring state
//@State var WPM = 120
//@Binding var LGBW: Int
//@Binding var elapsedTime: Int
//@Binding var wordCount: Int
//@Binding var deriative: Double
//@Binding var isCoverPresented: Bool
//@Environment(\.dismiss) private var dismiss
//
//@State private var CIS: Int = 0
//@State private var scoreTwo: Double = 0
//@State private var score: Int = 2
//@State private var expandWPM = false
//@State private var expandCIS = false
//
//private func computeWPM() {
//    guard elapsedTime > 0 else { WPM = 0; return }
//    let min = Double(elapsedTime) / 60
//    WPM = max(0, Int(round(Double(wordCount) / min)))
//}
//
//private func wpmPct(_ v: Int) -> Double {
//    if v <= 120 { return Double(max(0, v)) }
//    return Double(min(200, v))
//}
//
//private func lgbwPct(_ v: Int) -> Double {
//    if v <= 5 { return 100 }
//    let over = min(10, max(6, v))
//    let steps = over - 5
//    return max(0, 100 - Double(steps) * 20)
//}
//
//private func cisPct(_ v: Int) -> Double {
//    if v >= 80 && v <= 85 { return 100 }
//    if v > 85 { return max(0, 100 - Double(v - 85) * 6) }
//    return Double(max(0, v))
//}
//
//private func updateScore() {
//    let wp = wpmPct(WPM)
//    let lp = lgbwPct(LGBW)
//    let cp = cisPct(CIS)
//    let total = (wp + lp + cp) / 3
//    scoreTwo = max(0, min(100, total))
//    let idealWPM = Int(round(wp)) == 100
//    let idealLGBW = Int(round(lp)) == 100
//    let idealCIS = CIS >= 80 && CIS <= 85
//    score = (idealWPM && idealLGBW && idealCIS) ? 3 : 2
//}
//
//private func formatTime(_ t: TimeInterval) -> String {
//    guard t.isFinite && !t.isNaN else { return "0:00" }
//    let total = Int(t.rounded())
//    return String(format: "%d:%02d", total / 60, total % 60)
//}
//
//private func getAudios() {
//    do {
//        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        let result = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey], options: [])
//        self.audios = result
//            .filter { $0.pathExtension.lowercased() == "m4a" }
//            .sorted(by: { lhs, rhs in
//                let lDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
//                let rDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
//                return lDate > rDate
//            })
//    } catch {
//        print("List audios error: \(error.localizedDescription)")
//        self.audios = []
//    }
//}
//
//// MARK: - View
//
//    .onAppear {
//        computeWPM()
//        // Initialize CIS from the incoming derived value
//        CIS = Int(deriative.rounded())
//        updateScore()
//    }
//    .onChange(of: elapsedTime) { _ in computeWPM(); updateScore() }
//    .onChange(of: wordCount) { _ in computeWPM(); updateScore() }
//    .onChange(of: LGBW) { _ in updateScore() }
//    .onChange(of: deriative) { _, v in
//        CIS = Int(v.rounded())
//        updateScore()
//    }
//

