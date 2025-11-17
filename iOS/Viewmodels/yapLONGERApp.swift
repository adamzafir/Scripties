import SwiftUI

@main
struct yapLONGERApp: App {
    @StateObject private var recordingStore = RecordingStore()
    @StateObject private var scriptsViewModel = Screen2ViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    TabHolder()
                        .transition(.opacity)
                } else {
                    OnboardingView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: hasCompletedOnboarding)
            .environmentObject(recordingStore)
            .environmentObject(scriptsViewModel)
        }
    }
}
