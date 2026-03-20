import SwiftUI

struct TimerPresetPickerView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.profileStore) private var profileStore
    @Environment(\.purchaseManager) private var purchaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var showUpgrade = false

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        NavigationStack {
            List {
                ForEach(profileStore.profiles) { profile in
                    HStack(spacing: 12) {
                        Image(systemName: profile.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(theme.accent)
                            .frame(width: 36, height: 36)
                            .background(theme.pillBackground)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(theme.primary)
                            Text(profile.formattedInterval)
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        }

                        Spacer()

                        Toggle("", isOn: binding(for: profile))
                            .labelsHidden()
                            .tint(theme.accent)
                    }
                    .listRowBackground(theme.cardBackground)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .safeAreaInset(edge: .bottom) {
                if !purchaseManager.isPremium {
                    Button {
                        showUpgrade = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                            Text("Free: \(maxShortcuts) preset shortcuts on timer — get up to 7 with Premium")
                                .font(.caption)
                        }
                        .foregroundStyle(theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(theme.cardBackground)
                    }
                }
            }
            .navigationTitle("Timer Shortcuts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showUpgrade) {
                UpgradeView(highlight: .unlimitedPresets)
            }
        }
    }

    private var enabledCount: Int {
        profileStore.profiles.filter(\.showOnTimer).count
    }

    private var maxShortcuts: Int {
        purchaseManager.isPremium ? 7 : 3
    }

    private func binding(for profile: SessionProfile) -> Binding<Bool> {
        Binding(
            get: { profile.showOnTimer },
            set: { newValue in
                if newValue && !purchaseManager.isPremium && enabledCount >= maxShortcuts {
                    showUpgrade = true
                    return
                }
                var updated = profile
                updated.showOnTimer = newValue
                profileStore.save(updated)
            }
        )
    }
}
