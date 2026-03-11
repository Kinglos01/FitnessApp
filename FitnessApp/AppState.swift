import SwiftUI
import Observation

@Observable
class AppState {

    var currentUser: User?
    var isLoggedIn: Bool = false
    var hasCompletedOnboarding: Bool = false

    var pendingUserId: String?
    var pendingEmail: String?

    init() {}

    /// Called from RootView.onAppear.
    /// Only restores session if Supabase has an active session AND we have a saved profile.
    func restoreSessionIfNeeded() {
        guard let userId = AuthService.shared.currentUserId else {
            isLoggedIn = false
            hasCompletedOnboarding = false
            currentUser = nil
            return
        }
        // First try local cache for instant load
        loadUser(for: userId)
        // Then refresh from Supabase in the background to stay in sync
        Task {
            if let user = try? await ProfileService.shared.fetchProfile(userId: userId) {
                completeOnboarding(user: user)
            }
        }
    }

    /// Call after a successful sign-in to load the correct user's profile.
    func signIn(userId: String) {
        loadUser(for: userId)
        isLoggedIn = true
    }

    /// Call after the user finishes onboarding.
    func completeOnboarding(user: User) {
        currentUser = user
        hasCompletedOnboarding = true
        saveUser(user)
        pendingUserId = nil
        pendingEmail = nil
    }

    func signOut() {
        currentUser = nil
        isLoggedIn = false
        hasCompletedOnboarding = false
        pendingUserId = nil
        pendingEmail = nil
        // Clear the Supabase session so it won't auto-restore on next launch
        Task { try? await AuthService.shared.signOut() }
    }

    // MARK: - Private

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
        }
    }
}
