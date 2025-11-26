//
//  ContentView.swift
//  Scripties Watchos Watch App
//
//  Created by Adam Zafir on 11/22/25.
//

import SwiftUI
#if os(watchOS)

struct ContentView: View {
    @EnvironmentObject private var connectivity: WatchSessionManager

    var body: some View {
        NavigationStack {
            List {
                if connectivity.scripts.isEmpty {
                    ContentUnavailableView("No Scripts", systemImage: "list.bullet.rectangle")
                }

                ForEach(connectivity.scripts) { script in
                    NavigationLink {
                        WatchTeleprompterView(connectivity: connectivity, script: script)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(script.title)
                            Text(script.lastAccessed, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button {
                        connectivity.requestScriptsIfNeeded()
                    } label: {
                        Label("Refresh from iPhone", systemImage: "arrow.clockwise")
                    }
                }
            }
            .navigationTitle("Scripts")
            .onAppear {
                connectivity.requestScriptsIfNeeded()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchSessionManager())
}
#endif
