//
//  AchievementModels.swift
//  FitnessApp
//

import SwiftUI

// MARK: - Achievement Category

enum AchievementCategory: String, CaseIterable, Codable {
    case streak      = "Streak"
    case workouts    = "Workouts"
    case variety     = "Variety"
    case calories    = "Calories"
    case nutrition   = "Nutrition"
    case water       = "Hydration"
    case weight      = "Weight"
    case volume      = "Volume"
    case social      = "Milestones"

    var icon: String {
        switch self {
        case .streak:    return "flame.fill"
        case .workouts:  return "dumbbell.fill"
        case .variety:   return "shuffle"
        case .calories:  return "bolt.fill"
        case .nutrition: return "fork.knife"
        case .water:     return "drop.fill"
        case .weight:    return "scalemass.fill"
        case .volume:    return "chart.bar.fill"
        case .social:    return "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .streak:    return Color(hex: "FF6B35")
        case .workouts:  return Color(hex: "E84855")
        case .variety:   return Color(hex: "A855F7")
        case .calories:  return Color(hex: "3BB273")
        case .nutrition: return Color(hex: "F59E0B")
        case .water:     return Color(hex: "2196F3")
        case .weight:    return Color(hex: "9C6FE4")
        case .volume:    return Color(hex: "06B6D4")
        case .social:    return Color(hex: "FFB800")
        }
    }
}

// MARK: - Achievement Tier

enum AchievementTier: Int, Codable {
    case bronze = 1
    case silver = 2
    case gold   = 3

    var color: Color {
        switch self {
        case .bronze: return Color(hex: "CD7F32")
        case .silver: return Color(hex: "A8A9AD")
        case .gold:   return Color(hex: "FFD700")
        }
    }
    var label: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold:   return "Gold"
        }
    }
    var ringColor: Color {
        switch self {
        case .bronze: return Color(hex: "CD7F32")
        case .silver: return Color(hex: "C0C0C8")
        case .gold:   return Color(hex: "FFD700")
        }
    }
}

// MARK: - Achievement Definition

struct AchievementDefinition: Identifiable {
    let id: String
    let category: AchievementCategory
    let title: String
    let description: String
    let funFact: String
    let tier: AchievementTier
}

// MARK: - All Achievement Definitions

