import Foundation

enum PremiumFeature: String, CaseIterable, Identifiable {
    case unlimitedPresets
    case allTemplates
    case consistentHaptics
    case varyTiming
    case presetOverrides
    case morseHaptics
    case hapticDestination
    case fullHistory
    case allThemes
    case sessionBuilder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unlimitedPresets: "Unlimited Presets"
        case .allTemplates: "All 5 Built-in Templates"
        case .consistentHaptics: "Consistent Haptic Patterns"
        case .varyTiming: "Vary Timing"
        case .presetOverrides: "Per-Preset Sound & Haptic Overrides"
        case .morseHaptics: "Morse Code Haptics"
        case .hapticDestination: "Haptic Destination"
        case .fullHistory: "Full Session History"
        case .allThemes: "All Themes"
        case .sessionBuilder: "Session Builder"
        }
    }

    var icon: String {
        switch self {
        case .unlimitedPresets: "plus.rectangle.on.rectangle"
        case .allTemplates: "list.bullet.rectangle"
        case .consistentHaptics: "waveform.path"
        case .varyTiming: "plusminus"
        case .presetOverrides: "slider.horizontal.3"
        case .morseHaptics: "waveform"
        case .hapticDestination: "arrow.triangle.branch"
        case .fullHistory: "clock.arrow.circlepath"
        case .allThemes: "paintpalette"
        case .sessionBuilder: "arrow.triangle.2.circlepath"
        }
    }

    var subtitle: String {
        switch self {
        case .unlimitedPresets: "Unlimited presets for workouts, habits, and routines"
        case .allTemplates: "Riding Lesson, Strength, PT, Posture, Yoga"
        case .consistentHaptics: "Pick a specific haptic pattern on phone and watch"
        case .varyTiming: "Randomize buzz timing so you don't anticipate it"
        case .presetOverrides: "Customize haptics & sounds per preset"
        case .morseHaptics: "Feel your cue word tapped in Morse code"
        case .hapticDestination: "Choose where you feel the buzz — phone, watch, or both"
        case .fullHistory: "Keep your full training log"
        case .allThemes: "More color palettes, including future ones"
        case .sessionBuilder: "Chain presets into a sequence — one tap starts the whole flow"
        }
    }
}
