import XCTest
@testable import HabitCoach

@MainActor
final class MorsePlayerTests: XCTestCase {

    func testDefaultWordFromSimpleName() {
        XCTAssertEqual(MorsePlayer.defaultWord(from: "Yoga Flow"), "YOGA")
    }

    func testDefaultWordFromShortName() {
        XCTAssertEqual(MorsePlayer.defaultWord(from: "PT"), "PT")
    }

    func testDefaultWordStripsNonAlpha() {
        XCTAssertEqual(MorsePlayer.defaultWord(from: "30-Min HIIT"), "MINH")
    }

    func testDefaultWordFromEmptyString() {
        XCTAssertEqual(MorsePlayer.defaultWord(from: ""), "")
    }

    func testDefaultWordCapsAtFourChars() {
        XCTAssertEqual(MorsePlayer.defaultWord(from: "Strength Circuit"), "STRE")
    }

    func testEstimatedDurationPositive() {
        let duration = MorsePlayer.estimatedDuration(for: "SOS")
        XCTAssertGreaterThan(duration, 0)
    }

    func testEstimatedDurationEmpty() {
        XCTAssertEqual(MorsePlayer.estimatedDuration(for: ""), 0)
    }

    func testEstimatedDurationSOS() {
        // S = ... (3 dots + 2 intra gaps = 3+2=5 units)
        // O = --- (9 + 2 intra gaps = 9+2=11 units)
        // S = ... (5 units)
        // Inter-char gaps: 3 + 3 = 6 units
        // Total: 5 + 11 + 5 + 6 = 27 units
        let expected = 27.0 * 0.12
        let actual = MorsePlayer.estimatedDuration(for: "SOS")
        XCTAssertEqual(actual, expected, accuracy: 0.01)
    }

    func testEstimatedDurationIgnoresInvalidChars() {
        // "A!B" should be same as "AB"
        let withSymbols = MorsePlayer.estimatedDuration(for: "A!B")
        let withoutSymbols = MorsePlayer.estimatedDuration(for: "AB")
        XCTAssertEqual(withSymbols, withoutSymbols)
    }
}
