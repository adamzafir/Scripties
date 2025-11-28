import SwiftUI
import AVFoundation

struct ReviewView: View {
    // Target script to append review to
    var scriptItemID: UUID? = nil
    // Optional callback for external save handling (e.g., watch->phone)
    var onSave: ((Review) -> Void)? = nil
    var onDismiss: (() -> Void)? = nil
    var showsSaveButton: Bool = true
    var autoPersistOnAppear: Bool = false

    @EnvironmentObject private var scriptsViewModel: Screen2ViewModel
    @Environment(\.dismiss) private var dismiss

    @Binding private var review: Review

    // MARK: - Audio playback state
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var hasPersisted = false

    // MARK: - Expansions
    @State private var expandWPM = false
    @State private var expandCIS = false

    init(review: Binding<Review>, scriptItemID: UUID? = nil, showsSaveButton: Bool = true, autoPersistOnAppear: Bool = false, onSave: ((Review) -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        _review = review
        self.scriptItemID = scriptItemID
        self.showsSaveButton = showsSaveButton
        self.autoPersistOnAppear = autoPersistOnAppear
        self.onSave = onSave
        self.onDismiss = onDismiss
    }

    init(review: Review, scriptItemID: UUID? = nil, showsSaveButton: Bool = false, autoPersistOnAppear: Bool = false, onSave: ((Review) -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        _review = .constant(review)
        self.scriptItemID = scriptItemID
        self.showsSaveButton = showsSaveButton
        self.autoPersistOnAppear = autoPersistOnAppear
        self.onSave = onSave
        self.onDismiss = onDismiss
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: review.date)
    }

    private func togglePlayback() {
        guard let url = review.audioURL else { return }

        if let player = audioPlayer, player.url == url {
            if player.isPlaying {
                player.pause()
                isPlaying = false
            } else {
                player.play()
                isPlaying = true
            }
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            audioPlayer = player
            player.play()
            isPlaying = true
        } catch {
            print("Audio playback error: \(error.localizedDescription)")
            isPlaying = false
        }
    }

    private func persistReview(shouldDismiss: Bool = true) {
        guard !hasPersisted else {
            if shouldDismiss {
                dismiss()
                onDismiss?()
            }
            return
        }

        if let sid = scriptItemID {
            scriptsViewModel.appendReview(review, to: sid)
        }
        onSave?(review)
        hasPersisted = true
        if shouldDismiss {
            dismiss()
            onDismiss?()
        }
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Playback")
                            .font(.headline)
                        Text(formattedDate)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let url = review.audioURL {
                        Button {
                            togglePlayback()
                        } label: {
                            Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                                .foregroundStyle(.pri)
                        }
                        .tint(.pri)
                        .buttonStyle(.bordered)
                        .accessibilityLabel(url.lastPathComponent)
                    }
                }
            }

            Section("Result") {
                DisclosureGroup(isExpanded: $expandWPM) {
                    SemiCircleGauge(
                        progress: max(0, min(1, Double(review.wpm)/180)),
                        highlight: (100.0/180)...(120.0/180),
                        minLabel: "0",
                        maxLabel: "180",
                        valueLabel: "\(review.wpm)"
                    )
                    .frame(height: 110)

                    if review.wpm > 120 {
                        Text("Too fast. The best WPM is 120. The green band shows the ideal range.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if review.wpm < 100 {
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
                        Text("\(review.wpm)").monospacedDigit().foregroundStyle(.secondary)
                    }
                }

                DisclosureGroup(isExpanded: $expandCIS) {
                    HStack {
                        SemiCircleGauge(
                            progress: max(0,min(1,Double(review.cis)/100)),
                            highlight: (75.0/100)...(85.0/100),
                            minLabel: "0%",
                            maxLabel: "100%",
                            valueLabel: "\(review.cis)%"
                        )
                        .frame(height: 110)
                    }
                    if review.cis < 80 {
                        Text("Take less pauses. The best consistency (CIS) is 80–85%. The green band shows the ideal range.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if review.cis > 85 {
                        Text("Take more pauses. The best consistency (CIS) is 80–85%. The green band shows the ideal range.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Keep it up! The best consistency (CIS) is 80–85%. The green band shows the ideal range.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    HStack {
                        Text("Consistency")
                        Spacer()
                        Text("\(review.cis)%").monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }

            if showsSaveButton {
                Button {
                    persistReview()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .frame(height: 55)
                            .foregroundColor(.pri)
                            .glassEffect()
                        Text("Save Review")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("Review")
        .onAppear {
            if autoPersistOnAppear {
                persistReview(shouldDismiss: false)
            }
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
        review: Review(cis: 72, wpm: 118, audioURL: nil, date: Date()),
        scriptItemID: UUID(),
        showsSaveButton: true
    )
    .environmentObject(Screen2ViewModel())
}
