import SwiftUI

struct SettingsView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.purchaseManager) private var purchaseManager
    @State private var soundsExpanded = false
    @State private var showUpgrade = false
    @State private var upgradeFeature: PremiumFeature?

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(spacing: 0) {
                Text("Settings")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                VStack(spacing: 6) {
                    // MARK: - Haptics (global default)
                    sectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("DEFAULT HAPTICS")

                            Button {
                                settingsStore.settings.hapticMode = .randomized
                                settingsStore.save()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Randomized")
                                            .font(.subheadline)
                                            .foregroundStyle(theme.primary)
                                        Text("Varies each buzz so you don't tune it out")
                                            .font(.caption2)
                                            .foregroundStyle(theme.secondaryText)
                                    }
                                    Spacer()
                                    if settingsStore.settings.hapticMode == .randomized {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(theme.accent)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }

                            Button {
                                if purchaseManager.isPremium {
                                    settingsStore.settings.hapticMode = .consistent
                                    settingsStore.save()
                                } else {
                                    upgradeFeature = .consistentHaptics
                                    showUpgrade = true
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Consistent")
                                            .font(.subheadline)
                                            .foregroundStyle(theme.primary)
                                        Text("Same pattern every time")
                                            .font(.caption2)
                                            .foregroundStyle(theme.secondaryText)
                                    }
                                    Spacer()
                                    if !purchaseManager.isPremium {
                                        Image(systemName: "lock.fill")
                                            .font(.caption)
                                            .foregroundStyle(theme.secondaryText)
                                    } else if settingsStore.settings.hapticMode == .consistent {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(theme.accent)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }

                            if settingsStore.settings.hapticMode == .consistent {
                                Divider()
                                ForEach(HapticPattern.allCases) { pattern in
                                    Button {
                                        settingsStore.settings.hapticPattern = pattern
                                        settingsStore.save()
                                        previewHaptic(pattern)
                                    } label: {
                                        HStack {
                                            Text(pattern.displayName)
                                                .font(.subheadline)
                                                .foregroundStyle(theme.primary)
                                            Spacer()
                                            if settingsStore.settings.hapticPattern == pattern {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(theme.accent)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                    }
                                }
                            }

                            Button {
                                if purchaseManager.isPremium {
                                    settingsStore.settings.hapticMode = .morse
                                    settingsStore.save()
                                } else {
                                    upgradeFeature = .morseHaptics
                                    showUpgrade = true
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Morse Code")
                                            .font(.subheadline)
                                            .foregroundStyle(theme.primary)
                                        Text("Spells a word in taps you can feel")
                                            .font(.caption2)
                                            .foregroundStyle(theme.secondaryText)
                                    }
                                    Spacer()
                                    if !purchaseManager.isPremium {
                                        Image(systemName: "lock.fill")
                                            .font(.caption)
                                            .foregroundStyle(theme.secondaryText)
                                    } else if settingsStore.settings.hapticMode == .morse {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(theme.accent)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                    }

                    // MARK: - Haptic Destination
                    if ConnectivityService.shared.isReachable {
                        sectionCard {
                            VStack(alignment: .leading, spacing: 8) {
                                sectionLabel("HAPTIC DESTINATION")

                                ForEach(HapticDestination.allCases) { dest in
                                    Button {
                                        if purchaseManager.isPremium {
                                            settingsStore.settings.hapticDestination = dest
                                            settingsStore.save()
                                        } else {
                                            upgradeFeature = .hapticDestination
                                            showUpgrade = true
                                        }
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: dest.icon)
                                                .frame(width: 20)
                                            Text(dest.displayName)
                                                .font(.subheadline)
                                                .foregroundStyle(theme.primary)
                                            Spacer()
                                            if !purchaseManager.isPremium && dest != .iPhone {
                                                Image(systemName: "lock.fill")
                                                    .font(.caption)
                                                    .foregroundStyle(theme.secondaryText)
                                            } else if settingsStore.settings.hapticDestination == dest {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(theme.accent)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // MARK: - Sounds (global default)
                    sectionCard {
                        DisclosureGroup(isExpanded: $soundsExpanded) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Presets inherit these unless customized.")
                                    .font(.caption2)
                                    .foregroundStyle(theme.secondaryText)

                                #if os(iOS)
                                // Interval sound
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Interval")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(theme.primary)
                                    soundPicker(
                                        selection: Binding(
                                            get: { settingsStore.settings.intervalSound },
                                            set: {
                                                settingsStore.settings.intervalSound = $0
                                                settingsStore.save()
                                            }
                                        ),
                                        sounds: [noneOption] + AudioService.sounds.map {
                                            SoundOption(name: $0.name, displayName: $0.displayName)
                                        }
                                    )
                                }

                                Divider()

                                // Completion sound
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Session Complete")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(theme.primary)
                                    soundPicker(
                                        selection: Binding(
                                            get: { settingsStore.settings.completionSound },
                                            set: {
                                                settingsStore.settings.completionSound = $0
                                                settingsStore.save()
                                            }
                                        ),
                                        sounds: [noneOption] + AudioService.completionSounds.map {
                                            SoundOption(name: $0.name, displayName: $0.displayName)
                                        }
                                    )
                                }
                                #endif
                            }
                            .padding(.top, 4)
                        } label: {
                            sectionLabel("DEFAULT SOUNDS")
                        }
                        .tint(theme.accent)
                    }

                    // MARK: - Focus
                    sectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    sectionLabel("FOCUS REMINDER")
                                    Text("Show tip to enable Focus before sessions")
                                        .font(.caption)
                                        .foregroundStyle(theme.secondaryText)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { settingsStore.settings.focusReminderEnabled },
                                    set: {
                                        settingsStore.settings.focusReminderEnabled = $0
                                        settingsStore.save()
                                    }
                                ))
                                .labelsHidden()
                                .tint(theme.accent)
                            }

                            Text("When enabled, a tip appears on the timer screen reminding you to swipe down and turn on Focus for an uninterrupted session.")
                                .font(.caption2)
                                .foregroundStyle(theme.secondaryText)

                            Text("On Apple Watch, workout sessions automatically reduce notifications.")
                                .font(.caption2)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }

                    // MARK: - Appearance
                    sectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("APPEARANCE")

                            ForEach(AppTheme.allCases) { option in
                                let isDefault = option == .coachAuthority
                                let isLocked = !isDefault && !purchaseManager.isPremium
                                Button {
                                    if isLocked {
                                        upgradeFeature = .allThemes
                                        showUpgrade = true
                                    } else {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            themeManager.current = option
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        HStack(spacing: 4) {
                                            Circle().fill(option.primary).frame(width: 20, height: 20)
                                            Circle().fill(option.accent).frame(width: 20, height: 20)
                                        }
                                        Text(option.displayName)
                                            .font(.subheadline)
                                            .foregroundStyle(theme.primary)
                                        Spacer()
                                        if isLocked {
                                            Image(systemName: "lock.fill")
                                                .font(.caption)
                                                .foregroundStyle(theme.secondaryText)
                                        } else if themeManager.current == option {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(theme.accent)
                                                .fontWeight(.semibold)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // MARK: - Health
                    sectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("HEALTH")

                            Button {
                                if let url = URL(string: "x-apple-health://") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text("Manage HealthKit Permissions")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.primary)
                            }
                        }
                    }

                    // MARK: - FAQ
                    sectionCard {
                        VStack(alignment: .leading, spacing: 4) {
                            sectionLabel("FAQ")

                            faqItem(
                                q: "Why are haptics randomized by default?",
                                a: "Your body naturally adapts to repeated stimuli and tunes them out. Varying the haptic pattern each buzz keeps you noticing the reminder."
                            )
                            faqItem(
                                q: "Do I need an Apple Watch?",
                                a: "No. HabitCoach works great on iPhone alone — your phone plays haptic buzzes and sounds during sessions. An Apple Watch adds wrist haptics so your phone can stay in your pocket."
                            )
                            faqItem(
                                q: "How are iPhone and Watch haptics different?",
                                a: "iPhone haptics use the Taptic Engine and are felt in your hand or on a table. Apple Watch haptics tap your wrist — useful when your phone is in a bag or pocket."
                            )
                            faqItem(
                                q: "What does Focus mode do?",
                                a: "It silences other app notifications during your session. Swipe down from the top-right corner and tap Focus to enable it. On Apple Watch, workout sessions do this automatically."
                            )
                            faqItem(
                                q: "How do preset overrides work?",
                                a: "Each preset starts with your global default settings above. When editing a preset, toggle 'Custom' to change sounds or haptics for that specific activity."
                            )
                            faqItem(
                                q: "Will the screen stay on?",
                                a: "Yes. Your device prevents sleep during active sessions so you never lose your timer."
                            )
                            faqItem(
                                q: "How is session history stored?",
                                a: "Sessions are stored locally on your device. If you have an Apple Watch, watch sessions sync to your iPhone automatically when in range."
                            )
                        }
                    }

                    // MARK: - Privacy
                    sectionCard {
                        NavigationLink {
                            PrivacyPolicyView()
                        } label: {
                            HStack {
                                Text("Privacy Policy")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(theme.secondaryText)
                            }
                        }
                    }

                    // MARK: - Version
                    sectionCard {
                        HStack {
                            Text("Version")
                                .font(.subheadline)
                                .foregroundStyle(theme.primary)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                                .font(.subheadline)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeView(highlight: upgradeFeature)
        }
        } // NavigationStack
    }

    // MARK: - Helpers

    private func previewHaptic(_ pattern: HapticPattern) {
        #if os(iOS)
        switch pattern {
        case .notification:
            // Double warning notification — matches TimerViewModel
            let gen = UINotificationFeedbackGenerator()
            gen.prepare()
            gen.notificationOccurred(.warning)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                gen.notificationOccurred(.warning)
            }
        case .click:
            // Strong double-tap with .heavy at full intensity — matches TimerViewModel
            let gen = UIImpactFeedbackGenerator(style: .heavy)
            gen.prepare()
            gen.impactOccurred(intensity: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                gen.impactOccurred(intensity: 1.0)
            }
        case .success:
            // Triple success pulse — matches TimerViewModel
            let gen = UINotificationFeedbackGenerator()
            gen.prepare()
            gen.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                let impact = UIImpactFeedbackGenerator(style: .heavy)
                impact.impactOccurred(intensity: 1.0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                let impact = UIImpactFeedbackGenerator(style: .heavy)
                impact.impactOccurred(intensity: 1.0)
            }
        case .directionUp:
            // Strong double-tap with .rigid at full intensity — matches TimerViewModel
            let gen = UIImpactFeedbackGenerator(style: .rigid)
            gen.prepare()
            gen.impactOccurred(intensity: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                gen.impactOccurred(intensity: 1.0)
            }
        case .retry:
            // Long strong buzz with 4 sustained .heavy pulses — matches TimerViewModel
            let gen = UIImpactFeedbackGenerator(style: .heavy)
            gen.prepare()
            gen.impactOccurred(intensity: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                gen.impactOccurred(intensity: 1.0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                gen.impactOccurred(intensity: 1.0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                gen.impactOccurred(intensity: 1.0)
            }
        }
        #endif
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .tracking(1.2)
            .foregroundStyle(theme.secondaryText)
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func faqItem(q: String, a: String) -> some View {
        DisclosureGroup {
            Text(a)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .padding(.top, 2)
        } label: {
            Text(q)
                .font(.subheadline)
                .foregroundStyle(theme.primary)
        }
        .tint(theme.accent)
    }

    // MARK: - Sound picker

    private struct SoundOption: Identifiable {
        let name: String
        let displayName: String
        var id: String { name }
    }

    private var noneOption: SoundOption {
        SoundOption(name: "none", displayName: "None")
    }

    private func soundPicker(selection: Binding<String>, sounds: [SoundOption]) -> some View {
        ForEach(sounds) { sound in
            Button {
                selection.wrappedValue = sound.name
                #if os(iOS)
                if sound.name != "none" { AudioService.preview(sound.name) }
                #endif
            } label: {
                HStack {
                    Text(sound.displayName)
                        .font(.subheadline)
                        .foregroundStyle(theme.primary)
                    Spacer()
                    if selection.wrappedValue == sound.name {
                        Image(systemName: "checkmark")
                            .foregroundStyle(theme.accent)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }
}
