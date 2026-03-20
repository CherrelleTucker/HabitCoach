import XCTest
@testable import HabitCoach

final class SequenceTests: XCTestCase {

    // MARK: - SessionSequence Validation

    func testEmptySequenceIsInvalid() {
        let seq = SessionSequence(name: "Empty", steps: [])
        XCTAssertFalse(seq.isValid)
    }

    func testSequenceWithUnlimitedStepIsInvalid() {
        let profile = SessionProfile(name: "Test", intervalSeconds: 60)
        let step = SequenceStep(profile: profile, endCondition: .unlimited)
        let seq = SessionSequence(name: "Bad", steps: [step])
        XCTAssertFalse(seq.isValid)
    }

    func testSequenceWithCountStepIsValid() {
        let profile = SessionProfile(name: "Test", intervalSeconds: 60)
        let step = SequenceStep(profile: profile, endCondition: .afterCount(10))
        let seq = SessionSequence(name: "Good", steps: [step])
        XCTAssertTrue(seq.isValid)
    }

    func testSequenceWithDurationStepIsValid() {
        let profile = SessionProfile(name: "Test", intervalSeconds: 60)
        let step = SequenceStep(profile: profile, endCondition: .afterDuration(300))
        let seq = SessionSequence(name: "Good", steps: [step])
        XCTAssertTrue(seq.isValid)
    }

    func testSequenceWithMixedStepsOneUnlimitedIsInvalid() {
        let profile = SessionProfile(name: "Test", intervalSeconds: 60)
        let step1 = SequenceStep(profile: profile, endCondition: .afterCount(5))
        let step2 = SequenceStep(profile: profile, endCondition: .unlimited)
        let seq = SessionSequence(name: "Mixed", steps: [step1, step2])
        XCTAssertFalse(seq.isValid)
    }

    func testSequenceWithAllDefinedStepsIsValid() {
        let profile = SessionProfile(name: "Test", intervalSeconds: 60)
        let step1 = SequenceStep(profile: profile, endCondition: .afterCount(5))
        let step2 = SequenceStep(profile: profile, endCondition: .afterDuration(600))
        let step3 = SequenceStep(profile: profile, endCondition: .afterCount(10))
        let seq = SessionSequence(name: "Full", steps: [step1, step2, step3])
        XCTAssertTrue(seq.isValid)
    }

    // MARK: - Total Duration

    func testTotalEstimatedDurationAllDuration() {
        let profile = SessionProfile(name: "Test", intervalSeconds: 60)
        let step1 = SequenceStep(profile: profile, endCondition: .afterDuration(300))
        let step2 = SequenceStep(profile: profile, endCondition: .afterDuration(600))
        let seq = SessionSequence(name: "Test", steps: [step1, step2])
        XCTAssertEqual(seq.totalEstimatedDuration, 900)
    }

    func testTotalEstimatedDurationWithCountReturnsNil() {
        let profile = SessionProfile(name: "Test", intervalSeconds: 60)
        let step1 = SequenceStep(profile: profile, endCondition: .afterDuration(300))
        let step2 = SequenceStep(profile: profile, endCondition: .afterCount(10))
        let seq = SessionSequence(name: "Test", steps: [step1, step2])
        XCTAssertNil(seq.totalEstimatedDuration)
    }

    // MARK: - Formatted Duration

    func testFormattedTotalDurationMinutes() {
        let profile = SessionProfile(name: "Test", intervalSeconds: 60)
        let step = SequenceStep(profile: profile, endCondition: .afterDuration(1800))
        let seq = SessionSequence(name: "Test", steps: [step])
        XCTAssertEqual(seq.formattedTotalDuration, "30m")
    }

    func testFormattedTotalDurationHours() {
        let profile = SessionProfile(name: "Test", intervalSeconds: 60)
        let step1 = SequenceStep(profile: profile, endCondition: .afterDuration(3600))
        let step2 = SequenceStep(profile: profile, endCondition: .afterDuration(1800))
        let seq = SessionSequence(name: "Test", steps: [step1, step2])
        XCTAssertEqual(seq.formattedTotalDuration, "1h 30m")
    }

    // MARK: - SequenceStep

    func testStepEstimatedDurationWithDuration() {
        let profile = SessionProfile(name: "Test", intervalSeconds: 60)
        let step = SequenceStep(profile: profile, endCondition: .afterDuration(300))
        XCTAssertEqual(step.estimatedDuration, 300)
    }

