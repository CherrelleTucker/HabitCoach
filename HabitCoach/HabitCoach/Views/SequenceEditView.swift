import SwiftUI

struct SequenceEditView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.sequenceStore) private var sequenceStore
    @Environment(\.profileStore) private var profileStore
    @Environment(\.dismiss) private var dismiss

    let existing: SessionSequence?

    @State private var name: String = ""
    @State private var icon: String = "arrow.triangle.2.circlepath"
    @State private var transition: SequenceTransition = .autoAdvance
    @State private var countdownSeconds: Int = 5
    @State private var steps: [SequenceStep] = []
    @State private var showPresetPicker = false
    @State private var showDeleteConfirm = false

    private var theme: AppTheme { themeManager.current }
    private var isEditing: Bool { existing != nil }

    private static let availableIcons = [
        "arrow.triangle.2.circlepath",
        "figure.mixed.cardio",
        "dumbbell.fill",
        "figure.yoga",
        "flame.fill",
        "bolt.fill",
        "heart.fill",
        "star.fill",
    ]

    private let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    init(existing: SessionSequence? = nil) {
        self.existing = existing
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !steps.isEmpty &&
        steps.allSatisfy { step in
            switch step.endCondition {
            case .unlimited: return false
            case .afterCount, .afterDuration: return true
            }
        }
    }

    private var hasUnlimitedSteps: Bool {
        steps.contains { step in
            if case .unlimited = step.endCondition { return true }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Name
                    sectionCard {
                        VStack(alignment: .leading, spacing: 6) {
                            sectionLabel("Name")
                            TextField("e.g. Morning Workout, Full Circuit", text: $name)
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
                                }
                            }
                        }
                    }

                    // Transition
                    sectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("Transition Between Steps")

                            Picker("Transition", selection: $transition) {
                                Text("Auto-Advance").tag(SequenceTransition.autoAdvance)
                                Text("Manual").tag(SequenceTransition.manual)
                            }
                            .pickerStyle(.segmented)

                            if transition == .autoAdvance {
                                HStack {
                                    Text("Countdown")
                                        .font(.subheadline)
                                        .foregroundStyle(theme.primary)
                                    Spacer()
                                    Stepper("\(countdownSeconds)s", value: $countdownSeconds, in: 3...15)
                                        .font(.subheadline)
                                        .foregroundStyle(theme.primary)
                                }
                            }

                            Text(transition == .autoAdvance
                                ? "Next step starts automatically after a countdown."
                                : "Tap to start each step manually.")
                                .font(.caption2)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }

                    // Steps
                    sectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("Steps")

                            if steps.isEmpty {
                                Text("Add presets to build your sequence.")
                                    .font(.caption)
                                    .foregroundStyle(theme.secondaryText)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                                    stepRow(step, index: index)
                                    if index < steps.count - 1 {
                                        HStack {
                                            Spacer()
                                            Image(systemName: "arrow.down")
                                                .font(.caption2)
                                                .foregroundStyle(theme.secondaryText)
                                            Spacer()
                                        }
                                    }
                                }
                            }

                            Button {
                                showPresetPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Preset")
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(theme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(theme.pillBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            if hasUnlimitedSteps {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                    Text("Every step must have a defined end condition.")
                                        .font(.caption)
                                }
                                .foregroundStyle(theme.destructive)
                            }
                        }
                    }

                    // Delete (edit mode)
                    if isEditing {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Text("Delete Sequence")
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
            .navigationTitle(isEditing ? "Edit Sequence" : "New Sequence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
            .alert("Delete Sequence?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let id = existing?.id {
                        sequenceStore.delete(id: id)
                    }
                    dismiss()
                }
            }
            .onAppear { loadExisting() }
            .sheet(isPresented: $showPresetPicker) {
                presetPickerSheet
            }
        }
    }

    // MARK: - Step Row

    private func stepRow(_ step: SequenceStep, index: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.onAccent)
                .frame(width: 24, height: 24)
                .background(theme.accent)
                .clipShape(Circle())

            Image(systemName: step.profile.icon)
                .font(.system(size: 16))
                .foregroundStyle(theme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.profile.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.primary)

                HStack(spacing: 8) {
                    Text(step.profile.formattedInterval + " intervals")
                    Text(step.formattedEndCondition)
                }
                .font(.caption2)
                .foregroundStyle(theme.secondaryText)
            }

            Spacer()

            // End condition picker
            Menu {
                ForEach(TimerViewModel.endOptions.filter { if case .unlimited = $0.mode { return false }; return true }, id: \.label) { option in
                    Button(option.label) {
                        steps[index].endCondition = endConditionFromMode(option.mode)
                    }
                }
            } label: {
                Text(step.formattedEndCondition)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.pillBackground)
                    .clipShape(Capsule())
                    .foregroundStyle(theme.primary)
            }

            Button {
                steps.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(8)
        .background(theme.pillBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Preset Picker

    private var presetPickerSheet: some View {
        NavigationStack {
            List(profileStore.profiles) { profile in
                Button {
                    let step = SequenceStep(
                        profile: profile,
                        endCondition: profile.endCondition == .unlimited
                            ? .afterDuration(300)
                            : profile.endCondition
                    )
                    steps.append(step)
                    showPresetPicker = false
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: profile.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(theme.accent)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(theme.primary)
                            Text(profile.formattedInterval + " intervals")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Add Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showPresetPicker = false }
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadExisting() {
        guard let seq = existing else { return }
        name = seq.name
        icon = seq.icon
        transition = seq.transition
        countdownSeconds = seq.countdownSeconds
        steps = seq.steps
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !steps.isEmpty else { return }

        var sequence = existing ?? SessionSequence(name: "", steps: [])
        sequence.name = trimmedName
        sequence.icon = icon
        sequence.transition = transition
        sequence.countdownSeconds = countdownSeconds
        sequence.steps = steps

        sequenceStore.save(sequence)
        dismiss()
    }

    private func endConditionFromMode(_ mode: TimerViewModel.EndMode) -> SessionEndCondition {
        switch mode {
        case .unlimited: return .unlimited
        case .count(let n): return .afterCount(n)
        case .duration(let s): return .afterDuration(s)
        }
    }

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
}
