import SwiftUI

//  Goal Model
enum NutritionGoal: String, CaseIterable {
    case loseWeight = "Lose Weight"
    case maintain = "Maintain"
    case gainMuscle = "Gain Muscle"

    var calorieTarget: Int {
        switch self {
        case .loseWeight: return 1800
        case .maintain: return 2300
        case .gainMuscle: return 2800
        }
    }

    var icon: String {
        switch self {
        case .loseWeight: return "arrow.down.circle.fill"
        case .maintain: return "heart.circle.fill"
        case .gainMuscle: return "bolt.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .loseWeight: return .red
        case .maintain: return .blue
        case .gainMuscle: return .green
        }
    }
}

//- Meal Type
enum NutritionMealType: String, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
    case drink = "Drink"

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "leaf.fill"
        case .drink: return "drop.fill"
        }
    }
}

// MARK: - Quick Food Template
struct QuickFoodTemplate: Identifiable {
    let id = UUID()
    let name: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let mealType: NutritionMealType
}

// - Main View
struct NutritionView: View {
    @State private var service = NutritionService()
    @State private var searchText = ""
    @State private var foods: [FoodItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingQuickAddSheet = false

    @AppStorage("nutrition_goal") private var selectedGoalRaw = NutritionGoal.maintain.rawValue

    @Environment(NutritionManager.self) var nutritionManager

    private let quickFoods: [QuickFoodTemplate] = [
        QuickFoodTemplate(name: "Protein Shake", calories: 160, protein: 25, carbs: 8, fat: 3, mealType: .drink),
        QuickFoodTemplate(name: "Grilled Chicken", calories: 165, protein: 31, carbs: 0, fat: 4, mealType: .lunch),
        QuickFoodTemplate(name: "Rice Bowl", calories: 220, protein: 4, carbs: 45, fat: 2, mealType: .lunch),
        QuickFoodTemplate(name: "Banana", calories: 105, protein: 1, carbs: 27, fat: 0, mealType: .snack),
        QuickFoodTemplate(name: "Greek Yogurt", calories: 100, protein: 10, carbs: 7, fat: 0, mealType: .breakfast),
        QuickFoodTemplate(name: "Eggs", calories: 140, protein: 10, carbs: 1, fat: 10, mealType: .breakfast)
    ]

    private var selectedGoal: NutritionGoal {
        NutritionGoal(rawValue: selectedGoalRaw) ?? .maintain
    }

    private var calorieTarget: Int {
        selectedGoal.calorieTarget
    }

    private var remainingCalories: Int {
        calorieTarget - Int(nutritionManager.totalCalories)
    }

    private var calorieProgress: Double {
        guard calorieTarget > 0 else { return 0 }
        return min(nutritionManager.totalCalories / Double(calorieTarget), 1.0)
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {

                    // Goal / summary card
                    summaryCard

                    // Goal picker
                    goalPicker

                    // Search bar
                    searchBar

                    // Quick add
                    quickAddSection

                    // Search results
                    if !foods.isEmpty {
                        resultsSection
                    }

                    // Logged foods
                    loggedFoodsSection
                }
                .padding()
            }
            .navigationTitle("Nutrition")
            .sheet(isPresented: $showingQuickAddSheet) {
                QuickAddFoodSheet { food in
                    nutritionManager.logFood(food)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // - Summary Card
    private var summaryCard: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Nutrition")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(selectedGoal.rawValue)
                        .font(.subheadline)
                        .foregroundColor(selectedGoal.color)
                }
                Spacer()
                Image(systemName: selectedGoal.icon)
                    .font(.system(size: 28))
                    .foregroundColor(selectedGoal.color)
            }

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: calorieProgress)
                    .stroke(selectedGoal.color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 120, height: 120)

                VStack(spacing: 4) {
                    Text("\(Int(nutritionManager.totalCalories))")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("kcal")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 4)

            HStack(spacing: 12) {
                nutritionStat(title: "Goal", value: "\(calorieTarget)")
                nutritionStat(title: "Left", value: "\(max(remainingCalories, 0))")
                nutritionStat(title: "Foods", value: "\(nutritionManager.loggedFoods.count)")
            }

            HStack(spacing: 10) {
                macroChip(title: "Protein", value: nutritionManager.totalProtein, color: .blue)
                macroChip(title: "Carbs", value: nutritionManager.totalCarbs, color: .green)
                macroChip(title: "Fat", value: nutritionManager.totalFat, color: .orange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
        )
    }

    // - Goal Picker
    private var goalPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Goal")
                .font(.headline)

