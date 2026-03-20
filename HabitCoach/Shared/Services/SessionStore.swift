import Foundation
import os.log

private let logger = Logger(subsystem: "com.ctuckersolutions.habitcoach", category: "SessionStore")

@MainActor @Observable
class SessionStore {
    private static let storageKey = "saved_sessions"
    private static let maxSessions = 500

    var sessions: [Session] = []

    init() {
        load()
    }

    func save(_ session: Session) {
        sessions.insert(session, at: 0)
        // Trim to prevent unbounded growth
        if sessions.count > Self.maxSessions {
            sessions = Array(sessions.prefix(Self.maxSessions))
        }
        persist()
    }

    func delete(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
        persist()
    }

    func clearAll() {
        sessions.removeAll()
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            logger.error("Failed to encode sessions: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        do {
            sessions = try JSONDecoder().decode([Session].self, from: data)
        } catch {
            logger.error("Failed to decode sessions: \(error.localizedDescription)")
        }
    }
}
