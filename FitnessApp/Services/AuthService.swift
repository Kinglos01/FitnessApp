//
//  AuthService.swift
//  SimplyFit
//
//  Created by Nelson Mojica on 2/13/26.
//

import Foundation
import Supabase

final class AuthService {
    static let shared = AuthService()
    private init() {}

    func signUp(email: String, password: String) async throws -> String {
        let response = try await supabase.auth.signUp(email: email, password: password)
        return response.user.id.uuidString
    }

    func signIn(email: String, password: String) async throws -> String {
        let session = try await supabase.auth.signIn(email: email, password: password)
        return session.user.id.uuidString
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    var currentUserId: String? {
        supabase.auth.currentUser?.id.uuidString
    }
}