extension AchievementDefinition {
    static let all: [AchievementDefinition] = [

        // STREAK
        .init(id: "streak_3",           category: .streak,    title: "Spark",             description: "3 days in a row",                   funFact: "Three days is when habits actually start forming!",                            tier: .bronze),
        .init(id: "streak_7",           category: .streak,    title: "On Fire",            description: "7 days in a row",                   funFact: "A full week — you're officially a creature of habit!",                         tier: .silver),
        .init(id: "streak_30",          category: .streak,    title: "Unstoppable",        description: "30 days in a row",                  funFact: "30 days! Scientists say this is when neural pathways cement.",                 tier: .gold),
        .init(id: "no_days_off",        category: .streak,    title: "No Days Off",        description: "Log every day for a month",         funFact: "Full month zero rest days — your dedication is elite.",                        tier: .gold),
        .init(id: "perfect_week",       category: .streak,    title: "Perfect Week",       description: "All 7 days in a week",              funFact: "A perfect 7/7 week. Less than 5% of users ever pull this off.",               tier: .gold),
        .init(id: "weekend_warrior",    category: .streak,    title: "Weekend Warrior",    description: "Work out Sat & Sun",                funFact: "While everyone rests, you grind. Respect.",                                   tier: .silver),

        // WORKOUTS
        .init(id: "workouts_1",         category: .workouts,  title: "First Rep",          description: "Complete your first workout",       funFact: "Every champion started with workout #1.",                                      tier: .bronze),
        .init(id: "workouts_10",        category: .workouts,  title: "Getting Serious",    description: "Complete 10 workouts",              funFact: "10 workouts in — your body is already adapting.",                             tier: .bronze),
        .init(id: "workouts_50",        category: .workouts,  title: "Half Century",       description: "Complete 50 workouts",              funFact: "50 sessions — roughly 50 hours of becoming better.",                          tier: .silver),
        .init(id: "workouts_100",       category: .workouts,  title: "Centurion",          description: "Complete 100 workouts",             funFact: "100 workouts. More gym time than most do in years.",                           tier: .gold),
        .init(id: "double_session",     category: .workouts,  title: "Double Session",     description: "Log 2 workouts in one day",         funFact: "Two-a-days are an elite training technique. You're built different.",         tier: .silver),
        .init(id: "hour_club",          category: .workouts,  title: "Hour Club",          description: "Log a 60+ minute workout",          funFact: "60 minutes straight. That's serious commitment.",                             tier: .silver),
        .init(id: "grind_50_days",      category: .workouts,  title: "The Grind",          description: "50 total workout days",             funFact: "50 days on the calendar marked. Most people never get here.",                  tier: .silver),

        // VARIETY
        .init(id: "jack_of_all_trades", category: .variety,   title: "Jack of All Trades", description: "Try all 7 categories in a week",   funFact: "All 7 categories — you literally do it all.",                                 tier: .gold),
        .init(id: "cardio_king",        category: .variety,   title: "Cardio King",        description: "Complete 20 cardio workouts",       funFact: "20 cardio sessions — your heart is a machine.",                               tier: .silver),
        .init(id: "core_commander",     category: .variety,   title: "Core Commander",     description: "Complete 15 core workouts",         funFact: "15 core sessions — your abs are basically armor now.",                        tier: .silver),
        .init(id: "strength_beast",     category: .variety,   title: "Strength Beast",     description: "Complete 30 strength workouts",     funFact: "30 strength sessions — compound gains are compounding.",                      tier: .gold),
        .init(id: "new_move",           category: .variety,   title: "New Move",           description: "Log an exercise you've never done", funFact: "Trying new exercises keeps your muscles guessing. Smart training.",           tier: .bronze),

        // CALORIES
        .init(id: "calories_1000",      category: .calories,  title: "Spark Plug",         description: "Burn 1,000 total calories",         funFact: "1,000 kcal — that's about 10 miles walked!",                                 tier: .bronze),
        .init(id: "calories_5000",      category: .calories,  title: "Inferno",            description: "Burn 5,000 total calories",         funFact: "5,000 kcal — equivalent to running a full marathon!",                        tier: .silver),
        .init(id: "calories_10000",     category: .calories,  title: "Furnace",            description: "Burn 10,000 total calories",        funFact: "10,000 kcal — you've burned off 3 lbs of pure fat!",                         tier: .gold),
        .init(id: "marathon_miles",     category: .calories,  title: "Marathon Man",       description: "Log 26+ miles of cardio",           funFact: "26.2 miles logged. You've covered a full marathon distance!",                tier: .gold),
        .init(id: "early_bird",         category: .calories,  title: "Early Bird",         description: "Log a workout before 7am",          funFact: "Morning workouts boost metabolism for the entire day.",                       tier: .bronze),

        // NUTRITION
        .init(id: "clean_plate",        category: .nutrition, title: "Clean Plate",        description: "Hit calorie goal ±50 kcal, 3 days", funFact: "Precision nutrition 3 days straight — dietitian-level accuracy.",            tier: .silver),
        .init(id: "macro_master",       category: .nutrition, title: "Macro Master",       description: "Hit all 3 macros in one day",       funFact: "Protein, carbs AND fat all on target? That takes real discipline.",          tier: .gold),
        .init(id: "under_budget",       category: .nutrition, title: "Under Budget",       description: "Stay under calorie goal 7 days",    funFact: "7 days in a calorie deficit. Your body is thanking you.",                    tier: .silver),

        // WATER
        .init(id: "water_7",            category: .water,     title: "Stay Hydrated",      description: "Hit water goal 7 days",             funFact: "7 days of hydration — your skin, joints, and brain thank you!",              tier: .bronze),
        .init(id: "water_30",           category: .water,     title: "Flood Gates",        description: "Hit water goal 30 days",            funFact: "30 days hitting your water goal. You're basically part dolphin.",            tier: .gold),

        // WEIGHT
        .init(id: "weight_first",       category: .weight,    title: "On The Scale",       description: "Log your first weight",             funFact: "The first step to reaching your goal is knowing where you start.",           tier: .bronze),
        .init(id: "consistent_logger",  category: .weight,    title: "Consistent Logger",  description: "Log weight 7 days in a row",        funFact: "Daily weigh-ins show 40% better progress tracking. Science!",              tier: .bronze),
        .init(id: "month_tracker",      category: .weight,    title: "Month Tracker",      description: "Log weight every week for a month", funFact: "4 weeks of data — your trend line is actually meaningful now.",             tier: .silver),
        .init(id: "data_nerd",          category: .weight,    title: "Data Nerd",          description: "Have 30+ weight entries",           funFact: "30 data points — your trend is statistically significant.",                 tier: .gold),
        .init(id: "weight_goal",        category: .weight,    title: "Goal Crusher",       description: "Reach your target weight",          funFact: "You actually did it. Target reached. This one's rare.",                     tier: .gold),

        // VOLUME
        .init(id: "iron_ton",           category: .volume,    title: "Iron Ton",           description: "Lift 10,000 lbs total",             funFact: "10,000 lbs lifted. Heavier than a fully loaded school bus.",                tier: .gold),

        // MILESTONES
        .init(id: "early_bird_social",  category: .social,    title: "Night Owl",          description: "Log a workout after 9pm",           funFact: "Your body temp peaks at 6pm — night strength gains are real.",              tier: .bronze),
        .init(id: "lunch_break_hero",   category: .social,    title: "Lunch Break Hero",   description: "Work out between 12–2pm",           funFact: "Midday workouts improve afternoon focus by up to 20%.",                    tier: .bronze),
        .init(id: "overachiever",       category: .social,    title: "Overachiever",       description: "Beat weekly goal 3 weeks running",  funFact: "3 weeks of going above and beyond. The definition of extra.",              tier: .gold),
        .init(id: "ghost_mode",         category: .social,    title: "Ghost Mode",         description: "Log a workout with 0 calories",     funFact: "Pure mobility or stretching — recovery is training too.",                  tier: .bronze),
        .init(id: "creature_of_habit",  category: .social,    title: "Creature of Habit",  description: "Log the same workout 5 times",      funFact: "Repetition is the mother of mastery. Same move, 5 times over.",           tier: .silver),
        .init(id: "comeback_kid",       category: .social,    title: "Comeback Kid",       description: "Return after 7+ days off",          funFact: "Getting back after a break is harder than never stopping. Respect.",      tier: .silver),
    ]

