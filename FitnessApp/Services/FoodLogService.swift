//
//  FoodLogService.swift
//  FitnessApp
//

import Foundation
import Supabase

// MARK: - Model

struct FoodLogRecord: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let date: String
    let mealType: String
    let foodName: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double

    enum CodingKeys: String, CodingKey {
        case id
        case userId   = "user_id"
        case date
        case mealType = "meal_type"
        case foodName = "food_name"
        case calories
        case protein
        case carbs
        case fat
    }
}

// MARK: - Insert-only model (no id, let Supabase generate it)

private struct FoodLogInsert: Codable {
    let userId: UUID
    let date: String
    let mealType: String
    let foodName: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double

    enum CodingKeys: String, CodingKey {
        case userId   = "user_id"
        case date
        case mealType = "meal_type"
        case foodName = "food_name"
        case calories
        case protein
        case carbs
        case fat
    }
}

// MARK: - Service

final class FoodLogService {
    static let shared = FoodLogService()
    private init() {}

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func fetchTodayLogs(userId: String) async throws -> [FoodLogRecord] {
        guard let uid = UUID(uuidString: userId) else { return [] }
        let todayString = dateFormatter.string(from: Date())
        let response: [FoodLogRecord] = try await supabase
            .from("food_logs")
            .select()
            .eq("user_id", value: uid)
            .eq("date", value: todayString)
            .order("created_at")
            .execute()
            .value
        return response
    }

    func insertLog(userId: String, entry: LoggedFoodEntry) async throws {
        guard let uid = UUID(uuidString: userId) else { return }
        let todayString = dateFormatter.string(from: Date())
        let record = FoodLogInsert(
            userId: uid,
            date: todayString,
            mealType: entry.mealType.rawValue,
            foodName: entry.foodItem.description,
            calories: entry.foodItem.calories,
            protein: entry.foodItem.protein,
            carbs: entry.foodItem.carbs,
            fat: entry.foodItem.fat
        )
        try await supabase
            .from("food_logs")
            .insert(record)
            .execute()
    }

    func deleteLog(id: UUID) async throws {
        try await supabase
            .from("food_logs")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func deleteAllTodayLogs(userId: String) async throws {
        guard let uid = UUID(uuidString: userId) else { return }
        let todayString = dateFormatter.string(from: Date())
        try await supabase
            .from("food_logs")
            .delete()
            .eq("user_id", value: uid)
            .eq("date", value: todayString)
            .execute()
    }
}
