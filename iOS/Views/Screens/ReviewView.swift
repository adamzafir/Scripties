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
    @Binding var elapsedTime: Int
    @Binding var wordCount: Int
    @Binding var deriative: Double
    @Binding var isCoverPresented: Bool
    @Environment(\.dismiss) private var dismiss
    
    @State private var CIS: Int = 0
    @State private var scoreTwo: Double = 0
    @State private var score: Int = 2
    @State private var expandWPM = false
    @State private var expandCIS = false
    
    private func computeWPM() {
        guard elapsedTime > 0 else { WPM = 0; return }
        let min = Double(elapsedTime) / 60
        WPM = max(0, Int(round(Double(wordCount) / min)))
    }
    
    private func wpmPct(_ v: Int) -> Double {
        if v <= 120 { return Double(max(0, v)) }
        return Double(min(200, v))
    }
    
    private func lgbwPct(_ v: Int) -> Double {
        if v <= 5 { return 100 }
        let over = min(10, max(6, v))
        let steps = over - 5
        return max(0, 100 - Double(steps) * 20)
    }
    
    private func cisPct(_ v: Int) -> Double {
        if v >= 80 && v <= 85 { return 100 }
        if v > 85 { return max(0, 100 - Double(v - 85) * 6) }
        return Double(max(0, v))
    }
    
    private func updateScore() {
        let wp = wpmPct(WPM)
        let lp = lgbwPct(LGBW)
        let cp = cisPct(CIS)
        let total = (wp + lp + cp) / 3
        scoreTwo = max(0, min(100, total))
        let idealWPM = Int(round(wp)) == 100
        let idealLGBW = Int(round(lp)) == 100
        let idealCIS = CIS >= 80 && CIS <= 85
        score = (idealWPM && idealLGBW && idealCIS) ? 3 : 2
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
                Section("Result") {
                    
                    DisclosureGroup(isExpanded: $expandWPM) {
                        SemiCircleGauge(
                            progress: max(0, min(1, Double(WPM)/180)),
                            highlight: (100.0/180)...(120.0/180),
                            minLabel: "0",
                            maxLabel: "180",
                            valueLabel: "\(WPM)"
                        )
                        .frame(height: 90)
                        
                        if WPM > 120 {
                            Text("Too fast. The best WPM is 120. The green band shows the ideal range.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if WPM < 100 {
                            Text("Too slow. The best WPM is 120. The green band shows the ideal range.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Good! The best WPM is 120. The green band shows the ideal range.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        HStack {
                            Text("Words Per Minute")
                            Spacer()
                            Text("\(WPM)").monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                    
                    DisclosureGroup(isExpanded: $expandCIS) {
                        if CIS != 0 {
                            SemiCircleGauge(
                                progress: max(0,min(1,Double(CIS)/100)),
                                highlight: (75.0/100)...(85.0/100),
                                minLabel: "0%",
                                maxLabel: "100%",
                                valueLabel: "\(CIS)%"
                            )
                            .frame(height: 90)
                            if CIS < 80 {
                                Text("Take less pauses. The best consistency (CIS) is 80–85%. The green band shows the ideal range.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else if CIS > 85 {
                                Text("Take more pauses. The best consistency (CIS) is 80–85%. The green band shows the ideal range.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Keep it up! The best consistency (CIS) is 80–85%. The green band shows the ideal range.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Speech was not detected properly, please try again.")
                                .foregroundStyle(Color.red)
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        HStack {
                            Text("Consistency")
                            Spacer()
                            if CIS != 0 {
                                Text("\(CIS)%").monospacedDigit().foregroundStyle(.secondary)
                            } else {
                                Text("Error")
                                    .foregroundStyle(Color.red)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                
                Screen5()
                
                
                
                Button {
                    dismiss()
                    DispatchQueue.main.async { isCoverPresented = false }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .frame(height: 55)
                            .foregroundColor(.accentColor)
                            .glassEffect()
                        Text("Done")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    }
                    .padding()
                }
            }
            .onAppear {
                computeWPM()
                // Force CIS to 0 for testing
                CIS = 0
                updateScore()
            }
            .onChange(of: elapsedTime) { _ in computeWPM(); updateScore() }
            .onChange(of: wordCount) { _ in computeWPM(); updateScore() }
            .onChange(of: LGBW) { _ in updateScore() }
            // Disable CIS updates from 'deriative' while testing
            // .onChange(of: deriative) { _,v in CIS = Int(v.rounded()); updateScore() }
            
            .navigationTitle("Review")
            .navigationBarBackButtonHidden(true)
        }
    }
}
// MARK: - Gauge
struct SemiCircleGauge: View {
    var progress: Double
    var lineWidth: CGFloat = 14
    var label: String? = nil
    var highlight: ClosedRange<Double>?
    var minLabel: String?
    var maxLabel: String?
    var valueLabel: String?
    
    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let h = g.size.height
            let thick = max(10, min(14, h*2))
            let x = max(0,min(1,progress))*w
            let high = highlight.map { r -> (CGFloat,CGFloat) in
                let s = CGFloat(r.lowerBound)*w
                let e = CGFloat(r.upperBound)*w
                return (s,e-s)
            }
            
            ZStack {
                if let hframe = high {
                    Capsule()
                        .fill(Color.green.opacity(0.25))
                        .frame(width:hframe.1,height:thick)
                        .position(x:hframe.0+hframe.1/2,y:h/2)
                }
                
                Capsule()
                    .fill(Color.gray.opacity(0.25))
                    .frame(width:w,height:thick)
                    .position(x:w/2,y:h/2)
                
                Capsule()
                    .fill(progress>=0.5 ? Color.blue : Color.orange)
                    .frame(width:3,height:max(thick,20))
                    .position(x:x,y:h/2)
                
                if let min = minLabel {
                    Text(min).font(.caption2).position(x:10,y:h/2+thick/2+12)
                }
                if let max = maxLabel {
                    Text(max).font(.caption2).position(x:w-10,y:h/2+thick/2+12)
                }
                
                if let v = valueLabel {
                    Text(v).font(.caption).position(x:min(max(12,x),w-12),y:h/2-thick/2-10)
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
        deriative: .constant(70.0),
        isCoverPresented: .constant(false)
    )
    .environmentObject(RecordingStore())
}

