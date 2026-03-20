import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.themeManager) private var themeManager

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.primary)

                Text("Last updated: March 2026")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)

                section("What Data We Collect") {
                    Text("HabitCoach stores all data locally on your device. We do not collect, transmit, or share any personal information with third parties.")
                }

                section("HealthKit") {
                    Text("HabitCoach uses Apple HealthKit to run workout sessions on your Apple Watch. This allows haptic reminders to continue when the screen is off. Workout data is stored in HealthKit on your device and is never sent to our servers.")
                }

                section("Local Storage") {
                    Text("Your presets, session history, and settings are stored on-device using local storage. Watch data syncs to your paired iPhone via Apple's WatchConnectivity framework and never leaves your devices.")
                }

                section("In-App Purchases") {
                    Text("Premium purchases are processed entirely by Apple through the App Store. We do not have access to your payment information.")
                }

                section("Analytics & Tracking") {
                    Text("HabitCoach does not include any analytics SDKs, tracking pixels, or advertising frameworks. We do not track your usage or behavior.")
                }

                section("Children's Privacy") {
                    Text("HabitCoach does not knowingly collect any data from children under 13.")
                }

                section("Contact") {
                    Text("If you have questions about this privacy policy, contact us at privacy@ctuckersolutions.com.")
                }
            }
            .padding(16)
        }
        .background(theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.primary)
            content()
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
        }
    }
}
