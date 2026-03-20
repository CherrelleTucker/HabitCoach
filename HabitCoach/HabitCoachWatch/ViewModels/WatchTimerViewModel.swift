import Foundation
import os.log

private let logger = Logger(subsystem: "com.ctuckersolutions.habitcoach", category: "WatchTimerVM")

@MainActor @Observable
class WatchTimerViewModel {
    let timerService = TimerService()
    let workoutManager = WorkoutManager()
    let profileStore = ProfileStore()
    let settingsStore = SettingsStore()
    private let connectivity = ConnectivityService.shared

    // Config (synced from phone or set on watch)
    var intervalSeconds: Int = 60
    var varianceSeconds: Int = 0
    var endCondition: SessionEndCondition = .unlimited

    var activeProfile: SessionProfile?
    var sessions: [Session] = []
    private var sessionStartedAt: Date?

    // Sequence state
    var activeSequence: SessionSequence?
    var currentStepIndex: Int = 0
    var isSequenceRunning: Bool = false
    var isSequenceTransitioning: Bool = false
    var sequenceTransitionCountdown: Int = 0
    var isSequenceComplete: Bool = false
    var completedSequenceSessions: [Session] = []
    private var sequenceRunId: UUID?
    private var sequenceTransitionTimer: Timer?

    // Error feedback
    var healthKitError: String?

