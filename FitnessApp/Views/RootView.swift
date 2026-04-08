import SwiftUI

struct RootView: View {

    @Environment(AppState.self) var appState

    var body: some View {
        ZStack {
            if appState.isLoggedIn && appState.hasCompletedOnboarding {
                MainTabView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else if appState.isLoggedIn && !appState.hasCompletedOnboarding {
                UserInfoView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                ContentView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appState.hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.35), value: appState.isLoggedIn)
        .preferredColorScheme(appState.colorScheme)
        .onAppear {
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
