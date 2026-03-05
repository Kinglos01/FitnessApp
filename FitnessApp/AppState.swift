//
//  AppState.swift
//  FitnessApp
//
//  Created by Yohangel Adames on 3/4/26.
//

import SwiftUI
import Observation

@Observable
class AppState {

    var currentUser: User?
    var isLoggedIn: Bool = false
    var hasCompletedOnboarding: Bool = false

    // Temporary storage between sign-up and onboarding completion
    var pendingUserId: String?
    var pendingEmail: String?

    init() {
        loadUser()
    }

    /// Call this only after the user finishes onboarding (UserInfoView).
    func completeOnboarding(user: User) {
        currentUser = user
        hasCompletedOnboarding = true
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "savedUser")
        }
        pendingUserId = nil
        pendingEmail = nil
    }

    private func loadUser() {
        if let data = UserDefaults.standard.data(forKey: "savedUser"),
           let decoded = try? JSONDecoder().decode(User.self, from: data) {
            currentUser = decoded
            hasCompletedOnboarding = true
        }
    }

    func signOut() {
        currentUser = nil
        isLoggedIn = false
        hasCompletedOnboarding = false
        pendingUserId = nil
        pendingEmail = nil
        UserDefaults.standard.removeObject(forKey: "savedUser")
    }
}