    func testStepEstimatedDurationWithCountReturnsNil() {
        let profile = SessionProfile(name: "Test", intervalSeconds: 60)
        let step = SequenceStep(profile: profile, endCondition: .afterCount(10))
        XCTAssertNil(step.estimatedDuration)
    }

    func testStepFormattedEndCondition() {
        let profile = SessionProfile(name: "Test", intervalSeconds: 60)
        XCTAssertEqual(
            SequenceStep(profile: profile, endCondition: .afterCount(5)).formattedEndCondition,
            "5 reminders"
        )
        XCTAssertEqual(
            SequenceStep(profile: profile, endCondition: .afterDuration(900)).formattedEndCondition,
            "15 min"
        )
        XCTAssertEqual(
            SequenceStep(profile: profile, endCondition: .afterDuration(3600)).formattedEndCondition,
            "1 hr"
        )
    }

    // MARK: - Codable Round-Trip

    func testSequenceCodable() throws {
        let profile = SessionProfile(name: "Strength", icon: "dumbbell.fill", intervalSeconds: 45)
        let step = SequenceStep(profile: profile, endCondition: .afterCount(15))
        let seq = SessionSequence(
            name: "Morning Workout",
            steps: [step],
            transition: .autoAdvance,
            countdownSeconds: 5
        )

        let data = try JSONEncoder().encode(seq)
        let decoded = try JSONDecoder().decode(SessionSequence.self, from: data)

        XCTAssertEqual(decoded.name, "Morning Workout")
        XCTAssertEqual(decoded.steps.count, 1)
        XCTAssertEqual(decoded.steps[0].profile.name, "Strength")
        XCTAssertEqual(decoded.transition, .autoAdvance)
        XCTAssertEqual(decoded.countdownSeconds, 5)
    }

    // MARK: - Session Sequence Fields

    func testSessionSequenceFieldsOptional() throws {
        let session = Session(
            profileName: "Test",
            startedAt: Date(),
            endedAt: Date(),
            intervalSeconds: 60,
            varianceSeconds: 0,
            reminderCount: 5,
            wasCancelled: false
        )
        XCTAssertNil(session.sequenceId)
        XCTAssertNil(session.sequenceIndex)
        XCTAssertNil(session.sequenceName)
    }

    func testSessionWithSequenceFields() {
        let seqId = UUID()
        let session = Session(
            profileName: "Step 1",
            startedAt: Date(),
            endedAt: Date(),
            intervalSeconds: 45,
            varianceSeconds: 0,
            reminderCount: 10,
            wasCancelled: false,
            sequenceId: seqId,
            sequenceIndex: 0,
            sequenceName: "Morning Workout"
        )
        XCTAssertEqual(session.sequenceId, seqId)
        XCTAssertEqual(session.sequenceIndex, 0)
        XCTAssertEqual(session.sequenceName, "Morning Workout")
    }

    func testSessionWithSequenceFieldsCodable() throws {
        let seqId = UUID()
        let session = Session(
            profileName: "Step 1",
            startedAt: Date(),
            endedAt: Date(),
            intervalSeconds: 45,
            varianceSeconds: 0,
            reminderCount: 10,
            wasCancelled: false,
            sequenceId: seqId,
            sequenceIndex: 2,
            sequenceName: "Workout"
        )

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(Session.self, from: data)
        XCTAssertEqual(decoded.sequenceId, seqId)
        XCTAssertEqual(decoded.sequenceIndex, 2)
        XCTAssertEqual(decoded.sequenceName, "Workout")
    }

    // MARK: - TimerService reconfigure

    @MainActor
    func testTimerServiceReconfigure() {
        let service = TimerService()
        var buzzCount = 0

        service.start(intervalSeconds: 30, endCondition: .afterCount(5)) {
            buzzCount += 1
        }
        XCTAssertTrue(service.isRunning)
        XCTAssertEqual(service.intervalSeconds, 30)

        service.reconfigure(intervalSeconds: 60, endCondition: .afterCount(10)) {
            buzzCount += 1
        }
        XCTAssertTrue(service.isRunning)
        XCTAssertEqual(service.intervalSeconds, 60)
        XCTAssertEqual(service.elapsedSeconds, 0)
        XCTAssertEqual(service.reminderCount, 0)

        service.stop()
    }
}
