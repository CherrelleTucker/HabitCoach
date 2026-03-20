import SwiftUI

struct SequenceListView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.sequenceStore) private var sequenceStore
    @Environment(\.purchaseManager) private var purchaseManager
    @State private var editingSequence: SessionSequence?
    @State private var showCreate = false
    @State private var activeSequence: SessionSequence?
    @State private var showUpgrade = false

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sequences")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.primary)
                Spacer()
                if purchaseManager.isPremium {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.onAccent)
                            .frame(width: 44, height: 44)
                            .background(theme.accent)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Create new sequence")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            if !purchaseManager.isPremium {
                Spacer()
                premiumPrompt
                Spacer()
            } else if sequenceStore.sequences.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(sequenceStore.sequences) { sequence in
                            sequenceCard(sequence)
                                .onTapGesture {
                                    activeSequence = sequence
                                }
                                .contextMenu {
                                    Button {
                                        editingSequence = sequence
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        sequenceStore.delete(id: sequence.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            SequenceEditView()
        }
        .sheet(item: $editingSequence) { sequence in
            SequenceEditView(existing: sequence)
        }
        .fullScreenCover(item: $activeSequence) { sequence in
            SequenceTimerView(sequence: sequence)
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeView(highlight: .sessionBuilder)
        }
    }

    private var premiumPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 36))
                .foregroundStyle(theme.secondaryText)
            Text("Session Builder")
                .font(.headline)
                .foregroundStyle(theme.primary)
            Text("Chain presets into a sequence.\nOne tap starts the whole flow.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
            Button {
                showUpgrade = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                    Text("Unlock with Premium")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(theme.accent)
                .foregroundStyle(theme.onAccent)
                .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 36))
                .foregroundStyle(theme.secondaryText)
            Text("No Sequences Yet")
                .font(.headline)
                .foregroundStyle(theme.primary)
            Text("Chain presets into a full workout.\nWarm up, train, cool down — one tap.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
            Button {
                showCreate = true
            } label: {
                Text("Create Sequence")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(theme.accent)
                    .foregroundStyle(theme.onAccent)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
    }

    private func sequenceCard(_ sequence: SessionSequence) -> some View {
        HStack(spacing: 12) {
            Image(systemName: sequence.icon)
                .font(.system(size: 24))
                .foregroundStyle(theme.accent)
                .frame(width: 40, height: 40)
                .background(theme.pillBackground)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(sequence.name)
                    .font(.headline)
                    .foregroundStyle(theme.primary)

                HStack(spacing: 16) {
                    Label("\(sequence.steps.count) steps", systemImage: "list.number")
                    if sequence.totalEstimatedDuration != nil {
                        Label(sequence.formattedTotalDuration, systemImage: "timer")
                    }
                    Label(sequence.transition == .autoAdvance ? "Auto" : "Manual", systemImage: "arrow.right")
                }
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
            }

            Spacer()
            Image(systemName: "play.fill")
                .font(.caption)
                .foregroundStyle(theme.accent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
