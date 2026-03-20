import Foundation
import HealthKit
import os.log

private let logger = Logger(subsystem: "com.ctuckersolutions.habitcoach", category: "WorkoutManager")

@MainActor @Observable
class WorkoutManager {
    private let healthStore = HKHealthStore()
    var isSessionActive: Bool = false
    private(set) var isAuthorized: Bool = false

    #if os(watchOS)
    private var workoutSession: HKWorkoutSession?
    #endif

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.warning("HealthKit not available on this device")
            return
        }
        let typesToShare: Set<HKSampleType> = [HKQuantityType.workoutType()]
        let typesToRead: Set<HKObjectType> = [HKQuantityType.workoutType()]
        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            isAuthorized = true
        } catch {
            logger.error("HealthKit authorization failed: \(error.localizedDescription)")
        }
    }

    #if os(watchOS)
    func startWorkoutSession() async throws {
        if !isAuthorized {
            await requestAuthorization()
        }

        let config = HKWorkoutConfiguration()
        config.activityType = .mindAndBody
        config.locationType = .unknown

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        self.workoutSession = session

        session.startActivity(with: Date())
        isSessionActive = true
    }

    func endWorkoutSession() async throws {
        workoutSession?.end()
        workoutSession = nil
        isSessionActive = false
    }
    #endif
}
