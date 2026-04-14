import SwiftUI
import Observation

@Observable
class AppState {

    var currentUser: User?
    var isLoggedIn: Bool = false
    var hasCompletedOnboarding: Bool = false

    var pendingUserId: String?
    var pendingEmail: String?

    // NEW: shared profile store used across Profile / Settings / Dashboard
    var profileStore = ProfileStore()

    init() {}

    func restoreSessionIfNeeded() {
        guard let userId = AuthService.shared.currentUserId else {
            isLoggedIn = false
            hasCompletedOnboarding = false
            currentUser = nil
            profileStore.profile = nil
            NotificationManager.shared.clearAllFitnessNotifications()
            return
        }

        loadUser(for: userId)

        Task {
            if let user = try? await ProfileService.shared.fetchProfile(userId: userId) {
                await MainActor.run {
                    completeOnboarding(user: user)
                }
            } else if let currentUser {
                NotificationManager.shared.syncNotifications(for: currentUser)
            }
        }
    }

    func signIn(userId: String) {
        UserDefaults.standard.removeObject(forKey: storageKey(for: userId))
        isLoggedIn = true

        Task {
            if let user = try? await ProfileService.shared.fetchProfile(userId: userId) {
                await MainActor.run {
                    completeOnboarding(user: user)
                }
            }
        }
    }

    func completeOnboarding(user: User) {
        currentUser = user
        isLoggedIn = true
        hasCompletedOnboarding = true
        saveUser(user)
        pendingUserId = nil
        pendingEmail = nil

        syncProfileStoreFromCurrentUser()
        NotificationManager.shared.syncNotifications(for: user)
    }

    func signOut() {
        currentUser = nil
        isLoggedIn = false
        hasCompletedOnboarding = false
        pendingUserId = nil
        pendingEmail = nil
        profileStore.profile = nil

        NotificationManager.shared.clearAllFitnessNotifications()

        Task {
            try? await AuthService.shared.signOut()
        }
    }

    func syncProfileStoreFromCurrentUser() {
        guard let user = currentUser else {
            profileStore.profile = nil
            return
        }

        profileStore.load(
            userId: user.id,
            displayName: user.name,
            email: user.email
        )
    }

    private func storageKey(for userId: String) -> String {
        "savedUser_\(userId)"
    }

    private func saveUser(_ user: User) {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: storageKey(for: user.id))
        }
    }

    private func loadUser(for userId: String) {
        let key = storageKey(for: userId)
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(User.self, from: data) {
            currentUser = decoded
            hasCompletedOnboarding = true
            isLoggedIn = true
            syncProfileStoreFromCurrentUser()
        }
    }
}