    // Display helpers
    var formattedElapsed: String {
        let minutes = timerService.elapsedSeconds / 60
        let seconds = timerService.elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedNextBuzz: String {
        "~\(timerService.secondsUntilNextBuzz)s"
    }

    var intervalSummary: String {
        let m = intervalSeconds / 60
        let s = intervalSeconds % 60
        if s == 0 { return "\(m)m" }
        if m == 0 { return "\(s)s" }
        return "\(m)m \(s)s"
    }

    var varianceSummary: String {
        varianceSeconds > 0 ? "\u{00B1} \(varianceSeconds)s" : ""
    }

    var cycleSummary: String {
        switch endCondition {
        case .unlimited: return "\u{221E}"
        case .afterCount(let n): return "\(n)\u{00D7}"
        case .afterDuration(let s):
            let m = s / 60
            return m >= 60 ? "\(m / 60) hr" : "\(m) min"
        }
    }

    // MARK: - Profile Loading

    func loadProfile(_ profile: SessionProfile) {
        activeProfile = profile
        intervalSeconds = profile.intervalSeconds
        varianceSeconds = profile.varianceSeconds
        endCondition = profile.endCondition
    }

    func clearProfile() {
        activeProfile = nil
        intervalSeconds = 60
        varianceSeconds = 0
        endCondition = .unlimited
    }

    // MARK: - Connectivity

    func checkForIncomingData() {
        if let profiles = connectivity.receivedProfiles {
            profileStore.replaceAll(profiles)
            connectivity.receivedProfiles = nil
        }
        if let settings = connectivity.receivedSettings {
            settingsStore.settings = settings
            settingsStore.save()
            connectivity.receivedSettings = nil
        }
        if let sequences = connectivity.receivedSequences {
            // Store sequences for watch access
            if let data = try? JSONEncoder().encode(sequences) {
                UserDefaults.standard.set(data, forKey: "saved_sequences")
            }
            connectivity.receivedSequences = nil
        }
        if let seqCmd = connectivity.receivedSequenceCommand {
            if seqCmd.command == "startSequence", let sequence = seqCmd.sequence {
                Task { await startSequenceSession(sequence) }
            }
            connectivity.receivedSequenceCommand = nil
        }
        if let cmd = connectivity.receivedCommand {
            if cmd.command == "start", let profile = cmd.profile {
                loadProfile(profile)
                Task { await startSession() }
            } else if cmd.command == "stop" {
                Task { await stopSession() }
            }
            connectivity.receivedCommand = nil
        }
    }

    // MARK: - Session Control

    func startSession() async {
        sessionStartedAt = Date()
        healthKitError = nil
        let defaults = settingsStore.settings
        let hapticMode = activeProfile?.resolvedHapticMode(defaults: defaults) ?? defaults.hapticMode
        let fixedPattern = activeProfile?.resolvedHapticPattern(defaults: defaults) ?? defaults.hapticPattern
        let morseWord = activeProfile?.resolvedMorseWord ?? "BUZZ"

        #if os(watchOS)
        do {
            try await workoutManager.startWorkoutSession()
        } catch {
            logger.error("Failed to start workout session: \(error.localizedDescription)")
            healthKitError = "Could not start workout session"
        }
        #endif

        timerService.start(
            intervalSeconds: intervalSeconds,
            varianceSeconds: varianceSeconds,
            endCondition: endCondition
        ) {
            #if os(watchOS)
            switch hapticMode {
            case .randomized:
                let pattern = HapticPattern.allCases.randomElement() ?? .notification
                HapticService.play(pattern)
            case .consistent:
                HapticService.play(fixedPattern)
            case .morse:
                Task { await MorsePlayer.play(word: morseWord) }
            }
            #endif
        }
    }

    /// Called when TimerService auto-completes — ends workout and saves session
    func finishCompletedSession() async -> Session {
        let elapsed = timerService.elapsedSeconds
        let count = timerService.reminderCount

        #if os(watchOS)
        do {
            try await workoutManager.endWorkoutSession()
        } catch {
            logger.error("Failed to end workout after auto-complete: \(error.localizedDescription)")
        }
        // Play success haptic
        HapticService.play(.success)
        #endif

        let session = Session(
            profileId: activeProfile?.id,
            profileName: activeProfile?.name ?? "Quick Session",
            startedAt: sessionStartedAt ?? Date().addingTimeInterval(-Double(elapsed)),
            endedAt: Date(),
            intervalSeconds: intervalSeconds,
            varianceSeconds: varianceSeconds,
            reminderCount: count,
            wasCancelled: false
        )
        connectivity.sendSession(session)
        return session
    }

    func stopSession() async {
        let elapsed = timerService.elapsedSeconds
        let count = timerService.reminderCount
        let wasCancelled = !timerService.isComplete
        timerService.stop()

        #if os(watchOS)
        do {
            try await workoutManager.endWorkoutSession()
        } catch {
            logger.error("Failed to end workout session: \(error.localizedDescription)")
        }
        #endif

        let session = Session(
            profileId: activeProfile?.id,
            profileName: activeProfile?.name ?? "Quick Session",
            startedAt: sessionStartedAt ?? Date().addingTimeInterval(-Double(elapsed)),
            endedAt: Date(),
            intervalSeconds: intervalSeconds,
            varianceSeconds: varianceSeconds,
            reminderCount: count,
            wasCancelled: wasCancelled
        )
        sessions.append(session)
        connectivity.sendSession(session)
    }

    /// Call from scenePhase .active to catch up after backgrounding
    func resumeFromBackground() {
        timerService.resumeFromBackground()
    }

    // MARK: - Sequence Support

    var currentSequenceStep: SequenceStep? {
        guard let seq = activeSequence, currentStepIndex < seq.steps.count else { return nil }
        return seq.steps[currentStepIndex]
    }

    var sequenceProgress: String {
        guard let seq = activeSequence else { return "" }
        return "\(currentStepIndex + 1)/\(seq.steps.count)"
    }

    var isLastSequenceStep: Bool {
        guard let seq = activeSequence else { return true }
        return currentStepIndex >= seq.steps.count - 1
    }

    func startSequenceSession(_ sequence: SessionSequence) async {
        activeSequence = sequence
        currentStepIndex = 0
        sequenceRunId = UUID()
        completedSequenceSessions = []
        isSequenceRunning = true
        isSequenceComplete = false
        isSequenceTransitioning = false
        sessionStartedAt = Date()

        #if os(watchOS)
        do {
            try await workoutManager.startWorkoutSession()
        } catch {
            logger.error("Failed to start workout for sequence: \(error.localizedDescription)")
            healthKitError = "Could not start workout session"
        }
        #endif

        startCurrentSequenceStep()
    }

    private func startCurrentSequenceStep() {
        guard let step = currentSequenceStep else { return }
        let profile = step.profile
        let defaults = settingsStore.settings
        let hapticMode = profile.resolvedHapticMode(defaults: defaults)
        let fixedPattern = profile.resolvedHapticPattern(defaults: defaults)
        let morseWord = profile.resolvedMorseWord

        sessionStartedAt = Date()
        activeProfile = profile
        intervalSeconds = profile.intervalSeconds
        varianceSeconds = profile.varianceSeconds
        endCondition = step.endCondition

        let onInterval: () -> Void = {
            #if os(watchOS)
            switch hapticMode {
            case .randomized:
                let pattern = HapticPattern.allCases.randomElement() ?? .notification
                HapticService.play(pattern)
            case .consistent:
                HapticService.play(fixedPattern)
            case .morse:
                Task { await MorsePlayer.play(word: morseWord) }
            }
            #endif
        }

        let onComplete: () -> Void = { [weak self] in
            self?.handleSequenceStepComplete()
        }

        if timerService.isRunning {
            timerService.reconfigure(
                intervalSeconds: profile.intervalSeconds,
                varianceSeconds: profile.varianceSeconds,
                endCondition: step.endCondition,
                onInterval: onInterval,
                onComplete: onComplete
            )
        } else {
            timerService.start(
                intervalSeconds: profile.intervalSeconds,
                varianceSeconds: profile.varianceSeconds,
                endCondition: step.endCondition,
                onInterval: onInterval,
                onComplete: onComplete
            )
        }
    }

    private func handleSequenceStepComplete() {
        let session = Session(
            profileId: currentSequenceStep?.profile.id,
            profileName: currentSequenceStep?.profile.name ?? "Step",
            startedAt: sessionStartedAt ?? Date(),
            endedAt: Date(),
            intervalSeconds: intervalSeconds,
            varianceSeconds: varianceSeconds,
            reminderCount: timerService.reminderCount,
            wasCancelled: false,
            sequenceId: sequenceRunId,
            sequenceIndex: currentStepIndex,
            sequenceName: activeSequence?.name
        )
        completedSequenceSessions.append(session)
        connectivity.sendSession(session)

        if isLastSequenceStep {
            timerService.stop()
            isSequenceRunning = false
            isSequenceComplete = true

            #if os(watchOS)
            HapticService.play(.success)
            Task {
                do { try await workoutManager.endWorkoutSession() }
                catch { logger.error("Failed to end workout after sequence: \(error.localizedDescription)") }
            }
            #endif
        } else {
            enterSequenceTransition()
        }
    }

    private func enterSequenceTransition() {
        guard let sequence = activeSequence else { return }
        isSequenceTransitioning = true

        if sequence.transition == .autoAdvance {
            sequenceTransitionCountdown = sequence.countdownSeconds
            #if os(watchOS)
            HapticService.play(.success)
            #endif

            sequenceTransitionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.sequenceTransitionCountdown -= 1
                    if self.sequenceTransitionCountdown <= 0 {
                        self.advanceSequenceStep()
                    }
                }
            }
        }
    }

    func advanceSequenceStep() {
        sequenceTransitionTimer?.invalidate()
        sequenceTransitionTimer = nil
        isSequenceTransitioning = false
        sequenceTransitionCountdown = 0
        currentStepIndex += 1
        startCurrentSequenceStep()
    }

    func cancelSequence() async {
        sequenceTransitionTimer?.invalidate()
        sequenceTransitionTimer = nil
        isSequenceTransitioning = false

        if timerService.isRunning {
            let session = Session(
                profileId: currentSequenceStep?.profile.id,
                profileName: currentSequenceStep?.profile.name ?? "Step",
                startedAt: sessionStartedAt ?? Date(),
                endedAt: Date(),
                intervalSeconds: intervalSeconds,
                varianceSeconds: varianceSeconds,
                reminderCount: timerService.reminderCount,
                wasCancelled: true,
                sequenceId: sequenceRunId,
                sequenceIndex: currentStepIndex,
                sequenceName: activeSequence?.name
            )
            completedSequenceSessions.append(session)
            connectivity.sendSession(session)
        }

        timerService.stop()
        isSequenceRunning = false

        #if os(watchOS)
        do { try await workoutManager.endWorkoutSession() }
        catch { logger.error("Failed to end workout on sequence cancel: \(error.localizedDescription)") }
        #endif
    }

    func clearSequence() {
        activeSequence = nil
        currentStepIndex = 0
        isSequenceRunning = false
        isSequenceComplete = false
        completedSequenceSessions = []
    }
}
