import SwiftUI

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case coachAuthority
    case activeRecovery
    case darkAcademia
    case mysticGrove
    case runestone
    case dailyRitual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .coachAuthority: "Coach's Authority"
        case .activeRecovery: "Active Recovery"
        case .darkAcademia: "Dark Academia"
        case .mysticGrove: "Mystic Grove"
        case .runestone: "Runestone"
        case .dailyRitual: "Daily Ritual"
        }
    }

    // MARK: - Colors

    var primary: Color {
        switch self {
        case .coachAuthority: Color(hex: 0x1B2D4F)
        case .activeRecovery: Color(hex: 0x0A5E5C)
        case .darkAcademia:   Color(hex: 0x2C1810)
        case .mysticGrove:    Color(hex: 0x1A3A3A)
        case .runestone:      Color(hex: 0x3B3236)
        case .dailyRitual:    Color(hex: 0x2D2B3D)
        }
    }

    var accent: Color {
        switch self {
        case .coachAuthority: Color(hex: 0xD4932A)
        case .activeRecovery: Color(hex: 0xE07A5F)
        case .darkAcademia:   Color(hex: 0x8B4513)
        case .mysticGrove:    Color(hex: 0x4ECDC4)
        case .runestone:      Color(hex: 0xC4956A)
        case .dailyRitual:    Color(hex: 0x7C6BC4)
        }
    }

    var background: Color {
        switch self {
        case .coachAuthority: Color(hex: 0xF5F0EB)
        case .activeRecovery: Color(hex: 0xF7F5F2)
        case .darkAcademia:   Color(hex: 0xF2E8DC)
        case .mysticGrove:    Color(hex: 0xE8F4F2)
        case .runestone:      Color(hex: 0xF0EDEB)
        case .dailyRitual:    Color(hex: 0xF0EEF6)
        }
    }

    var watchBackground: Color {
        switch self {
        case .coachAuthority: Color(hex: 0x1B2D4F)
        case .activeRecovery: Color(hex: 0x0A2E2D)
        case .darkAcademia:   Color(hex: 0x1A0F09)
        case .mysticGrove:    Color(hex: 0x0D2626)
        case .runestone:      Color(hex: 0x1E191B)
        case .dailyRitual:    Color(hex: 0x16152A)
        }
    }

    var secondaryText: Color {
        switch self {
        case .coachAuthority: Color(hex: 0x7A8199)
        case .activeRecovery: Color(hex: 0x6B8A89)
        case .darkAcademia:   Color(hex: 0x8C7B6B)
        case .mysticGrove:    Color(hex: 0x6A9E9A)
        case .runestone:      Color(hex: 0x8A7E82)
        case .dailyRitual:    Color(hex: 0x8986A0)
        }
    }

    var watchSecondaryText: Color {
        switch self {
        case .coachAuthority: Color(hex: 0x8A9BBF)
        case .activeRecovery: Color(hex: 0x5FA8A6)
        case .darkAcademia:   Color(hex: 0x9E8A78)
        case .mysticGrove:    Color(hex: 0x5BBFB8)
        case .runestone:      Color(hex: 0xA09498)
        case .dailyRitual:    Color(hex: 0x9B98B5)
        }
    }

    var success: Color {
        switch self {
        case .coachAuthority: Color(hex: 0x2E8B57)
        case .activeRecovery: Color(hex: 0x4A9B7F)
        case .darkAcademia:   Color(hex: 0x5E8C61)
        case .mysticGrove:    Color(hex: 0x3EAF8A)
        case .runestone:      Color(hex: 0x6B9E6B)
        case .dailyRitual:    Color(hex: 0x5E9B76)
        }
    }

    var cardBackground: Color {
        switch self {
        case .coachAuthority: Color(hex: 0xFFFFFF)
        case .activeRecovery: Color(hex: 0xFFFFFF)
        case .darkAcademia:   Color(hex: 0xFAF5EE)
        case .mysticGrove:    Color(hex: 0xF5FDFB)
        case .runestone:      Color(hex: 0xFAF8F7)
        case .dailyRitual:    Color(hex: 0xF9F7FF)
        }
    }

    var pillBackground: Color {
        switch self {
        case .coachAuthority: Color(hex: 0xE8E3DD)
        case .activeRecovery: Color(hex: 0xE5EDEC)
        case .darkAcademia:   Color(hex: 0xE6D9CA)
        case .mysticGrove:    Color(hex: 0xD5EAE7)
        case .runestone:      Color(hex: 0xE3DFDD)
        case .dailyRitual:    Color(hex: 0xE2DFEE)
        }
    }

    var onAccent: Color { .white }

    var destructive: Color {
        Color(hex: 0x8B3A3A)
    }

    #if os(iOS)
    var uiBackgroundColor: UIColor {
        switch self {
        case .coachAuthority: UIColor(red: 0xF5/255.0, green: 0xF0/255.0, blue: 0xEB/255.0, alpha: 1)
        case .activeRecovery: UIColor(red: 0xF7/255.0, green: 0xF5/255.0, blue: 0xF2/255.0, alpha: 1)
        case .darkAcademia:   UIColor(red: 0xF2/255.0, green: 0xE8/255.0, blue: 0xDC/255.0, alpha: 1)
        case .mysticGrove:    UIColor(red: 0xE8/255.0, green: 0xF4/255.0, blue: 0xF2/255.0, alpha: 1)
        case .runestone:      UIColor(red: 0xF0/255.0, green: 0xED/255.0, blue: 0xEB/255.0, alpha: 1)
        case .dailyRitual:    UIColor(red: 0xF0/255.0, green: 0xEE/255.0, blue: 0xF6/255.0, alpha: 1)
        }
    }
    #endif
}

// MARK: - Color hex initializer

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
