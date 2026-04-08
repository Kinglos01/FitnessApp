import SwiftUI

struct RootView: View {

    @Environment(AppState.self) var appState

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
