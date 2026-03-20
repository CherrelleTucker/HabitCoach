import Foundation
import os.log

private let logger = Logger(subsystem: "com.ctuckersolutions.habitcoach", category: "SettingsStore")

enum HapticMode: String, Codable, Equatable {
    case randomized
    case consistent
    case morse
}

enum HapticDestination: String, Codable, Equatable, CaseIterable, Identifiable {
    case iPhone
    case watch
    case both

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .iPhone: "iPhone"
        case .watch: "Apple Watch"
        case .both: "iPhone + Watch"
        }
    }

    var icon: String {
        switch self {
        case .iPhone: "iphone"
        case .watch: "applewatch"
        case .both: "iphone.and.arrow.forward"
        }
    }
}

struct SessionSettings: Codable, Equatable {
    var hapticMode: HapticMode = .randomized
    var hapticPattern: HapticPattern = .notification
    var hapticDestination: HapticDestination = .iPhone
    var intervalSound: String = "none"
    var completionSound: String = "done"
    var focusReminderEnabled: Bool = true
}

@MainActor @Observable
class SettingsStore {
    private static let storageKey = "session_settings"

    var settings: SessionSettings = SessionSettings()

    init() {
        load()
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
            #if os(iOS)
            ConnectivityService.shared.sendSettings(settings)
            #endif
        } catch {
            logger.error("Failed to encode settings: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        do {
            settings = try JSONDecoder().decode(SessionSettings.self, from: data)
        } catch {
            logger.error("Failed to decode settings: \(error.localizedDescription)")
        }
    }
}
