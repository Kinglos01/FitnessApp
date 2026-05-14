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
    @State private var selectedMealType: NutritionMealType = .breakfast
    @State private var customFoods: [CustomFoodRecord] = []
    @State private var topFoods: [CustomFoodRecord] = []
    @State private var selectedFood: FoodItem? = nil
    @State private var showAllCustomFoods = false
    @State private var deleteTarget: CustomFoodRecord? = nil
    @State private var deletePopupVisible: Bool = false

    private var permanentFoods: [CustomFoodRecord] { customFoods.filter { !$0.isTemporary } }
    private var temporaryFoods: [CustomFoodRecord] { customFoods.filter { $0.isTemporary } }
    private var visibleCustomFoods: [CustomFoodRecord] {
        let all = permanentFoods + temporaryFoods
        return showAllCustomFoods ? all : Array(all.prefix(6))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.brandNavy.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        summaryCard
                        searchSection       // search bar + results inline
                        quickAddSection
                        customFoodsSection
                        loggedFoodsSection
                    }
                    .padding()
                }

                // MARK: - Delete Popup Overlay
                if deletePopupVisible, let record = deleteTarget {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) {
                                deletePopupVisible = false
                                deleteTarget = nil
                            }
                        }
                        .zIndex(98)

                    VStack(spacing: 16) {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.brandOrange)

                        Text("Delete Food")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.brandCream)

                        Text("Permanently delete \"\(record.foodName)\"?\nThis cannot be undone.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.brandCream.opacity(0.6))
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    deletePopupVisible = false
                                    deleteTarget = nil
                                }
                            } label: {
                                Text("Cancel")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.brandCream)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.brandCream.opacity(0.1))
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)

                            Button {
                                Task {
                                    try? await CustomFoodService.shared.deleteCustomFood(id: record.id)
                                    loadFoods()
                                }
                                withAnimation(.easeOut(duration: 0.2)) {
                                    deletePopupVisible = false
                                    deleteTarget = nil
                                }
                            } label: {
                                Text("Delete")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(24)
                    .background(Color.brandNavy)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.5), radius: 24)
                    .padding(.horizontal, 32)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .zIndex(99)
                }
            }
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.brandNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showingQuickAddSheet, onDismiss: { loadFoods() }) {
                SaveCustomFoodSheet(selectedMealType: selectedMealType) { food, mealType, isTemporary in
                    nutritionManager.logFood(food, mealType: mealType)
                    let uid = appState.currentUser?.id ?? ""
                    guard !uid.isEmpty else { return }
                    Task {
                        try? await CustomFoodService.shared.insertCustomFood(
                            userId: uid,
                            name: food.description,
                            calories: food.calories,
                            protein: food.protein,
                            carbs: food.carbs,
                            fat: food.fat,
                            mealType: mealType.rawValue,
                            isTemporary: isTemporary
                        )
                        loadFoods()
                    }
                }
            }
            .sheet(item: $selectedFood) { food in
                FoodDetailSheet(food: food, mealType: selectedMealType) { confirmedFood, qty in
                    let multiplied = FoodItem(
                        fdcId: confirmedFood.fdcId,
                        description: qty > 1 ? "\(confirmedFood.description) x\(qty)" : confirmedFood.description,
                        foodNutrients: [
                            FoodNutrient(nutrientId: 1008, value: confirmedFood.calories * Double(qty)),
                            FoodNutrient(nutrientId: 1003, value: confirmedFood.protein * Double(qty)),
                            FoodNutrient(nutrientId: 1005, value: confirmedFood.carbs * Double(qty)),
                            FoodNutrient(nutrientId: 1004, value: confirmedFood.fat * Double(qty))
                        ]
                    )
                    nutritionManager.logFood(multiplied, mealType: selectedMealType)
                    foods = []
                    searchText = ""
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
            loadFoods()
            let uid = appState.currentUser?.id ?? ""
            if !uid.isEmpty {
                Task { try? await CustomFoodService.shared.deleteExpiredTemporaryFoods(userId: uid) }
            }
        }
        .task { await nutritionManager.loadFromSupabase() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            nutritionManager.reloadBurnedCalories()
            loadFoods()
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

                    Circle().stroke(lapColor(lap: 0).opacity(0.15), lineWidth: 14).frame(width: 110, height: 110)
                    ForEach(0..<min(lapIndex, 4), id: \.self) { lap in
                        Circle().stroke(lapColor(lap: lap), lineWidth: 14).frame(width: 110, height: 110).id("lap-\(lap)")
                    }
                    Group {
                        if activeFraction > 0 {
                            if activeFraction >= 1.0 {
                                Circle().stroke(currentColor, lineWidth: 14).frame(width: 110, height: 110)
                            } else {
                                Circle().trim(from: 0, to: activeFraction)
                                    .stroke(currentColor, style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                                    .rotationEffect(.degrees(-90)).frame(width: 110, height: 110)
                            }
                        }
                    }
                    .animation(.easeOut(duration: 0.5), value: activeFraction)

                    if lapIndex >= 4 {
                        Text("×\(lapIndex + 1)").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2).background(lapColor(lap: 3)).clipShape(Capsule()).offset(y: 28)
                    }
                    VStack(spacing: 2) {
                        Text("\(Int(nutritionManager.totalCalories))").font(.title2).fontWeight(.bold)
                            .foregroundColor(isOver ? currentColor : .brandCream)
                        Text(isOver ? "over!" : "eaten").font(.caption2)
                            .foregroundColor(isOver ? currentColor : Color.brandCream.opacity(0.5))
                    }
                }
                .frame(width: 110, height: 110)

                VStack(alignment: .leading, spacing: 10) {
                    calorieStatRow(label: "Base target", value: "\(nutritionManager.calorieTarget) kcal", color: .brandCream)
                    if nutritionManager.caloriesBurnedToday > 0 {
                        calorieStatRow(label: "Burned today", value: "+ \(nutritionManager.caloriesBurnedToday) kcal", color: Color(red: 0.25, green: 0.72, blue: 0.55))
                        Divider().background(Color.brandCream.opacity(0.12))
                        calorieStatRow(label: "Available today", value: "\(nutritionManager.calorieTarget + nutritionManager.caloriesBurnedToday) kcal", color: .brandCream)
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
                .padding(10).background(Color.brandOrange.opacity(0.08)).cornerRadius(10)
            }

            Divider().background(Color.brandCream.opacity(0.12))

            VStack(spacing: 10) {
                macroBar(label: "Protein", current: nutritionManager.totalProtein, target: Double(nutritionManager.proteinTarget), color: .brandBlue)
                macroBar(label: "Carbs",   current: nutritionManager.totalCarbs,   target: Double(nutritionManager.carbTarget),    color: Color(red: 0.25, green: 0.72, blue: 0.55))
                macroBar(label: "Fat",     current: nutritionManager.totalFat,     target: Double(nutritionManager.fatTarget),     color: .brandOrange)
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
            return [Color(red: 1.0, green: 0.6, blue: 0.6), Color(red: 0.96, green: 0.33, blue: 0.33),
                    Color(red: 0.75, green: 0.19, blue: 0.19), Color(red: 0.48, green: 0.08, blue: 0.08)][clampedLap]
        case .maintain:
            return [Color(red: 0.36, green: 0.88, blue: 0.66), Color(red: 0.11, green: 0.74, blue: 0.48),
                    Color(red: 0.06, green: 0.43, blue: 0.34), Color(red: 0.03, green: 0.31, blue: 0.25)][clampedLap]
        case .gainMuscle:
            return [Color(red: 0.52, green: 0.72, blue: 0.92), Color(red: 0.29, green: 0.62, blue: 1.0),
                    Color(red: 0.09, green: 0.37, blue: 0.65), Color(red: 0.05, green: 0.27, blue: 0.49)][clampedLap]
        }
    }

    // MARK: - Search Section (bar + inline results)
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Food Database")
                .font(.headline)
                .foregroundColor(.brandCream)

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(Color.brandCream.opacity(0.4))
                TextField("", text: $searchText)
                    .placeholder(when: searchText.isEmpty) {
                        Text("Search USDA food database...").foregroundColor(Color.brandCream.opacity(0.3))
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

            // Meal type chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(NutritionMealType.allCases, id: \.self) { type in
                        Button { selectedMealType = type } label: {
                            Label(type.rawValue, systemImage: type.icon)
                                .font(.caption).fontWeight(.semibold)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Capsule().fill(selectedMealType == type ? Color.brandLime.opacity(0.2) : Color.brandCream.opacity(0.06)))
                                .foregroundColor(selectedMealType == type ? .brandLime : Color.brandCream.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Inline results appear right below the bar
            if !foods.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(foods.count) results")
                            .font(.caption)
                            .foregroundColor(Color.brandCream.opacity(0.4))
                        Spacer()
                        Button { foods = []; searchText = "" } label: {
                            Text("Clear")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundColor(Color.brandCream.opacity(0.4))
                        }
                    }
                    LazyVStack(spacing: 10) {
                        ForEach(foods) { food in
                            USDAFoodRow(food: food) {
                                selectedFood = food
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Quick Add
    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Add")
                .font(.headline)
                .foregroundColor(.brandCream)

            if topFoods.isEmpty {
                Text("Your most used foods will appear here")
                    .font(.subheadline)
                    .foregroundColor(Color.brandCream.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(topFoods) { record in
                            Button {
                                let food = makeFoodItem(from: record)
                                let meal = mealType(from: record.mealType)
                                nutritionManager.logFood(food, mealType: meal)
                                Task { try? await CustomFoodService.shared.incrementUseCount(id: record.id) }
                            } label: {
                                let meal = mealType(from: record.mealType)
                                VStack(alignment: .leading, spacing: 6) {
                                    Label(meal.rawValue, systemImage: meal.icon)
                                        .font(.caption2).foregroundColor(Color.brandCream.opacity(0.5))
                                    Text(record.foodName)
                                        .font(.subheadline).fontWeight(.semibold).lineLimit(1)
                                        .foregroundColor(.brandCream)
                                    Text("\(Int(record.calories)) kcal")
                                        .font(.caption).foregroundColor(Color.brandCream.opacity(0.5))
                                    HStack(spacing: 6) {
                                        Text("P:\(Int(record.protein))g").font(.caption2).foregroundColor(.brandBlue)
                                        Text("C:\(Int(record.carbs))g").font(.caption2).foregroundColor(Color(red: 0.25, green: 0.72, blue: 0.55))
                                        Text("F:\(Int(record.fat))g").font(.caption2).foregroundColor(.brandOrange)
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
    }

    // MARK: - Custom Foods Section
    private var customFoodsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("My Foods")
                    .font(.headline)
                    .foregroundColor(.brandCream)
                Spacer()
                Button {
                    showingQuickAddSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 13, weight: .semibold))
                        Text("Add Food").font(.subheadline).fontWeight(.semibold)
                    }
                    .foregroundColor(.brandLime)
                }
            }

            if customFoods.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife.circle").font(.system(size: 32)).foregroundColor(Color.brandCream.opacity(0.15))
                    Text("No saved foods yet").font(.subheadline).foregroundColor(Color.brandCream.opacity(0.4))
                    Text("Tap Add Food to create your first custom food")
                        .font(.caption).foregroundColor(Color.brandCream.opacity(0.3)).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                // Hold anywhere on a row to delete
                Text("Hold a food to delete it")
                    .font(.system(size: 10))
                    .foregroundColor(Color.brandCream.opacity(0.25))
                    .frame(maxWidth: .infinity, alignment: .trailing)

                LazyVStack(spacing: 8) {
                    ForEach(visibleCustomFoods) { record in
                        customFoodRow(record)
                    }
                }

                let total = permanentFoods.count + temporaryFoods.count
                if total > 6 {
                    Button {
                        withAnimation { showAllCustomFoods.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Text(showAllCustomFoods ? "See Less" : "See All \(total) Foods")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: showAllCustomFoods ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.brandLime)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color.brandLime.opacity(0.08)).cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
        .cornerRadius(16)
    }

    private func customFoodRow(_ record: CustomFoodRecord) -> some View {
        let meal = mealType(from: record.mealType)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(record.foodName)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(.brandCream).lineLimit(1)
                    if record.isTemporary {
                        Text("ONE-TIME")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.brandOrange)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.brandOrange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 8) {
                    Label(meal.rawValue, systemImage: meal.icon)
                        .font(.caption2).foregroundColor(Color.brandCream.opacity(0.4))
                    Text("·").foregroundColor(Color.brandCream.opacity(0.3))
                    Text("\(Int(record.calories)) kcal")
                        .font(.caption2).foregroundColor(Color.brandCream.opacity(0.5))
                }
                HStack(spacing: 6) {
                    Text("P:\(Int(record.protein))g").font(.caption2).foregroundColor(.brandBlue)
                    Text("C:\(Int(record.carbs))g").font(.caption2).foregroundColor(Color(red: 0.25, green: 0.72, blue: 0.55))
                    Text("F:\(Int(record.fat))g").font(.caption2).foregroundColor(.brandOrange)
                }
            }
            Spacer()
            // Log button only — delete via long press on row
            Button {
                let food = makeFoodItem(from: record)
                nutritionManager.logFood(food, mealType: meal)
                if !record.isTemporary {
                    Task { try? await CustomFoodService.shared.incrementUseCount(id: record.id) }
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.brandLime)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.brandCream.opacity(0.04))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandCream.opacity(0.08), lineWidth: 0.5))
        .cornerRadius(12)
        .onLongPressGesture {
            deleteTarget = record
            withAnimation(.spring(response: 0.3)) {
                deletePopupVisible = true
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
                    Image(systemName: "fork.knife.circle").font(.system(size: 42)).foregroundColor(Color.brandCream.opacity(0.2))
                    Text("No foods logged yet").foregroundColor(Color.brandCream.opacity(0.5))
                    Text("Search above or use quick add").font(.caption).foregroundColor(Color.brandCream.opacity(0.35))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 30)
                .background(Color.brandCream.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
                .cornerRadius(16)
            } else {
                ForEach(NutritionMealType.allCases, id: \.self) { mealType in
                    let entries = nutritionManager.loggedEntries.filter { $0.mealType == mealType }
                    if !entries.isEmpty { mealSection(mealType: mealType, entries: entries) }
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

    private func loadFoods() {
        let uid = appState.currentUser?.id ?? ""
        guard !uid.isEmpty else { return }
        Task {
            async let all = CustomFoodService.shared.fetchCustomFoods(userId: uid)
            async let top = CustomFoodService.shared.fetchTopFoods(userId: uid)
            customFoods = (try? await all) ?? []
            topFoods    = (try? await top) ?? []
        }
    }

    private func makeFoodItem(from record: CustomFoodRecord) -> FoodItem {
        FoodItem(
            fdcId: Int(Date().timeIntervalSince1970 * 1000) + Int.random(in: 1...999),
            description: record.foodName,
            foodNutrients: [
                FoodNutrient(nutrientId: 1008, value: record.calories),
                FoodNutrient(nutrientId: 1003, value: record.protein),
                FoodNutrient(nutrientId: 1005, value: record.carbs),
                FoodNutrient(nutrientId: 1004, value: record.fat)
            ]
        )
    }

    private func mealType(from string: String?) -> NutritionMealType {
        guard let raw = string else { return .snack }
        return NutritionMealType(rawValue: raw) ?? .snack
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

// MARK: - USDA Food Row (expanded details)

struct USDAFoodRow: View {
    let food: FoodItem
    let onAdd: () -> Void

    // Extra nutrients from USDA
    private var fiber: Double {
        food.foodNutrients.first(where: { $0.nutrientId == 1079 })?.value ?? 0
    }
    private var sugar: Double {
        food.foodNutrients.first(where: { $0.nutrientId == 2000 })?.value ?? 0
    }
    private var sodium: Double {
        food.foodNutrients.first(where: { $0.nutrientId == 1093 })?.value ?? 0
    }
    private var cholesterol: Double {
        food.foodNutrients.first(where: { $0.nutrientId == 1253 })?.value ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.description)
                        .font(.subheadline).fontWeight(.semibold).lineLimit(2)
                        .foregroundColor(.brandCream)
                    Text("Per 100g · USDA")
                        .font(.system(size: 10))
                        .foregroundColor(Color.brandCream.opacity(0.35))
                }
                Spacer()
                Button(action: onAdd) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Add")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.brandNavy)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.brandLime)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Primary macros row
            HStack(spacing: 0) {
                nutrientCell(value: food.calories, label: "Calories", unit: "kcal", color: .brandOrange)
                Divider().frame(height: 32).background(Color.brandCream.opacity(0.1))
                nutrientCell(value: food.protein, label: "Protein", unit: "g", color: .brandBlue)
                Divider().frame(height: 32).background(Color.brandCream.opacity(0.1))
                nutrientCell(value: food.carbs, label: "Carbs", unit: "g", color: Color(red: 0.25, green: 0.72, blue: 0.55))
                Divider().frame(height: 32).background(Color.brandCream.opacity(0.1))
                nutrientCell(value: food.fat, label: "Fat", unit: "g", color: .brandOrange)
            }
            .padding(.vertical, 8)
            .background(Color.brandCream.opacity(0.04))
            .cornerRadius(10)

            // Secondary nutrients row — only show if data exists
            let hasExtra = fiber > 0 || sugar > 0 || sodium > 0 || cholesterol > 0
            if hasExtra {
                HStack(spacing: 12) {
                    if fiber > 0 {
                        extraNutrientBadge(label: "Fiber", value: fiber, unit: "g", color: Color(red: 0.6, green: 0.85, blue: 0.4))
                    }
                    if sugar > 0 {
                        extraNutrientBadge(label: "Sugar", value: sugar, unit: "g", color: Color(red: 0.95, green: 0.65, blue: 0.2))
                    }
                    if sodium > 0 {
                        extraNutrientBadge(label: "Sodium", value: sodium, unit: "mg", color: Color(red: 0.7, green: 0.55, blue: 0.95))
                    }
                    if cholesterol > 0 {
                        extraNutrientBadge(label: "Cholesterol", value: cholesterol, unit: "mg", color: Color(red: 0.9, green: 0.45, blue: 0.45))
                    }
                }
            }
        }
        .padding(14)
        .background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
        .cornerRadius(14)
    }

    private func nutrientCell(value: Double, label: String, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(value))")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(unit).font(.system(size: 9)).foregroundColor(color.opacity(0.7))
            Text(label).font(.system(size: 9)).foregroundColor(Color.brandCream.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    private func extraNutrientBadge(label: String, value: Double, unit: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text("\(String(format: "%.1f", value))\(unit)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Color.brandCream.opacity(0.5))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Save Custom Food Sheet

struct SaveCustomFoodSheet: View {
    @Environment(\.dismiss) private var dismiss
    var selectedMealType: NutritionMealType
    let onSave: (FoodItem, NutritionMealType, Bool) -> Void

    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var mealType: NutritionMealType = .breakfast
    @State private var quantity = "1"

    init(selectedMealType: NutritionMealType = .breakfast, onSave: @escaping (FoodItem, NutritionMealType, Bool) -> Void) {
        self.selectedMealType = selectedMealType
        self.onSave = onSave
        _mealType = State(initialValue: selectedMealType)
    }

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func buildFood(qty: Double) -> FoodItem {
        FoodItem(
            fdcId: Int(Date().timeIntervalSince1970 * 1000) + Int.random(in: 1000...9999),
            description: name.trimmingCharacters(in: .whitespacesAndNewlines),
            foodNutrients: [
                FoodNutrient(nutrientId: 1008, value: (Double(calories) ?? 0) * qty),
                FoodNutrient(nutrientId: 1003, value: (Double(protein) ?? 0) * qty),
                FoodNutrient(nutrientId: 1005, value: (Double(carbs) ?? 0) * qty),
                FoodNutrient(nutrientId: 1004, value: (Double(fat) ?? 0) * qty)
            ]
        )
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.brandNavy.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 14) {
                            brandField(label: "Food Name", text: $name, placeholder: "e.g. Chicken and Rice")
                            Picker("Meal Type", selection: $mealType) {
                                ForEach(NutritionMealType.allCases, id: \.self) { type in
                                    Label(type.rawValue, systemImage: type.icon).tag(type)
                                }
                            }
                            .pickerStyle(.menu).tint(.brandLime)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.brandCream.opacity(0.07))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandCream.opacity(0.18), lineWidth: 1))
                            .cornerRadius(12)
                            brandField(label: "Quantity", text: $quantity, placeholder: "1", keyboard: .numberPad)
                        }

                        VStack(spacing: 14) {
                            Text("NUTRITION PER SERVING")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.brandLime.opacity(0.6))
                                .tracking(1.2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            brandField(label: "Calories",   text: $calories, placeholder: "e.g. 450", keyboard: .numberPad)
                            brandField(label: "Protein (g)", text: $protein,  placeholder: "e.g. 35",  keyboard: .decimalPad)
                            brandField(label: "Carbs (g)",   text: $carbs,    placeholder: "e.g. 50",  keyboard: .decimalPad)
                            brandField(label: "Fat (g)",     text: $fat,      placeholder: "e.g. 12",  keyboard: .decimalPad)
                        }

                        VStack(spacing: 12) {
                            Button {
                                let qty = Double(max(Int(quantity) ?? 1, 1))
                                onSave(buildFood(qty: qty), mealType, false)
                                dismiss()
                            } label: {
                                VStack(spacing: 4) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "bookmark.fill")
                                        Text("Save to Account").font(.system(size: 16, weight: .bold, design: .rounded))
                                    }
                                    .foregroundColor(.brandNavy)
                                    Text("Stays in My Foods permanently")
                                        .font(.system(size: 11)).foregroundColor(Color.brandNavy.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color.brandLime).cornerRadius(14)
                            }
                            .disabled(!isValid).opacity(isValid ? 1 : 0.4)

                            Button {
                                let qty = Double(max(Int(quantity) ?? 1, 1))
                                onSave(buildFood(qty: qty), mealType, true)
                                dismiss()
                            } label: {
                                VStack(spacing: 4) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "clock")
                                        Text("Use Once").font(.system(size: 16, weight: .bold, design: .rounded))
                                    }
                                    .foregroundColor(.brandOrange)
                                    Text("Only visible today, then removed")
                                        .font(.system(size: 11)).foregroundColor(Color.brandOrange.opacity(0.7))
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color.brandOrange.opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandOrange.opacity(0.4), lineWidth: 1))
                                .cornerRadius(14)
                            }
                            .disabled(!isValid).opacity(isValid ? 1 : 0.4)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add Custom Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.brandNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.brandCream.opacity(0.6))
                }
            }
        }
    }

    private func brandField(label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(Color.brandCream.opacity(0.5))
            ZStack(alignment: .leading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder).foregroundColor(Color.brandCream.opacity(0.3)).padding(.leading, 12)
                }
                TextField("", text: text).foregroundColor(.brandCream).keyboardType(keyboard).padding(12)
            }
            .background(Color.brandCream.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandCream.opacity(0.18), lineWidth: 1))
            .cornerRadius(12)
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
                Text(food.description).font(.subheadline).fontWeight(.semibold).lineLimit(2).foregroundColor(.brandCream)
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
                Text(food.description).font(.subheadline).fontWeight(.semibold).lineLimit(2).foregroundColor(.brandCream)
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
        .padding().background(Color.brandCream.opacity(0.04)).cornerRadius(12)
    }
}

