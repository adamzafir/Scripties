import SwiftUI

@main
struct yapLONGERApp: App {
    @StateObject private var recordingStore = RecordingStore()
    
    var body: some Scene {
        WindowGroup {
            Screen4(
                   WPM: 120,
                   LGBW: .constant(23),
                   elapsedTime: .constant(150),
                   wordCount: .constant(50),
                   deriative: .constant(85.0)
               )
                .environmentObject(recordingStore)
        }
    }
}
