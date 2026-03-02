import Foundation

/// Sample data used exclusively by #Preview blocks.
/// Nothing here is referenced at runtime.
enum MockData {

    // MARK: - Exercises

    static let exercises: [Exercise] = [
        Exercise(
            bodyPart: "chest",
            equipment: "barbell",
            id: "mock-1",
            name: "Barbell Bench Press",
            target: "pectorals",
            secondaryMuscles: ["triceps", "anterior deltoids"],
            instructions: [
                "Lie flat on a bench with feet on the floor.",
                "Grip the bar slightly wider than shoulder width.",
                "Lower the bar to mid-chest, then press up."
            ],
            description: "Compound chest press using a barbell.",
            difficulty: "intermediate",
            category: "strength"
        ),
        Exercise(
            bodyPart: "back",
            equipment: "cable",
            id: "mock-2",
            name: "Seated Cable Row",
            target: "lats",
            secondaryMuscles: ["biceps", "rhomboids"],
            instructions: [
                "Sit at the cable row station with knees slightly bent.",
                "Pull the handle toward your torso, squeezing shoulder blades.",
                "Slowly return to the start position."
            ],
            description: "Horizontal pulling movement for back width.",
            difficulty: "beginner",
            category: "strength"
        ),
        Exercise(
            bodyPart: "upper legs",
            equipment: "barbell",
            id: "mock-3",
            name: "Barbell Squat",
            target: "quadriceps",
            secondaryMuscles: ["glutes", "hamstrings", "core"],
            instructions: [
                "Place the barbell across your upper back.",
                "Squat down until thighs are parallel to the floor.",
                "Drive through your heels to stand back up."
            ],
            description: "Fundamental lower-body compound lift.",
            difficulty: "intermediate",
            category: "strength"
        ),
        Exercise(
            bodyPart: "upper arms",
            equipment: "dumbbell",
            id: "mock-4",
            name: "Dumbbell Bicep Curl",
            target: "biceps",
            secondaryMuscles: ["forearms"],
            instructions: [
                "Stand with a dumbbell in each hand, arms at your sides.",
                "Curl the weights up while keeping elbows pinned.",
                "Lower under control."
            ],
            description: "Isolation exercise for the biceps.",
            difficulty: "beginner",
            category: "strength"
        ),
        Exercise(
            bodyPart: "waist",
            equipment: "body weight",
            id: "mock-5",
            name: "Hanging Leg Raise",
            target: "abs",
            secondaryMuscles: ["hip flexors"],
            instructions: [
                "Hang from a pull-up bar with straight arms.",
                "Raise your legs until they are parallel to the floor.",
                "Lower slowly without swinging."
            ],
            description: "Advanced core exercise using body weight.",
            difficulty: "advanced",
            category: "strength"
        ),
        Exercise(
            bodyPart: "shoulders",
            equipment: "dumbbell",
            id: "mock-6",
            name: "Dumbbell Shoulder Press",
            target: "deltoids",
            secondaryMuscles: ["triceps", "upper chest"],
            instructions: [
                "Sit on a bench with back support.",
                "Press dumbbells overhead until arms are extended.",
                "Lower to shoulder height and repeat."
            ],
            description: "Overhead pressing movement for shoulders.",
            difficulty: "intermediate",
            category: "strength"
        )
    ]

    // MARK: - Food Items

    static let foodItems: [FoodItem] = [
        FoodItem(
            fdcId: 90001,
            description: "Grilled Chicken Breast",
            foodNutrients: [
                FoodNutrient(nutrientId: 1008, value: 165),   // calories
                FoodNutrient(nutrientId: 1003, value: 31),    // protein
                FoodNutrient(nutrientId: 1005, value: 0),     // carbs
                FoodNutrient(nutrientId: 1004, value: 3.6)    // fat
            ]
        ),
        FoodItem(
            fdcId: 90002,
            description: "Brown Rice (1 cup cooked)",
            foodNutrients: [
                FoodNutrient(nutrientId: 1008, value: 216),
                FoodNutrient(nutrientId: 1003, value: 5),
                FoodNutrient(nutrientId: 1005, value: 45),
                FoodNutrient(nutrientId: 1004, value: 1.8)
            ]
        ),
        FoodItem(
            fdcId: 90003,
            description: "Banana (medium)",
            foodNutrients: [
                FoodNutrient(nutrientId: 1008, value: 105),
                FoodNutrient(nutrientId: 1003, value: 1.3),
                FoodNutrient(nutrientId: 1005, value: 27),
                FoodNutrient(nutrientId: 1004, value: 0.4)
            ]
        )
    ]

    // MARK: - Pre-populated NutritionManager

    static var populatedNutritionManager: NutritionManager {
        let manager = NutritionManager()
        for food in foodItems {
            manager.logFood(food)
        }
        return manager
    }
}
