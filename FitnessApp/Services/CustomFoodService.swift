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

    enum CodingKeys: String, CodingKey {
        case id
        case userId    = "user_id"
        case foodName  = "food_name"
        case calories
        case protein
        case carbs
        case fat
        case mealType  = "meal_type"
        case useCount  = "use_count"
        case createdAt = "created_at"
    }
}

// MARK: - Insert-only model

private struct CustomFoodInsert: Codable {
    let userId: UUID
    let foodName: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let mealType: String?

    enum CodingKeys: String, CodingKey {
        case userId   = "user_id"
        case foodName = "food_name"
        case calories
        case protein
        case carbs
        case fat
        case mealType = "meal_type"
    }
}

// MARK: - Service

final class CustomFoodService {
    static let shared = CustomFoodService()
    private init() {}

    func fetchCustomFoods(userId: String) async throws -> [CustomFoodRecord] {
        guard let uid = UUID(uuidString: userId) else { return [] }
        let response: [CustomFoodRecord] = try await supabase
            .from("custom_foods")
            .select()
            .eq("user_id", value: uid)
            .order("use_count", ascending: false)
            .limit(20)
            .execute()
            .value
        return response
    }

    func insertCustomFood(userId: String, name: String, calories: Double, protein: Double, carbs: Double, fat: Double, mealType: String?) async throws {
        guard let uid = UUID(uuidString: userId) else { return }
        let record = CustomFoodInsert(
            userId: uid,
            foodName: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            mealType: mealType
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
}
