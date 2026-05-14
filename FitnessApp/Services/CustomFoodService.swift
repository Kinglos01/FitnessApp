//
//  CustomFoodService.swift
//  SimplyFit
//

import Foundation
import Supabase

// MARK: - Model

struct CustomFoodRecord: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let foodName: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let mealType: String?
    let useCount: Int
    let createdAt: Date?
    let isTemporary: Bool
    let createdDate: String? // "yyyy-MM-dd"

    enum CodingKeys: String, CodingKey {
        case id
        case userId      = "user_id"
        case foodName    = "food_name"
        case calories
        case protein
        case carbs
        case fat
        case mealType    = "meal_type"
        case useCount    = "use_count"
        case createdAt   = "created_at"
        case isTemporary = "is_temporary"
        case createdDate = "created_date"
    }

    // Is this one-time food still valid for today?
    var isValidToday: Bool {
        guard isTemporary else { return true }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let today = f.string(from: Date())
        return createdDate == today
    }
}

// MARK: - Insert model

private struct CustomFoodInsert: Codable {
    let userId: UUID
    let foodName: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let mealType: String?
    let isTemporary: Bool
    let createdDate: String

    enum CodingKeys: String, CodingKey {
        case userId      = "user_id"
        case foodName    = "food_name"
        case calories
        case protein
        case carbs
        case fat
        case mealType    = "meal_type"
        case isTemporary = "is_temporary"
        case createdDate = "created_date"
    }
}

// MARK: - Service

final class CustomFoodService {
    static let shared = CustomFoodService()
    private init() {}

    private var todayString: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // Fetch permanent foods + today's temporary foods
    func fetchCustomFoods(userId: String) async throws -> [CustomFoodRecord] {
        guard let uid = UUID(uuidString: userId) else { return [] }
        let response: [CustomFoodRecord] = try await supabase
            .from("custom_foods")
            .select()
            .eq("user_id", value: uid)
            .order("use_count", ascending: false)
            .execute()
            .value
        // Filter: keep permanent ones + today's temporary ones
        return response.filter { $0.isValidToday }
    }

    // Fetch top 3 by use_count for Quick Add
    func fetchTopFoods(userId: String) async throws -> [CustomFoodRecord] {
        guard let uid = UUID(uuidString: userId) else { return [] }
        let response: [CustomFoodRecord] = try await supabase
            .from("custom_foods")
            .select()
            .eq("user_id", value: uid)
            .eq("is_temporary", value: false)
            .order("use_count", ascending: false)
            .limit(3)
            .execute()
            .value
        return response
    }

    func insertCustomFood(
        userId: String,
        name: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        mealType: String?,
        isTemporary: Bool = false
    ) async throws {
        guard let uid = UUID(uuidString: userId) else { return }
        let record = CustomFoodInsert(
            userId: uid,
            foodName: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            mealType: mealType,
            isTemporary: isTemporary,
            createdDate: todayString
        )
        try await supabase
            .from("custom_foods")
            .insert(record)
            .execute()
    }

    func incrementUseCount(id: UUID) async throws {
        let rows: [CustomFoodRecord] = try await supabase
            .from("custom_foods")
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        guard let current = rows.first else { return }
        try await supabase
            .from("custom_foods")
            .update(["use_count": current.useCount + 1])
            .eq("id", value: id)
            .execute()
    }

    func deleteCustomFood(id: UUID) async throws {
        try await supabase
            .from("custom_foods")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // Clean up expired temporary foods (call on app launch or view appear)
    func deleteExpiredTemporaryFoods(userId: String) async throws {
        guard let uid = UUID(uuidString: userId) else { return }
        try await supabase
            .from("custom_foods")
            .delete()
            .eq("user_id", value: uid)
            .eq("is_temporary", value: true)
            .neq("created_date", value: todayString)
            .execute()
    }
}
