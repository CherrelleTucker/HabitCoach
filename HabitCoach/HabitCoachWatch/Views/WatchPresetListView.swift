import SwiftUI

struct WatchPresetListView: View {
    @Environment(\.themeManager) private var themeManager
    @State var viewModel = WatchTimerViewModel()

    private let connectivity = ConnectivityService.shared
    private var theme: AppTheme { themeManager.current }

    private var visiblePresets: [SessionProfile] {
        viewModel.profileStore.profiles.filter(\.showOnTimer)
    }

    var body: some View {
        List {
            NavigationLink {
                WatchTimerView(viewModel: viewModel)
                    .onAppear { viewModel.clearProfile() }
            } label: {
                Label("Quick Start", systemImage: "bolt.fill")
                    .foregroundStyle(theme.accent)
            }

            if visiblePresets.isEmpty {
                Text("Sync presets from iPhone")
                    .font(.caption2)
                    .foregroundStyle(theme.watchSecondaryText)
            } else {
                ForEach(visiblePresets) { profile in
                    NavigationLink {
                        WatchTimerView(viewModel: viewModel)
                            .onAppear { viewModel.loadProfile(profile) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: profile.icon)
                                .frame(width: 20)
                                .foregroundStyle(theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                    .font(.caption)
                                Text(profile.formattedInterval)
                                    .font(.caption2)
                                    .foregroundStyle(theme.watchSecondaryText)
                            }
                        }
                    }
                }
            }

            // Sequences section
            let sequences = loadSequences()
            if !sequences.isEmpty {
                Section("Sequences") {
                    ForEach(sequences) { sequence in
                        NavigationLink {
                            WatchSequenceTimerView(viewModel: viewModel, sequence: sequence)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: sequence.icon)
                                    .frame(width: 20)
                                    .foregroundStyle(theme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sequence.name)
                                        .font(.caption)
                                    Text("\(sequence.steps.count) steps")
                                        .font(.caption2)
                                        .foregroundStyle(theme.watchSecondaryText)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("HabitCoach")
        .onAppear {
            viewModel.checkForIncomingData()
            Task { await viewModel.workoutManager.requestAuthorization() }
        }
    }

    private func loadSequences() -> [SessionSequence] {
        guard let data = UserDefaults.standard.data(forKey: "saved_sequences"),
              let sequences = try? JSONDecoder().decode([SessionSequence].self, from: data) else {
            return []
        }
        return sequences
    }
}
