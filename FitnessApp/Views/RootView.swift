import SwiftUI

struct RootView: View {
    @Environment(AppState.self) var appState
    @State private var themeManager = ThemeManager.shared

    var body: some View {
        Group {
            if appState.isLoggedIn && appState.hasCompletedOnboarding {
                MainTabView()
            } else if appState.isLoggedIn && !appState.hasCompletedOnboarding {
                UserInfoView()
            } else {
                ContentView()
            }
        }
        .environment(themeManager)
        .preferredColorScheme(themeManager.current.colorScheme)
        .task {
            appState.restoreSessionIfNeeded()
            let granted = await NotificationManager.shared.requestPermission()
            if granted {
                NotificationManager.shared.syncNotifications(for: appState.currentUser)
            }
        }
        .onChange(of: appState.currentUser?.id) { _, _ in
            NotificationManager.shared.syncNotifications(for: appState.currentUser)
        }
    }
}
