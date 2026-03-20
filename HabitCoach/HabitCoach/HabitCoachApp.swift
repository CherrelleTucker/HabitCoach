import SwiftUI

@main
struct HabitCoachApp: App {
    @State private var themeManager = ThemeManager()
    @State private var sessionStore = SessionStore()
    @State private var profileStore = ProfileStore()
    @State private var settingsStore = SettingsStore()
    @State private var sequenceStore = SequenceStore()
    @State private var purchaseManager = PurchaseManager()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    private let connectivity = ConnectivityService.shared

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                ContentView()
                    .environment(\.themeManager, themeManager)
                    .environment(\.sessionStore, sessionStore)
                    .environment(\.profileStore, profileStore)
                    .environment(\.settingsStore, settingsStore)
                    .environment(\.sequenceStore, sequenceStore)
                    .environment(\.purchaseManager, purchaseManager)
                    .onAppear {
                        applyWindowBackground()
                        syncToWatch()
                    }
                    .onChange(of: themeManager.current) { _, _ in applyWindowBackground() }
                    .onChange(of: connectivity.receivedSession) { _, session in
                        if let session {
                            sessionStore.save(session)
                            connectivity.receivedSession = nil
                        }
                    }
                    .onChange(of: connectivity.receivedSequences) { _, sequences in
                        if let sequences {
                            sequenceStore.replaceAll(sequences)
                            connectivity.receivedSequences = nil
                        }
                    }
                    .onChange(of: connectivity.isReachable) { _, reachable in
                        if reachable { syncToWatch() }
                    }
            } else {
                OnboardingView()
                    .environment(\.themeManager, themeManager)
                    .environment(\.sessionStore, sessionStore)
                    .environment(\.profileStore, profileStore)
                    .environment(\.settingsStore, settingsStore)
                    .environment(\.sequenceStore, sequenceStore)
                    .environment(\.purchaseManager, purchaseManager)
            }
        }
        .defaultAppStorage(.standard)
    }

    private func syncToWatch() {
        connectivity.sendProfiles(profileStore.profiles)
        connectivity.sendSequences(sequenceStore.sequences)
        connectivity.sendSettings(settingsStore.settings)
        connectivity.sendPremiumStatus(purchaseManager.isPremium)
    }

    private func applyWindowBackground() {
        let bgColor = themeManager.current.uiBackgroundColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for scene in UIApplication.shared.connectedScenes {
                guard let ws = scene as? UIWindowScene else { continue }
                ws.windows.forEach { $0.backgroundColor = bgColor }
            }
        }
    }
}

// MARK: - Environment Keys

private struct SessionStoreKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = SessionStore()
}

private struct ProfileStoreKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = ProfileStore()
}

private struct SettingsStoreKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = SettingsStore()
}

private struct SequenceStoreKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = SequenceStore()
}

extension EnvironmentValues {
    var sessionStore: SessionStore {
        get { self[SessionStoreKey.self] }
        set { self[SessionStoreKey.self] = newValue }
    }

    var profileStore: ProfileStore {
        get { self[ProfileStoreKey.self] }
        set { self[ProfileStoreKey.self] = newValue }
    }

    var settingsStore: SettingsStore {
        get { self[SettingsStoreKey.self] }
        set { self[SettingsStoreKey.self] = newValue }
    }

    var sequenceStore: SequenceStore {
        get { self[SequenceStoreKey.self] }
        set { self[SequenceStoreKey.self] = newValue }
    }
}
