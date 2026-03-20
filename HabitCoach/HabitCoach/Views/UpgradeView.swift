import SwiftUI

struct UpgradeView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.purchaseManager) private var purchaseManager
    @Environment(\.dismiss) private var dismiss

    let highlightedFeature: PremiumFeature?

    init(highlight: PremiumFeature? = nil) {
        self.highlightedFeature = highlight
    }

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(theme.accent)

                        Text("HabitCoach Premium")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(theme.primary)

                        Text("One-time purchase. Unlock everything.")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                    }
                    .padding(.top, 8)

                    // Feature list
                    VStack(spacing: 0) {
                        ForEach(PremiumFeature.allCases) { feature in
                            featureRow(feature)
                            if feature != PremiumFeature.allCases.last {
                                Divider().padding(.leading, 48)
                            }
                        }
                    }
                    .padding(12)
                    .background(theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Purchase button
                    #if os(iOS)
                    Button {
                        Task { await purchaseManager.purchase() }
                    } label: {
                        Group {
                            if purchaseManager.purchaseInProgress {
                                ProgressView()
                                    .tint(theme.onAccent)
                            } else if let product = purchaseManager.product {
                                Text("Unlock for \(product.displayPrice)")
                            } else {
                                // Product still loading from App Store
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .tint(theme.onAccent)
                                    Text("Loading…")
                                }
                            }
                        }
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(purchaseManager.product != nil ? theme.accent : theme.secondaryText)
                        .foregroundStyle(theme.onAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(purchaseManager.purchaseInProgress || purchaseManager.product == nil)
                    .accessibilityLabel(
                        purchaseManager.product != nil
                            ? "Unlock for \(purchaseManager.product!.displayPrice)"
                            : "Loading purchase option"
                    )
                    .accessibilityHint("Double-tap to purchase HabitCoach Premium")
                    .accessibilityValue(purchaseManager.purchaseInProgress ? "Loading" : "")

                    // Restore
                    Button {
                        Task { await purchaseManager.restore() }
                    } label: {
                        Text("Restore Purchase")
                            .font(.subheadline)
                            .foregroundStyle(theme.accent)
                    }
                    #endif

                    // Error
                    if let error = purchaseManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(theme.destructive)
                    }
                }
                .padding(16)
            }
            .background(theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(theme.primary)
                }
            }
        }
    }

    private func featureRow(_ feature: PremiumFeature) -> some View {
        HStack(spacing: 12) {
            Image(systemName: feature.icon)
                .font(.system(size: 18))
                .foregroundStyle(theme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.primary)
                Text(feature.subtitle)
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryText)
            }

            Spacer()

            if feature == highlightedFeature {
                Image(systemName: "arrow.left")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(.vertical, 8)
        .background(
            feature == highlightedFeature
                ? theme.pillBackground.opacity(0.5)
                : Color.clear
        )
    }
}
