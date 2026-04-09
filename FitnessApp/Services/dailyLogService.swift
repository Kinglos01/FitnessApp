//
//  dailyLogService.swift
//  FitnessApp
//
//  Created by Carlos Berio on 4/8/26.
//
//


import Foundation
import Supabase

// MARK: - Model

struct DailyLog: Codable {
    let user_id: String
    let date: String
    var water_consumed: Int
    var water_goal: Int
    var calories_eaten: Double
    var calories_burned: Int
    var workouts_completed: Int
}

struct DailyLogResponse: Codable , Identifiable{
    let id: String
    let user_id: String
    let date: String
    var water_consumed: Int
    var water_goal: Int
    var calories_eaten: Double
    var calories_burned: Int
    var workouts_completed: Int
}

// MARK: - Service

final class DailyLogService {
    static let shared = DailyLogService()
    private init() {}

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Upsert today's log
    func upsertLog(
        userId: String,
        date: Date = Date(),
        waterConsumed: Int,
        waterGoal: Int,
        caloriesEaten: Double,
        caloriesBurned: Int,
        workoutsCompleted: Int
    ) async throws {
        let log = DailyLog(
            user_id: userId,
            date: dateFormatter.string(from: date),
            water_consumed: waterConsumed,
            water_goal: waterGoal,
            calories_eaten: caloriesEaten,
            calories_burned: caloriesBurned,
            workouts_completed: workoutsCompleted
        )

        try await supabase
            .from("daily_logs")
            .upsert(log, onConflict: "user_id,date")
            .execute()
    }

    // MARK: - Fetch single day
    func fetchLog(userId: String, date: Date) async throws -> DailyLogResponse? {
        let dateString = dateFormatter.string(from: date)
        let response: [DailyLogResponse] = try await supabase
            .from("daily_logs")
            .select()
            .eq("user_id", value: userId)
            .eq("date", value: dateString)
            .execute()
            .value
        return response.first
    }

    // MARK: - Fetch date range (for calendar)
    func fetchLogs(userId: String, from startDate: Date, to endDate: Date) async throws -> [DailyLogResponse] {
        let start = dateFormatter.string(from: startDate)
        let end   = dateFormatter.string(from: endDate)
        let response: [DailyLogResponse] = try await supabase
            .from("daily_logs")
            .select()
            .eq("user_id", value: userId)
            .gte("date", value: start)
            .lte("date", value: end)
            .execute()
            .value
        return response
    }
}
