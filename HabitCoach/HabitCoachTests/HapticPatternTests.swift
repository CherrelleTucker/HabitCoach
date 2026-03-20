import XCTest
@testable import HabitCoach

final class HapticPatternTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(HapticPattern.allCases.count, 5)
    }

    func testDisplayNames() {
        XCTAssertEqual(HapticPattern.notification.displayName, "Strong Tap")
        XCTAssertEqual(HapticPattern.click.displayName, "Light Tap")
        XCTAssertEqual(HapticPattern.success.displayName, "Confirmation")
        XCTAssertEqual(HapticPattern.directionUp.displayName, "Encouraging")
        XCTAssertEqual(HapticPattern.retry.displayName, "Gentle Nudge")
    }

    func testIdentifiable() {
        for pattern in HapticPattern.allCases {
            XCTAssertEqual(pattern.id, pattern.rawValue)
        }
    }

    func testCodableRoundtrip() throws {
        for pattern in HapticPattern.allCases {
            let data = try JSONEncoder().encode(pattern)
            let decoded = try JSONDecoder().decode(HapticPattern.self, from: data)
            XCTAssertEqual(decoded, pattern)
        }
    }

    func testUniqueDisplayNames() {
        let names = HapticPattern.allCases.map(\.displayName)
        XCTAssertEqual(names.count, Set(names).count, "Display names should be unique")
    }

    func testUniqueRawValues() {
        let values = HapticPattern.allCases.map(\.rawValue)
        XCTAssertEqual(values.count, Set(values).count, "Raw values should be unique")
    }
}
