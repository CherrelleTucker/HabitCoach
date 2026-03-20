import Foundation
import os.log

private let logger = Logger(subsystem: "com.ctuckersolutions.habitcoach", category: "ProfileStore")

@MainActor @Observable
class ProfileStore {
    private static let storageKey = "saved_profiles"

    var profiles: [SessionProfile] = []

    init() {
        load()
    }

    func save(_ profile: SessionProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        persist()
    }

    func delete(at offsets: IndexSet) {
        profiles.remove(atOffsets: offsets)
        persist()
    }

    func delete(id: UUID) {
        profiles.removeAll { $0.id == id }
        persist()
    }

    func replaceAll(_ newProfiles: [SessionProfile]) {
        profiles = newProfiles
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(profiles)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
            #if os(iOS)
            ConnectivityService.shared.sendProfiles(profiles)
            #endif
        } catch {
            logger.error("Failed to encode profiles: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else {
            seedTemplates()
            return
        }
        do {
            profiles = try JSONDecoder().decode([SessionProfile].self, from: data)
        } catch {
            logger.error("Failed to decode profiles: \(error.localizedDescription)")
            seedTemplates()
        }
    }

    private func seedTemplates() {
        profiles = SessionProfile.templates.map { template in
            var p = template
            p.isTemplate = true
            return p
        }
        persist()
    }
}
