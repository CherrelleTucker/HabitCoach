import SwiftUI

struct TimerView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.sessionStore) private var sessionStore
    @Environment(\.profileStore) private var profileStore
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.purchaseManager) private var purchaseManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = TimerViewModel()
    @Binding var sessionActive: Bool
    @State private var showStopConfirm = false
    @State private var showPresetPicker = false
    @State private var focusTipDismissed = false
    @State private var completedSession: Session?
    @State private var showHapticSettingsAlert = false
    @State private var hasShownHapticTip = false

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        VStack(spacing: 0) {
            if let session = completedSession {
                completionView(session)
            } else if viewModel.timerService.isRunning {
                activeSessionView
            } else {
                idleView
            }
        }
        .onAppear {
            viewModel.sessionStore = sessionStore
            viewModel.settingsStore = settingsStore
        }
        .onChange(of: viewModel.timerService.isRunning) { wasRunning, running in
            if wasRunning && !running && !viewModel.timerService.isComplete {
                sessionActive = false
                UIApplication.shared.isIdleTimerDisabled = false
            } else if wasRunning && !running && viewModel.timerService.isComplete {
                sessionActive = false
                UIApplication.shared.isIdleTimerDisabled = false
                let session = buildCompletedSession()
                sessionStore.save(session)
                completedSession = session
            } else {
                sessionActive = running
                UIApplication.shared.isIdleTimerDisabled = running
            }
            if !running { focusTipDismissed = false }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && viewModel.timerService.isRunning {
                viewModel.timerService.resumeFromBackground()
            }
        }
        .alert("Haptic Reminders", isPresented: $showHapticSettingsAlert) {
            Button("Got It") { }
        } message: {
            Text("For the strongest buzz, make sure these are ON in your iPhone Settings:\n\n• Settings → Sounds & Haptics → System Haptics (ON)\n• Settings → Accessibility → Touch → Vibration (ON)\n• Silent mode switch (ring/silent) does NOT affect haptics\n\nIf you still can't feel haptics, try removing your phone case during sessions.")
        }
    }

    private func buildCompletedSession() -> Session {
        let defaults = settingsStore.settings
        // Play completion sound
        let completionSound = viewModel.selectedProfile?.resolvedCompletionSound(defaults: defaults) ?? defaults.completionSound
        #if os(iOS)
        AudioService.play(completionSound)
        // Haptic celebration
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif

        return Session(
            profileId: viewModel.selectedProfile?.id,
            profileName: viewModel.selectedProfile?.name ?? "Quick Session",
            startedAt: Date().addingTimeInterval(-Double(viewModel.timerService.elapsedSeconds)),
            endedAt: Date(),
            intervalSeconds: viewModel.effectiveIntervalSeconds,
            varianceSeconds: viewModel.randomizeEnabled ? viewModel.varianceSeconds : 0,
            reminderCount: viewModel.timerService.reminderCount,
            wasCancelled: false
        )
    }

    // MARK: - Completion view

    private func completionView(_ session: Session) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(theme.success)

            Text("Session Complete")
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.primary)

            VStack(spacing: 8) {
                completionStat(label: "Duration", value: session.formattedDuration)
                completionStat(label: "Reminders", value: "\(session.reminderCount)")
                if let name = viewModel.selectedProfile?.name {
                    completionStat(label: "Preset", value: name)
                }
            }
            .padding(16)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 32)

            Spacer()

            Button {
                completedSession = nil
            } label: {
                Text("Done")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.accent)
                    .foregroundStyle(theme.onAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private func completionStat(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.primary)
        }
    }

    // MARK: - Idle (setup) view

    private var idleView: some View {
        VStack(spacing: 0) {
            Spacer().frame(maxHeight: 40)

            VStack(spacing: 2) {
                Text(formattedSelectedInterval)
                    .font(.system(size: 56, weight: .light, design: .monospaced))
                    .foregroundStyle(theme.primary)

                if let profile = viewModel.selectedProfile {
                    Text(profile.name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.accent)
                } else {
                    Text("Ready to start")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .padding(.bottom, 12)

            // Preset picker
            profilePicker
                .padding(.bottom, 8)

            setupControls

            // Focus tip
            if settingsStore.settings.focusReminderEnabled && !focusTipDismissed {
                HStack(spacing: 8) {
                    Image(systemName: "moon.fill")
                        .font(.caption)
                        .foregroundStyle(theme.accent)
                    Text("Swipe down and enable Focus for an uninterrupted session")
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryText)
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            focusTipDismissed = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(theme.secondaryText)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                }
                .padding(10)
                .background(theme.pillBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                if !hasShownHapticTip {
                    hasShownHapticTip = true
                    showHapticSettingsAlert = true
                    // Start session after a brief delay so user sees the tip
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        viewModel.start(destination: resolvedDestination)
                    }
                } else {
                    viewModel.start(destination: resolvedDestination)
                }
            } label: {
                Text("Start Session")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.accent)
                    .foregroundStyle(theme.onAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityLabel("Start session")
            .accessibilityHint("Begins a timed coaching session with haptic reminders")
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if purchaseManager.isPremium && ConnectivityService.shared.isReachable {
                // Premium + watch: show destination label
                Label("Haptics: \(resolvedDestination.displayName)", systemImage: resolvedDestination.icon)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .padding(.top, 4)
            } else if ConnectivityService.shared.isReachable {
                // Free + watch: keep two-button layout
                Button {
                    viewModel.startOnWatch()
                } label: {
                    Label("Start on Watch", systemImage: "applewatch")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.pillBackground)
                        .foregroundStyle(theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
            } else {
                // No watch
                Label("Haptics and sounds will play on your iPhone", systemImage: "iphone.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .padding(.top, 8)
            }

            Spacer()
        }
    }

    private var resolvedDestination: HapticDestination {
        let defaults = settingsStore.settings
        return viewModel.selectedProfile?.resolvedHapticDestination(defaults: defaults) ?? defaults.hapticDestination
    }

    /// Show the selected interval duration in idle mode instead of "00:00"
    private var formattedSelectedInterval: String {
        let total = viewModel.effectiveIntervalSeconds
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Active session (locked) view

    private var activeSessionView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Big timer
            VStack(spacing: 4) {
                Text(viewModel.formattedElapsed)
                    .font(.system(size: 72, weight: .light, design: .monospaced))
                    .foregroundStyle(theme.accent)
                    .accessibilityLabel("Elapsed time: \(viewModel.formattedElapsed)")

                Text("\(viewModel.timerService.reminderCount) reminders \u{00B7} next in \(viewModel.formattedNextBuzz)")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }

            Spacer().frame(height: 32)

            // Progress (if finite)
            if let total = viewModel.timerService.totalCycles, total > 0 {
                VStack(spacing: 8) {
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.pillBackground)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.accent)
                                .frame(width: geo.size.width * CGFloat(viewModel.timerService.reminderCount) / CGFloat(total))
                        }
                    }
                    .frame(height: 8)
                    .padding(.horizontal, 40)

                    Text("\(viewModel.timerService.reminderCount) of \(total)")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                        .accessibilityLabel("\(viewModel.timerService.reminderCount) of \(total) reminders complete")
                }
            }

            Spacer()

            // Cancel button — requires confirmation
            Button {
                showStopConfirm = true
            } label: {
                Text("End Session")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.destructive)
                    .foregroundStyle(theme.onAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityLabel("End session")
            .accessibilityHint("Stops the current coaching session")
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .alert("End Session?", isPresented: $showStopConfirm) {
            Button("Keep Going", role: .cancel) { }
            Button("End Session", role: .destructive) {
                viewModel.stop()
            }
        } message: {
            Text("Your current session will be stopped.")
        }
    }

    // MARK: - Preset Picker

    private var timerPresets: [SessionProfile] {
        let all = profileStore.profiles.filter(\.showOnTimer)
        let limit = purchaseManager.isPremium ? 7 : 3
        return Array(all.prefix(limit))
    }

    private var profilePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                profileChip("Quick", icon: "bolt.fill", isActive: viewModel.selectedProfile == nil) {
                    viewModel.clearProfile()
                }
                ForEach(timerPresets) { profile in
                    profileChip(profile.name, icon: profile.icon, isActive: viewModel.selectedProfile?.id == profile.id) {
                        viewModel.loadProfile(profile)
                    }
                }
                // Edit button (always visible so user can add presets back)
                Button {
                    showPresetPicker = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14))
                        .frame(width: 44, height: 44)
                        .background(theme.pillBackground)
                        .foregroundStyle(theme.secondaryText)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Edit presets")
            }
            .padding(.horizontal, 16)
        }
        .sheet(isPresented: $showPresetPicker) {
            TimerPresetPickerView()
        }
    }

    private func profileChip(_ label: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(width: 44, height: 44)
                .background(isActive ? theme.primary : theme.pillBackground)
                .foregroundStyle(isActive ? theme.onAccent : theme.primary)
                .clipShape(Circle())
        }
        .accessibilityLabel("\(label) preset\(isActive ? ", selected" : "")")
    }

    // MARK: - Setup Controls

    private let pillColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    private var setupControls: some View {
        VStack(spacing: 8) {
            // Interval section
            sectionCard {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Interval")

                    LazyVGrid(columns: pillColumns, spacing: 6) {
                        ForEach(TimerViewModel.presets, id: \.seconds) { preset in
                            pillButton(
                                preset.label,
                                isActive: viewModel.intervalMode == .preset(preset.seconds)
                            ) {
                                viewModel.intervalMode = .preset(preset.seconds)
                            }
                        }
                        pillButton(
                            "Custom",
                            isActive: viewModel.intervalMode == .custom,
                            accentStyle: true
                        ) {
                            viewModel.intervalMode = .custom
                        }
                    }

                    // Custom editor
                    if viewModel.intervalMode == .custom {
                        HStack(spacing: 0) {
                            customField(value: $viewModel.customMinutes, range: 0...59, unit: "min")
                            Text(":").font(.title3).foregroundStyle(theme.secondaryText).padding(.horizontal, 8)
                            customField(value: $viewModel.customSeconds, range: 0...59, unit: "sec")
                        }
                        .padding(8)
                        .background(theme.pillBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            // Vary timing section
            sectionCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        sectionLabel("Vary timing")
                        if !purchaseManager.isPremium {
                            Text("Add randomness so you don't anticipate the buzz")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        } else if viewModel.randomizeEnabled {
                            Text("\u{00B1} \(viewModel.varianceSeconds)s around interval")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        } else {
                            Text("Buzz at exact interval")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                    Spacer()
                    if !purchaseManager.isPremium {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    } else {
                        Toggle("", isOn: $viewModel.randomizeEnabled)
                            .labelsHidden()
                            .tint(theme.accent)
                            .accessibilityLabel("Vary timing")
                    }
                }

                if viewModel.randomizeEnabled && purchaseManager.isPremium {
                    HStack {
                        Text("\u{00B1} 5s")
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryText)
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.varianceSeconds) },
                                set: { viewModel.varianceSeconds = Int($0) }
                            ),
                            in: 5...60,
                            step: 5
                        )
                        .tint(theme.accent)
                        Text("\u{00B1} 60s")
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }

            // End condition section
            sectionCard {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("End after")
                    LazyVGrid(columns: pillColumns, spacing: 6) {
                        ForEach(TimerViewModel.endOptions, id: \.label) { option in
                            pillButton(
                                option.label,
                                isActive: viewModel.endMode == option.mode
                            ) {
                                viewModel.endMode = option.mode
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
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
                .background(
                    isActive
                        ? (accentStyle ? AnyShapeStyle(theme.accent) : AnyShapeStyle(theme.primary))
                        : AnyShapeStyle(theme.pillBackground)
                )
                .foregroundStyle(
                    isActive ? theme.onAccent : theme.primary
                )
                .clipShape(Capsule())
        }
        .accessibilityLabel("\(label)\(isActive ? ", selected" : "")")
    }

    private func customField(value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        VStack(spacing: 2) {
            Picker(unit, selection: value) {
                ForEach(Array(range), id: \.self) { n in
                    Text("\(n)").tag(n)
                }
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
}
