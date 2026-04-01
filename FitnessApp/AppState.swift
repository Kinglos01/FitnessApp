import SwiftUI
import Observation

@Observable
class AppState {

    var currentUser: User?
    var isLoggedIn: Bool = false
    var hasCompletedOnboarding: Bool = false

    var pendingUserId: String?
    var pendingEmail: String?

    // MARK: - Appearance (per-account)
    // "Light", "Dark", or "System"; persisted per user id
    var appearancePreference: String = "System"

    var colorScheme: ColorScheme? {
        switch appearancePreference.lowercased() {
        case "light": return .light
        case "dark":  return .dark
        default:        return nil
        }
    }

    private func appearanceKey(for userId: String?) -> String {
        let uid = userId ?? "guest"
        return "appearance_\(uid)"
    }

    func loadAppearance(for userId: String?) {
        let key = appearanceKey(for: userId)
        if let stored = UserDefaults.standard.string(forKey: key) {
            appearancePreference = stored
        } else {
            appearancePreference = "System"
        }
    }

    func setAppearance(_ preference: String) {
        appearancePreference = preference
        let key = appearanceKey(for: currentUser?.id)
        UserDefaults.standard.set(preference, forKey: key)
    }

    init() {}

    /// Called from RootView.onAppear.
    /// Only restores session if Supabase has an active session AND we have a saved profile.
    func restoreSessionIfNeeded() {
        guard let userId = AuthService.shared.currentUserId else {
            isLoggedIn = false
            hasCompletedOnboarding = false
            currentUser = nil
            loadAppearance(for: nil)
            return
        }
        // First try local cache for instant load
        loadUser(for: userId)
        loadAppearance(for: userId)
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
        loadAppearance(for: userId)
        isLoggedIn = true
    }

    /// Call after the user finishes onboarding.
    func completeOnboarding(user: User) {
        currentUser = user
        hasCompletedOnboarding = true
        saveUser(user)
        loadAppearance(for: user.id)
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
        loadAppearance(for: nil)
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
            loadAppearance(for: userId)
        }
    }
}
