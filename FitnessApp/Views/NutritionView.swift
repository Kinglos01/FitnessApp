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
            ZStack {
                Color.brandNavy.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        summaryCard
                        searchBar
                        quickAddSection
                        if !foods.isEmpty { resultsSection }
                        loggedFoodsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.brandNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
        .task {
            await nutritionManager.loadFromSupabase()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            nutritionManager.reloadBurnedCalories()
        }
    }

    // MARK: - Summary Card
    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Nutrition")
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(.brandCream)
                    if let tdee = nutritionManager.userTDEE {
                        Text("Base target: \(tdee + nutritionManager.goal.calorieDelta) kcal · \(nutritionManager.goal.rawValue)")
                            .font(.caption).foregroundColor(Color.brandCream.opacity(0.5))
                    }
                }
                Spacer()
                Image(systemName: nutritionManager.goal.icon)
                    .font(.system(size: 28))
                    .foregroundColor(nutritionManager.goal.color)
            }

            HStack(spacing: 24) {
                ZStack {
                    let progress = nutritionManager.totalCalories / Double(nutritionManager.calorieTarget)
                    let lapIndex = Int(progress)
                    let lapFraction = progress - Double(lapIndex)
                    let isOver = progress > 1.0
                    let currentLap = min(lapIndex, 3)
                    let currentColor = lapColor(lap: currentLap)
                    let activeFraction: Double = !isOver ? progress : (lapFraction == 0 ? 1.0 : lapFraction)

                    Circle()
                        .stroke(lapColor(lap: 0).opacity(0.15), lineWidth: 14)
                        .frame(width: 110, height: 110)

                    ForEach(0..<min(lapIndex, 4), id: \.self) { lap in
                        Circle()
                            .stroke(lapColor(lap: lap), lineWidth: 14)
                            .frame(width: 110, height: 110)
                            .id("lap-\(lap)")
                    }

                    Group {
                        if activeFraction > 0 {
                            if activeFraction >= 1.0 {
                                Circle()
                                    .stroke(currentColor, lineWidth: 14)
                                    .frame(width: 110, height: 110)
                            } else {
                                Circle()
                                    .trim(from: 0, to: activeFraction)
                                    .stroke(currentColor, style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 110, height: 110)
                            }
                        }
                    }
                    .animation(.easeOut(duration: 0.5), value: activeFraction)

                    if lapIndex >= 4 {
                        Text("×\(lapIndex + 1)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(lapColor(lap: 3))
                            .clipShape(Capsule())
                            .offset(y: 28)
                    }

                    VStack(spacing: 2) {
                        Text("\(Int(nutritionManager.totalCalories))")
                            .font(.title2).fontWeight(.bold)
                            .foregroundColor(isOver ? currentColor : .brandCream)
                        Text(isOver ? "over!" : "eaten")
                            .font(.caption2)
                            .foregroundColor(isOver ? currentColor : Color.brandCream.opacity(0.5))
                    }
                }
                .frame(width: 110, height: 110)

                VStack(alignment: .leading, spacing: 10) {
                    calorieStatRow(label: "Base target",  value: "\(nutritionManager.calorieTarget) kcal", color: .brandCream)
                    if nutritionManager.caloriesBurnedToday > 0 {
                        calorieStatRow(label: "Burned today", value: "+ \(nutritionManager.caloriesBurnedToday) kcal", color: Color(red: 0.25, green: 0.72, blue: 0.55))
                        Divider().background(Color.brandCream.opacity(0.12))
                        calorieStatRow(
                            label: "Available today",
                            value: "\(nutritionManager.calorieTarget + nutritionManager.caloriesBurnedToday) kcal",
                            color: .brandCream
                        )
                    }
                    let remaining = nutritionManager.remainingCalories
                    calorieStatRow(
                        label: remaining < 0 ? "Over budget" : "Remaining",
                        value: remaining < 0 ? "+\(abs(remaining)) kcal" : "\(remaining) kcal",
                        color: remaining < 0 ? .brandOrange : Color(red: 0.25, green: 0.72, blue: 0.55)
                    )
                }
                Spacer()
            }

            if nutritionManager.caloriesBurnedToday > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill").foregroundColor(.brandOrange).font(.caption)
                    Text("You burned \(nutritionManager.caloriesBurnedToday) kcal from today's workouts — added to your budget")
                        .font(.caption).foregroundColor(Color.brandCream.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.brandOrange.opacity(0.08))
                .cornerRadius(10)
            }

            Divider().background(Color.brandCream.opacity(0.12))

            VStack(spacing: 10) {
                macroBar(label: "Protein", current: nutritionManager.totalProtein,
                         target: Double(nutritionManager.proteinTarget), color: .brandBlue)
                macroBar(label: "Carbs",   current: nutritionManager.totalCarbs,
                         target: Double(nutritionManager.carbTarget),    color: Color(red: 0.25, green: 0.72, blue: 0.55))
                macroBar(label: "Fat",     current: nutritionManager.totalFat,
                         target: Double(nutritionManager.fatTarget),     color: .brandOrange)
            }
        }
        .padding()
        .background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
        .cornerRadius(20)
    }
    private func lapColor(lap: Int) -> Color {
        let clampedLap = min(lap, 3)
        switch nutritionManager.goal {
        case .loseWeight:
            let shades: [Color] = [
                Color(red: 1.0,  green: 0.6,  blue: 0.6),
                Color(red: 0.96, green: 0.33, blue: 0.33),
                Color(red: 0.75, green: 0.19, blue: 0.19),
                Color(red: 0.48, green: 0.08, blue: 0.08),
            ]
            return shades[clampedLap]
        case .maintain:
            let shades: [Color] = [
                Color(red: 0.36, green: 0.88, blue: 0.66),
                Color(red: 0.11, green: 0.74, blue: 0.48),
                Color(red: 0.06, green: 0.43, blue: 0.34),
                Color(red: 0.03, green: 0.31, blue: 0.25),
            ]
            return shades[clampedLap]
        case .gainMuscle:
            let shades: [Color] = [
                Color(red: 0.52, green: 0.72, blue: 0.92),
                Color(red: 0.29, green: 0.62, blue: 1.0),
                Color(red: 0.09, green: 0.37, blue: 0.65),
                Color(red: 0.05, green: 0.27, blue: 0.49),
            ]
            return shades[clampedLap]
        }
    }

    // MARK: - Search
    private var searchBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Food").font(.headline).foregroundColor(.brandCream)
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(Color.brandCream.opacity(0.4))
                TextField("", text: $searchText)
                    .placeholder(when: searchText.isEmpty) {
                        Text("Search food...").foregroundColor(Color.brandCream.opacity(0.3))
                    }
                    .foregroundColor(.brandCream)
                    .textInputAutocapitalization(.never)
                    .onSubmit { Task { await search() } }
                if isLoading { ProgressView().tint(.brandLime).scaleEffect(0.9) }
                if !searchText.isEmpty {
                    Button { searchText = ""; foods = [] } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(Color.brandCream.opacity(0.4))
                    }
                }
            }
            .padding(12)
            .background(Color.brandCream.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandCream.opacity(0.18), lineWidth: 1))
            .cornerRadius(12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(NutritionMealType.allCases, id: \.self) { type in
                        Button { selectedMealType = type } label: {
                            Label(type.rawValue, systemImage: type.icon)
                                .font(.caption).fontWeight(.semibold)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(
                                    Capsule().fill(selectedMealType == type
                                                   ? Color.brandLime.opacity(0.2) : Color.brandCream.opacity(0.06))
                                )
                                .foregroundColor(selectedMealType == type ? .brandLime : Color.brandCream.opacity(0.6))
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
                Text("Quick Add").font(.headline).foregroundColor(.brandCream)
                Spacer()
                Button("Custom") { showingQuickAddSheet = true }
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.brandLime)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(quickFoods) { item in
                        Button {
                            nutritionManager.logFood(makeFoodItem(from: item), mealType: item.mealType)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Label(item.mealType.rawValue, systemImage: item.mealType.icon)
                                    .font(.caption2).foregroundColor(Color.brandCream.opacity(0.5))
                                Text(item.name).font(.subheadline).fontWeight(.semibold).lineLimit(1)
                                    .foregroundColor(.brandCream)
                                Text("\(Int(item.calories)) kcal").font(.caption).foregroundColor(Color.brandCream.opacity(0.5))
                                HStack(spacing: 6) {
                                    Text("P:\(Int(item.protein))g").font(.caption2).foregroundColor(.brandBlue)
                                    Text("C:\(Int(item.carbs))g").font(.caption2).foregroundColor(Color(red: 0.25, green: 0.72, blue: 0.55))
                                    Text("F:\(Int(item.fat))g").font(.caption2).foregroundColor(.brandOrange)
                                }
                            }
                            .frame(width: 140, alignment: .leading)
                            .padding()
                            .background(Color.brandCream.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
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
            Text("Search Results").font(.headline).foregroundColor(.brandCream)
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

    // MARK: - Logged Foods
    private var loggedFoodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Logged Today").font(.headline).foregroundColor(.brandCream)
                Spacer()
                if !nutritionManager.loggedEntries.isEmpty {
                    Button("Clear All") { nutritionManager.clearAll() }
                        .font(.subheadline).foregroundColor(.brandOrange)
                }
            }

            if nutritionManager.loggedEntries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 42)).foregroundColor(Color.brandCream.opacity(0.2))
                    Text("No foods logged yet").foregroundColor(Color.brandCream.opacity(0.5))
                    Text("Search above or use quick add")
                        .font(.caption).foregroundColor(Color.brandCream.opacity(0.35))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 30)
                .background(Color.brandCream.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
                .cornerRadius(16)
            } else {
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
                Image(systemName: mealType.icon).foregroundColor(.brandLime).font(.subheadline)
                Text(mealType.rawValue).font(.subheadline).fontWeight(.bold).foregroundColor(.brandCream)
                Spacer()
                let total = entries.reduce(0.0) { $0 + $1.foodItem.calories }
                Text("\(Int(total)) kcal").font(.caption).foregroundColor(Color.brandCream.opacity(0.5))
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
        .background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
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

    private func calorieStatRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).font(.caption).foregroundColor(Color.brandCream.opacity(0.5))
            Spacer()
            Text(value).font(.caption).fontWeight(.semibold).foregroundColor(color)
        }
    }

    private func macroBar(label: String, current: Double, target: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption).foregroundColor(Color.brandCream.opacity(0.5))
                Spacer()
                Text("\(Int(current))g / \(Int(target))g").font(.caption).fontWeight(.semibold).foregroundColor(.brandCream)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.brandCream.opacity(0.1)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(current > target ? Color.brandOrange : color)
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
                    .foregroundColor(.brandCream)
                HStack(spacing: 10) {
                    MacroLabel(value: food.calories, label: "kcal", color: .brandOrange)
                    MacroLabel(value: food.protein,  label: "P",    color: .brandBlue)
                    MacroLabel(value: food.carbs,    label: "C",    color: Color(red: 0.25, green: 0.72, blue: 0.55))
                    MacroLabel(value: food.fat,      label: "F",    color: .brandOrange)
                }
            }
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.brandLime)
            }
        }
        .padding()
        .background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
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
                    .foregroundColor(.brandCream)
                HStack(spacing: 10) {
                    MacroLabel(value: food.calories, label: "kcal", color: .brandOrange)
                    MacroLabel(value: food.protein,  label: "P",    color: .brandBlue)
                    MacroLabel(value: food.carbs,    label: "C",    color: Color(red: 0.25, green: 0.72, blue: 0.55))
                    MacroLabel(value: food.fat,      label: "F",    color: .brandOrange)
                }
            }
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash.circle.fill").font(.title3).foregroundColor(.brandOrange)
            }
        }
        .padding()
        .background(Color.brandCream.opacity(0.04))
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
            ZStack {
                Color.brandNavy.ignoresSafeArea()
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
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Custom Food")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.brandNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.brandCream.opacity(0.6))
                }
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
                    .foregroundColor(.brandLime)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Placeholder extension
extension View {
    func placeholder<Content: View>(when shouldShow: Bool, @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: .leading) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    NutritionView()
        .environment(NutritionManager())
        .environment(AppState())
}
