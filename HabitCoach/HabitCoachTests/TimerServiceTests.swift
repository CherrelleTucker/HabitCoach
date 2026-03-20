import XCTest
@testable import HabitCoach

@MainActor
final class TimerServiceTests: XCTestCase {

    // MARK: - Basic Start/Stop

    func testStartSetsRunning() {
        let sut = TimerService()
        sut.start(intervalSeconds: 10) { }
        XCTAssertTrue(sut.isRunning)
        sut.stop()
    }

    func testStopClearsRunning() {
        let sut = TimerService()
        sut.start(intervalSeconds: 10) { }
        sut.stop()
        XCTAssertFalse(sut.isRunning)
    }

    func testStartResetsState() {
        let sut = TimerService()
        sut.start(intervalSeconds: 10) { }
        // Simulate some elapsed time
        sut.stop()
        sut.start(intervalSeconds: 20) { }
        XCTAssertEqual(sut.elapsedSeconds, 0)
        XCTAssertEqual(sut.reminderCount, 0)
        XCTAssertEqual(sut.intervalSeconds, 20)
        sut.stop()
    }

    func testRejectsZeroInterval() {
        let sut = TimerService()
        sut.start(intervalSeconds: 0) { }
        XCTAssertFalse(sut.isRunning, "Should not start with zero interval")
    }

    func testRejectsNegativeInterval() {
        let sut = TimerService()
        sut.start(intervalSeconds: -5) { }
        XCTAssertFalse(sut.isRunning, "Should not start with negative interval")
    }

    // MARK: - End Conditions

    func testIsCompleteUnlimited() {
        let sut = TimerService()
        sut.endCondition = .unlimited
        sut.reminderCount = 999
        sut.elapsedSeconds = 99999
        XCTAssertFalse(sut.isComplete, "Unlimited should never be complete")
    }

    func testIsCompleteAfterCount() {
        let sut = TimerService()
        sut.endCondition = .afterCount(5)
        sut.reminderCount = 4
        XCTAssertFalse(sut.isComplete)
        sut.reminderCount = 5
        XCTAssertTrue(sut.isComplete)
        sut.reminderCount = 6
        XCTAssertTrue(sut.isComplete)
    }

    func testIsCompleteAfterDuration() {
        let sut = TimerService()
        sut.endCondition = .afterDuration(300)
        sut.elapsedSeconds = 299
        XCTAssertFalse(sut.isComplete)
        sut.elapsedSeconds = 300
        XCTAssertTrue(sut.isComplete)
    }

    // MARK: - Total Cycles

    func testTotalCyclesUnlimited() {
        let sut = TimerService()
        sut.endCondition = .unlimited
        XCTAssertNil(sut.totalCycles)
    }

    func testTotalCyclesCount() {
        let sut = TimerService()
        sut.endCondition = .afterCount(10)
        XCTAssertEqual(sut.totalCycles, 10)
    }

    func testTotalCyclesDuration() {
        let sut = TimerService()
        sut.intervalSeconds = 60
        sut.endCondition = .afterDuration(300)
        XCTAssertEqual(sut.totalCycles, 5) // 300 / 60
    }

    func testTotalCyclesDurationZeroInterval() {
        let sut = TimerService()
        sut.intervalSeconds = 0
        sut.endCondition = .afterDuration(300)
        XCTAssertNil(sut.totalCycles, "Should not divide by zero")
    }

    // MARK: - Variance

    func testStartWithVarianceSetsConfig() {
        let sut = TimerService()
        sut.start(intervalSeconds: 60, varianceSeconds: 15, endCondition: .unlimited) { }
        XCTAssertEqual(sut.intervalSeconds, 60)
        XCTAssertEqual(sut.varianceSeconds, 15)
        XCTAssertTrue(sut.secondsUntilNextBuzz >= 5) // minimum floor
        sut.stop()
    }

    // MARK: - Resume from Background

    func testResumeFromBackgroundNotRunning() {
        let sut = TimerService()
        // Should not crash when not running
        sut.resumeFromBackground()
        XCTAssertFalse(sut.isRunning)
    }
}
