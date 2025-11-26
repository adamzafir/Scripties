import Foundation
import SwiftUI
import Combine
import WatchConnectivity

struct Review: Identifiable, Codable {
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        cis = (try? container.decode(Int.self, forKey: .cis)) ?? 0
        wpm = (try? container.decode(Int.self, forKey: .wpm)) ?? 0
        audioURL = try? container.decode(URL.self, forKey: .audioURL)
        date = (try? container.decode(Date.self, forKey: .date)) ?? Date()
    }
}

struct Reviews: Identifiable, Codable  {
    var id: UUID
    var reviewsItems: [Review] = []

    init(id: UUID = UUID(), reviewsItems: [Review] = []) {
        self.id = id
        self.reviewsItems = reviewsItems
    }
}

struct ScriptSummary: Identifiable, Codable {
    var id: UUID
    var title: String
    var scriptText: String
    var lastAccessed: Date
}

struct ScriptItem: Identifiable, Codable {
    var id: UUID
    var title: String
    var scriptText: String
    var lastAccessed: Date
    var pastReviews: Reviews

    init(
        id: UUID = UUID(),
        title: String,
        scriptText: String,
        lastAccessed: Date = Date(),
        pastReviews: Reviews = Reviews(id: UUID(), reviewsItems: [])
    ) {
        self.id = id
        self.title = title
        self.scriptText = scriptText
        self.lastAccessed = lastAccessed
        self.pastReviews = pastReviews
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        title = (try? container.decode(String.self, forKey: .title)) ?? "Untitled Script"
        scriptText = (try? container.decode(String.self, forKey: .scriptText)) ?? ""
        lastAccessed = (try? container.decode(Date.self, forKey: .lastAccessed)) ?? Date.distantPast

        if let decodedReviews = try? container.decode(Reviews.self, forKey: .pastReviews) {
            pastReviews = decodedReviews
        } else {
            pastReviews = Reviews(id: UUID(), reviewsItems: [])
        }
    }
}

class Screen2ViewModel: NSObject, ObservableObject {
    @Published var scriptItems: [ScriptItem] = [
    ]
    
    private var untitledCount: Int = 0
    private var cancellables = Set<AnyCancellable>()
    private let fileURL: URL
    private var watchSession: WCSession? = WCSession.isSupported() ? .default : nil

    override init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("scripts.json")
        super.init()
        
        load()
        sortByRecency()
        activateWatchSession()
        sendScriptsToWatch()
        
        $scriptItems
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.sortByRecency()
                self?.save()
                self?.sendScriptsToWatch()
            }
            .store(in: &cancellables)
    }

    func addNewScriptAtFront(title: String? = nil, scriptText: String = "") {
        let providedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle: String
        if let t = providedTitle, !t.isEmpty {
            finalTitle = t
        } else {
            if untitledCount == 0 {
                finalTitle = "Untitled Script"
            } else {
                finalTitle = "Untitled Script \(untitledCount + 1)"
            }
            untitledCount += 1
        }

        let newItem = ScriptItem(
            id: UUID(),
            title: finalTitle,
            scriptText: scriptText,
            lastAccessed: Date(),
            pastReviews: Reviews(id: UUID(), reviewsItems: [])
        )
        scriptItems.insert(newItem, at: 0)
        sortByRecency()
        save()
    }
    
    func markAccessed(id: UUID) {
        guard let idx = scriptItems.firstIndex(where: { $0.id == id }) else { return }
        scriptItems[idx].lastAccessed = Date()
        sortByRecency()
        save()
    }
    
    func updateScript(id: UUID, title: String? = nil, scriptText: String? = nil) {
        guard let idx = scriptItems.firstIndex(where: { $0.id == id }) else { return }
        if let title { scriptItems[idx].title = title }
        if let scriptText { scriptItems[idx].scriptText = scriptText }
        scriptItems[idx].lastAccessed = Date()
        sortByRecency()
        save()
    }
    
    func appendReview(to scriptID: UUID, cis: Int, wpm: Int, audioURL: URL?) {
        guard let idx = scriptItems.firstIndex(where: { $0.id == scriptID }) else { return }
        let review = Review(id: UUID(), cis: cis, wpm: wpm, audioURL: audioURL, date: Date())
        insert(review: review, into: idx)
    }

    func appendReview(_ review: Review, to scriptID: UUID) {
        guard let idx = scriptItems.firstIndex(where: { $0.id == scriptID }) else { return }
        insert(review: review, into: idx)
    }

    private func insert(review: Review, into index: Int) {
        scriptItems[index].pastReviews.reviewsItems.insert(review, at: 0)
        scriptItems[index].pastReviews.reviewsItems.sort { $0.date > $1.date }
        scriptItems[index].lastAccessed = Date()
        save()
    }
    
    private func sortByRecency() {
        scriptItems.sort { $0.lastAccessed > $1.lastAccessed }
    }
    
    // MARK: - Persistence
    
    func save() {
        do {
            let data = try JSONEncoder().encode(scriptItems)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("Failed to save scripts: \(error.localizedDescription)")
        }
    }
    
    func load() {
        do {
            let fm = FileManager.default
            guard fm.fileExists(atPath: fileURL.path) else { return }
            let data = try Data(contentsOf: fileURL)
            if let decoded = try? JSONDecoder().decode([ScriptItem].self, from: data) {
                self.scriptItems = normalizeScripts(decoded)
            } else {
                struct OldScriptItem: Identifiable, Codable {
                    var id: UUID
                    var title: String
                    var scriptText: String
                }
                let old = try JSONDecoder().decode([OldScriptItem].self, from: data)
                self.scriptItems = old.map {
                    ScriptItem(
                        id: $0.id,
                        title: $0.title,
                        scriptText: $0.scriptText,
                        lastAccessed: Date.distantPast,
                        pastReviews: Reviews(id: UUID(), reviewsItems: [])
                    )
                }
                save()
            }
            sortByRecency()
            let untitledBase = "Untitled Script"
            let maxSuffix = scriptItems.compactMap { item -> Int? in
                if item.title == untitledBase { return 1 }
                if item.title.hasPrefix(untitledBase + " ") {
                    let suffix = item.title.dropFirst((untitledBase + " ").count)
                    return Int(suffix)
                }
                return nil
            }.max() ?? 0
            self.untitledCount = max(0, maxSuffix)
        } catch {
            print("Failed to load scripts: \(error.localizedDescription)")
        }
    }

    private func normalizeScripts(_ scripts: [ScriptItem]) -> [ScriptItem] {
        scripts.map { item in
            var script = item
            script.pastReviews.reviewsItems.sort { $0.date > $1.date }
            return script
        }
    }
}