    static func find(_ id: String) -> AchievementDefinition? {
        all.first { $0.id == id }
    }
}

// MARK: - Unlocked Achievement

struct UnlockedAchievement: Codable, Identifiable {
    let id: String
    let unlockedAt: Date
    enum CodingKeys: String, CodingKey {
        case id
        case unlockedAt = "unlocked_at"
    }
}

// MARK: - Achievement Engine

struct AchievementEngine {
    static func evaluate(
        existing: Set<String>,
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
    ) -> [String] {
        var toUnlock: [String] = []
        func check(_ id: String, condition: Bool) {
            if condition && !existing.contains(id) { toUnlock.append(id) }
        }

        check("streak_3",           condition: workoutStreak >= 3)
        check("streak_7",           condition: workoutStreak >= 7)
        check("streak_30",          condition: workoutStreak >= 30)
        check("no_days_off",        condition: hasLogged30DaysAny)
        check("perfect_week",       condition: workoutStreak >= 7)
        check("weekend_warrior",    condition: weekendWorkoutsThisWeek >= 2)
        check("workouts_1",         condition: totalWorkouts >= 1)
        check("workouts_10",        condition: totalWorkouts >= 10)
        check("workouts_50",        condition: totalWorkouts >= 50)
        check("workouts_100",       condition: totalWorkouts >= 100)
        check("double_session",     condition: hasDoubleSessionDay)
        check("hour_club",          condition: longestWorkoutMinutes >= 60)
        check("grind_50_days",      condition: totalWorkouts >= 50)
        check("jack_of_all_trades", condition: categoriesThisWeek.count >= 7)
        check("cardio_king",        condition: cardioWorkouts >= 20)
        check("core_commander",     condition: coreWorkouts >= 15)
        check("strength_beast",     condition: strengthWorkouts >= 30)
        check("new_move",           condition: hasNewExercise)
        check("calories_1000",      condition: totalCaloriesBurned >= 1_000)
        check("calories_5000",      condition: totalCaloriesBurned >= 5_000)
        check("calories_10000",     condition: totalCaloriesBurned >= 10_000)
        check("marathon_miles",     condition: totalMilesCardio >= 26.2)
        check("early_bird",         condition: hasEarlyBirdWorkout)
        check("clean_plate",        condition: caloriePrecisionDays >= 3)
        check("macro_master",       condition: macroHitDays >= 1)
        check("under_budget",       condition: underBudgetDays >= 7)
        check("water_7",            condition: waterGoalDaysHit >= 7)
        check("water_30",           condition: waterGoalDaysHit >= 30)
        check("weight_first",       condition: !weightEntries.isEmpty)
        check("consistent_logger",  condition: weightLogDaysStreak >= 7)
        check("month_tracker",      condition: weightLogWeeks >= 4)
        check("data_nerd",          condition: totalWeightEntries >= 30)
        check("iron_ton",           condition: totalLiftedLbs >= 10_000)
        check("early_bird_social",  condition: hasNightOwlWorkout)
        check("lunch_break_hero",   condition: hasLunchBreakWorkout)
        check("overachiever",       condition: weeksAboveGoal >= 3)
        check("ghost_mode",         condition: hasZeroCalWorkout)
        check("creature_of_habit",  condition: hasSameWorkout5Times)
        check("comeback_kid",       condition: hadBreakBeforeReturn)

        if let last = weightEntries.last?.weightLbs,
           let target = targetWeightLbs,
           weightEntries.count >= 2 {
            check("weight_goal", condition: last <= target)
        }

        return toUnlock
    }
}
