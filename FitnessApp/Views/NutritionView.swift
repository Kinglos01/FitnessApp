import SwiftUI

// MARK: - Meal Type
enum NutritionMealType: String, CaseIterable, Codable {
    case breakfast = "Breakfast"
    case lunch     = "Lunch"
    case dinner    = "Dinner"
    case snack     = "Snack"
    case drink     = "Drink"

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch:     return "sun.max.fill"
        case .dinner:    return "moon.stars.fill"
        case .snack:     return "leaf.fill"
        case .drink:     return "drop.fill"
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

// MARK: - Main View
struct NutritionView: View {
    @Environment(NutritionManager.self) var nutritionManager
    @Environment(AppState.self) var appState

    @State private var service = NutritionService()
    @State private var searchText = ""
    @State private var foods: [FoodItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingQuickAddSheet = false
    @State private var selectedMealType: NutritionMealType = .snack
    @State private var showingActivityPicker = false

    private let quickFoods: [QuickFoodTemplate] = [
        QuickFoodTemplate(name: "Protein Shake",    calories: 160, protein: 25, carbs: 8,  fat: 3,  mealType: .drink),
        QuickFoodTemplate(name: "Grilled Chicken",  calories: 165, protein: 31, carbs: 0,  fat: 4,  mealType: .lunch),
        QuickFoodTemplate(name: "Rice Bowl",        calories: 220, protein: 4,  carbs: 45, fat: 2,  mealType: .lunch),
        QuickFoodTemplate(name: "Banana",           calories: 105, protein: 1,  carbs: 27, fat: 0,  mealType: .snack),
        QuickFoodTemplate(name: "Greek Yogurt",     calories: 100, protein: 10, carbs: 7,  fat: 0,  mealType: .breakfast),
        QuickFoodTemplate(name: "Eggs",             calories: 140, protein: 10, carbs: 1,  fat: 10, mealType: .breakfast)
    ]

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    summaryCard
                    activityAndGoalSection
                    searchBar
                    quickAddSection
                    if !foods.isEmpty { resultsSection }
                    loggedFoodsSection
                }
                .padding()
            }
            .navigationTitle("Nutrition")
            .sheet(isPresented: $showingQuickAddSheet) {
                QuickAddFoodSheet(selectedMealType: selectedMealType) { food, mealType in
                    nutritionManager.logFood(food, mealType: mealType)
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
        .onAppear {
            nutritionManager.configure(
                userId: appState.currentUser?.id ?? "guest",
                user: appState.currentUser
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            nutritionManager.reloadBurnedCalories()
        }
    }

    // MARK: - Summary Card
    private var summaryCard: some View {
        VStack(spacing: 16) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Nutrition")
                        .font(.title2).fontWeight(.bold)
                    if let tdee = nutritionManager.userTDEE {
                        Text("Base target: \(tdee + nutritionManager.goal.calorieDelta) kcal · \(nutritionManager.goal.rawValue)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: nutritionManager.goal.icon)
                    .font(.system(size: 28))
                    .foregroundColor(nutritionManager.goal.color)
            }

            // Calorie ring
            HStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.15), lineWidth: 14)
                        .frame(width: 110, height: 110)
                    Circle()
                        .trim(from: 0, to: min(nutritionManager.totalCalories / Double(nutritionManager.calorieTarget), 1.0))
                        .stroke(nutritionManager.goal.color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 110, height: 110)
                        .animation(.easeOut(duration: 0.5), value: nutritionManager.totalCalories)
                    VStack(spacing: 2) {
                        Text("\(Int(nutritionManager.totalCalories))")
                            .font(.title2).fontWeight(.bold)
                        Text("eaten").font(.caption2).foregroundColor(.gray)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    calorieStatRow(label: "Base target",  value: "\(nutritionManager.calorieTarget) kcal", color: .primary)
                    if nutritionManager.caloriesBurnedToday > 0 {
                        calorieStatRow(label: "Burned today", value: "+ \(nutritionManager.caloriesBurnedToday) kcal", color: .green)
                        Divider()
                        calorieStatRow(
                            label: "Available today",
                            value: "\(nutritionManager.calorieTarget + nutritionManager.caloriesBurnedToday) kcal",
                            color: .primary
                        )
                    }
                    calorieStatRow(
                        label: "Remaining",
                        value: "\(max(nutritionManager.remainingCalories, 0)) kcal",
                        color: nutritionManager.remainingCalories < 0 ? .red : .green
                    )
                }
                Spacer()
            }

            // Burned calories banner (only shown if workouts logged)
            if nutritionManager.caloriesBurnedToday > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill").foregroundColor(.orange).font(.caption)
                    Text("You burned \(nutritionManager.caloriesBurnedToday) kcal from today's workouts — added to your budget")
                        .font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(10)
            }