// MARK: - Watch Connectivity
extension Screen2ViewModel: WCSessionDelegate {
    private func activateWatchSession() {
        guard let watchSession, WCSession.isSupported() else { return }
        watchSession.delegate = self
        watchSession.activate()
    }

    private func scriptsData() -> Data? {
        let summaries = scriptItems.map { ScriptSummary(id: $0.id, title: $0.title, scriptText: $0.scriptText, lastAccessed: $0.lastAccessed) }
        return try? JSONEncoder().encode(summaries)
    }

    private func sendScriptsToWatch() {
        guard let watchSession, watchSession.isPaired, watchSession.isWatchAppInstalled else {
            return
        }
        guard let data = scriptsData() else { return }

        let byteCount = data.count
        print("WC: pushing scripts (\(byteCount) bytes)")

        // If the watch app is in the foreground, push immediately.
        if watchSession.isReachable {
            watchSession.sendMessage(["scripts": data], replyHandler: nil) { error in
                print("WC sendMessage error: \(error.localizedDescription)")
            }
        }

        // Keep background/queued paths too.
        do {
            try watchSession.updateApplicationContext(["scripts": data])
        } catch {
            print("WC updateApplicationContext error: \(error.localizedDescription)")
        }

        // Also transfer as userInfo for background delivery.
        watchSession.transferUserInfo(["type": "scripts", "scripts": data])
    }

    // iOS 13+: activation completion (iOS)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("WC iOS activation: \(activationState.rawValue) error: \(error?.localizedDescription ?? "none")")
        if activationState == .activated {
            sendScriptsToWatch()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    // Reachability changed: if the watch app just came to foreground, push immediately.
    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            sendScriptsToWatch()
        }
    }

    // Watch state changed (e.g., app installed later) — try again.
    func sessionWatchStateDidChange(_ session: WCSession) {
        sendScriptsToWatch()
    }

    // Live message without reply (legacy callers)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let type = message["type"] as? String else { return }
        if type == "requestScripts" {
            DispatchQueue.main.async { self.sendScriptsToWatch() }
        } else if type == "review" {
            handleReviewPayload(message)
        }
    }

    // Live message with reply (watch prefers this when reachable)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        guard let type = message["type"] as? String else {
            replyHandler([:])
            return
        }
        if type == "requestScripts" {
            if let data = scriptsData() {
                replyHandler(["scripts": data])
            } else {
                replyHandler([:])
            }
        } else if type == "review" {
            handleReviewPayload(message)
            replyHandler([:]) // ack
        } else {
            replyHandler([:])
        }
    }

    // Background request from watch
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        if let type = userInfo["type"] as? String, type == "requestScripts" {
            DispatchQueue.main.async { self.sendScriptsToWatch() }
        } else {
            handleReviewPayload(userInfo)
        }
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard
            let meta = file.metadata,
            let scriptIDString = meta["scriptID"] as? String,
            let reviewIDString = meta["reviewID"] as? String,
            let scriptID = UUID(uuidString: scriptIDString),
            let reviewID = UUID(uuidString: reviewIDString)
        else { return }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent(file.fileURL.lastPathComponent)

        do {
            // fileExists only has a path-based API
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: file.fileURL, to: dest)

            DispatchQueue.main.async {
                self.attachAudio(url: dest, reviewID: reviewID, scriptID: scriptID)
            }
        } catch {
            print("Failed to persist audio from watch: \(error.localizedDescription)")
        }
    }

    private func handleReviewPayload(_ message: [String: Any]) {
        guard let type = message["type"] as? String, type == "review" else { return }
        guard
            let scriptIDString = message["scriptID"] as? String,
            let scriptID = UUID(uuidString: scriptIDString),
            let cis = message["cis"] as? Int,
            let wpm = message["wpm"] as? Int
        else { return }

        let reviewID = UUID(uuidString: message["reviewID"] as? String ?? "") ?? UUID()
        let dateInterval = message["date"] as? TimeInterval ?? Date().timeIntervalSince1970
        let review = Review(id: reviewID, cis: cis, wpm: wpm, audioURL: nil, date: Date(timeIntervalSince1970: dateInterval))
        DispatchQueue.main.async {
            self.appendReview(review, to: scriptID)
        }
    }

    private func attachAudio(url: URL, reviewID: UUID, scriptID: UUID) {
        guard let scriptIndex = scriptItems.firstIndex(where: { $0.id == scriptID }) else { return }
        if let reviewIndex = scriptItems[scriptIndex].pastReviews.reviewsItems.firstIndex(where: { $0.id == reviewID }) {
            scriptItems[scriptIndex].pastReviews.reviewsItems[reviewIndex].audioURL = url
            save()
        }
    }
}
