#if os(watchOS)
import Foundation
import WatchConnectivity
import SwiftUI
import Combine

struct WatchScript: Identifiable, Codable {
    var id: UUID
    var title: String
    var scriptText: String
    var lastAccessed: Date
}

struct WatchReview: Identifiable, Codable {
    var id: UUID
    var cis: Int
    var wpm: Int
    var audioURL: URL?
    var date: Date

    init(id: UUID = UUID(), cis: Int, wpm: Int, audioURL: URL? = nil, date: Date = Date()) {
        self.id = id
        self.cis = cis
        self.wpm = wpm
        self.audioURL = audioURL
        self.date = date
    }
}

@MainActor
final class WatchSessionManager: NSObject, WCSessionDelegate, ObservableObject {
    @Published var scripts: [WatchScript] = []
    @Published var isReachable: Bool = false

    private let session: WCSession = WCSession.default

    override init() {
        super.init()
        session.delegate = self
        session.activate()
        // Do not request here; wait for activationDidComplete to avoid lost messages.
    }

    // Call this from your Refresh button
    func requestScriptsIfNeeded() {
        // Prefer a live message with reply if reachable
        if session.isReachable {
            session.sendMessage(
                ["type": "requestScripts"],
                replyHandler: { [weak self] reply in
                    guard let data = reply["scripts"] as? Data,
                          let decoded = try? JSONDecoder().decode([WatchScript].self, from: data)
                    else { return }
                    Task { @MainActor in
                        self?.scripts = decoded.sorted { $0.lastAccessed > $1.lastAccessed }
                    }
                },
                errorHandler: { error in
                    // Fallback to background path if live message fails
                    self.session.transferUserInfo(["type": "requestScripts"])
                }
            )
        } else {
            // Background request; iPhone should answer by pushing applicationContext or userInfo with scripts
            session.transferUserInfo(["type": "requestScripts"])
        }
    }

    func send(review: WatchReview, for script: WatchScript) {
        let payload: [String: Any] = [
            "type": "review",
            "scriptID": script.id.uuidString,
            "reviewID": review.id.uuidString,
            "cis": review.cis,
            "wpm": review.wpm,
            "date": review.date.timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: { error in
                print("Review send error: \(error.localizedDescription)")
            })
        } else {
            session.transferUserInfo(payload)
        }

        if let audioURL = review.audioURL, FileManager.default.fileExists(atPath: audioURL.path) {
            let metadata = [
                "scriptID": script.id.uuidString,
                "reviewID": review.id.uuidString
            ]
            session.transferFile(audioURL, metadata: metadata)
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let reachable = session.isReachable
        let isActivated = (activationState == .activated)

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isReachable = reachable
            if isActivated {
                // Now safe to request
                self.requestScriptsIfNeeded()
            }
        }
    }

    nonisolated
    func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isReachable = reachable
        }
    }

    // Receive current-state pushes from iPhone
    nonisolated
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        guard let data = applicationContext["scripts"] as? Data else { return }
        let decoded = try? JSONDecoder().decode([WatchScript].self, from: data)
        Task { @MainActor [weak self] in
            guard let self, let decoded else { return }
            self.scripts = decoded.sorted { $0.lastAccessed > $1.lastAccessed }
        }
    }

    // Receive background pushes from iPhone
    nonisolated
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        guard let data = userInfo["scripts"] as? Data else { return }
        let decoded = try? JSONDecoder().decode([WatchScript].self, from: data)
        Task { @MainActor [weak self] in
            guard let self, let decoded else { return }
            self.scripts = decoded.sorted { $0.lastAccessed > $1.lastAccessed }
        }
    }

    // Receive live replies/messages with scripts
    nonisolated
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let data = message["scripts"] as? Data,
           let decoded = try? JSONDecoder().decode([WatchScript].self, from: data) {
            Task { @MainActor [weak self] in
                self?.scripts = decoded.sorted { $0.lastAccessed > $1.lastAccessed }
            }
        }
    }

    nonisolated
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        // If the watch ever needs to respond, implement here. For now, just ack.
        replyHandler([:])
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {}
    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) { replyHandler(Data()) }
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {}
}
#endif
