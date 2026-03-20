import SwiftUI

struct OnboardingView: View {
    @Environment(\.themeManager) private var themeManager
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var page = 0

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        TabView(selection: $page) {
            // Page 1: Welcome
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(theme.accent)
                Text("HabitCoach")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(theme.primary)
                Text("Haptic reminders that keep you on track")
                    .font(.body)
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
                Spacer()
                pageIndicator(current: 0)
                nextButton("Next") { page = 1 }
            }
            .padding(32)
            .tag(0)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Welcome to HabitCoach. Haptic reminders that keep you on track.")

            // Page 2: How it works
            VStack(spacing: 20) {
                Spacer()
                VStack(spacing: 16) {
                    step(icon: "list.bullet.rectangle.fill", text: "Pick a preset or configure a quick session")
                    step(icon: "play.fill", text: "Start your session")
                    step(icon: "iphone.radiowaves.left.and.right", text: "Your device buzzes at each interval")
                    step(icon: "applewatch", text: "Pair an Apple Watch for wrist haptics on the go")
                }
                Spacer()
                pageIndicator(current: 1)
                nextButton("Next") { page = 2 }
            }
            .padding(32)
            .tag(1)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("How it works. Pick a preset, start your session, and your device buzzes at each interval.")

            // Page 3: Why randomized
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "shuffle")
                    .font(.system(size: 50))
                    .foregroundStyle(theme.accent)
                Text("Why randomized?")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.primary)
                Text("Your body naturally adapts to repeated stimuli and tunes them out. HabitCoach varies haptic patterns by default so each buzz stays noticeable.")
                    .font(.body)
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
                Spacer()
                pageIndicator(current: 2)
                nextButton("Next") { page = 3 }
            }
            .padding(32)
            .tag(2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Why randomized? HabitCoach varies haptic patterns so each buzz stays noticeable.")

            // Page 4: Get started
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(theme.accent)
                Text("You're all set")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.primary)
                Text("Set up your first preset or jump right into a quick session.")
                    .font(.body)
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
                Spacer()
                pageIndicator(current: 3)
                Button {
                    hasSeenOnboarding = true
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(theme.accent)
                        .clipShape(Capsule())
                }
                .accessibilityLabel("Get Started")
                .accessibilityHint("Dismisses onboarding and opens the app")
            }
            .padding(32)
            .tag(3)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("You're all set. Set up your first preset or jump right into a quick session.")
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(theme.background)
    }

    private func step(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(theme.accent)
                .frame(width: 36)
            Text(text)
                .font(.body)
                .foregroundStyle(theme.primary)
        }
    }

    private func pageIndicator(current: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(i == current ? theme.accent : theme.pillBackground)
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityLabel("Page \(current + 1) of 4")
    }

    private func nextButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .accessibilityLabel("Next page")
    }
}
