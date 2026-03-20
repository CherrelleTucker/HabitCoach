import SwiftUI

enum AppTab: String, CaseIterable {
    case timer, profiles, sequences, history, settings

    var label: String {
        switch self {
        case .timer: "Timer"
        case .profiles: "Presets"
        case .sequences: "Sequences"
        case .history: "History"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .timer: "timer"
        case .profiles: "list.bullet"
        case .sequences: "arrow.triangle.2.circlepath"
        case .history: "clock.arrow.circlepath"
        case .settings: "gear"
        }
    }
}

struct ContentView: View {
    @Environment(\.themeManager) private var themeManager
    @State private var selectedTab: AppTab = .timer
    @State private var showMenu = false
    @State private var sessionActive = false

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        ZStack {
            // Background fills entire screen including behind status bar
            theme.background
                .ignoresSafeArea()

            // Main content stays within safe area
            VStack(spacing: 0) {
                // Menu bar row — hidden during active session
                if !sessionActive {
                    HStack {
                        Button {
                            withAnimation(.spring(duration: 0.25)) {
                                showMenu.toggle()
                            }
                        } label: {
                            Image(systemName: showMenu ? "xmark" : "line.3.horizontal")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(theme.onAccent)
                                .frame(width: 40, height: 40)
                                .background(theme.primary)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                        }
                        .accessibilityLabel(showMenu ? "Close menu" : "Open menu")
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }

                // Page content — TimerView stays alive to preserve timer state
                ZStack {
                    TimerView(sessionActive: $sessionActive)
                        .opacity(selectedTab == .timer ? 1 : 0)
                        .allowsHitTesting(selectedTab == .timer)

                    if selectedTab == .profiles {
                        ProfileListView()
                    } else if selectedTab == .sequences {
                        SequenceListView()
                    } else if selectedTab == .history {
                        SessionHistoryView()
                    } else if selectedTab == .settings {
                        SettingsView()
                    }
                }
            }

            // Dropdown menu overlay — disabled during active session
            if showMenu && !sessionActive {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showMenu = false
                        }
                    }

                VStack {
                    HStack {
                        VStack(spacing: 0) {
                            ForEach(AppTab.allCases, id: \.self) { tab in
                                Button {
                                    guard !sessionActive else { return }
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        selectedTab = tab
                                        showMenu = false
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: tab.icon)
                                            .frame(width: 20)
                                        Text(tab.label)
                                        Spacer()
                                        if tab == selectedTab {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                        }
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(tab == selectedTab ? theme.accent : theme.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                if tab != AppTab.allCases.last {
                                    Divider().padding(.leading, 46)
                                }
                            }
                        }
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                        .frame(width: 180)
                        .transition(.scale(scale: 0.8, anchor: .topLeading).combined(with: .opacity))

                        Spacer()
                    }
                    .padding(.leading, 16)
                    .padding(.top, 48)

                    Spacer()
                }
            }
        }
        .preferredColorScheme(.light)
    }
}
