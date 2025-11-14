import Foundation
import AVFoundation
import SwiftUI
import Combine

@MainActor
final class RecordingStore: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var latestRecordingURL: URL? = nil
    @Published var permissionDenied: Bool = false
    
    private var session: AVAudioSession = .sharedInstance()
    private var recorder: AVAudioRecorder?
    private var recordedCount: Int = 0
    
    init() {
        Task { await configureSessionIfNeeded() }
        // Seed count from existing files so names increment
        recordedCount = (try? FileManager.default
            .contentsOfDirectory(at: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0],
                                 includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension.lowercased() == "m4a" }
            .count ?? 0
    }
    
    func requestPermissionIfNeeded() async {
        if #available(iOS 17.0, *) {
            let granted = await AVAudioApplication.requestRecordPermission()
            permissionDenied = !granted
        } else {
            await withCheckedContinuation { cont in
                session.requestRecordPermission { granted in
                    Task { @MainActor in
                        self.permissionDenied = !granted
                        cont.resume()
                    }
                }
            }
        }
    }
    
    func configureSessionIfNeeded() async {
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("RecordingStore session error: \(error.localizedDescription)")
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        Task {
            await requestPermissionIfNeeded()
            guard !permissionDenied else { return }
            await configureSessionIfNeeded()
            do {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                recordedCount += 1
                let fileURL = docs.appendingPathComponent("myRcd\(recordedCount).m4a")
                
                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 12_000,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
                
                let rec = try AVAudioRecorder(url: fileURL, settings: settings)
                rec.prepareToRecord()
                rec.record()
                recorder = rec
                isRecording = true
            } catch {
                print("Recording start error: \(error.localizedDescription)")
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        recorder?.stop()
        latestRecordingURL = recorder?.url
        recorder = nil
        isRecording = false
    }
}