            Divider()

            // Macro progress bars
            VStack(spacing: 10) {
                macroBar(label: "Protein", current: nutritionManager.totalProtein,
                         target: Double(nutritionManager.proteinTarget), color: .blue)
                macroBar(label: "Carbs",   current: nutritionManager.totalCarbs,
                         target: Double(nutritionManager.carbTarget),    color: .green)
                macroBar(label: "Fat",     current: nutritionManager.totalFat,
                         target: Double(nutritionManager.fatTarget),     color: .orange)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemGray6)))
    }

    // MARK: - Goal Picker
    private var activityAndGoalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Goal").font(.headline)
            Text("To permanently change your nutrition goals, go to settings.")
                .font(.caption)
                .foregroundColor(Color(.systemGray))
                .padding(.top, 4)
                .padding(.bottom, 2)
            
            
            HStack(spacing: 10) {
                ForEach(NutritionGoal.allCases, id: \.self) { g in
                    Button { nutritionManager.setGoal(g) } label: {
                        VStack(spacing: 6) {
                            Image(systemName: g.icon).font(.system(size: 18))
                            Text(g.rawValue).font(.caption).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(nutritionManager.goal == g ? g.color.opacity(0.18) : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(nutritionManager.goal == g ? g.color : Color.clear, lineWidth: 1.5)
                        )
                        .foregroundColor(nutritionManager.goal == g ? g.color : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemGray6)))
    }

    // MARK: - Search
    private var searchBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Search USDA Foods").font(.headline)
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Search food...", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .onSubmit { Task { await search() } }
                if isLoading { ProgressView().scaleEffect(0.9) }
                if !searchText.isEmpty {
                    Button { searchText = ""; foods = [] } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Meal type selector for search results
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(NutritionMealType.allCases, id: \.self) { type in
                        Button { selectedMealType = type } label: {
                            Label(type.rawValue, systemImage: type.icon)
                                .font(.caption).fontWeight(.semibold)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(
                                    Capsule().fill(selectedMealType == type
                                                   ? Color.orange.opacity(0.2) : Color(.systemGray5))
                                )
                                .foregroundColor(selectedMealType == type ? .orange : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Quick Add
    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Quick Add").font(.headline)
                Spacer()
                Button("Custom") { showingQuickAddSheet = true }
                    .font(.subheadline).fontWeight(.semibold)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(quickFoods) { item in
                        Button {
                            nutritionManager.logFood(makeFoodItem(from: item), mealType: item.mealType)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Label(item.mealType.rawValue, systemImage: item.mealType.icon)
                                    .font(.caption2).foregroundColor(.secondary)
                                Text(item.name).font(.subheadline).fontWeight(.semibold).lineLimit(1)
                                Text("\(Int(item.calories)) kcal").font(.caption).foregroundColor(.secondary)
                                HStack(spacing: 6) {
                                    Text("P:\(Int(item.protein))g").font(.caption2).foregroundColor(.blue)
                                    Text("C:\(Int(item.carbs))g").font(.caption2).foregroundColor(.green)
                                    Text("F:\(Int(item.fat))g").font(.caption2).foregroundColor(.orange)
                                }
                            }
                            .frame(width: 140, alignment: .leading)
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

    // MARK: - Search Results
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Search Results").font(.headline)
            LazyVStack(spacing: 10) {
                ForEach(foods) { food in
                    FoodRowView(food: food) {
                        nutritionManager.logFood(food, mealType: selectedMealType)
                        foods = []
                        searchText = ""
                    }
                }
            }
        }
    }

    // MARK: - Logged Foods (grouped by meal type)
    private var loggedFoodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Logged Today").font(.headline)
                Spacer()
                if !nutritionManager.loggedEntries.isEmpty {
                    Button("Clear All") { nutritionManager.clearAll() }
                        .font(.subheadline).foregroundColor(.red)
                }
            }

            if nutritionManager.loggedEntries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 42)).foregroundColor(.gray.opacity(0.4))
                    Text("No foods logged yet").foregroundColor(.gray)
                    Text("Search above or use quick add")
                        .font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 30)
                .background(Color(.systemGray6)).cornerRadius(16)
            } else {
                // Group by meal type
                ForEach(NutritionMealType.allCases, id: \.self) { mealType in
                    let entries = nutritionManager.loggedEntries.filter { $0.mealType == mealType }
                    if !entries.isEmpty {
                        mealSection(mealType: mealType, entries: entries)
                    }
                }
            }
        }
    }

    private func mealSection(mealType: NutritionMealType, entries: [LoggedFoodEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: mealType.icon).foregroundColor(.orange).font(.subheadline)
                Text(mealType.rawValue).font(.subheadline).fontWeight(.bold)
                Spacer()
                let total = entries.reduce(0.0) { $0 + $1.foodItem.calories }
                Text("\(Int(total)) kcal").font(.caption).foregroundColor(.secondary)
            }
            ForEach(entries) { entry in
                LoggedFoodCard(food: entry.foodItem) {
                    if let idx = nutritionManager.loggedEntries.firstIndex(where: { $0.id == entry.id }) {
                        nutritionManager.removeEntry(at: IndexSet(integer: idx))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    // MARK: - Helpers
    private func search() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true; errorMessage = nil
        do { foods = try await service.searchFoods(query: trimmed) }
        catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    private func makeFoodItem(from template: QuickFoodTemplate) -> FoodItem {
        FoodItem(
            fdcId: Int(Date().timeIntervalSince1970 * 1000) + Int.random(in: 1...999),
            description: template.name,
            foodNutrients: [
                FoodNutrient(nutrientId: 1008, value: template.calories),
                FoodNutrient(nutrientId: 1003, value: template.protein),
                FoodNutrient(nutrientId: 1005, value: template.carbs),
                FoodNutrient(nutrientId: 1004, value: template.fat)
            ]
        )
    }

    // MARK: - Sub-views
    private func calorieStatRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.caption).fontWeight(.semibold).foregroundColor(color)
        }
    }

    private func macroBar(label: String, current: Double, target: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("\(Int(current))g / \(Int(target))g").font(.caption).fontWeight(.semibold)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(current > target ? Color.red : color)
                        .frame(width: geo.size.width * min(target > 0 ? current / target : 0, 1.0), height: 6)
                        .animation(.easeOut(duration: 0.4), value: current)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Helper Views
struct FoodRowView: View {
    let food: FoodItem
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(food.description).font(.subheadline).fontWeight(.semibold).lineLimit(2)
                HStack(spacing: 10) {
                    MacroLabel(value: food.calories, label: "kcal", color: .orange)
                    MacroLabel(value: food.protein,  label: "P",    color: .blue)
                    MacroLabel(value: food.carbs,    label: "C",    color: .green)
                    MacroLabel(value: food.fat,      label: "F",    color: .red)
                }
            }
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.orange)
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
                Text(food.description).font(.subheadline).fontWeight(.semibold).lineLimit(2)
                HStack(spacing: 10) {
                    MacroLabel(value: food.calories, label: "kcal", color: .orange)
                    MacroLabel(value: food.protein,  label: "P",    color: .blue)
                    MacroLabel(value: food.carbs,    label: "C",    color: .green)
                    MacroLabel(value: food.fat,      label: "F",    color: .red)
                }
            }
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash.circle.fill").font(.title3).foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct MacroLabel: View {
    let value: Double
    let label: String
    let color: Color

    var body: some View {
        Text("\(Int(value))\(label)")
            .font(.caption).fontWeight(.semibold).foregroundColor(color)
    }
}

