import SwiftUI

struct Screen4: View {
    @State var WPM = 120.0
    @Binding var LGBW: Int
    @State private var CIS = 70
    @State private var score: Int = 2
    @State private var scoreTwo: Double = 67
    @Binding var elapsedTime: Int
    @Binding var wordCount: Int
    @Binding var deriative: Double
    let minVal = 0.0
    let maxVal = 250.0
    
    private func wpmPercentage(_ wpm: Int) -> Double {
        if wpm <= 120 {
            
            let pct = 100 + (wpm - 120)
            return Double(max(0, min(100, pct)))
        } else {
            
            let pct = 100 + (wpm - 120)
            return Double(max(0, min(200, pct)))
        }
    }
    private func wrdEstimate(_wordCount: Int) -> Double{
        let estimate = Double(_wordCount) / 120.0
        let estSeconds = Int(estimate) * 60
        let finEst = Int(estSeconds) % 60
        return Double(finEst)
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
        let wpmPct = wpmPercentage(Int(WPM))
        let lgbwPct = lgbwPercentage(LGBW)
        let cisPct = cisPercentage(CIS)
        
        let overall = (wpmPct + lgbwPct + cisPct) / 3.0
        scoreTwo = max(0, min(100, overall))
        score = computeScoreThreePoint(wpmPct: wpmPct, lgbwPct: lgbwPct, cisPct: cisPct)
    }
    
    private func updateWPMFromBindings() {
        // Compute words per minute safely from wordCount and elapsedTime (seconds)
        guard elapsedTime > 0 else {
            WPM = 0
            return
        }
        let minutes = Double(elapsedTime) / 60.0
        let computed = Int(round(Double(wordCount) / minutes))
        WPM = Double(max(0, computed))
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
                Form{
                    Section("Result"){
                        LabeledContent {
                            Text(String(WPM))
                        } label: {
                            Text("Words per minute")
                        }
                        LabeledContent {
                            Text(String(deriative))
                        } label: {
                            Text("Consistency in speech (%)")
                        }
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
                    
                   
                      
                        
            
                   
                        Screen5(scoreTwo: $scoreTwo)
                    
                }
                VStack {
                    Gauge(value: WPM, in: 0...240) {
                        Text("Words Per Minute")
                    } currentValueLabel: {
                                Text("\(Int(WPM))")
                            } minimumValueLabel: {
                                Text("\(Int(minVal))")
                            } maximumValueLabel: {
                                Text("\(Int(maxVal))")
                            }
                    Gauge(value: WPM, in: 0...1) {
                        Text("Consitency")
                    } currentValueLabel: {
                                Text("\(Int(deriative))")
                            } minimumValueLabel: {
                                Text("\(Int(0))")
                            } maximumValueLabel: {
                                Text("\(Int(2))")
                            }
                    
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
            }
            .onAppear {
                updateWPMFromBindings()
                updateScores()
            }
            .navigationTitle("Review")
        }
        .navigationBarBackButtonHidden(true)
    }
    
    
}
   
