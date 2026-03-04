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

    var currentUser: User? {
        didSet { saveUser() }
    }
    var isLoggedIn: Bool = false
    var hasCompletedOnboarding: Bool = false

    init() {
        loadUser()
    }

    private func saveUser() {
        guard let user = currentUser else { return }
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "savedUser")
            hasCompletedOnboarding = true
        }
    }

    private func loadUser() {
        // Only restore profile data, never auto-login
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
        UserDefaults.standard.removeObject(forKey: "savedUser")
    }
}
