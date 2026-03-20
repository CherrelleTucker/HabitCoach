import SwiftUI

struct WatchTimerView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var viewModel: WatchTimerViewModel

    private var theme: AppTheme { themeManager.current }

    @State private var completedSession: Session?

    var body: some View {
        VStack(spacing: 6) {
            if let session = completedSession {
                watchCompletionView(session)
            } else if viewModel.timerService.isRunning {
                activeView
            } else {
                idleView
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && viewModel.timerService.isRunning {
                viewModel.resumeFromBackground()
            }
        }
        .onChange(of: viewModel.timerService.isRunning) { wasRunning, running in
            if wasRunning && !running {
                if viewModel.timerService.isComplete {
                    // Auto-completed — end workout, save session, sync
                    Task {
                        let session = await viewModel.finishCompletedSession()
                        completedSession = session
                    }
                }
                // Manual stop is handled by stopSession() directly
            }
        }
    }

    // MARK: - Watch Completion

    private func watchCompletionView(_ session: Session) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(theme.accent)

            Text("Complete")
                .font(.headline)
                .foregroundStyle(theme.accent)

            VStack(spacing: 4) {
                Text(session.formattedDuration)
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(theme.accent)
                Text("\(session.reminderCount) reminders")
                    .font(.caption2)
                    .foregroundStyle(theme.watchSecondaryText)
            }

            Button {
                completedSession = nil
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 8) {
            if let profile = viewModel.activeProfile {
                Text(profile.name)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(theme.accent)
            }

            Text(viewModel.intervalSummary)
                .font(.system(.title, design: .monospaced))
                .foregroundStyle(theme.accent)

            HStack(spacing: 4) {
                if !viewModel.varianceSummary.isEmpty {
                    Text(viewModel.varianceSummary)
                }
                Text("\u{00B7}")
                Text(viewModel.cycleSummary)
            }
            .font(.caption2)
            .foregroundStyle(theme.watchSecondaryText)

            if let error = viewModel.healthKitError {
                Text(error)
                    .font(.system(size: 9))
                    .foregroundStyle(theme.destructive)
            }

            Button {
                Task { await viewModel.startSession() }
            } label: {
                Text("Start")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
            .accessibilityLabel("Start session")
            .accessibilityHint("Begins a coaching session with haptic reminders")
        }
    }

    // MARK: - Active

    private var activeView: some View {
        VStack(spacing: 4) {
            if let profile = viewModel.activeProfile {
                Text(profile.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.accent)
            }

            Text(viewModel.formattedElapsed)
                .font(.system(.title, design: .monospaced))
                .foregroundStyle(theme.accent)
                .accessibilityLabel("Elapsed time: \(viewModel.formattedElapsed)")

            Text("Next in \(viewModel.formattedNextBuzz)")
                .font(.caption2)
                .foregroundStyle(theme.watchSecondaryText)

            // Progress dots (if finite cycles)
            if let total = viewModel.timerService.totalCycles, total > 0 {
                HStack(spacing: 3) {
                    ForEach(0..<min(total, 12), id: \.self) { i in
                        Circle()
                            .fill(i < viewModel.timerService.reminderCount ? theme.accent : theme.watchSecondaryText.opacity(0.3))
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.vertical, 2)

                Text("\(viewModel.timerService.reminderCount) of \(total)")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.watchSecondaryText)
            } else {
                Text("\(viewModel.timerService.reminderCount) reminders")
                    .font(.caption2)
                    .foregroundStyle(theme.watchSecondaryText)
                    .padding(.vertical, 2)
            }

            Button(role: .destructive) {
                Task { await viewModel.stopSession() }
            } label: {
                Text("Stop")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.destructive)
            .accessibilityLabel("Stop session")
            .accessibilityHint("Ends the current coaching session")
        }
    }
}
