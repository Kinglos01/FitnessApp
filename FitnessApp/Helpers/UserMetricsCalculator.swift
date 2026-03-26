//
//  UserMetricsCalculator.swift
//  FitnessApp
//

import Foundation

struct UserMetricsCalculator {

    // MARK: - BMI
    // Formula: (weight in lbs / height in inches²) × 703
    static func bmi(weightLbs: Double, heightInches: Double) -> Double {
        guard heightInches > 0 else { return 0 }
        return (weightLbs / (heightInches * heightInches)) * 703
    }

    static func bmiCategory(bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }

    static func bmiColor(bmi: Double) -> String {
        // Returns a string color name to be converted in SwiftUI
        switch bmi {
        case ..<18.5: return "blue"
        case 18.5..<25: return "green"
        case 25..<30: return "orange"
        default: return "red"
        }
    }

    // MARK: - Activity Multiplier
    // Standard TDEE activity multipliers
    static func activityMultiplier(for activityLevel: String) -> Double {
        switch activityLevel {
        case "Sedentary":           return 1.2
        case "Lightly Active":      return 1.375
        case "Moderately Active":   return 1.55
        case "Very Active":         return 1.725
        case "Athlete":             return 1.9
        default:                    return 1.55
        }
    }

    // MARK: - TDEE
    // TDEE = BMR × activity multiplier
    // BMR is already computed on the User model (Mifflin-St Jeor)
    static func tdee(bmr: Double, activityLevel: String) -> Double {
        return bmr * activityMultiplier(for: activityLevel)
    }

    // MARK: - Recommended Calorie Goal
    // Adjusts TDEE based on primary goal:
    // Lose Weight:        TDEE - 500  (safe ~1 lb/week deficit)
    // Maintain Weight:    TDEE
    // Build Muscle:       TDEE + 300  (lean bulk surplus)
    // Improve Endurance:  TDEE + 100  (slight surplus for performance)
    static func recommendedCalorieGoal(bmr: Double, activityLevel: String, primaryGoal: String) -> Int {
        let tdee = tdee(bmr: bmr, activityLevel: activityLevel)
        let adjustment: Double
        switch primaryGoal {
        case "Lose Weight":         adjustment = -500
        case "Maintain Weight":     adjustment = 0
        case "Build Muscle":        adjustment = 300
        case "Improve Endurance":   adjustment = 100
        default:                    adjustment = 0
        }
        // Clamp between 1200 and 5000 for safety
        return min(5000, max(1200, Int((tdee + adjustment).rounded())))
    }

    // MARK: - Macro Targets
    // Returns (protein grams, carbs grams, fat grams) based on goal and calorie goal
    // Protein: 0.8g per lb of bodyweight (standard recommendation)
    // Fat: 25% of calories / 9 cal per gram
    // Carbs: remaining calories / 4 cal per gram
    static func macroTargets(weightLbs: Double, calorieGoal: Int, primaryGoal: String) -> (protein: Int, carbs: Int, fat: Int) {
        let protein = Int((weightLbs * 0.8).rounded())
        let fatCalories = Double(calorieGoal) * 0.25
        let fat = Int((fatCalories / 9).rounded())
        let proteinCalories = Double(protein) * 4
        let carbCalories = Double(calorieGoal) - proteinCalories - fatCalories
        let carbs = max(0, Int((carbCalories / 4).rounded()))
        return (protein, carbs, fat)
    }

    // MARK: - Convenience: full recommendation from User
    static func recommendation(for user: User) -> (calories: Int, protein: Int, carbs: Int, fat: Int, bmi: Double, bmiCategory: String) {
        let calories = recommendedCalorieGoal(
            bmr: user.bmr,
            activityLevel: user.activityLevel,
            primaryGoal: user.primaryGoal
        )
        let macros = macroTargets(
            weightLbs: user.weightLbs,
            calorieGoal: calories,
            primaryGoal: user.primaryGoal
        )
        let bmiValue = bmi(weightLbs: user.weightLbs, heightInches: user.height)
        return (calories, macros.protein, macros.carbs, macros.fat, bmiValue, bmiCategory(bmi: bmiValue))
    }
}
