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
    
    @discardableResult
    func evaluateAndUnlock(
        userId: String,
        workoutStreak: Int,
        totalWorkouts: Int,
        totalCaloriesBurned: Int,
        waterGoalDaysHit: Int,
        weightEntries: [WeightEntry],
        targetWeightLbs: Double?,
        hasEarlyBirdWorkout: Bool = false,
        hasNightOwlWorkout: Bool = false,
        hasLunchBreakWorkout: Bool = false,
        hadBreakBeforeReturn: Bool = false,
        hasZeroCalWorkout: Bool = false,
        hasSameWorkout5Times: Bool = false,
        hasDoubleSessionDay: Bool = false,
        longestWorkoutMinutes: Int = 0,
        totalMilesCardio: Double = 0,
        totalLiftedLbs: Double = 0,
        categoriesThisWeek: Set<String> = [],
        weekendWorkoutsThisWeek: Int = 0,
        caloriePrecisionDays: Int = 0,
        underBudgetDays: Int = 0,
        macroHitDays: Int = 0,
        weightLogDaysStreak: Int = 0,
        weightLogWeeks: Int = 0,
        totalWeightEntries: Int = 0,
        weeksAboveGoal: Int = 0,
        hasNewExercise: Bool = false,
        cardioWorkouts: Int = 0,
        coreWorkouts: Int = 0,
        strengthWorkouts: Int = 0,
        hasLogged30DaysAny: Bool = false
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
                targetWeightLbs: targetWeightLbs,
                hasEarlyBirdWorkout: hasEarlyBirdWorkout,
                hasNightOwlWorkout: hasNightOwlWorkout,
                hasLunchBreakWorkout: hasLunchBreakWorkout,
                hadBreakBeforeReturn: hadBreakBeforeReturn,
                hasZeroCalWorkout: hasZeroCalWorkout,
                hasSameWorkout5Times: hasSameWorkout5Times,
                hasDoubleSessionDay: hasDoubleSessionDay,
                longestWorkoutMinutes: longestWorkoutMinutes,
                totalMilesCardio: totalMilesCardio,
                totalLiftedLbs: totalLiftedLbs,
                categoriesThisWeek: categoriesThisWeek,
                weekendWorkoutsThisWeek: weekendWorkoutsThisWeek,
                caloriePrecisionDays: caloriePrecisionDays,
                underBudgetDays: underBudgetDays,
                macroHitDays: macroHitDays,
                weightLogDaysStreak: weightLogDaysStreak,
                weightLogWeeks: weightLogWeeks,
                totalWeightEntries: totalWeightEntries,
                weeksAboveGoal: weeksAboveGoal,
                hasNewExercise: hasNewExercise,
                cardioWorkouts: cardioWorkouts,
                coreWorkouts: coreWorkouts,
                strengthWorkouts: strengthWorkouts,
                hasLogged30DaysAny: hasLogged30DaysAny
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
