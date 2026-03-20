import Foundation
#if os(iOS)
import UIKit
import AudioToolbox
#endif

@MainActor @Observable
class TimerViewModel {
    let timerService = TimerService()
    var sessionStore: SessionStore?
    var settingsStore: SettingsStore?
    var selectedProfile: SessionProfile?
    private var sessionStartedAt: Date?

    // Interval
    enum IntervalMode: Hashable {
        case preset(Int)
        case custom
    }
    var intervalMode: IntervalMode = .preset(60)
    var customMinutes: Int = 1
    var customSeconds: Int = 30

    var effectiveIntervalSeconds: Int {
        switch intervalMode {
        case .preset(let s): return s
        case .custom: return customMinutes * 60 + customSeconds
        }
    }

    // Variance
    var randomizeEnabled: Bool = false
    var varianceSeconds: Int = 15

    // End condition
    enum EndMode: Hashable {
        case unlimited
        case count(Int)
        case duration(Int)
    }
    var endMode: EndMode = .unlimited

    var effectiveEndCondition: SessionEndCondition {
        switch endMode {
        case .unlimited: return .unlimited
        case .count(let n): return .afterCount(n)
        case .duration(let s): return .afterDuration(s)
        }
    }

    // Display
    var formattedElapsed: String {
        let minutes = timerService.elapsedSeconds / 60
        let seconds = timerService.elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedNextBuzz: String {
        "~\(timerService.secondsUntilNextBuzz)s"
    }

    static let presets: [(label: String, seconds: Int)] = [
        ("30s", 30), ("1m", 60), ("2m", 120), ("5m", 300), ("10m", 600),
    ]

    static let endOptions: [(label: String, mode: EndMode)] = [
        ("\u{221E}", .unlimited), ("5\u{00D7}", .count(5)), ("10\u{00D7}", .count(10)),
        ("15 min", .duration(900)), ("30 min", .duration(1800)), ("1 hr", .duration(3600)),
    ]

    func loadProfile(_ profile: SessionProfile) {
        selectedProfile = profile

        let isPreset = Self.presets.contains { $0.seconds == profile.intervalSeconds }
        if isPreset {
            intervalMode = .preset(profile.intervalSeconds)
        } else {
            intervalMode = .custom
            customMinutes = profile.intervalSeconds / 60
            customSeconds = profile.intervalSeconds % 60
        }

        randomizeEnabled = profile.varianceSeconds > 0
        varianceSeconds = max(profile.varianceSeconds, 15)

        switch profile.endCondition {
        case .unlimited: endMode = .unlimited
        case .afterCount(let n): endMode = .count(n)
        case .afterDuration(let s): endMode = .duration(s)
        }
    }

    func clearProfile() {
        selectedProfile = nil
    }

    func startOnWatch() {
        let profile = SessionProfile(
            name: selectedProfile?.name ?? "Quick Session",
            icon: selectedProfile?.icon ?? "bolt.fill",
            intervalSeconds: effectiveIntervalSeconds,
            varianceSeconds: randomizeEnabled ? varianceSeconds : 0,
            endCondition: effectiveEndCondition
        )
        ConnectivityService.shared.sendStartCommand(profile: profile)
    }

    func start(destination: HapticDestination = .iPhone) {
        // If watch-only, delegate entirely to the watch
        if destination == .watch {
            startOnWatch()
            return
        }

        // If "both", also send start command to watch
        if destination == .both {
            startOnWatch()
        }

        sessionStartedAt = Date()
        let defaults = settingsStore?.settings ?? SessionSettings()
        let intervalSound = selectedProfile?.resolvedIntervalSound(defaults: defaults) ?? defaults.intervalSound
        let hapticMode = selectedProfile?.resolvedHapticMode(defaults: defaults) ?? defaults.hapticMode
        let fixedPattern = selectedProfile?.resolvedHapticPattern(defaults: defaults) ?? defaults.hapticPattern
        let morseWord = selectedProfile?.resolvedMorseWord ?? "BUZZ"

        timerService.start(
            intervalSeconds: effectiveIntervalSeconds,
            varianceSeconds: randomizeEnabled ? varianceSeconds : 0,
            endCondition: effectiveEndCondition
        ) {
            #if os(iOS)
            AudioService.play(intervalSound)
            // iPhone haptic on each buzz — all patterns use strongest styles
            // so athletes can feel them while moving.
            // System vibration is stronger than Taptic Engine and felt in pockets.
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            switch hapticMode {
            case .randomized:
                // Rotate between the three strongest haptic patterns
                let patterns: [() -> Void] = [
                    {
                        // Double heavy impact
                        let gen = UIImpactFeedbackGenerator(style: .heavy)
                        gen.prepare()
                        gen.impactOccurred(intensity: 1.0)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            gen.impactOccurred(intensity: 1.0)
                        }
                    },
                    {
                        // Triple rigid impact
                        let gen = UIImpactFeedbackGenerator(style: .rigid)
                        gen.prepare()
                        gen.impactOccurred(intensity: 1.0)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            gen.impactOccurred(intensity: 1.0)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                            gen.impactOccurred(intensity: 1.0)
                        }
                    },
                    {
                        // Warning notification (strongest notification type)
                        let gen = UINotificationFeedbackGenerator()
                        gen.prepare()
                        gen.notificationOccurred(.warning)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            let gen2 = UIImpactFeedbackGenerator(style: .heavy)
                            gen2.impactOccurred(intensity: 1.0)
                        }
                    },
                ]
                patterns.randomElement()?()
            case .consistent:
                switch fixedPattern {
                case .notification:
                    // Double warning notification
                    let gen = UINotificationFeedbackGenerator()
                    gen.prepare()
                    gen.notificationOccurred(.warning)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        gen.notificationOccurred(.warning)
                    }
                case .click:
                    // Strong double-tap (was .light, now .heavy)
                    let gen = UIImpactFeedbackGenerator(style: .heavy)
                    gen.prepare()
                    gen.impactOccurred(intensity: 1.0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        gen.impactOccurred(intensity: 1.0)
                    }
                case .success:
                    // Triple success pulse
                    let gen = UINotificationFeedbackGenerator()
                    gen.prepare()
                    gen.notificationOccurred(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        let impact = UIImpactFeedbackGenerator(style: .heavy)
                        impact.impactOccurred(intensity: 1.0)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                        let impact = UIImpactFeedbackGenerator(style: .heavy)
                        impact.impactOccurred(intensity: 1.0)
                    }
                case .directionUp:
                    // Strong double-tap (was .medium at 0.7, now .rigid at 1.0)
                    let gen = UIImpactFeedbackGenerator(style: .rigid)
                    gen.prepare()
                    gen.impactOccurred(intensity: 1.0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        gen.impactOccurred(intensity: 1.0)
                    }
                case .retry:
                    // Long strong buzz (was .soft, now .heavy with sustained pulses)
                    let gen = UIImpactFeedbackGenerator(style: .heavy)
                    gen.prepare()
                    gen.impactOccurred(intensity: 1.0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        gen.impactOccurred(intensity: 1.0)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        gen.impactOccurred(intensity: 1.0)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                        gen.impactOccurred(intensity: 1.0)
                    }
                }
            case .morse:
                Task { await MorsePlayer.play(word: morseWord) }
            }
            #endif
        }
    }

    func stop() {
        // Called for cancellations. Natural completions are handled by TimerView's completion screen.
        let session = Session(
            profileId: selectedProfile?.id,
            profileName: selectedProfile?.name ?? "Quick Session",
            startedAt: sessionStartedAt ?? Date(),
            endedAt: Date(),
            intervalSeconds: effectiveIntervalSeconds,
            varianceSeconds: randomizeEnabled ? varianceSeconds : 0,
            reminderCount: timerService.reminderCount,
            wasCancelled: true
        )
        timerService.stop()
        sessionStore?.save(session)
    }
}
