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
                .init(id: "streak_3",           category: .streak,    title: "Spark",             description: "3 days in a row",                      funFact: "It takes an average of 66 days to form a new habit, but the brain starts building neural pathways after just 3 consecutive days.",         tier: .bronze),
                .init(id: "streak_7",           category: .streak,    title: "On Fire",            description: "7 days in a row",                      funFact: "People who exercise consistently for 7 days in a row are 40% more likely to keep going for the rest of the month.",                        tier: .silver),
                .init(id: "streak_30",          category: .streak,    title: "Unstoppable",        description: "30 days in a row",                     funFact: "After 30 days of consistent exercise, the brain physically rewires itself and begins to crave the activity.",                               tier: .gold),
                .init(id: "no_days_off",        category: .streak,    title: "No Days Off",        description: "Log every day for a month",            funFact: "Elite athletes often train 350 or more days per year using careful load management to avoid injury.",                                       tier: .gold),
                .init(id: "perfect_week",       category: .streak,    title: "Perfect Week",       description: "All 7 days in a week",                 funFact: "Less than 5% of gym members worldwide ever complete a full 7 day training week.",                                                          tier: .gold),
                .init(id: "weekend_warrior",    category: .streak,    title: "Weekend Warrior",    description: "Work out Saturday and Sunday",         funFact: "Research shows people who exercise just 1 to 2 days a week still reduce their risk of heart disease by up to 40%.",                        tier: .silver),

                // WORKOUTS
                .init(id: "workouts_1",         category: .workouts,  title: "First Rep",          description: "Complete your first workout",          funFact: "Your body starts producing more mitochondria after just a single workout session, immediately improving energy production.",                tier: .bronze),
                .init(id: "workouts_10",        category: .workouts,  title: "Getting Serious",    description: "Complete 10 workouts",                 funFact: "After 10 workouts, your muscles have already increased their capillary density to deliver more oxygen to working tissue.",                 tier: .bronze),
                .init(id: "workouts_50",        category: .workouts,  title: "Half Century",       description: "Complete 50 workouts",                 funFact: "50 workouts is roughly 50 hours of training, the same amount elite athletes typically log in just two weeks.",                             tier: .silver),
                .init(id: "workouts_100",       category: .workouts,  title: "Centurion",          description: "Complete 100 workouts",                funFact: "Scientists estimate it takes around 100 hours of deliberate practice to become noticeably competent at any physical skill.",               tier: .gold),
                .init(id: "double_session",     category: .workouts,  title: "Double Session",     description: "Log 2 workouts in one day",            funFact: "Two-a-day training was originally developed by the US military in the 1960s to maximize fitness gains in the shortest possible time.",     tier: .silver),
                .init(id: "hour_club",          category: .workouts,  title: "Hour Club",          description: "Log a 60 minute workout",              funFact: "A 60-minute moderate intensity workout burns enough calories to offset a full meal for the average adult.",                                tier: .silver),
                .init(id: "grind_50_days",      category: .workouts,  title: "The Grind",          description: "50 total workout days",                funFact: "People who reach 50 workout days are statistically 3 times more likely to stay active for the remainder of the year.",                    tier: .silver),

                // VARIETY
                .init(id: "jack_of_all_trades", category: .variety,   title: "Jack of All Trades", description: "Try all 7 categories in a week",      funFact: "Cross-training across multiple disciplines reduces injury risk by up to 50% compared to single sport training.",                            tier: .gold),
                .init(id: "cardio_king",        category: .variety,   title: "Cardio King",        description: "Complete 20 cardio workouts",          funFact: "Just 20 minutes of cardio triggers the release of BDNF, a protein that stimulates the growth of new brain cells.",                        tier: .silver),
                .init(id: "core_commander",     category: .variety,   title: "Core Commander",     description: "Complete 15 core workouts",            funFact: "The human core contains over 35 individual muscles. Most people only train 4 or 5 of them in a typical workout.",                         tier: .silver),
                .init(id: "strength_beast",     category: .variety,   title: "Strength Beast",     description: "Complete 30 strength workouts",        funFact: "Muscle tissue burns approximately 3 times more calories at rest than fat tissue, even when the body is completely inactive.",             tier: .gold),
                .init(id: "new_move",           category: .variety,   title: "New Move",           description: "Log an exercise you have never done",  funFact: "Learning a new physical movement activates the cerebellum and prefrontal cortex simultaneously, which boosts overall brain plasticity.",   tier: .bronze),

                // CALORIES
                .init(id: "calories_1000",      category: .calories,  title: "Spark Plug",         description: "Burn 1,000 total calories",            funFact: "Burning 1,000 calories through exercise is the rough energy equivalent of walking 10 miles at a steady pace.",                            tier: .bronze),
                .init(id: "calories_5000",      category: .calories,  title: "Inferno",            description: "Burn 5,000 total calories",            funFact: "5,000 calories is approximately the energy cost of running a full marathon from start to finish.",                                         tier: .silver),
                .init(id: "calories_10000",     category: .calories,  title: "Furnace",            description: "Burn 10,000 total calories",           funFact: "10,000 calories is roughly the total energy stored in 3 pounds of body fat.",                                                             tier: .gold),
                .init(id: "marathon_miles",     category: .calories,  title: "Marathon Man",       description: "Log 26 or more miles of cardio",       funFact: "The marathon distance of 26.2 miles was standardized at the 1908 London Olympics so the race would finish in front of the royal box.",    tier: .gold),
                .init(id: "early_bird",         category: .calories,  title: "Early Bird",         description: "Log a workout before 7am",             funFact: "Morning exercisers fall asleep faster and get up to 25% more deep sleep per night compared to people who exercise in the evening.",        tier: .bronze),

                // NUTRITION
                .init(id: "clean_plate",        category: .nutrition, title: "Clean Plate",        description: "Hit calorie goal within 50 kcal, 3 days", funFact: "Hitting a calorie target within 50 kcal requires the same level of dietary precision that registered dietitians spend years developing.", tier: .silver),
                .init(id: "macro_master",       category: .nutrition, title: "Macro Master",       description: "Hit all 3 macros in one day",          funFact: "Protein, carbohydrates, and fats each trigger completely different hormonal responses that regulate hunger, energy, and muscle recovery.",  tier: .gold),
                .init(id: "under_budget",       category: .nutrition, title: "Under Budget",       description: "Stay under calorie goal 7 days",       funFact: "A sustained 7-day calorie deficit is the point at which the body begins preferentially burning stored fat as its primary fuel source.",     tier: .silver),

                // WATER
                .init(id: "water_7",            category: .water,     title: "Stay Hydrated",      description: "Hit water goal 7 days",                funFact: "Even mild dehydration of just 1 to 2 percent of body weight can reduce physical and cognitive performance by up to 10 percent.",          tier: .bronze),
                .init(id: "water_30",           category: .water,     title: "Flood Gates",        description: "Hit water goal 30 days",               funFact: "Drinking adequate water consistently for 30 days has been shown to improve skin elasticity and kidney filtration efficiency.",              tier: .gold),

                // WEIGHT
                .init(id: "weight_first",       category: .weight,    title: "On The Scale",       description: "Log your first weight",                funFact: "Body weight can fluctuate by up to 5 pounds in a single day due to water retention, food volume, and sodium intake alone.",               tier: .bronze),
                .init(id: "consistent_logger",  category: .weight,    title: "Consistent Logger",  description: "Log weight 7 days in a row",           funFact: "Daily weigh-ins reduce overall weight gain by an average of 1.7% more than weekly weigh-ins, according to Cornell University research.",  tier: .bronze),
                .init(id: "month_tracker",      category: .weight,    title: "Month Tracker",      description: "Log weight every week for a month",    funFact: "Four weeks of weight data provides enough statistical points to calculate a meaningful trend line and filter out daily noise.",            tier: .silver),
                .init(id: "data_nerd",          category: .weight,    title: "Data Nerd",          description: "Have 30 or more weight entries",       funFact: "With 30 data points, a weight trend becomes statistically significant with a confidence interval exceeding 95 percent.",                  tier: .gold),
                .init(id: "weight_goal",        category: .weight,    title: "Goal Crusher",       description: "Reach your target weight",             funFact: "Only about 20% of people who set a weight loss or gain goal ever actually reach it, making this one of the rarest achievements in fitness.", tier: .gold),

                // VOLUME
                .init(id: "iron_ton",           category: .volume,    title: "Iron Ton",           description: "Lift 10,000 lbs total",                funFact: "10,000 pounds is heavier than a fully loaded school bus, which weighs approximately 9,000 pounds when packed with passengers.",           tier: .gold),

                // MILESTONES
                .init(id: "early_bird_social",  category: .social,    title: "Night Owl",          description: "Log a workout after 9pm",              funFact: "Core body temperature peaks between 4pm and 7pm, which is why measurable strength output is consistently higher in the evening hours.",   tier: .bronze),
                .init(id: "lunch_break_hero",   category: .social,    title: "Lunch Break Hero",   description: "Work out between 12 and 2pm",          funFact: "Midday exercise has been shown to improve afternoon cognitive performance and sustained focus by up to 20% in office-based workers.",     tier: .bronze),
                .init(id: "overachiever",       category: .social,    title: "Overachiever",       description: "Beat weekly goal 3 weeks running",     funFact: "Consistently exceeding fitness goals is linked to higher baseline dopamine levels, which improves both mood and long-term motivation.",   tier: .gold),
                .init(id: "ghost_mode",         category: .social,    title: "Ghost Mode",         description: "Log a workout with 0 calories",        funFact: "Active recovery sessions like stretching and mobility work reduce delayed onset muscle soreness by up to 30% compared to full rest.",     tier: .bronze),
                .init(id: "creature_of_habit",  category: .social,    title: "Creature of Habit",  description: "Log the same workout 5 times",         funFact: "Repeating the same exercise pattern 5 times encodes the movement into procedural memory, making the motion feel fully automatic.",       tier: .silver),
                .init(id: "comeback_kid",       category: .social,    title: "Comeback Kid",       description: "Return after 7 or more days off",      funFact: "Muscle memory allows returning athletes to regain lost strength up to 3 times faster than the original time it took to build it.",      tier: .silver),
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
