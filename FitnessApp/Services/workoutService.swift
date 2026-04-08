//
//  workoutService.swift
//  FitnessApp
//
//  Created by Carlos Berio on 4/8/26.
//


import Foundation
import Supabase

// MARK: - Supabase Workout Row

struct WorkoutRow: Codable, Identifiable {
    let id: UUID
    let user_id: String
    var name: String
    var category: String
    var sets: Int
    var reps: Int
    var weight_lbs: Double?
    var duration_mins: Int?
    var calories_burned: Int
    var notes: String
    var date: Date
    var is_completed: Bool
}

struct WorkoutInsert: Codable {
    let id: UUID
    let user_id: String
    let name: String
    let category: String
    let sets: Int
    let reps: Int
    let weight_lbs: Double?
    let duration_mins: Int?
    let calories_burned: Int
    let notes: String
    let date: Date
    let is_completed: Bool
}

// MARK: - WorkoutService

final class WorkoutService {
    static let shared = WorkoutService()
    private init() {}

    // MARK: - Upsert single workout
    func upsertWorkout(_ entry: ActivityEntry, userId: String) async throws {
        let row = WorkoutInsert(
            id:              entry.id,
            user_id:         userId,
            name:            entry.name,
            category:        entry.category.rawValue,
            sets:            entry.sets,
            reps:            entry.reps,
            weight_lbs:      entry.weight,
            duration_mins:   entry.duration,
            calories_burned: entry.caloriesBurned,
            notes:           entry.notes,
            date:            entry.date,
            is_completed:    entry.isCompleted
        )
        try await supabase
            .from("workouts")
            .upsert(row, onConflict: "id")
            .execute()
    }

    // MARK: - Delete workout
    func deleteWorkout(id: UUID) async throws {
        try await supabase
            .from("workouts")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Fetch all workouts for user
    func fetchWorkouts(userId: String) async throws -> [ActivityEntry] {
        let rows: [WorkoutRow] = try await supabase
            .from("workouts")
            .select()
            .eq("user_id", value: userId)
            .order("date", ascending: false)
            .execute()
            .value

        return rows.compactMap { row in
            guard let category = ExerciseCategory(rawValue: row.category) else { return nil }
            return ActivityEntry(
                id:             row.id,
                name:           row.name,
                category:       category,
                sets:           row.sets,
                reps:           row.reps,
                weight:         row.weight_lbs,
                duration:       row.duration_mins,
                caloriesBurned: row.calories_burned,
                notes:          row.notes,
                date:           row.date,
                isCompleted:    row.is_completed
            )
        }
    }

    // MARK: - Fetch workouts for date range (for calendar / admin)
    func fetchWorkouts(userId: String, from startDate: Date, to endDate: Date) async throws -> [ActivityEntry] {
        let rows: [WorkoutRow] = try await supabase
            .from("workouts")
            .select()
            .eq("user_id", value: userId)
            .gte("date", value: startDate.ISO8601Format())
            .lte("date", value: endDate.ISO8601Format())
            .order("date", ascending: true)
            .execute()
            .value

        return rows.compactMap { row in
            guard let category = ExerciseCategory(rawValue: row.category) else { return nil }
            return ActivityEntry(
                id:             row.id,
                name:           row.name,
                category:       category,
                sets:           row.sets,
                reps:           row.reps,
                weight:         row.weight_lbs,
                duration:       row.duration_mins,
                caloriesBurned: row.calories_burned,
                notes:          row.notes,
                date:           row.date,
                isCompleted:    row.is_completed
            )
        }
    }

    // MARK: - Admin: fetch any user's workouts
    func fetchWorkouts(forAdminUserId targetUserId: String) async throws -> [ActivityEntry] {
        return try await fetchWorkouts(userId: targetUserId)
    }

    // MARK: - Admin: upsert workout for any user
    func upsertWorkout(_ entry: ActivityEntry, forAdminUserId targetUserId: String) async throws {
        try await upsertWorkout(entry, userId: targetUserId)
    }

    // MARK: - Admin: delete workout for any user
    func deleteWorkout(id: UUID, forAdminUserId: String) async throws {
        try await deleteWorkout(id: id)
    }
}
