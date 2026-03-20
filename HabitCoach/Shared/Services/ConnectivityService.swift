import Foundation
import WatchConnectivity
import os.log

private let logger = Logger(subsystem: "com.ctuckersolutions.habitcoach", category: "Connectivity")

@MainActor @Observable
class ConnectivityService: NSObject, WCSessionDelegate {
    static let shared = ConnectivityService()
    private var wcSession: WCSession?

    // Incoming data — observed by ViewModels
    var receivedProfiles: [SessionProfile]?
    var receivedCommand: (command: String, profile: SessionProfile?)?
    var receivedSession: Session?
    var receivedSettings: SessionSettings?
    var receivedSequences: [SessionSequence]?
    var receivedSequenceCommand: (command: String, sequence: SessionSequence?)?

    var isReachable: Bool { wcSession?.isReachable ?? false }

    override init() {
        super.init()
        if WCSession.isSupported() {
            wcSession = WCSession.default
            wcSession?.delegate = self
            wcSession?.activate()
        }
    }

    // MARK: - Send to Watch

    func sendProfiles(_ profiles: [SessionProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else {
            logger.error("Failed to encode profiles for sync")
            return
        }
        wcSession?.transferUserInfo(["profiles": data])
        logger.debug("Sent \(profiles.count) profiles to watch")
    }

    func sendStartCommand(profile: SessionProfile) {
        guard let data = try? JSONEncoder().encode(profile) else {
            logger.error("Failed to encode profile for start command")
            return
        }
        let message: [String: Any] = ["command": "start", "profile": data]
        wcSession?.sendMessage(message, replyHandler: nil) { error in
            logger.error("Failed to send start command: \(error.localizedDescription)")
        }
    }

    func sendStopCommand() {
        wcSession?.sendMessage(["command": "stop"], replyHandler: nil) { error in
            logger.error("Failed to send stop command: \(error.localizedDescription)")
        }
    }

    func sendSettings(_ settings: SessionSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            logger.error("Failed to encode settings for sync")
            return
        }
        wcSession?.transferUserInfo(["settings": data])
        logger.debug("Sent settings to watch")
    }

    func sendSequences(_ sequences: [SessionSequence]) {
        guard let data = try? JSONEncoder().encode(sequences) else {
            logger.error("Failed to encode sequences for sync")
            return
        }
        wcSession?.transferUserInfo(["sequences": data])
        logger.debug("Sent \(sequences.count) sequences to watch")
    }

    func sendStartSequenceCommand(sequence: SessionSequence) {
        guard let data = try? JSONEncoder().encode(sequence) else {
            logger.error("Failed to encode sequence for start command")
            return
        }
        let message: [String: Any] = ["command": "startSequence", "sequence": data]
        wcSession?.sendMessage(message, replyHandler: nil) { error in
            logger.error("Failed to send startSequence command: \(error.localizedDescription)")
        }
    }

    func sendPremiumStatus(_ isPremium: Bool) {
        wcSession?.transferUserInfo(["isPremium": isPremium])
        logger.debug("Sent premium status: \(isPremium)")
    }

    // MARK: - Send to iPhone

    func sendSession(_ session: Session) {
        guard let data = try? JSONEncoder().encode(session) else {
            logger.error("Failed to encode session for sync")
            return
        }
        wcSession?.transferUserInfo(["session": data])
        logger.debug("Sent session to iPhone")
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            logger.error("WCSession activation failed: \(error.localizedDescription)")
        } else {
            logger.info("WCSession activated: \(String(describing: activationState.rawValue))")
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        // Decode on this queue, then dispatch to MainActor
        var profiles: [SessionProfile]?
        var decodedSession: Session?
        var decodedSettings: SessionSettings?
        var premiumStatus: Bool?

        if let data = userInfo["profiles"] as? Data {
            do {
                profiles = try JSONDecoder().decode([SessionProfile].self, from: data)
                logger.debug("Received \(profiles?.count ?? 0) profiles")
            } catch {
                logger.error("Failed to decode profiles: \(error.localizedDescription)")
            }
        }
        if let data = userInfo["session"] as? Data {
            do {
                decodedSession = try JSONDecoder().decode(Session.self, from: data)
                logger.debug("Received session from watch")
            } catch {
                logger.error("Failed to decode session: \(error.localizedDescription)")
            }
        }
        if let isPremium = userInfo["isPremium"] as? Bool {
            premiumStatus = isPremium
            logger.debug("Received premium status: \(isPremium)")
        }
        var decodedSequences: [SessionSequence]?
        if let data = userInfo["sequences"] as? Data {
            do {
                decodedSequences = try JSONDecoder().decode([SessionSequence].self, from: data)
                logger.debug("Received \(decodedSequences?.count ?? 0) sequences")
            } catch {
                logger.error("Failed to decode sequences: \(error.localizedDescription)")
            }
        }
        if let data = userInfo["settings"] as? Data {
            do {
                decodedSettings = try JSONDecoder().decode(SessionSettings.self, from: data)
                logger.debug("Received settings")
            } catch {
                logger.error("Failed to decode settings: \(error.localizedDescription)")
            }
        }

        Task { @MainActor in
            if let profiles { self.receivedProfiles = profiles }
            if let decodedSession { self.receivedSession = decodedSession }
            if let decodedSettings { self.receivedSettings = decodedSettings }
            if let decodedSequences { self.receivedSequences = decodedSequences }
            if let premiumStatus {
                UserDefaults.standard.set(premiumStatus, forKey: PurchaseManager.unlockKey)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let command = message["command"] as? String else {
            logger.warning("Received message without command key")
            return
        }
        if command == "startSequence" {
            var sequence: SessionSequence?
            if let data = message["sequence"] as? Data {
                do {
                    sequence = try JSONDecoder().decode(SessionSequence.self, from: data)
                } catch {
                    logger.error("Failed to decode sequence from command: \(error.localizedDescription)")
                }
            }
            let result = (command: command, sequence: sequence)
            Task { @MainActor in
                self.receivedSequenceCommand = result
            }
        } else {
            var profile: SessionProfile?
            if let data = message["profile"] as? Data {
                do {
                    profile = try JSONDecoder().decode(SessionProfile.self, from: data)
                } catch {
                    logger.error("Failed to decode profile from command: \(error.localizedDescription)")
                }
            }
            let result = (command: command, profile: profile)
            Task { @MainActor in
                self.receivedCommand = result
            }
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
