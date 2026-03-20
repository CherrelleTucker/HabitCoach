import XCTest
@testable import HabitCoach

final class EndConditionTests: XCTestCase {

    // MARK: - Codable

    func testCodableUnlimited() throws {
        let condition = SessionEndCondition.unlimited
        let data = try JSONEncoder().encode(condition)
        let decoded = try JSONDecoder().decode(SessionEndCondition.self, from: data)
        XCTAssertEqual(decoded, condition)
    }

    func testCodableAfterCount() throws {
        let condition = SessionEndCondition.afterCount(10)
        let data = try JSONEncoder().encode(condition)
        let decoded = try JSONDecoder().decode(SessionEndCondition.self, from: data)
        XCTAssertEqual(decoded, condition)
    }

    func testCodableAfterDuration() throws {
        let condition = SessionEndCondition.afterDuration(1800)
        let data = try JSONEncoder().encode(condition)
        let decoded = try JSONDecoder().decode(SessionEndCondition.self, from: data)
        XCTAssertEqual(decoded, condition)
    }

    // MARK: - Hashable

    func testHashableEquality() {
        XCTAssertEqual(SessionEndCondition.unlimited, SessionEndCondition.unlimited)
        XCTAssertEqual(SessionEndCondition.afterCount(5), SessionEndCondition.afterCount(5))
        XCTAssertNotEqual(SessionEndCondition.afterCount(5), SessionEndCondition.afterCount(10))
        XCTAssertNotEqual(SessionEndCondition.afterCount(5), SessionEndCondition.afterDuration(5))
    }

    func testUsableInSet() {
        let conditions: Set<SessionEndCondition> = [
            .unlimited, .afterCount(5), .afterDuration(300), .afterCount(5)
        ]
        XCTAssertEqual(conditions.count, 3, "Duplicate .afterCount(5) should be deduplicated")
    }
}
