import SwiftUI

struct ProfileEditView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.profileStore) private var profileStore
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.purchaseManager) private var purchaseManager
    @Environment(\.dismiss) private var dismiss

    let existing: SessionProfile?

    @State private var name: String = ""
    @State private var icon: String = "figure.mixed.cardio"
    @State private var intervalSeconds: Int = 60
    @State private var customMinutes: Int = 1
    @State private var customSeconds: Int = 0
    @State private var useCustomInterval: Bool = false
    @State private var varianceSeconds: Int = 0
    @State private var varyEnabled: Bool = false
    @State private var endCondition: SessionEndCondition = .unlimited
    @State private var showDeleteConfirm = false
    @State private var showUpgrade = false
    @State private var upgradeFeature: PremiumFeature?

    // Override toggles
    @State private var customHaptics: Bool = false
    @State private var customSounds: Bool = false

    // Override values
    @State private var hapticMode: HapticMode = .randomized
    @State private var hapticPattern: HapticPattern = .notification
    @State private var hapticDestination: HapticDestination = .iPhone
    @State private var morseWord: String = ""
    @State private var intervalSound: String = "none"
    @State private var completionSound: String = "done"

    private var theme: AppTheme { themeManager.current }
    private let pillColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
    private let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
    private var isEditing: Bool { existing != nil }

    private static let availableIcons = [
        "figure.mixed.cardio",
        "figure.equestrian.sports",
        "figure.strengthtraining.traditional",
        "dumbbell.fill",
        "figure.yoga",
        "figure.stand",
        "figure.run",
        "figure.walk",
        "figure.cooldown",
        "figure.pilates",
        "figure.hiking",
        "figure.dance",
        "figure.martial.arts",
        "sportscourt.fill",
        "heart.fill",
    ]

    init(existing: SessionProfile? = nil) {
        self.existing = existing
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Name
                    sectionCard {
                        VStack(alignment: .leading, spacing: 6) {
                            sectionLabel("Name")
                            TextField("e.g. Morning Stretch, Monday Focus", text: $name)
                                .font(.body)
                                .padding(10)
                                .background(theme.pillBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // Icon
                    sectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("Icon")
                            LazyVGrid(columns: iconColumns, spacing: 8) {
                                ForEach(Self.availableIcons, id: \.self) { iconName in
                                    Button {
                                        icon = iconName
                                    } label: {
                                        Image(systemName: iconName)
                                            .font(.system(size: 20))
                                            .frame(width: 44, height: 44)
                                            .background(icon == iconName ? theme.accent : theme.pillBackground)
                                            .foregroundStyle(icon == iconName ? theme.onAccent : theme.primary)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .accessibilityLabel("\(iconName) icon\(icon == iconName ? ", selected" : "")")
                                }
                            }
                        }
                    }

                    // Interval
                    sectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("Interval")
                            LazyVGrid(columns: pillColumns, spacing: 6) {
                                ForEach(TimerViewModel.presets, id: \.seconds) { preset in
                                    pillButton(preset.label, isActive: !useCustomInterval && intervalSeconds == preset.seconds) {
                                        useCustomInterval = false
                                        intervalSeconds = preset.seconds
                                    }
                                }
                                pillButton("Custom", isActive: useCustomInterval, accentStyle: true) {
                                    useCustomInterval = true
                                }
                            }
                            if useCustomInterval {
                                HStack(spacing: 0) {
                                    customField(value: $customMinutes, range: 0...59, unit: "min")
                                    Text(":").font(.title3).foregroundStyle(theme.secondaryText).padding(.horizontal, 8)
                                    customField(value: $customSeconds, range: 0...59, unit: "sec")
                                }
                                .padding(8)
                                .background(theme.pillBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }

                    // Vary timing
                    sectionCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                sectionLabel("Vary timing")
                                if !purchaseManager.isPremium {
                                    Text("Add randomness so you don't anticipate the buzz")
                                        .font(.caption)
                                        .foregroundStyle(theme.secondaryText)
                                } else {
                                    Text(varyEnabled ? "\u{00B1} \(varianceSeconds)s around interval" : "Buzz at exact interval")
                                        .font(.caption)
                                        .foregroundStyle(theme.secondaryText)
                                }
                            }
                            Spacer()
                            if !purchaseManager.isPremium {
                                Button {
                                    upgradeFeature = .varyTiming
                                    showUpgrade = true
                                } label: {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundStyle(theme.secondaryText)
                                }
                            } else {
                                Toggle("", isOn: $varyEnabled)
                                    .labelsHidden()
                                    .tint(theme.accent)
                            }
                        }
                        if varyEnabled && purchaseManager.isPremium {
                            HStack {
                                Text("\u{00B1} 5s").font(.caption2).foregroundStyle(theme.secondaryText)
                                Slider(
                                    value: Binding(
                                        get: { Double(varianceSeconds) },
                                        set: { varianceSeconds = Int($0) }
                                    ),
                                    in: 5...60, step: 5
                                ).tint(theme.accent)
                                Text("\u{00B1} 60s").font(.caption2).foregroundStyle(theme.secondaryText)
                            }
                        }
                    }

                    // End after
                    sectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("End after")
                            LazyVGrid(columns: pillColumns, spacing: 6) {
                                ForEach(TimerViewModel.endOptions, id: \.label) { option in
                                    let condition = endConditionFromMode(option.mode)
                                    pillButton(option.label, isActive: endCondition == condition) {
                                        endCondition = condition
                                    }
                                }
                            }
                        }
                    }

                    // MARK: - Haptics override
                    sectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    sectionLabel("HAPTICS")
                                    if !customHaptics {
                                        Text("Using default: \(settingsStore.settings.hapticMode == .randomized ? "Randomized" : settingsStore.settings.hapticPattern.displayName)")
                                            .font(.caption)
                                            .foregroundStyle(theme.secondaryText)
                                    }
                                }
                                Spacer()
                                if !purchaseManager.isPremium {
                                    Button {
                                        upgradeFeature = .presetOverrides
                                        showUpgrade = true
                                    } label: {
                                        Image(systemName: "lock.fill")
                                            .font(.caption)
                                            .foregroundStyle(theme.secondaryText)
                                    }
                                } else {
                                    Toggle("", isOn: $customHaptics)
                                        .labelsHidden()
                                        .tint(theme.accent)
                                }
                            }

                            if customHaptics {
                                Text("Custom for this preset")
                                    .font(.caption2)
                                    .foregroundStyle(theme.accent)

                                Button {
                                    hapticMode = .randomized
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Randomized")
                                                .font(.subheadline)
                                                .foregroundStyle(theme.primary)
                                            Text("Varies each buzz")
                                                .font(.caption2)
                                                .foregroundStyle(theme.secondaryText)
                                        }
                                        Spacer()
                                        if hapticMode == .randomized {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(theme.accent)
                                                .fontWeight(.semibold)
                                        }
                                    }
                                }

                                Button {
                                    hapticMode = .consistent
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
                                        if hapticMode == .consistent {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(theme.accent)
                                                .fontWeight(.semibold)
                                        }
                                    }
                                }

                                Button {
                                    hapticMode = .morse
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Morse Code")
                                                .font(.subheadline)
                                                .foregroundStyle(theme.primary)
                                            Text("Spells a word in taps")
                                                .font(.caption2)
                                                .foregroundStyle(theme.secondaryText)
                                        }
                                        Spacer()
                                        if hapticMode == .morse {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(theme.accent)
                                                .fontWeight(.semibold)
                                        }
                                    }
                                }

                                if hapticMode == .consistent {
                                    Divider()
                                    ForEach(HapticPattern.allCases) { pattern in
                                        Button {
                                            hapticPattern = pattern
                                        } label: {
                                            HStack {
                                                Text(pattern.displayName)
                                                    .font(.subheadline)
                                                    .foregroundStyle(theme.primary)
                                                Spacer()
                                                if hapticPattern == pattern {
                                                    Image(systemName: "checkmark")
                                                        .foregroundStyle(theme.accent)
                                                        .fontWeight(.semibold)
                                                }
                                            }
                                        }
                                    }
                                }

                                if hapticMode == .morse {
                                    Divider()
                                    VStack(alignment: .leading, spacing: 4) {
                                        sectionLabel("MORSE WORD")
                                        TextField(
                                            MorsePlayer.defaultWord(from: name),
                                            text: $morseWord
                                        )
                                        #if os(iOS)
                                        .textInputAutocapitalization(.characters)
                                        #endif
                                        .font(.body.monospaced())
                                        .padding(10)
                                        .background(theme.pillBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .onChange(of: morseWord) { _, newValue in
                                            let filtered = String(newValue.filter { $0.isLetter }.prefix(5))
                                            if filtered != newValue { morseWord = filtered }
                                        }

                                        let displayWord = morseWord.isEmpty ? MorsePlayer.defaultWord(from: name) : morseWord
                                        Text("~\(String(format: "%.1f", MorsePlayer.estimatedDuration(for: displayWord)))s per buzz")
                                            .font(.caption2)
                                            .foregroundStyle(theme.secondaryText)
                                    }
                                }

                                // Haptic destination override
                                if ConnectivityService.shared.isReachable {
                                    Divider()
                                    VStack(alignment: .leading, spacing: 6) {
                                        sectionLabel("DESTINATION")
                                        ForEach(HapticDestination.allCases) { dest in
                                            Button {
                                                hapticDestination = dest
                                            } label: {
                                                HStack(spacing: 10) {
                                                    Image(systemName: dest.icon)
                                                        .frame(width: 20)
                                                    Text(dest.displayName)
                                                        .font(.subheadline)
                                                        .foregroundStyle(theme.primary)
                                                    Spacer()
                                                    if hapticDestination == dest {
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
                        }
                    }

                    // MARK: - Sounds override
                    sectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    sectionLabel("SOUNDS")
                                    if !customSounds {
                                        Text("Using defaults from Settings")
                                            .font(.caption)
                                            .foregroundStyle(theme.secondaryText)
                                    }
                                }
                                Spacer()
                                if !purchaseManager.isPremium {
                                    Button {
                                        upgradeFeature = .presetOverrides
                                        showUpgrade = true
                                    } label: {
                                        Image(systemName: "lock.fill")
                                            .font(.caption)
                                            .foregroundStyle(theme.secondaryText)
                                    }
                                } else {
                                    Toggle("", isOn: $customSounds)
                                        .labelsHidden()
                                        .tint(theme.accent)
                                }
                            }

                            if customSounds {
                                Text("Custom for this preset")
                                    .font(.caption2)
                                    .foregroundStyle(theme.accent)

                                #if os(iOS)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Interval")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(theme.primary)
                                    soundPicker(
                                        selection: $intervalSound,
                                        sounds: [noneOption] + AudioService.sounds.map {
                                            SoundOption(name: $0.name, displayName: $0.displayName)
                                        }
                                    )
                                }

                                Divider()

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Session Complete")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(theme.primary)
                                    soundPicker(
                                        selection: $completionSound,
                                        sounds: [noneOption] + AudioService.completionSounds.map {
                                            SoundOption(name: $0.name, displayName: $0.displayName)
                                        }
                                    )
                                }
                                #endif
                            }
                        }
                    }

                    // Delete button (edit mode only)
                    if isEditing {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Text("Delete Preset")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(theme.destructive)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(theme.background)
            .navigationTitle(isEditing ? "Edit Preset" : "New Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Delete Preset?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let id = existing?.id {
                        profileStore.delete(id: id)
                    }
                    dismiss()
                }
            }
            .onAppear { loadExisting() }
            .sheet(isPresented: $showUpgrade) {
                UpgradeView(highlight: upgradeFeature)
            }
        }
    }

    private func loadExisting() {
        guard let p = existing else { return }
        name = p.name
        icon = p.icon
        intervalSeconds = p.intervalSeconds
        varianceSeconds = p.varianceSeconds
        varyEnabled = p.varianceSeconds > 0
        endCondition = p.endCondition

        // Haptic overrides
        customHaptics = p.hapticModeOverride != nil || p.hapticPatternOverride != nil || p.morseWord != nil || p.hapticDestinationOverride != nil
        hapticMode = p.hapticModeOverride ?? settingsStore.settings.hapticMode
        hapticPattern = p.hapticPatternOverride ?? settingsStore.settings.hapticPattern
        hapticDestination = p.hapticDestinationOverride ?? settingsStore.settings.hapticDestination
        morseWord = p.morseWord ?? ""

        // Sound overrides
        customSounds = p.intervalSoundOverride != nil || p.completionSoundOverride != nil
        intervalSound = p.intervalSoundOverride ?? settingsStore.settings.intervalSound
        completionSound = p.completionSoundOverride ?? settingsStore.settings.completionSound

        let isPreset = TimerViewModel.presets.contains { $0.seconds == p.intervalSeconds }
        useCustomInterval = !isPreset
        if useCustomInterval {
            customMinutes = p.intervalSeconds / 60
            customSeconds = p.intervalSeconds % 60
        }
    }

    private func save() {
        let effectiveInterval = useCustomInterval ? (customMinutes * 60 + customSeconds) : intervalSeconds
        guard effectiveInterval > 0 else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        var profile = existing ?? SessionProfile(name: "", intervalSeconds: 60)
        profile.name = trimmedName
        profile.icon = icon
        profile.intervalSeconds = effectiveInterval
        profile.varianceSeconds = varyEnabled ? varianceSeconds : 0
        profile.endCondition = endCondition

        // Haptic overrides
        profile.hapticModeOverride = customHaptics ? hapticMode : nil
        profile.hapticPatternOverride = customHaptics && hapticMode == .consistent ? hapticPattern : nil
        profile.hapticDestinationOverride = customHaptics ? hapticDestination : nil
        profile.morseWord = customHaptics && hapticMode == .morse && !morseWord.isEmpty ? morseWord.uppercased() : nil

        // Sound overrides
        profile.intervalSoundOverride = customSounds ? intervalSound : nil
        profile.completionSoundOverride = customSounds ? completionSound : nil

        profileStore.save(profile)
        dismiss()
    }

    private func endConditionFromMode(_ mode: TimerViewModel.EndMode) -> SessionEndCondition {
        switch mode {
        case .unlimited: return .unlimited
        case .count(let n): return .afterCount(n)
        case .duration(let s): return .afterDuration(s)
        }
    }

    // MARK: - Shared UI helpers

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .medium))
            .tracking(1.2)
            .foregroundStyle(theme.secondaryText)
    }

    private func pillButton(_ label: String, isActive: Bool, accentStyle: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isActive ? (accentStyle ? AnyShapeStyle(theme.accent) : AnyShapeStyle(theme.primary)) : AnyShapeStyle(theme.pillBackground))
                .foregroundStyle(isActive ? theme.onAccent : theme.primary)
                .clipShape(Capsule())
        }
    }

    private func customField(value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        VStack(spacing: 2) {
            Picker(unit, selection: value) {
                ForEach(Array(range), id: \.self) { n in Text("\(n)").tag(n) }
            }
            .pickerStyle(.wheel)
            .frame(width: 60, height: 60)
            .clipped()
            Text(unit.uppercased())
                .font(.system(size: 8, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(theme.secondaryText)
        }
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
                if sound.name != "none" {
                    AudioService.preview(sound.name)
                }
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
