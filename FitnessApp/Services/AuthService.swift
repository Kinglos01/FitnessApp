//
//  AuthService.swift
//  FitnessApp
//
//  Created by Nelson Mojica on 2/13/26.
//

import Foundation
import FirebaseAuth

final class AuthService {
    static let shared = AuthService()
    private init() {}

    func signUp(email: String, password: String) async throws -> FirebaseAuth.User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return result.user
    }

    func signIn(email: String, password: String) async throws -> FirebaseAuth.User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return result.user
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    var currentUser: FirebaseAuth.User? {
        Auth.auth().currentUser
    }
}


