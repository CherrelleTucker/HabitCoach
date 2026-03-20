import SwiftUI

@MainActor @Observable
class ThemeManager {
    var current: AppTheme {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: "selectedTheme")
        }
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: saved) {
            self.current = theme
        } else {
            self.current = .coachAuthority
        }
    }
}

// MARK: - Environment key

private struct ThemeManagerKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = ThemeManager()
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}
