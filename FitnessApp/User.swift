import Foundation

struct User: Codable, Identifiable {
    var id: String
    var email: String
    var name: String
    var weight: Double    // stored in lbs
    var height: Double    // stored in total inches
    var birthDate: Date
    var gender: String
    var activityLevel: String = "Moderately Active"
    var primaryGoal: String = "Lose Weight"
    var calorieGoal: Int = 2200
    var targetWeightLbs: Double? = nil
    var customCaloriesEnabled: Bool = false
    var units: String = "Imperial"

    // MARK: - Computed Getters

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }

    var weightLbs: Double {
        weight
    }

    var weightKg: Double {
        weight * 0.453592
    }

    var heightInches: Int {
        Int(height) % 12
    }

    var heightFeet: Int {
        Int(height) / 12
    }

    var heightCm: Double {
        height * 2.54
    }

    // MARK: - BMR (Mifflin-St Jeor Equation)
    // Males:   BMR = 10 × kg + 6.25 × cm - 5 × age + 5
    // Females: BMR = 10 × kg + 6.25 × cm - 5 × age - 161
    // Other/Prefer Not To Say: average of both

    var bmr: Double {
        let kg = weightKg
        let cm = heightCm
        let a  = Double(age)

        switch gender.lowercased() {
        case "male":
            return (10 * kg) + (6.25 * cm) - (5 * a) + 5
        case "female":
            return (10 * kg) + (6.25 * cm) - (5 * a) - 161
        default:
            let male   = (10 * kg) + (6.25 * cm) - (5 * a) + 5
            let female = (10 * kg) + (6.25 * cm) - (5 * a) - 161
            return (male + female) / 2
        }
    }

    // MARK: - Calorie Burn Calculator
    // Uses MET formula: Calories = MET × weightKg × durationHours
    // This is what the CardioCalorieCalculator will call directly on the User

    func caloriesBurned(met: Double, durationMinutes: Int) -> Int {
        let hours = Double(durationMinutes) / 60.0
        return max(0, Int((met * weightKg * hours).rounded()))
    }

    func caloriesBurnedByDistance(met: Double, speedMph: Double, distanceMiles: Double) -> Int {
        let hours = distanceMiles / speedMph
        return max(0, Int((met * weightKg * hours).rounded()))
    }

    func estimatedDurationMinutes(distanceMiles: Double, speedMph: Double) -> Int {
        max(1, Int(((distanceMiles / speedMph) * 60).rounded()))
    }
}
