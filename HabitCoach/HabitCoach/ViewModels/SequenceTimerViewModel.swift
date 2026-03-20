import Foundation
#if os(iOS)
import UIKit
import AudioToolbox
#endif

@MainActor @Observable
class SequenceTimerViewModel {
    let timerService = TimerService()
    var sessionStore: SessionStore?
    var settingsStore: SettingsStore?

    // Sequence state
    var sequence: SessionSequence?
    var currentStepIndex: Int = 0
    var isSequenceActive: Bool = false
    var isTransitioning: Bool = false
    var transitionCountdown: Int = 0
    var completedStepSessions: [Session] = []
    var isSequenceComplete: Bool = false

    private var sequenceRunId: UUID?
    private var stepStartedAt: Date?
    private var transitionTimer: Timer?

    // MARK: - Computed

    var currentStep: SequenceStep? {
        guard let sequence, currentStepIndex < sequence.steps.count else { return nil }
        return sequence.steps[currentStepIndex]
    }

    var isLastStep: Bool {
        guard let sequence else { return true }
        return currentStepIndex >= sequence.steps.count - 1
    }

    var sequenceProgress: String {
        guard let sequence else { return "" }
        return "\(currentStepIndex + 1) of \(sequence.steps.count)"
    }

    var formattedElapsed: String {
        let minutes = timerService.elapsedSeconds / 60
        let seconds = timerService.elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedNextBuzz: String {
        "~\(timerService.secondsUntilNextBuzz)s"
    }

    var aggregateDuration: TimeInterval {
        completedStepSessions.compactMap { $0.duration }.reduce(0, +)
    }

    var aggregateReminders: Int {
        completedStepSessions.reduce(0) { $0 + $1.reminderCount }
    }

    var formattedAggregateDuration: String {
        let total = Int(aggregateDuration)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Actions

    func startSequence(_ seq: SessionSequence, destination: HapticDestination = .iPhone) {
        sequence = seq
        currentStepIndex = 0
        sequenceRunId = UUID()
        completedStepSessions = []
        isSequenceActive = true
        isSequenceComplete = false
        isTransitioning = false

        // If watch destination, send sequence to watch
        if destination == .watch {
            ConnectivityService.shared.sendStartSequenceCommand(sequence: seq)
            return
        }
        if destination == .both {
            ConnectivityService.shared.sendStartSequenceCommand(sequence: seq)
        }

        startCurrentStep()
    }

    func advanceToNextStep() {
        transitionTimer?.invalidate()
        transitionTimer = nil
        isTransitioning = false
        transitionCountdown = 0

        currentStepIndex += 1
        startCurrentStep()
    }

    func cancelSequence() {
        transitionTimer?.invalidate()
        transitionTimer = nil
        isTransitioning = false

        // Save current step as cancelled if timer was running
        if timerService.isRunning {
            saveCurrentStepSession(wasCancelled: true)
        }

        timerService.stop()
        isSequenceActive = false
    }

    // MARK: - Internal

    private func startCurrentStep() {
        guard let step = currentStep else { return }
        let profile = step.profile
        let defaults = settingsStore?.settings ?? SessionSettings()

        stepStartedAt = Date()

        let intervalSound = profile.resolvedIntervalSound(defaults: defaults)
        let hapticMode = profile.resolvedHapticMode(defaults: defaults)
        let fixedPattern = profile.resolvedHapticPattern(defaults: defaults)
        let morseWord = profile.resolvedMorseWord

        let onInterval: () -> Void = {
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

        if timerService.isRunning {
            // Seamless transition — reconfigure without stopping
            timerService.reconfigure(
                intervalSeconds: profile.intervalSeconds,
                varianceSeconds: profile.varianceSeconds,
                endCondition: step.endCondition,
                onInterval: onInterval,
                onComplete: { [weak self] in self?.handleStepComplete() }
            )
        } else {
            timerService.start(
                intervalSeconds: profile.intervalSeconds,
                varianceSeconds: profile.varianceSeconds,
                endCondition: step.endCondition,
                onInterval: onInterval,
                onComplete: { [weak self] in self?.handleStepComplete() }
            )
        }
    }

    private func handleStepComplete() {
        saveCurrentStepSession(wasCancelled: false)

        if isLastStep {
            // Sequence finished
            timerService.stop()
            isSequenceComplete = true
            isSequenceActive = false

            #if os(iOS)
            let completionSound = settingsStore?.settings.completionSound ?? "done"
            AudioService.play(completionSound)
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
            #endif
        } else {
            // Enter transition
            enterTransition()
        }
    }

    private func enterTransition() {
        guard let sequence else { return }

        isTransitioning = true

        if sequence.transition == .autoAdvance {
            transitionCountdown = sequence.countdownSeconds

            #if os(iOS)
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
            #endif

            transitionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.transitionCountdown -= 1
                    if self.transitionCountdown <= 0 {
                        self.advanceToNextStep()
                    }
                }
            }
        }
        // For .manual, just wait — user taps advanceToNextStep()
    }

    private func saveCurrentStepSession(wasCancelled: Bool) {
        guard let step = currentStep else { return }

        let session = Session(
            profileId: step.profile.id,
            profileName: step.profile.name,
            startedAt: stepStartedAt ?? Date(),
            endedAt: Date(),
            intervalSeconds: step.profile.intervalSeconds,
            varianceSeconds: step.profile.varianceSeconds,
            reminderCount: timerService.reminderCount,
            wasCancelled: wasCancelled,
            sequenceId: sequenceRunId,
            sequenceIndex: currentStepIndex,
            sequenceName: sequence?.name
        )
        completedStepSessions.append(session)
        sessionStore?.save(session)
    }
}
