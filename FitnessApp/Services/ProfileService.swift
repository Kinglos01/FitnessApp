//
//  ProfileService.swift
//  FitnessApp
//

import Foundation
import Supabase

// MARK: - WeightHistoryEntry

struct WeightHistoryEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var weight_lbs: Double

    // Only encode/decode date and weight — never id
    // id is generated locally and never stored in Supabase
    enum CodingKeys: String, CodingKey {
        case date
        case weight_lbs
    }

    init(date: Date, weight_lbs: Double) {
        self.id         = UUID()
        self.date       = date
        self.weight_lbs = weight_lbs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.weight_lbs = (try? container.decode(Double.self, forKey: .weight_lbs)) ?? 0

        // Handle date as either Date or ISO8601/yyyy-MM-dd string from jsonb
        if let d = try? container.decode(Date.self, forKey: .date) {
            self.date = d
        } else if let s = try? container.decode(String.self, forKey: .date) {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsed = iso.date(from: s) {
                self.date = parsed
            } else {
                let fallback = DateFormatter()
                fallback.dateFormat = "yyyy-MM-dd"
                self.date = fallback.date(from: s) ?? Date()
            }
        } else {
            self.date = Date()
        }
    }
}

// MARK: - ProfileUpdate

struct ProfileUpdate: Codable {
    let name: String
    let weight_lbs: Double
    let height_in: Double
    let birth_date: String
    let gender: String
    let activity_level: String
    let primary_goal: String
    let calorie_goal: Int
    let target_weight_lbs: Double?
    let custom_calories_enabled: Bool
    let units: String
    let weight_history: [WeightHistoryEntry]
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
    let weight_history: [WeightHistoryEntry]?
    let is_admin: Bool?
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
            units: response.units ?? "Imperial",
            isAdmin: response.is_admin ?? false
        )
    }

    // MARK: - Append weight entry
    func appendWeightEntry(userId: String, weightLbs: Double) async throws {
        let response: ProfileResponse = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value

        var history = response.weight_history ?? []
        let newEntry = WeightHistoryEntry(date: Date(), weight_lbs: weightLbs)
        history.append(newEntry)

        try await supabase
            .from("profiles")
            .update([
                "weight_lbs":     AnyEncodable(weightLbs),
                "weight_history": AnyEncodable(history)
            ])
            .eq("id", value: userId)
            .execute()
    }

    // MARK: - Fetch weight history
    func fetchWeightHistory(userId: String) async throws -> [WeightHistoryEntry] {
        let response: ProfileResponse = try await supabase
            .from("profiles")
            .select("id, weight_history")
            .eq("id", value: userId)
            .single()
            .execute()
            .value

        return (response.weight_history ?? []).sorted { $0.date < $1.date }
    }

    // MARK: - Admin: fetch any user's profile by email
    func fetchProfileByEmail(email: String) async throws -> ProfileResponse {
        let response: [ProfileResponse] = try await supabase
            .from("profiles")
            .select()
            .eq("email", value: email)
            .execute()
            .value

        guard let profile = response.first else {
            throw NSError(domain: "ProfileService", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "No user found with that email."])
        }
        return profile
    }

    // MARK: - Admin: update any user's weight history
    func updateWeightHistory(userId: String, history: [WeightHistoryEntry]) async throws {
        let currentWeight = history.last?.weight_lbs
        var updateDict: [String: AnyEncodable] = [
            "weight_history": AnyEncodable(history)
        ]
        if let w = currentWeight {
            updateDict["weight_lbs"] = AnyEncodable(w)
        }
        try await supabase
            .from("profiles")
            .update(updateDict)
            .eq("id", value: userId)
            .execute()
    }
}

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) { _encode = value.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
