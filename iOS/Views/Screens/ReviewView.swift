import SwiftUI

struct ReviewView: View {
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

    var body: some View {
        NavigationStack {
            VStack {
#if DEBUG
                Text("DEBUG: Elapsed Time: \(elapsedTime)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 10)
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
                                Text("\(Int(deriative.rounded()))%")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Screen5()
                }
                NavigationLink {
                                    TabHolder()
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
                .onChange(of: elapsedTime) { _, _ in
                    updateWPMFromBindings()
                    updateScores()
                }
                .onChange(of: wordCount) { _, _ in
                    updateWPMFromBindings()
                    updateScores()
                }
                .onChange(of: deriative) { _, newValue in
                    CIS = Int(newValue.rounded())
                    updateScores()
                }
                .navigationTitle("Review")
            }
            .navigationBarBackButtonHidden(true)
        }
    }
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
                let centerX = totalWidth / 2
                let delta = abs(clamped - 0.5)
                let extent = (totalWidth / 2) * delta * 2
                let isRight = clamped >= 0.5
                let indicatorX = clamped * totalWidth

                let highlightFrame: (x: CGFloat, width: CGFloat)? = {
                    guard let r = highlight else { return nil }
                    let start = CGFloat(max(0.0, min(1.0, r.lowerBound))) * totalWidth
                    let end = CGFloat(max(0.0, min(1.0, r.upperBound))) * totalWidth
                    let minX = min(start, end)
                    let w = max(0, end - start)
                    return (x: minX + w / 2, width: w)
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let maxLabel {
                        Text(maxLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .position(x: totalWidth - 8, y: totalHeight/2 + lineThickness/2 + 10)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    if let valueLabel {
                        Text(valueLabel)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .position(x: min(max(12, indicatorX), totalWidth - 12), y: max(0, totalHeight/2 - lineThickness/2 - 10))
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
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}

#Preview {
    ReviewView(
        LGBW: .constant(5),
        elapsedTime: .constant(120),
        wordCount: .constant(240),
        deriative: .constant(82.0)
    )
    .environmentObject(RecordingStore())
}
