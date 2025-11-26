import SwiftUI
#if os(watchOS)

struct ReviewView: View {
    @ObservedObject var connectivity: WatchSessionManager
    var script: WatchScript
    @Binding var review: WatchReview
    @Binding var alreadySent: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section(header: Text("Summary")) {
                HStack {
                    Text("WPM")
                    Spacer()
                    Text("\(review.wpm)")
                }
                HStack {
                    Text("CIS")
                    Spacer()
                    Text("\(review.cis)%")
                }
                HStack {
                    Text("Date")
                    Spacer()
                    Text(review.date, style: .time)
                }
            }

            if review.audioURL != nil {
                Section {
                    Label("Audio attached", systemImage: "waveform")
                }
            }

            Button {
                connectivity.send(review: review, for: script)
                alreadySent = true
                dismiss()
            } label: {
                Label(alreadySent ? "Resend to iPhone" : "Send to iPhone", systemImage: "paperplane.fill")
            }
            .tint(alreadySent ? .blue : .green)
        }
        .navigationTitle("Review")
    }
}
#endif
