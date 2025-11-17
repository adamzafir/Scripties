import SwiftUI

@main
struct yapLONGERApp: App {
    @StateObject private var recordingStore = RecordingStore()
    @StateObject private var scriptsViewModel = Screen2ViewModel()
    
    var body: some Scene {
        WindowGroup {
           TabHolder()
                .environmentObject(recordingStore)
                .environmentObject(scriptsViewModel)
        }
    }
}