            HStack(spacing: 10) {
                ForEach(NutritionGoal.allCases, id: \.self) { goal in
                    Button {
                        selectedGoalRaw = goal.rawValue
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: goal.icon)
                            Text(goal.rawValue)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selectedGoal == goal ? goal.color.opacity(0.18) : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(selectedGoal == goal ? goal.color : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .foregroundColor(selectedGoal == goal ? goal.color : .primary)
                }
            }
        }
    }

    // - Search Bar
    private var searchBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Search USDA Foods")
                .font(.headline)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search food...", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        Task { await search() }
                    }

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.9)
                }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        foods = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    //  Quick Add Section
    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Quick Add")
                    .font(.headline)
                Spacer()
                Button("Custom") {
                    showingQuickAddSheet = true
                }
                .font(.subheadline)
                .fontWeight(.semibold)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(quickFoods) { item in
                        Button {
                            nutritionManager.logFood(makeFoodItem(from: item))
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(2)
                                Text("\(Int(item.calories)) kcal")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(item.mealType.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 135, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // Results Section
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Search Results")
                .font(.headline)

            LazyVStack(spacing: 10) {
                ForEach(foods) { food in
                    FoodRowView(food: food) {
                        nutritionManager.logFood(food)
                        foods = []
                        searchText = ""
                    }
                }
            }
        }
    }

    // Logged Foods Section
    private var loggedFoodsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Logged Today")
                    .font(.headline)
                Spacer()
                if !nutritionManager.loggedFoods.isEmpty {
                    Button("Clear All") {
                        nutritionManager.clearAll()
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                }
            }

            if nutritionManager.loggedFoods.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 42))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("No foods logged yet")
                        .foregroundColor(.gray)
                    Text("Search above or use quick add")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color(.systemGray6))
                .cornerRadius(16)
            } else {
                ForEach(Array(nutritionManager.loggedFoods.enumerated()), id: \.element.id) { index, food in
                    LoggedFoodCard(food: food) {
                        nutritionManager.removeFood(at: IndexSet(integer: index))
                    }
                }
            }
        }
    }

    // - Search
    private func search() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            foods = try await service.searchFoods(query: trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // Manual Food Builder
    private func makeFoodItem(from template: QuickFoodTemplate) -> FoodItem {
        FoodItem(
            fdcId: Int(Date().timeIntervalSince1970 * 1000) + Int.random(in: 1...999),
            description: template.name,
            foodNutrients: [
                FoodNutrient(nutrientId: 1008, value: template.calories), // calories
                FoodNutrient(nutrientId: 1003, value: template.protein),  // protein
                FoodNutrient(nutrientId: 1005, value: template.carbs),    // carbs
                FoodNutrient(nutrientId: 1004, value: template.fat)       // fat
            ]
        )
    }
}

// Helper Views
struct FoodRowView: View {
    let food: FoodItem
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(food.description)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    MacroLabel(value: food.calories, label: "kcal", color: .orange)
                    MacroLabel(value: food.protein, label: "P", color: .blue)
                    MacroLabel(value: food.carbs, label: "C", color: .green)
                    MacroLabel(value: food.fat, label: "F", color: .red)
                }
            }

            Spacer()

            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }
}

struct LoggedFoodCard: View {
    let food: FoodItem
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(food.description)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    MacroLabel(value: food.calories, label: "kcal", color: .orange)
                    MacroLabel(value: food.protein, label: "P", color: .blue)
                    MacroLabel(value: food.carbs, label: "C", color: .green)
                    MacroLabel(value: food.fat, label: "F", color: .red)
                }
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash.circle.fill")
                    .font(.title3)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }
}

struct MacroLabel: View {
    let value: Double
    let label: String
    let color: Color

    var body: some View {
        Text("\(Int(value))\(label)")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(color)
    }
}

struct QuickAddFoodSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (FoodItem) -> Void

    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var mealType: NutritionMealType = .snack

    var body: some View {
        NavigationView {
            Form {
                Section("Food") {
                    TextField("Food name", text: $name)

                    Picker("Meal Type", selection: $mealType) {
                        ForEach(NutritionMealType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }

                Section("Nutrition") {
                    TextField("Calories", text: $calories)
                        .keyboardType(.numberPad)
                    TextField("Protein (g)", text: $protein)
                        .keyboardType(.decimalPad)
                    TextField("Carbs (g)", text: $carbs)
                        .keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $fat)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Custom Food")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !finalName.isEmpty else { return }

                        let mealPrefix = mealType.rawValue + ": "

                        let food = FoodItem(
                            fdcId: Int(Date().timeIntervalSince1970 * 1000) + Int.random(in: 1000...9999),
                            description: mealPrefix + finalName,
                            foodNutrients: [
                                FoodNutrient(nutrientId: 1008, value: Double(calories) ?? 0),
                                FoodNutrient(nutrientId: 1003, value: Double(protein) ?? 0),
                                FoodNutrient(nutrientId: 1005, value: Double(carbs) ?? 0),
                                FoodNutrient(nutrientId: 1004, value: Double(fat) ?? 0)
                            ]
                        )

                        onSave(food)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

//  Small UI Helpers
private func nutritionStat(title: String, value: String) -> some View {
    VStack(spacing: 4) {
        Text(value)
            .font(.headline)
            .fontWeight(.bold)
        Text(title)
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .background(Color.white)
    .cornerRadius(12)
}

private func macroChip(title: String, value: Double, color: Color) -> some View {
    VStack(spacing: 4) {
        Text("\(Int(value))g")
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(color)
        Text(title)
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .background(Color.white)
    .cornerRadius(12)
}

#Preview {
    NutritionView()
        .environment(NutritionManager())
}
