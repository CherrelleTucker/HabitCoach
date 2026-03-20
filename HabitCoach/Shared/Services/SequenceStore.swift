import Foundation
import os.log

private let logger = Logger(subsystem: "com.ctuckersolutions.habitcoach", category: "SequenceStore")

@MainActor @Observable
class SequenceStore {
    private static let storageKey = "saved_sequences"

    var sequences: [SessionSequence] = []

    init() {
        load()
    }

    func save(_ sequence: SessionSequence) {
        if let index = sequences.firstIndex(where: { $0.id == sequence.id }) {
            sequences[index] = sequence
        } else {
            sequences.append(sequence)
        }
        persist()
    }

    func delete(id: UUID) {
        sequences.removeAll { $0.id == id }
        persist()
    }

    func replaceAll(_ newSequences: [SessionSequence]) {
        sequences = newSequences
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(sequences)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
            #if os(iOS)
            ConnectivityService.shared.sendSequences(sequences)
            #endif
        } catch {
            logger.error("Failed to encode sequences: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else {
            return
        }
        do {
            sequences = try JSONDecoder().decode([SessionSequence].self, from: data)
        } catch {
            logger.error("Failed to decode sequences: \(error.localizedDescription)")
        }
    }
}
