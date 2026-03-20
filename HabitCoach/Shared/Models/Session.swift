import Foundation

struct Session: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var profileId: UUID?
    var profileName: String
    var startedAt: Date
    var endedAt: Date?
    var intervalSeconds: Int
    var varianceSeconds: Int
    var reminderCount: Int
    var wasCancelled: Bool
    var sequenceId: UUID? = nil
    var sequenceIndex: Int? = nil
    var sequenceName: String? = nil

    var duration: TimeInterval? {
        guard let end = endedAt else { return nil }
        return end.timeIntervalSince(startedAt)
    }

    var formattedDuration: String {
        guard let dur = duration else { return "--" }
        let total = Int(dur)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
