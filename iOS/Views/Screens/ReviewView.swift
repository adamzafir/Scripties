import SwiftUI

struct Screen4: View {
    @State var WPM = 120.0
    @Binding var LGBW: Int
    @Binding var elapsedTime: Int
    @Binding var wordCount: Int
    @Binding var deriative: Double
    let minVal = 0.0
    let maxVal = 250.0
    
    private func wrdEstimate(_wordCount: Int) -> Double{
        let estimate = Double(_wordCount) / 120.0
        let estSeconds = Int(estimate) * 60
        let finEst = Int(estSeconds) % 60
        return Double(finEst)
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
                        Screen5()
                }
                .onAppear {
                    deriative = deriative * 100
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
                    Gauge(value: deriative) {
                        Text("Consistency")
                    } currentValueLabel: {
                                Text("\(Int(deriative))")
                            } minimumValueLabel: {
                                Text("\(Int(0))")
                            } maximumValueLabel: {
                                Text("\(Int(100))%")
                            }
                            .gaugeStyle(.accessoryLinear)
                }
                NavigationLink {
                    TabHolder()
                } label:  {
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
            .navigationTitle("Review")
        }
        .navigationBarBackButtonHidden(true)
    }
    
    
}
   
#Preview {
    Screen4(
        LGBW: .constant(5),
        elapsedTime: .constant(60),
        wordCount: .constant(120),
        deriative: .constant(0.75)
    )
    .environmentObject(RecordingStore())
}