struct QuickAddFoodSheet: View {
    @Environment(\.dismiss) private var dismiss
    var selectedMealType: NutritionMealType
    let onSave: (FoodItem, NutritionMealType) -> Void

    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var mealType: NutritionMealType = .snack

    init(selectedMealType: NutritionMealType = .snack, onSave: @escaping (FoodItem, NutritionMealType) -> Void) {
        self.selectedMealType = selectedMealType
        self.onSave = onSave
        _mealType = State(initialValue: selectedMealType)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Food") {
                    TextField("Food name", text: $name)
                    Picker("Meal Type", selection: $mealType) {
                        ForEach(NutritionMealType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                }
                Section("Nutrition") {
                    TextField("Calories",    text: $calories).keyboardType(.numberPad)
                    TextField("Protein (g)", text: $protein).keyboardType(.decimalPad)
                    TextField("Carbs (g)",   text: $carbs).keyboardType(.decimalPad)
                    TextField("Fat (g)",     text: $fat).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Custom Food")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !finalName.isEmpty else { return }
                        let food = FoodItem(
                            fdcId: Int(Date().timeIntervalSince1970 * 1000) + Int.random(in: 1000...9999),
                            description: finalName,
                            foodNutrients: [
                                FoodNutrient(nutrientId: 1008, value: Double(calories) ?? 0),
                                FoodNutrient(nutrientId: 1003, value: Double(protein) ?? 0),
                                FoodNutrient(nutrientId: 1005, value: Double(carbs) ?? 0),
                                FoodNutrient(nutrientId: 1004, value: Double(fat) ?? 0)
                            ]
                        )
                        onSave(food, mealType)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NutritionView()
        .environment(NutritionManager())
        .environment(AppState())
}
