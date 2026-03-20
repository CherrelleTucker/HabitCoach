import SwiftUI

@main
struct HabitCoachWatchApp: App {
    @State private var themeManager = ThemeManager()
    @State private var purchaseManager = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchPresetListView()
            }
            .environment(\.themeManager, themeManager)
            .environment(\.purchaseManager, purchaseManager)
        }
    }
}
