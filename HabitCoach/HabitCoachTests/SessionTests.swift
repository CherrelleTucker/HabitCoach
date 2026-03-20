import XCTest
@testable import HabitCoach

final class SessionTests: XCTestCase {

    // MARK: - Duration

    func testDurationCalculation() {
        let start = Date()
        let end = start.addingTimeInterval(300) // 5 minutes
        let session = Session(
            profileName: "Test",
            startedAt: start,
            endedAt: end,
            intervalSeconds: 60,
            varianceSeconds: 0,
            reminderCount: 5,
            wasCancelled: false
        )
        XCTAssertEqual(session.duration!, 300, accuracy: 0.01)
    }

    func testDurationNilWhenNoEndDate() {
        let session = Session(
            profileName: "Test",
            startedAt: Date(),
            endedAt: nil,
            intervalSeconds: 60,
            varianceSeconds: 0,
            reminderCount: 0,
            wasCancelled: false
        )
        XCTAssertNil(session.duration)
    }

    func testFormattedDuration() {
        let start = Date()
        let end = start.addingTimeInterval(125) // 2:05
        let session = Session(
            profileName: "Test",
            startedAt: start,
            endedAt: end,
            intervalSeconds: 60,
            varianceSeconds: 0,
            reminderCount: 2,
            wasCancelled: false
        )
        XCTAssertEqual(session.formattedDuration, "2:05")
    }

    func testFormattedDurationNoEnd() {
        let session = Session(
            profileName: "Test",
            startedAt: Date(),
            endedAt: nil,
            intervalSeconds: 60,
            varianceSeconds: 0,
            reminderCount: 0,
            wasCancelled: false
        )
        XCTAssertEqual(session.formattedDuration, "--")
    }

    // MARK: - Codable

    func testCodableRoundtrip() throws {
        let session = Session(
            profileId: UUID(),
            profileName: "Roundtrip",
            startedAt: Date(),
            endedAt: Date().addingTimeInterval(600),
            intervalSeconds: 120,
            varianceSeconds: 15,
            reminderCount: 5,
            wasCancelled: false
        )
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(Session.self, from: data)

        XCTAssertEqual(decoded.id, session.id)
        XCTAssertEqual(decoded.profileId, session.profileId)
        XCTAssertEqual(decoded.profileName, "Roundtrip")
        XCTAssertEqual(decoded.intervalSeconds, 120)
        XCTAssertEqual(decoded.varianceSeconds, 15)
        XCTAssertEqual(decoded.reminderCount, 5)
        XCTAssertFalse(decoded.wasCancelled)
    }

    func testCodableWithNilProfileId() throws {
        let session = Session(
            profileName: "Quick",
            startedAt: Date(),
            endedAt: Date(),
            intervalSeconds: 60,
            varianceSeconds: 0,
            reminderCount: 1,
            wasCancelled: true
        )
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(Session.self, from: data)
        XCTAssertNil(decoded.profileId)
        XCTAssertTrue(decoded.wasCancelled)
    }

    // MARK: - Equatable

    func testEquatable() {
        let id = UUID()
        let date = Date()
        let a = Session(id: id, profileName: "A", startedAt: date, endedAt: date, intervalSeconds: 60, varianceSeconds: 0, reminderCount: 1, wasCancelled: false)
        let b = Session(id: id, profileName: "A", startedAt: date, endedAt: date, intervalSeconds: 60, varianceSeconds: 0, reminderCount: 1, wasCancelled: false)
        XCTAssertEqual(a, b)
    }
}
