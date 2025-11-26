//
//  Scripties_WatchosApp.swift
//  Scripties Watchos Watch App
//
//  Created by Adam Zafir on 11/22/25.
//

import SwiftUI
#if os(watchOS)

@main
struct Scripties_Watchos_Watch_AppApp: App {
    @StateObject private var connectivity = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivity)
        }
    }
}
#endif
