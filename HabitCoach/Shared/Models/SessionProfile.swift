import Foundation

struct SessionProfile: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var icon: String = "figure.mixed.cardio"
    var intervalSeconds: Int
    var varianceSeconds: Int = 0
    var endCondition: SessionEndCondition = .unlimited
    var notes: String = ""
    var hapticModeOverride: HapticMode? = nil
    var hapticPatternOverride: HapticPattern? = nil
    var intervalSoundOverride: String? = nil
    var completionSoundOverride: String? = nil
    var morseWord: String? = nil
    var hapticDestinationOverride: HapticDestination? = nil
    var createdAt: Date = Date()
    var isTemplate: Bool = false
    var showOnTimer: Bool = true

    var formattedInterval: String {
        if intervalSeconds >= 60 {
            let m = intervalSeconds / 60
            let s = intervalSeconds % 60
            return s > 0 ? "\(m)m \(s)s" : "\(m)m"
        }
        return "\(intervalSeconds)s"
    }

    var formattedEndCondition: String {
        switch endCondition {
        case .unlimited: return "No limit"
        case .afterCount(let n): return "\(n) reminders"
        case .afterDuration(let s):
            if s >= 3600 { return "\(s / 3600) hr" }
            return "\(s / 60) min"
        }
    }

    // MARK: - Resolved Settings (override or global default)

    func resolvedHapticMode(defaults: SessionSettings) -> HapticMode {
        hapticModeOverride ?? defaults.hapticMode
    }

    func resolvedHapticPattern(defaults: SessionSettings) -> HapticPattern {
        hapticPatternOverride ?? defaults.hapticPattern
    }

    func resolvedHapticDestination(defaults: SessionSettings) -> HapticDestination {
        hapticDestinationOverride ?? defaults.hapticDestination
    }

    func resolvedIntervalSound(defaults: SessionSettings) -> String {
        intervalSoundOverride ?? defaults.intervalSound
    }

    func resolvedCompletionSound(defaults: SessionSettings) -> String {
        completionSoundOverride ?? defaults.completionSound
    }

    var resolvedMorseWord: String {
        let word = morseWord?.trimmingCharacters(in: .whitespaces) ?? ""
        return word.isEmpty ? MorsePlayer.defaultWord(from: name) : word.uppercased()
    }

    // MARK: - Free vs Premium

    static let freeTemplateNames: Set<String> = ["Strength Circuit", "Posture Check"]

    var isFreeTemplate: Bool {
        isTemplate && Self.freeTemplateNames.contains(name)
    }

    // MARK: - Default Templates

    static let templates: [SessionProfile] = [
        SessionProfile(
            name: "Riding Lesson",
            icon: "figure.equestrian.sports",
            intervalSeconds: 120,        // every 2 min
            varianceSeconds: 30,          // ± 30s so it feels natural
            endCondition: .afterDuration(3600), // 1 hr lesson
            notes: "Posture check: heels down, shoulders back, soft hands"
        ),
        SessionProfile(
            name: "Strength Circuit",
            icon: "dumbbell.fill",
            intervalSeconds: 45,          // 45s sets
            varianceSeconds: 0,           // precise timing for circuits
            endCondition: .afterCount(15), // 15 rounds ≈ 3 sets of 5 exercises
            notes: "Rest on the buzz, go on the next"
        ),
        SessionProfile(
            name: "PT Exercises",
            icon: "figure.strengthtraining.traditional",
            intervalSeconds: 30,          // 30s per exercise
            varianceSeconds: 0,
            endCondition: .afterCount(10), // 10 exercises
            notes: "Hold each stretch/exercise until the next buzz"
        ),
        SessionProfile(
            name: "Posture Check",
            icon: "figure.stand",
            intervalSeconds: 300,         // every 5 min
            varianceSeconds: 60,          // ± 1 min
            endCondition: .afterDuration(7200), // 2 hrs (desk work)
            notes: "Sit up straight, relax shoulders, unclench jaw"
        ),
        SessionProfile(
            name: "Yoga Flow",
            icon: "figure.yoga",
            intervalSeconds: 60,          // 1 min per pose
            varianceSeconds: 15,
            endCondition: .afterDuration(1800), // 30 min
            notes: "Transition to next pose on the buzz"
        ),
    ]
}