struct MacroLabel: View {
    let value: Double
    let label: String
    let color: Color

    var body: some View {
        Text("\(Int(value))\(label)").font(.caption).fontWeight(.semibold).foregroundColor(color)
    }
}

struct FoodDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let food: FoodItem
    let mealType: NutritionMealType
    let onConfirm: (FoodItem, Int) -> Void
    @State private var quantity: Int = 1

    var body: some View {
        NavigationView {
            ZStack {
                Color.brandNavy.ignoresSafeArea()
                VStack(spacing: 20) {
                    Text(food.description)
                        .font(.title3).fontWeight(.bold).foregroundColor(.brandCream)
                        .multilineTextAlignment(.center).padding(.top, 8)

                    HStack(spacing: 16) {
                        MacroLabel(value: food.calories * Double(quantity), label: " kcal", color: .brandLime)
                        MacroLabel(value: food.protein * Double(quantity),  label: "g P",   color: .brandBlue)
                        MacroLabel(value: food.carbs * Double(quantity),    label: "g C",   color: Color(red: 0.25, green: 0.72, blue: 0.55))
                        MacroLabel(value: food.fat * Double(quantity),      label: "g F",   color: .brandOrange)
                    }
                    .padding().frame(maxWidth: .infinity).background(Color.brandCream.opacity(0.06)).cornerRadius(14)

                    HStack {
                        Text("Quantity").font(.headline).foregroundColor(.brandCream)
                        Spacer()
                        Button { if quantity > 1 { quantity -= 1 } } label: {
                            Image(systemName: "minus.circle.fill").font(.title2)
                                .foregroundColor(.brandOrange.opacity(quantity <= 1 ? 0.3 : 1.0))
                        }
                        .disabled(quantity <= 1)
                        Text("\(quantity)").font(.title2).fontWeight(.bold).foregroundColor(.brandCream).frame(minWidth: 40)
                        Button { if quantity < 20 { quantity += 1 } } label: {
                            Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.brandLime)
                        }
                        .disabled(quantity >= 20)
                    }
                    .padding(.horizontal)

                    Spacer()

                    Button {
                        onConfirm(food, quantity)
                        dismiss()
                    } label: {
                        Text("Add \(quantity) to Log")
                            .font(.headline).fontWeight(.bold).foregroundColor(.brandNavy)
                            .frame(maxWidth: .infinity).padding().background(Color.brandLime).cornerRadius(14)
                    }
                    .padding(.horizontal).padding(.bottom)
                }
                .padding()
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.brandNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.brandCream.opacity(0.6))
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
