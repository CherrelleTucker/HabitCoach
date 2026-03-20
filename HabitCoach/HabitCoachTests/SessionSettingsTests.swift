import XCTest
@testable import HabitCoach

final class SessionSettingsTests: XCTestCase {

    // MARK: - Defaults

    func testDefaultValues() {
        let settings = SessionSettings()
        XCTAssertEqual(settings.hapticMode, .randomized)
        XCTAssertEqual(settings.hapticPattern, .notification)
        XCTAssertEqual(settings.intervalSound, "none")
        XCTAssertEqual(settings.completionSound, "done")
        XCTAssertTrue(settings.focusReminderEnabled)
    }

    // MARK: - Codable

    func testCodableRoundtrip() throws {
        var settings = SessionSettings()
        settings.hapticMode = .consistent
        settings.hapticPattern = .click
        settings.intervalSound = "bell"
        settings.completionSound = "fanfare"
        settings.focusReminderEnabled = false

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(SessionSettings.self, from: data)

        XCTAssertEqual(decoded.hapticMode, .consistent)
        XCTAssertEqual(decoded.hapticPattern, .click)
        XCTAssertEqual(decoded.intervalSound, "bell")
        XCTAssertEqual(decoded.completionSound, "fanfare")
        XCTAssertFalse(decoded.focusReminderEnabled)
    }

    // MARK: - Equatable

    func testEquatable() {
        let a = SessionSettings()
        var b = SessionSettings()
        XCTAssertEqual(a, b)

        b.hapticMode = .consistent
        XCTAssertNotEqual(a, b)
    }

    // MARK: - HapticMode

    func testHapticModeCodable() throws {
        let data = try JSONEncoder().encode(HapticMode.randomized)
        let decoded = try JSONDecoder().decode(HapticMode.self, from: data)
        XCTAssertEqual(decoded, .randomized)
    }
}
