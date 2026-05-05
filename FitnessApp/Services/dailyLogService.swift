//
//  dailyLogService.swift
//  SimplyFit
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

    // MARK: - Upsert today's log (partial update)
    /// Pass only the values you want to change; nil fields keep their existing value.
    func upsertLog(
        userId: String,
        date: Date = Date(),
        waterConsumed: Int? = nil,
        waterGoal: Int? = nil,
        caloriesEaten: Double? = nil,
        caloriesBurned: Int? = nil,
        workoutsCompleted: Int? = nil
    ) async throws {
        let existing = try? await fetchLog(userId: userId, date: date)

        let log = DailyLog(
            user_id: userId,
            date: dateFormatter.string(from: date),
            water_consumed: waterConsumed ?? existing?.water_consumed ?? 0,
            water_goal: waterGoal ?? existing?.water_goal ?? 8,
            calories_eaten: caloriesEaten ?? existing?.calories_eaten ?? 0,
            calories_burned: caloriesBurned ?? existing?.calories_burned ?? 0,
            workouts_completed: workoutsCompleted ?? existing?.workouts_completed ?? 0
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

    // MARK: - Fetch today's log (convenience)
    func fetchTodayLog(userId: String) async throws -> DailyLogResponse? {
        return try await fetchLog(userId: userId, date: Date())
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
