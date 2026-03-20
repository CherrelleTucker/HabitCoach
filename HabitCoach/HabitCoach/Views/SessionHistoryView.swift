import SwiftUI

struct SessionHistoryView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.sessionStore) private var sessionStore
    @Environment(\.purchaseManager) private var purchaseManager
    @State private var showClearConfirm = false
    @State private var showUpgrade = false

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if sessionStore.sessions.isEmpty {
                    Text("History")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.primary)
                } else {
                    Text("History (\(sessionStore.sessions.count))")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.primary)
                }
                Spacer()
                if !sessionStore.sessions.isEmpty {
                    Button {
                        showClearConfirm = true
                    } label: {
                        Text("Clear All")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(theme.destructive)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            if sessionStore.sessions.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                List {
                    let visibleSessions = purchaseManager.isPremium
                        ? sessionStore.sessions
                        : Array(sessionStore.sessions.prefix(10))
                    let grouped = groupSessions(visibleSessions)
                    ForEach(grouped, id: \.id) { group in
                        if let seqName = group.sequenceName, group.sessions.count > 1 {
                            DisclosureGroup {
                                ForEach(group.sessions) { session in
                                    sessionRow(session)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                if let idx = sessionStore.sessions.firstIndex(where: { $0.id == session.id }) {
                                                    sessionStore.delete(at: IndexSet(integer: idx))
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            } label: {
                                sequenceGroupHeader(name: seqName, sessions: group.sessions)
                            }
                            .tint(theme.accent)
                            .listRowBackground(theme.cardBackground)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        } else {
                            ForEach(group.sessions) { session in
                                sessionRow(session)
                                    .listRowBackground(theme.cardBackground)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            if let idx = sessionStore.sessions.firstIndex(where: { $0.id == session.id }) {
                                                sessionStore.delete(at: IndexSet(integer: idx))
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    if !purchaseManager.isPremium && sessionStore.sessions.count > 10 {
                        Button {
                            showUpgrade = true
                        } label: {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                Text("See all \(sessionStore.sessions.count) sessions with Premium")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .listRowBackground(theme.cardBackground)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .alert("Clear All History?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                sessionStore.clearAll()
            }
        } message: {
            Text("This will permanently delete all \(sessionStore.sessions.count) sessions.")
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeView(highlight: .fullHistory)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundStyle(theme.secondaryText)
            Text("No Sessions Yet")
                .font(.headline)
                .foregroundStyle(theme.primary)
            Text("Your completed sessions will appear here.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.startedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.primary)
                Spacer()
                if session.wasCancelled {
                    Text("Cancelled")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.destructive)
                }
            }

            Text(session.profileName)
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.accent)

            HStack(spacing: 16) {
                Label(session.formattedDuration, systemImage: "timer")
                Label("\(session.reminderCount) buzzes", systemImage: "bell.fill")
                Label(formatInterval(session.intervalSeconds), systemImage: "repeat")
            }
            .font(.caption)
            .foregroundStyle(theme.secondaryText)
        }
        .padding(12)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.profileName), \(session.formattedDuration), \(session.reminderCount) reminders\(session.wasCancelled ? ", cancelled" : "")")
    }

    // MARK: - Sequence Grouping

    private struct SessionGroup: Identifiable {
        let id: String
        let sequenceName: String?
        let sessions: [Session]
    }

    private func groupSessions(_ sessions: [Session]) -> [SessionGroup] {
        var groups: [SessionGroup] = []
        var i = 0
        while i < sessions.count {
            let session = sessions[i]
            if let seqId = session.sequenceId {
                // Collect all sessions with this sequenceId
                var seqSessions = [session]
                var j = i + 1
                while j < sessions.count, sessions[j].sequenceId == seqId {
                    seqSessions.append(sessions[j])
                    j += 1
                }
                seqSessions.sort { ($0.sequenceIndex ?? 0) < ($1.sequenceIndex ?? 0) }
                groups.append(SessionGroup(
                    id: seqId.uuidString,
                    sequenceName: session.sequenceName,
                    sessions: seqSessions
                ))
                i = j
            } else {
                groups.append(SessionGroup(
                    id: session.id.uuidString,
                    sequenceName: nil,
                    sessions: [session]
                ))
                i += 1
            }
        }
        return groups
    }

    private func sequenceGroupHeader(name: String, sessions: [Session]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(theme.accent)
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primary)
                Spacer()
                if sessions.first?.wasCancelled == true || sessions.last?.wasCancelled == true {
                    Text("Partial")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.destructive)
                }
            }
            HStack(spacing: 16) {
                let totalDuration = sessions.compactMap { $0.duration }.reduce(0, +)
                let totalBuzzes = sessions.reduce(0) { $0 + $1.reminderCount }
                Label(formatDuration(totalDuration), systemImage: "timer")
                Label("\(totalBuzzes) buzzes", systemImage: "bell.fill")
                Label("\(sessions.count) steps", systemImage: "list.number")
            }
            .font(.caption)
            .foregroundStyle(theme.secondaryText)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = Int(duration)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatInterval(_ seconds: Int) -> String {
        if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return s > 0 ? "\(m)m \(s)s" : "\(m)m"
        }
        return "\(seconds)s"
    }
}
