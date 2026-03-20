import Foundation

enum HapticPattern: String, Codable, CaseIterable, Identifiable {
    case notification
    case click
    case success
    case directionUp
    case retry

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notification: "Strong Tap"
        case .click: "Light Tap"
        case .success: "Confirmation"
        case .directionUp: "Encouraging"
        case .retry: "Gentle Nudge"
        }
    }
}
