//
//  ProfileService.swift
//  FitnessApp
//
//  Reads and writes to the public.profiles table via Supabase.
//

import Foundation
import Supabase

/// Matches the Supabase profiles table columns for updates.
struct ProfileUpdate: Codable {
    let name: String
    let weight_lbs: Double
    let height_in: Double
    let birth_date: String   // "YYYY-MM-DD"
    let gender: String
}

final class ProfileService {
    static let shared = ProfileService()
    private init() {}

    func updateProfile(userId: String, update: ProfileUpdate) async throws {
        try await supabase
            .from("profiles")
            .update(update)
            .eq("id", value: userId)
            .execute()
    }
}
