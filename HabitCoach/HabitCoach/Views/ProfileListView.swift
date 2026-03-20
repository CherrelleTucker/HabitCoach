import SwiftUI

struct ProfileListView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.profileStore) private var profileStore
    @Environment(\.purchaseManager) private var purchaseManager
    @State private var editingProfile: SessionProfile?
    @State private var showCreate = false
    @State private var showUpgrade = false
    @State private var upgradeFeature: PremiumFeature?

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Presets")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.primary)
                Spacer()
                Button {
                    if purchaseManager.isPremium || profileStore.profiles.count < 4 {
                        showCreate = true
                    } else {
                        upgradeFeature = .unlimitedPresets
                        showUpgrade = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.onAccent)
                        .frame(width: 44, height: 44)
                        .background(theme.accent)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Create new preset")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            if profileStore.profiles.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(profileStore.profiles) { profile in
                            let isLocked = profile.isTemplate && !profile.isFreeTemplate && !purchaseManager.isPremium
                            profileCard(profile, locked: isLocked)
                                .onTapGesture {
                                    if isLocked {
                                        upgradeFeature = .allTemplates
                                        showUpgrade = true
                                    } else {
                                        editingProfile = profile
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            ProfileEditView()
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditView(existing: profile)
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeView(highlight: upgradeFeature)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet")
                .font(.system(size: 36))
                .foregroundStyle(theme.secondaryText)
            Text("No Presets Yet")
                .font(.headline)
                .foregroundStyle(theme.primary)
            Text("Save configurations for workouts, habits,\nroutines, or anything on a schedule.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                if purchaseManager.isPremium || profileStore.profiles.count < 4 {
                    showCreate = true
                } else {
                    upgradeFeature = .unlimitedPresets
                    showUpgrade = true
                }
            } label: {
                Text("Create Preset")
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

    private func profileCard(_ profile: SessionProfile, locked: Bool = false) -> some View {
        HStack(spacing: 12) {

            Image(systemName: profile.icon)
                .font(.system(size: 24))
                .foregroundStyle(theme.accent)
                .frame(width: 40, height: 40)
                .background(theme.pillBackground)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(profile.name)
                    .font(.headline)
                    .foregroundStyle(theme.primary)

                HStack(spacing: 16) {
                    Label(profile.formattedInterval, systemImage: "timer")
                    if profile.varianceSeconds > 0 {
                        Label("± \(profile.varianceSeconds)s", systemImage: "arrow.left.arrow.right")
                    }
                    Label(profile.formattedEndCondition, systemImage: "flag")
                }
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
            }

            Spacer()
            if locked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(profile.name) preset, \(profile.formattedInterval) interval\(locked ? ", locked" : "")")
        .accessibilityHint(locked ? "Tap to unlock with Premium" : "Tap to edit")
    }
}
