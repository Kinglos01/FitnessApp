//
//  AchievementService.swift
//  FitnessApp
//
 
import Foundation
import Supabase
 
// MARK: - AchievementService
 
final class AchievementService {
    static let shared = AchievementService()
    private init() {}
 
    // MARK: - Fetch
 
    /// Returns all unlocked achievements for a user.
    func fetchUnlocked(userId: String) async throws -> [UnlockedAchievement] {
        let response: [UnlockedAchievement] = try await supabase
            .from("user_achievements")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        return response
    }
 
    // MARK: - Unlock
 
    /// Inserts a new achievement row. Ignores conflict (already unlocked).
    func unlock(userId: String, achievementId: String) async throws {
        struct Row: Encodable {
            let user_id: String
            let id: String
            let unlocked_at: String
        }
 
        let formatter = ISO8601DateFormatter()
        let row = Row(
            user_id: userId,
            id: achievementId,
            unlocked_at: formatter.string(from: Date())
        )
 
        try await supabase
            .from("user_achievements")
            .upsert(row, onConflict: "user_id,id")   // safe: won't duplicate
            .execute()
    }
 
    // MARK: - Evaluate & Unlock New
 
    /// Runs the achievement engine and persists any newly earned badges.
    /// Returns the IDs that were newly unlocked (so the caller can show toasts).
    @discardableResult
    func evaluateAndUnlock(
        userId: String,
        workoutStreak: Int,
        totalWorkouts: Int,
        totalCaloriesBurned: Int,
        waterGoalDaysHit: Int,
        weightEntries: [WeightHistoryEntry],
        targetWeightLbs: Double?
    ) async -> [String] {
        guard !userId.isEmpty else { return [] }
 
        do {
            let existing = try await fetchUnlocked(userId: userId)
            let existingIds = Set(existing.map { $0.id })
 
            let newIds = AchievementEngine.evaluate(
                existing: existingIds,
                workoutStreak: workoutStreak,
                totalWorkouts: totalWorkouts,
                totalCaloriesBurned: totalCaloriesBurned,
                waterGoalDaysHit: waterGoalDaysHit,
                weightEntries: weightEntries,
                targetWeightLbs: targetWeightLbs
            )
 
            for id in newIds {
                try await unlock(userId: userId, achievementId: id)
            }
 
            return newIds
        } catch {
            print("AchievementService error: \(error)")
            return []
        }
    }
}
