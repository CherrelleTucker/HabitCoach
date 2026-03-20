import SwiftUI

struct WatchSequenceTimerView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.dismiss) private var dismiss

    @State var viewModel: WatchTimerViewModel
    let sequence: SessionSequence

    @State private var showCancelConfirm = false
    @State private var completedSequence = false

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        Group {
            if completedSequence {
                completionView
            } else if viewModel.isSequenceRunning {
                if viewModel.isSequenceTransitioning {
                    transitionView
                } else {
                    activeView
                }
            } else {
                readyView
            }
        }
        .onChange(of: viewModel.isSequenceComplete) { _, complete in
            if complete {
                completedSequence = true
            }
        }
    }

    // MARK: - Ready

    private var readyView: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: sequence.icon)
                    .font(.title3)
                    .foregroundStyle(theme.accent)

                Text(sequence.name)
                    .font(.headline)
                    .foregroundStyle(theme.primary)

                Text("\(sequence.steps.count) steps")
                    .font(.caption2)
                    .foregroundStyle(theme.watchSecondaryText)

                ForEach(Array(sequence.steps.enumerated()), id: \.element.id) { i, step in
                    HStack(spacing: 6) {
                        Text("\(i + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(theme.accent)
                        Text(step.profile.name)
                            .font(.caption2)
                            .foregroundStyle(theme.primary)
                        Spacer()
                    }
                }

                Button {
                    Task { await viewModel.startSequenceSession(sequence) }
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.caption.weight(.semibold))
                }
                .tint(theme.accent)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Active

    private var activeView: some View {
        VStack(spacing: 4) {
            if let step = viewModel.currentSequenceStep {
                Text("\(viewModel.sequenceProgress) \(step.profile.name)")
                    .font(.caption2)
                    .foregroundStyle(theme.accent)
            }

            Text(viewModel.formattedElapsed)
                .font(.system(size: 40, weight: .thin, design: .rounded))
                .foregroundStyle(theme.primary)
                .monospacedDigit()

            Text("Next \(viewModel.formattedNextBuzz)")
                .font(.caption2)
                .foregroundStyle(theme.watchSecondaryText)

            // Progress dots
            HStack(spacing: 3) {
                ForEach(0..<(viewModel.activeSequence?.steps.count ?? 0), id: \.self) { i in
                    Circle()
                        .fill(i <= viewModel.currentStepIndex ? theme.accent : theme.watchSecondaryText.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 2)

            Button {
                showCancelConfirm = true
            } label: {
                Text("End")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .confirmationDialog("End sequence?", isPresented: $showCancelConfirm) {
            Button("End Sequence", role: .destructive) {
                Task { await viewModel.cancelSequence() }
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - Transition

    private var transitionView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(theme.accent)

            if !viewModel.isLastSequenceStep,
               let nextStep = viewModel.activeSequence?.steps[viewModel.currentStepIndex + 1] {
                Text("Next: \(nextStep.profile.name)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.primary)

                if viewModel.activeSequence?.transition == .autoAdvance {
                    Text("\(viewModel.sequenceTransitionCountdown)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.accent)
                        .monospacedDigit()
                } else {
                    Button {
                        viewModel.advanceSequenceStep()
                    } label: {
                        Text("Start")
                            .font(.caption.weight(.semibold))
                    }
                    .tint(theme.accent)
                }
            }
        }
    }

    // MARK: - Completion

    private var completionView: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(theme.accent)

                Text("Done!")
                    .font(.headline)
                    .foregroundStyle(theme.primary)

                let totalBuzzes = viewModel.completedSequenceSessions.reduce(0) { $0 + $1.reminderCount }
                Text("\(viewModel.completedSequenceSessions.count) steps, \(totalBuzzes) buzzes")
                    .font(.caption2)
                    .foregroundStyle(theme.watchSecondaryText)

                Button {
                    viewModel.clearSequence()
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.caption.weight(.semibold))
                }
                .tint(theme.accent)
            }
        }
    }
}
