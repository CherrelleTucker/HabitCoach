import SwiftUI

struct SequenceTimerView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.sessionStore) private var sessionStore
    @Environment(\.settingsStore) private var settingsStore
    @Environment(\.dismiss) private var dismiss

    let sequence: SessionSequence

    @State private var viewModel = SequenceTimerViewModel()
    @State private var showCancelConfirm = false

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            if viewModel.isSequenceComplete {
                completionView
            } else if viewModel.isSequenceActive {
                if viewModel.isTransitioning {
                    transitionView
                } else {
                    activeView
                }
            } else {
                readyView
            }
        }
        .onAppear {
            viewModel.sessionStore = sessionStore
            viewModel.settingsStore = settingsStore
        }
        .alert("End Sequence?", isPresented: $showCancelConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) {
                viewModel.cancelSequence()
                dismiss()
            }
        } message: {
            Text("This will end the current sequence. Completed steps are saved.")
        }
    }

    // MARK: - Ready State

    private var readyView: some View {
        VStack(spacing: 16) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.primary)
                        .frame(width: 44, height: 44)
                        .background(theme.pillBackground)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Close")
                Spacer()
            }
            .padding(.horizontal, 16)

            Spacer()

            Image(systemName: sequence.icon)
                .font(.system(size: 40))
                .foregroundStyle(theme.accent)

            Text(sequence.name)
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.primary)

            Text("\(sequence.steps.count) steps \u{2022} \(sequence.formattedTotalDuration)")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)

            // Step list
            VStack(spacing: 4) {
                ForEach(Array(sequence.steps.enumerated()), id: \.element.id) { index, step in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(theme.onAccent)
                            .frame(width: 20, height: 20)
                            .background(theme.accent.opacity(0.7))
                            .clipShape(Circle())

                        Image(systemName: step.profile.icon)
                            .font(.caption)
                            .foregroundStyle(theme.accent)
                            .frame(width: 16)

                        Text(step.profile.name)
                            .font(.subheadline)
                            .foregroundStyle(theme.primary)

                        Spacer()

                        Text(step.formattedEndCondition)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)

            Spacer()

            Button {
                viewModel.startSequence(sequence)
            } label: {
                Text("Start Sequence")
                    .font(.headline)
                    .foregroundStyle(theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .accessibilityLabel("Start Sequence")
            .accessibilityHint("Begins running all steps in this sequence")
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Active State

    private var activeView: some View {
        VStack(spacing: 0) {
            // Progress header
            if let step = viewModel.currentStep {
                VStack(spacing: 4) {
                    Text("Step \(viewModel.sequenceProgress)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.secondaryText)

                    HStack(spacing: 6) {
                        Image(systemName: step.profile.icon)
                            .font(.caption)
                        Text(step.profile.name)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(theme.accent)

                    // Step progress dots
                    HStack(spacing: 4) {
                        ForEach(0..<(viewModel.sequence?.steps.count ?? 0), id: \.self) { i in
                            Circle()
                                .fill(i < viewModel.currentStepIndex ? theme.accent : (i == viewModel.currentStepIndex ? theme.accent : theme.pillBackground))
                                .frame(width: 8, height: 8)
                                .opacity(i <= viewModel.currentStepIndex ? 1.0 : 0.5)
                        }
                    }
                }
                .padding(.top, 16)
            }

            Spacer()

            // Timer display
            Text(viewModel.formattedElapsed)
                .font(.system(size: 72, weight: .thin, design: .rounded))
                .foregroundStyle(theme.primary)
                .monospacedDigit()

            Text("Next buzz \(viewModel.formattedNextBuzz)")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .padding(.top, 4)

            // Progress bar
            if viewModel.currentStep != nil {
                let total = viewModel.timerService.totalCycles
                if let total, total > 0 {
                    ProgressView(value: Double(viewModel.timerService.reminderCount), total: Double(total))
                        .tint(theme.accent)
                        .padding(.horizontal, 40)
                        .padding(.top, 16)
                }
            }

            Text("\(viewModel.timerService.reminderCount) buzzes")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .padding(.top, 8)

            Spacer()

            // Cancel button
            Button {
                showCancelConfirm = true
            } label: {
                Text("End Sequence")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.destructive)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
            }
            .accessibilityLabel("End Sequence")
            .accessibilityHint("Stops the current sequence. Completed steps are saved.")
            .padding(.bottom, 24)
        }
    }

    // MARK: - Transition State

    private var transitionView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.accent)

            if let step = viewModel.currentStep {
                Text("\(step.profile.name) Complete")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.primary)
            }

            // Next up
            if !viewModel.isLastStep, let nextStep = viewModel.sequence?.steps[viewModel.currentStepIndex + 1] {
                VStack(spacing: 8) {
                    Text("Next Up")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.secondaryText)

                    HStack(spacing: 8) {
                        Image(systemName: nextStep.profile.icon)
                            .font(.title3)
                            .foregroundStyle(theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(nextStep.profile.name)
                                .font(.headline)
                                .foregroundStyle(theme.primary)
                            Text(nextStep.formattedEndCondition)
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
                }

                if viewModel.sequence?.transition == .autoAdvance {
                    Text("Starting in \(viewModel.transitionCountdown)...")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.primary)
                        .monospacedDigit()
                } else {
                    Button {
                        viewModel.advanceToNextStep()
                    } label: {
                        Text("Start Next Step")
                            .font(.headline)
                            .foregroundStyle(theme.onAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .accessibilityLabel("Start Next Step")
                    .accessibilityHint("Advances to the next step in the sequence")
                    .padding(.horizontal, 24)
                }
            }

            Spacer()

            Button {
                showCancelConfirm = true
            } label: {
                Text("End Sequence")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.destructive)
                    .padding(.vertical, 12)
            }
            .accessibilityLabel("End Sequence")
            .accessibilityHint("Stops the current sequence. Completed steps are saved.")
            .padding(.bottom, 24)
        }
    }

    // MARK: - Completion State

    private var completionView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(theme.accent)

            Text("Sequence Complete!")
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.primary)

            Text(sequence.name)
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)

            // Aggregate stats
            VStack(spacing: 12) {
                HStack(spacing: 24) {
                    statItem(value: viewModel.formattedAggregateDuration, label: "Total Time")
                    statItem(value: "\(viewModel.aggregateReminders)", label: "Total Buzzes")
                    statItem(value: "\(viewModel.completedStepSessions.count)", label: "Steps")
                }

                Divider()

                // Per-step breakdown
                ForEach(viewModel.completedStepSessions) { session in
                    HStack {
                        if let index = session.sequenceIndex {
                            Text("\(index + 1).")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.accent)
                        }
                        Text(session.profileName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(theme.primary)
                        Spacer()
                        Text(session.formattedDuration)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                        Text("\(session.reminderCount) buzzes")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }
            .padding(16)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .accessibilityLabel("Done")
            .accessibilityHint("Closes the sequence completion screen")
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(theme.secondaryText)
        }
    }
}
