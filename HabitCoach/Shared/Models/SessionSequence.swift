import Foundation

enum SequenceTransition: String, Codable, Hashable {
    case autoAdvance
    case manual
}

struct SequenceStep: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var profile: SessionProfile
    var endCondition: SessionEndCondition

    var estimatedDuration: Int? {
        switch endCondition {
        case .unlimited: return nil
        case .afterCount: return nil
        case .afterDuration(let s): return s
        }
    }

    var formattedEndCondition: String {
        switch endCondition {
        case .unlimited: return "No limit"
        case .afterCount(let n): return "\(n) reminders"
        case .afterDuration(let s):
            if s >= 3600 { return "\(s / 3600) hr" }
            return "\(s / 60) min"
        }
    }
}

struct SessionSequence: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var icon: String = "arrow.triangle.2.circlepath"
    var steps: [SequenceStep]
    var transition: SequenceTransition = .autoAdvance
    var countdownSeconds: Int = 5
    var createdAt: Date = Date()

    var isValid: Bool {
        !steps.isEmpty && steps.allSatisfy { step in
            switch step.endCondition {
            case .unlimited: return false
            case .afterCount, .afterDuration: return true
            }
        }
    }

    var totalEstimatedDuration: Int? {
        let durations = steps.compactMap { $0.estimatedDuration }
        guard durations.count == steps.count else { return nil }
        return durations.reduce(0, +)
    }

    var formattedTotalDuration: String {
        guard let total = totalEstimatedDuration else { return "--" }
        if total >= 3600 {
            let h = total / 3600
            let m = (total % 3600) / 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(total / 60)m"
    }
}
