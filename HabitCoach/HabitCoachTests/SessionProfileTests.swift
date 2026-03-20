import XCTest
@testable import HabitCoach

final class SessionProfileTests: XCTestCase {

    // MARK: - Resolved Settings (Override or Global Default)

    private let globalDefaults = SessionSettings(
        hapticMode: .randomized,
        hapticPattern: .notification,
        intervalSound: "bell",
        completionSound: "done",
        focusReminderEnabled: true
    )

    func testResolvedHapticModeUsesGlobalWhenNoOverride() {
        let profile = SessionProfile(name: "Test", intervalSeconds: 60)
        XCTAssertEqual(profile.resolvedHapticMode(defaults: globalDefaults), .randomized)
    }

    func testResolvedHapticModeUsesOverride() {
        var profile = SessionProfile(name: "Test", intervalSeconds: 60)
        profile.hapticModeOverride = .consistent
        XCTAssertEqual(profile.resolvedHapticMode(defaults: globalDefaults), .consistent)
    }

    func testResolvedHapticPatternUsesGlobalWhenNoOverride() {
        let profile = SessionProfile(name: "Test", intervalSeconds: 60)
        XCTAssertEqual(profile.resolvedHapticPattern(defaults: globalDefaults), .notification)
    }

    func testResolvedHapticPatternUsesOverride() {
        var profile = SessionProfile(name: "Test", intervalSeconds: 60)
        profile.hapticPatternOverride = .click
        XCTAssertEqual(profile.resolvedHapticPattern(defaults: globalDefaults), .click)
    }

    func testResolvedIntervalSoundUsesGlobalWhenNoOverride() {
        let profile = SessionProfile(name: "Test", intervalSeconds: 60)
        XCTAssertEqual(profile.resolvedIntervalSound(defaults: globalDefaults), "bell")
    }

    func testResolvedIntervalSoundUsesOverride() {
        var profile = SessionProfile(name: "Test", intervalSeconds: 60)
        profile.intervalSoundOverride = "chime"
        XCTAssertEqual(profile.resolvedIntervalSound(defaults: globalDefaults), "chime")
    }

    func testResolvedCompletionSoundUsesGlobalWhenNoOverride() {
        let profile = SessionProfile(name: "Test", intervalSeconds: 60)
        XCTAssertEqual(profile.resolvedCompletionSound(defaults: globalDefaults), "done")
    }

    func testResolvedCompletionSoundUsesOverride() {
        var profile = SessionProfile(name: "Test", intervalSeconds: 60)
        profile.completionSoundOverride = "fanfare"
        XCTAssertEqual(profile.resolvedCompletionSound(defaults: globalDefaults), "fanfare")
    }

    // MARK: - Formatted Properties

    func testFormattedIntervalSeconds() {
        let profile = SessionProfile(name: "Test", intervalSeconds: 45)
        XCTAssertEqual(profile.formattedInterval, "45s")
    }

    func testFormattedIntervalMinutes() {
        let profile = SessionProfile(name: "Test", intervalSeconds: 120)
        XCTAssertEqual(profile.formattedInterval, "2m")
    }

    func testFormattedIntervalMinutesAndSeconds() {
        let profile = SessionProfile(name: "Test", intervalSeconds: 90)
        XCTAssertEqual(profile.formattedInterval, "1m 30s")
    }

    func testFormattedEndConditionUnlimited() {
        var profile = SessionProfile(name: "Test", intervalSeconds: 60)
        profile.endCondition = .unlimited
        XCTAssertEqual(profile.formattedEndCondition, "No limit")
    }

    func testFormattedEndConditionCount() {
        var profile = SessionProfile(name: "Test", intervalSeconds: 60)
        profile.endCondition = .afterCount(10)
        XCTAssertEqual(profile.formattedEndCondition, "10 reminders")
    }

    func testFormattedEndConditionDurationMinutes() {
        var profile = SessionProfile(name: "Test", intervalSeconds: 60)
        profile.endCondition = .afterDuration(1800)
        XCTAssertEqual(profile.formattedEndCondition, "30 min")
    }

    func testFormattedEndConditionDurationHours() {
        var profile = SessionProfile(name: "Test", intervalSeconds: 60)
        profile.endCondition = .afterDuration(3600)
        XCTAssertEqual(profile.formattedEndCondition, "1 hr")
    }

    // MARK: - Templates

    func testTemplatesExist() {
        XCTAssertFalse(SessionProfile.templates.isEmpty, "Should have default templates")
        XCTAssertEqual(SessionProfile.templates.count, 5)
    }

    func testTemplatesHaveValidIntervals() {
        for template in SessionProfile.templates {
            XCTAssertGreaterThan(template.intervalSeconds, 0, "\(template.name) has invalid interval")
        }
    }

    func testTemplatesHaveNames() {
        for template in SessionProfile.templates {
            XCTAssertFalse(template.name.isEmpty, "Template should have a name")
        }
    }

    // MARK: - Codable Roundtrip

    func testCodableRoundtrip() throws {
        var profile = SessionProfile(name: "Roundtrip Test", intervalSeconds: 45)
        profile.hapticModeOverride = .consistent
        profile.hapticPatternOverride = .success
        profile.intervalSoundOverride = "chime"
        profile.completionSoundOverride = "fanfare"
        profile.varianceSeconds = 10
        profile.endCondition = .afterCount(5)
        profile.showOnTimer = false

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(SessionProfile.self, from: data)

        XCTAssertEqual(decoded.name, "Roundtrip Test")
        XCTAssertEqual(decoded.intervalSeconds, 45)
        XCTAssertEqual(decoded.hapticModeOverride, .consistent)
        XCTAssertEqual(decoded.hapticPatternOverride, .success)
        XCTAssertEqual(decoded.intervalSoundOverride, "chime")
        XCTAssertEqual(decoded.completionSoundOverride, "fanfare")
        XCTAssertEqual(decoded.varianceSeconds, 10)
        XCTAssertEqual(decoded.endCondition, .afterCount(5))
        XCTAssertEqual(decoded.showOnTimer, false)
    }

    func testCodableRoundtripNilOverrides() throws {
        let profile = SessionProfile(name: "Nil Test", intervalSeconds: 60)
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(SessionProfile.self, from: data)

        XCTAssertNil(decoded.hapticModeOverride)
        XCTAssertNil(decoded.hapticPatternOverride)
        XCTAssertNil(decoded.intervalSoundOverride)
        XCTAssertNil(decoded.completionSoundOverride)
    }
}
