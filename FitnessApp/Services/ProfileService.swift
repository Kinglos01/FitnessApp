//
//  ProfileService.swift
//  FitnessApp
//
//  Reads and writes to the public.profiles table via Supabase.
//

//
//  ProfileService.swift
//  FitnessApp
//

import Foundation
import Supabase

// MARK: - ProfileUpdate

struct ProfileUpdate: Codable {
    let name: String
    let weight_lbs: Double
    let height_in: Double
    let birth_date: String          // "YYYY-MM-DD"
    let gender: String
    let activity_level: String
    let primary_goal: String
    let calorie_goal: Int
    let target_weight_lbs: Double?
    let custom_calories_enabled: Bool
    let units: String
}

// MARK: - ProfileResponse

struct ProfileResponse: Codable {
    let id: String
    let email: String?
    let name: String?
    let weight_lbs: Double?
    let height_in: Double?
    let birth_date: String?
    let gender: String?
    let activity_level: String?
    let primary_goal: String?
    let calorie_goal: Int?
    let target_weight_lbs: Double?
    let custom_calories_enabled: Bool?
    let units: String?
}

// MARK: - ProfileService

final class ProfileService {
    static let shared = ProfileService()
    private init() {}

    // MARK: - Update
    func updateProfile(userId: String, update: ProfileUpdate) async throws {
        try await supabase
            .from("profiles")
            .update(update)
            .eq("id", value: userId)
            .execute()
    }

    // MARK: - Fetch
    func fetchProfile(userId: String) async throws -> User {
        let response: ProfileResponse = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let birthDate = formatter.date(from: response.birth_date ?? "") ?? Date()

        return User(
            id: response.id,
            email: response.email ?? "",
            name: response.name ?? "",
            weight: response.weight_lbs ?? 150,
            height: response.height_in ?? 66,
            birthDate: birthDate,
            gender: response.gender ?? "Prefer Not To Say",
            activityLevel: response.activity_level ?? "Moderately Active",
            primaryGoal: response.primary_goal ?? "Lose Weight",
            calorieGoal: response.calorie_goal ?? 2200,
            targetWeightLbs: response.target_weight_lbs,
            customCaloriesEnabled: response.custom_calories_enabled ?? false,
            units: response.units ?? "Imperial"
        )
    }
}
