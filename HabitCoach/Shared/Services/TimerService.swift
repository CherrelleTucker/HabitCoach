import Foundation
import os.log
#if os(iOS)
import AVFoundation
#endif

private let logger = Logger(subsystem: "com.ctuckersolutions.habitcoach", category: "TimerService")

enum SessionEndCondition: Codable, Hashable {
    case unlimited
    case afterCount(Int)
    case afterDuration(Int) // seconds
}

@MainActor @Observable
class TimerService {
    // State
    var isRunning: Bool = false
    var elapsedSeconds: Int = 0
    var reminderCount: Int = 0
    var secondsUntilNextBuzz: Int = 0

    // Configuration
    var intervalSeconds: Int = 60
    var varianceSeconds: Int = 0
    var endCondition: SessionEndCondition = .unlimited

    private var timer: Timer?
    private var nextBuzzAt: Int = 0
    private var onInterval: (() -> Void)?
    private var onComplete: (() -> Void)?

    // Background persistence
    private var sessionStartDate: Date?
    private var pausedAt: Date?

    #if os(iOS)
    /// Silent audio player that keeps the app alive in background
    private var backgroundPlayer: AVAudioPlayer?
    #endif

    var isComplete: Bool {
        switch endCondition {
        case .unlimited:
            return false
        case .afterCount(let count):
            return reminderCount >= count
        case .afterDuration(let duration):
            return elapsedSeconds >= duration
        }
    }

    var totalCycles: Int? {
        switch endCondition {
        case .unlimited: return nil
        case .afterCount(let count): return count
        case .afterDuration(let duration):
            guard intervalSeconds > 0 else { return nil }
            return duration / intervalSeconds
        }
    }

    func start(
        intervalSeconds: Int,
        varianceSeconds: Int = 0,
        endCondition: SessionEndCondition = .unlimited,
        onInterval: @escaping () -> Void,
        onComplete: (() -> Void)? = nil
    ) {
        guard intervalSeconds > 0 else {
            logger.error("Cannot start timer with interval <= 0")
            return
        }
        self.intervalSeconds = intervalSeconds
        self.varianceSeconds = varianceSeconds
        self.endCondition = endCondition
        self.onInterval = onInterval
        self.onComplete = onComplete
        self.elapsedSeconds = 0
        self.reminderCount = 0
        self.isRunning = true
        self.sessionStartDate = Date()
        self.pausedAt = nil

        #if os(iOS)
        startBackgroundAudio()
        #endif

        scheduleNextBuzz()
        startTicking()
    }

    /// Reconfigures the timer for a new step without stopping the underlying timer.
    /// Used by sequence playback to transition between steps seamlessly.
    func reconfigure(
        intervalSeconds: Int,
        varianceSeconds: Int = 0,
        endCondition: SessionEndCondition,
        onInterval: @escaping () -> Void,
        onComplete: (() -> Void)? = nil
    ) {
        self.intervalSeconds = intervalSeconds
        self.varianceSeconds = varianceSeconds
        self.endCondition = endCondition
        self.onInterval = onInterval
        self.onComplete = onComplete
        self.elapsedSeconds = 0
        self.reminderCount = 0
        self.sessionStartDate = Date()
        scheduleNextBuzz()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        sessionStartDate = nil
        pausedAt = nil
        #if os(iOS)
        stopBackgroundAudio()
        #endif
    }

    /// Called when app returns to foreground — recalculates elapsed time from wall clock
    func resumeFromBackground() {
        guard isRunning, let startDate = sessionStartDate else { return }

        let now = Date()
        let wallElapsed = Int(now.timeIntervalSince(startDate))
        let missedSeconds = wallElapsed - elapsedSeconds

        if missedSeconds > 1 {
            logger.info("Resuming from background, catching up \(missedSeconds)s")

            // Fast-forward elapsed time
            elapsedSeconds = wallElapsed

            // Count any missed buzzes
            while elapsedSeconds >= nextBuzzAt && !isComplete {
                reminderCount += 1
                onInterval?()
                if isComplete {
                    onComplete?()
                    stop()
                    return
                }
                scheduleNextBuzz()
            }

            secondsUntilNextBuzz = max(0, nextBuzzAt - elapsedSeconds)
        }

        // Restart the tick timer if it was invalidated
        if timer == nil {
            startTicking()
        }
    }

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isRunning else { return }
                self.elapsedSeconds += 1
                self.secondsUntilNextBuzz = max(0, self.nextBuzzAt - self.elapsedSeconds)

                if self.elapsedSeconds >= self.nextBuzzAt {
                    self.reminderCount += 1
                    self.onInterval?()

                    if self.isComplete {
                        self.onComplete?()
                        self.stop()
                    } else {
                        self.scheduleNextBuzz()
                    }
                }
            }
        }
    }

    private func scheduleNextBuzz() {
        var next = intervalSeconds
        if varianceSeconds > 0 {
            let range = -varianceSeconds...varianceSeconds
            next += Int.random(in: range)
            next = max(5, next) // minimum 5 seconds between buzzes
        }
        nextBuzzAt = elapsedSeconds + next
        secondsUntilNextBuzz = next
    }

    // MARK: - Background Audio (iOS)
    // Plays a silent audio loop so iOS keeps the app alive in background.
    // This allows the timer and haptics to continue when the user switches apps.

    #if os(iOS)
    private func startBackgroundAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            logger.error("Failed to configure audio session: \(error.localizedDescription)")
        }

        // Use cached silent WAV data (1 second of silence, 16-bit mono 44100 Hz)
        guard let silentData = Self.silentWAVData else {
            logger.error("Failed to generate silent audio data")
            return
        }

        do {
            let player = try AVAudioPlayer(data: silentData)
            player.numberOfLoops = -1 // loop forever
            player.volume = 0.0
            player.play()
            backgroundPlayer = player
            logger.info("Background audio started")
        } catch {
            logger.error("Failed to start background audio: \(error.localizedDescription)")
        }
    }

    private func stopBackgroundAudio() {
        backgroundPlayer?.stop()
        backgroundPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        logger.info("Background audio stopped")
    }

    /// Cached silent WAV data to avoid regenerating every session start.
    private static let silentWAVData: Data? = generateSilentWAV(durationSeconds: 1.0)

    /// Generates a minimal WAV file with silence, entirely in memory.
    private static func generateSilentWAV(durationSeconds: Double) -> Data? {
        let sampleRate: UInt32 = 44100
        let bitsPerSample: UInt16 = 16
        let channels: UInt16 = 1
        let numSamples = UInt32(Double(sampleRate) * durationSeconds)
        let dataSize = numSamples * UInt32(bitsPerSample / 8) * UInt32(channels)
        let fileSize = 36 + dataSize

        var data = Data()
        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)
        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM
        data.append(contentsOf: withUnsafeBytes(of: channels.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        let blockAlign = channels * (bitsPerSample / 8)
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        // data chunk
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        data.append(Data(count: Int(dataSize))) // silence (all zeros)
        return data
    }
    #endif
}
