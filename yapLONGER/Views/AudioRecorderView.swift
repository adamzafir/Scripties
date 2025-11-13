//
//  AudioRecorderView.swift
//  yapLONGER
//
//  Created by T Krobot on 13/11/25.
//

import SwiftUI
import AVKit

struct ContentView: View {
    var body: some View {
        Home()
            .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}

struct Home: View {
    @State private var record = false
    @State private var session: AVAudioSession?
    @State private var recorder: AVAudioRecorder?
    @State private var player: AVAudioPlayer?
    @State private var currentlyPlayingURL: URL?
    @State private var alert = false
    @State private var audio = false
    @State private var audios: [URL] = []
    // Hold a strong reference to the AVAudioPlayer delegate
    @State private var playerDelegate: PlaybackDelegate?
    
    var body: some View {
        NavigationView {
            VStack {
                List(self.audios, id: \.self) { url in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(url.lastPathComponent)
                                .lineLimit(1)
                            if currentlyPlayingURL == url {
                                Text("Playing…")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        Spacer()
                        Button(action: {
                            togglePlayback(for: url)
                        }) {
                            Image(systemName: (currentlyPlayingURL == url) ? "stop.circle.fill" : "play.circle.fill")
                                .font(.system(size: 24, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        togglePlayback(for: url)
                    }
                }
                
                Button(action: {
                    if record {
                        // Stop recording
                        recorder?.stop()
                        record = false
                        getAudios()
                    } else {
                        startRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 70, height: 70)
                        if self.record {
                            Circle()
                                .stroke(Color.white, lineWidth: 6)
                                .frame(width: 85, height: 85)
                        }
                    }
                }
                .padding(.vertical, 25)
            }
            .navigationBarTitle("RecordAudio")
        }
        .alert(isPresented: self.$alert, content: {
            Alert(title: Text("Error"), message: Text("Enable Microphone Access in Settings"))
        })
        .onAppear {
            configureAudioSessionAndRequestPermission()
        }
    }
    
    private func configureAudioSessionAndRequestPermission() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            self.session = session
            
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        if !granted {
                            self.alert = true
                        } else {
                            self.getAudios()
                        }
                    }
                }
            } else {
                session.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        if !granted {
                            self.alert = true
                        } else {
                            self.getAudios()
                        }
                    }
                }
            }
        } catch {
            print("Audio session error: \(error.localizedDescription)")
        }
    }
    
    private func startRecording() {
        // Stop any playback before recording
        stopPlayback()
        
        do {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = docs.appendingPathComponent("myRcd\(self.audios.count + 1).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let newRecorder = try AVAudioRecorder(url: fileName, settings: settings)
            newRecorder.prepareToRecord()
            newRecorder.record()
            self.recorder = newRecorder
            self.record = true
        } catch {
            print("Start recording error: \(error.localizedDescription)")
        }
    }
    
    private func getAudios() {
        do {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let result = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
            self.audios = result
                .filter { $0.pathExtension.lowercased() == "m4a" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            print("List audios error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Playback
    
    private func togglePlayback(for url: URL) {
        // If tapping the currently playing item, stop
        if currentlyPlayingURL == url {
            stopPlayback()
            return
        }
        // Otherwise, start playing the selected URL
        startPlayback(url: url)
    }
    
    private func startPlayback(url: URL) {
        // Don’t play while recording
        guard !record else { return }
        
        do {
            // Configure session for playback while still allowing recording category
            try session?.setActive(true)
            
            // Stop any previous playback
            stopPlayback()
            
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.prepareToPlay()
            
            // Set up delegate using a strong reference
            let delegate = PlaybackDelegate(onFinish: {
                // No weak capture needed; Home is a struct and this closure
                // does not create a retain cycle with AVAudioPlayer.
                stopPlayback()
            })
            self.playerDelegate = delegate
            newPlayer.delegate = delegate
            
            newPlayer.play()
            self.player = newPlayer
            self.currentlyPlayingURL = url
        } catch {
            print("Playback error: \(error.localizedDescription)")
            stopPlayback()
        }
    }
    
    private func stopPlayback() {
        player?.stop()
        player = nil
        currentlyPlayingURL = nil
        // Release delegate when stopping
        playerDelegate = nil
    }
}

// A small helper to handle AVAudioPlayerDelegate without making Home conform directly.
private final class PlaybackDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
