#if os(iOS)
import AudioToolbox
import os.log

private let logger = Logger(subsystem: "com.ctuckersolutions.habitcoach", category: "AudioService")

struct AudioService {
    enum Category: String {
        case subtle
        case assertive
    }

    struct Sound: Identifiable, Equatable {
        let name: String
        let displayName: String
        let category: Category
        let systemSoundID: SystemSoundID
        var id: String { name }
    }

    static let sounds: [Sound] = [
        // Subtle
        Sound(name: "ping", displayName: "Ping", category: .subtle, systemSoundID: 1016),
        Sound(name: "tap", displayName: "Tap", category: .subtle, systemSoundID: 1104),
        Sound(name: "pop", displayName: "Pop", category: .subtle, systemSoundID: 1123),
        Sound(name: "tink", displayName: "Tink", category: .subtle, systemSoundID: 1103),
        Sound(name: "click", displayName: "Click", category: .subtle, systemSoundID: 1105),
        // Moderate
        Sound(name: "bell", displayName: "Bell", category: .subtle, systemSoundID: 1013),
        Sound(name: "chime", displayName: "Chime", category: .subtle, systemSoundID: 1008),
        Sound(name: "glass", displayName: "Glass", category: .subtle, systemSoundID: 1054),
        // Assertive
        Sound(name: "horn", displayName: "Horn", category: .assertive, systemSoundID: 1033),
        Sound(name: "alarm", displayName: "Alarm", category: .assertive, systemSoundID: 1005),
        Sound(name: "buzzer", displayName: "Buzzer", category: .assertive, systemSoundID: 1073),
        Sound(name: "alert", displayName: "Alert", category: .assertive, systemSoundID: 1072),
    ]

    static let completionSounds: [Sound] = [
        Sound(name: "fanfare", displayName: "Fanfare", category: .assertive, systemSoundID: 1025),
        Sound(name: "success", displayName: "Success", category: .subtle, systemSoundID: 1001),
        Sound(name: "done", displayName: "Done", category: .assertive, systemSoundID: 1007),
        Sound(name: "triumph", displayName: "Triumph", category: .assertive, systemSoundID: 1026),
    ]

    static let none = "none"

    static func play(_ soundName: String) {
        guard soundName != none else { return }
        let all = sounds + completionSounds
        guard let sound = all.first(where: { $0.name == soundName }) else {
            logger.warning("Sound not found: \(soundName)")
            return
        }
        AudioServicesPlaySystemSound(sound.systemSoundID)
    }

    static func preview(_ soundName: String) {
        play(soundName)
    }
}
#endif
