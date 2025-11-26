import SwiftUI

struct PastReviewsView: View {
    @EnvironmentObject private var viewModel: Screen2ViewModel
    var scriptID: UUID

    private var script: ScriptItem? {
        viewModel.scriptItems.first(where: { $0.id == scriptID })
    }

    private var reviews: [Review] {
        guard let script else { return [] }
        return script.pastReviews.reviewsItems.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            if let script {
                Section(script.title) {
                    if reviews.isEmpty {
                        ContentUnavailableView("No Reviews", systemImage: "clock.arrow.circlepath")
                    } else {
                        ForEach(reviews) { review in
                            NavigationLink {
                                ReviewView(review: review, showsSaveButton: false)
                                    .environmentObject(viewModel)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("WPM \(review.wpm) • CIS \(review.cis)%")
                                        .fontWeight(.semibold)
                                    Text(review.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("Script not found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("Past Reviews")
    }
}
