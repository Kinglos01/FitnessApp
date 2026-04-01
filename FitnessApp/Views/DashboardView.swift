import SwiftUI

// MARK: - Dashboard Workout Reader
// Reads ActivityEntry data from the same UserDefaults key used by ActivityLogViewModel
// so no shared state object is needed — just a lightweight reload on appear.

private struct DashboardWorkoutReader {
    static func storageKey(for userId: String) -> String { "savedExercises_\(userId)" }

    static func completedToday(userId: String) -> [ActivityEntry] {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey(for: userId)),
            let decoded = try? JSONDecoder().decode([ActivityEntry].self, from: data)
        else { return [] }

        let today = Calendar.current.startOfDay(for: Date())
        return decoded.filter {
            $0.isCompleted &&
            Calendar.current.startOfDay(for: $0.date) == today
        }
    }
}

// MARK: - DashboardView

struct DashboardView: View {

    @Environment(NutritionManager.self) var nutritionManager
    @Environment(AppState.self) var appState

    @AppStorage("waterGoal") private var waterGoal: Int = 8
    @State private var waterConsumed: Int = 0
    @State private var showSettings: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var showWaterGoalPicker: Bool = false
    @State private var completedWorkouts: [ActivityEntry] = []
    @State private var allExercises: [ActivityEntry] = []
    @State private var selectedDaySnapshot: DaySnapshot? = nil
    @State private var showWeightSheet: Bool = false
    @State private var latestWeight: Double? = nil

    private var userId: String { appState.currentUser?.id ?? "" }

    private var waterKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return "waterConsumed_\(userId)_\(f.string(from: Date()))"
    }

    private var firstName: String {
        let full = appState.currentUser?.name ?? ""
        let first = full.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? "Friend" : first
    }

    private var calorieGoal: Double { Double(nutritionManager.calorieTarget) }

    var calorieProgress: Double {
        min(nutritionManager.totalCalories / max(calorieGoal, 1), 1.0)
    }

    // MARK: - Real Stats
    var workoutStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = cal.startOfDay(for: Date())
        while true {
            let hasWorkout = allExercises.contains {
                $0.isCompleted && cal.startOfDay(for: $0.date) == checkDate
            }
            if hasWorkout { streak += 1 } else { break }
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate)!
        }
        return streak
    }

    var activeThisWeek: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let daysFromMonday = (cal.component(.weekday, from: today) + 5) % 7
        let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today)!
        return (0...daysFromMonday).filter { offset in
            let day = cal.date(byAdding: .day, value: offset, to: monday)!
            return allExercises.contains { $0.isCompleted && cal.startOfDay(for: $0.date) == day }
        }.count
    }

    var workoutsThisMonth: Int {
        let cal = Calendar.current
        let now = Date()
        let month = cal.component(.month, from: now)
        let year  = cal.component(.year,  from: now)
        return allExercises.filter {
            $0.isCompleted &&
            cal.component(.month, from: $0.date) == month &&
            cal.component(.year,  from: $0.date) == year
        }.count
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning" }
        else if hour < 17 { return "Good Afternoon" }
        else { return "Good Evening" }
    }

    private var totalBurnedToday: Int {
        completedWorkouts.reduce(0) { $0 + $1.caloriesBurned }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    greetingHeader
                    weekStrip
                    calorieCard
                    waterCard
                    weightCard
                    quickStatsBar
                    todaysWorkoutsCard
                    if !nutritionManager.loggedFoods.isEmpty { foodLogPreview }
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
        }
        .onAppear { reloadAll() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            reloadAll()
        }
        .sheet(item: $selectedDaySnapshot) { snap in
            DayDetailSheet(snapshot: snap)
                .environment(appState)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
                .environment(appState)
        }
        .sheet(isPresented: $showWeightSheet) {
            WeightTrackerSheet()
                .environment(appState)
        }
        .task {
            await refreshLatestWeight()
        }
        .onChange(of: showWeightSheet) { _, isShowing in
            if !isShowing {
                Task {
                    await refreshLatestWeight()
                }
            }
        }
    }

    private func refreshLatestWeight() async {
        do {
            let entries = try await WeightLogService.shared.fetchEntries()
            if let latest = entries.last {
                latestWeight = latest.weightLbs
            }
        } catch {
            print("Failed to fetch weight: \(error)")
        }
    }

    private func reloadAll() {
        let uid = appState.currentUser?.id ?? ""
        // Load exercises
        let key = "savedExercises_\(uid)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ActivityEntry].self, from: data) {
            allExercises = decoded
        }
        let today = Calendar.current.startOfDay(for: Date())
        completedWorkouts = allExercises.filter {
            $0.isCompleted && Calendar.current.startOfDay(for: $0.date) == today
        }
        // Load water
        waterConsumed = UserDefaults.standard.integer(forKey: waterKey)
        // Ensure nutrition is configured so the calorie card isn't 0 on first load
        nutritionManager.configure(userId: uid, user: appState.currentUser)
        nutritionManager.reloadBurnedCalories()
    }

    // MARK: - Week Strip

    private var weekStrip: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let daysFromMonday = (cal.component(.weekday, from: today) + 5) % 7
        let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today)!
        let weekDays = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
        let dayInitials = ["M", "T", "W", "T", "F", "S", "S"]
        let uid = appState.currentUser?.id ?? ""
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("This Week").font(.headline)
                Spacer()
                Text(weekRangeLabel(monday: monday))
                    .font(.caption).foregroundColor(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { idx, date in
                    let isToday = cal.isDateInToday(date)
                    let isFuture = date > today
                    let dayStart = cal.startOfDay(for: date)
                    let dayNum = cal.component(.day, from: date)

                    // Activity
                    let hasWorkout = !isFuture && allExercises.contains {
                        $0.isCompleted && cal.startOfDay(for: $0.date) == dayStart
                    }

                    // Nutrition
                    let logKey = "nutritionLog_\(uid)_\(f.string(from: dayStart))"
                    let calsEaten: Double = {
                        guard let data = UserDefaults.standard.data(forKey: logKey),
                              let entries = try? JSONDecoder().decode([LoggedFoodEntry].self, from: data)
                        else { return 0 }
                        return entries.reduce(0) { $0 + $1.foodItem.calories }
                    }()
                    let calorieProgress = min(calsEaten / Double(max(nutritionManager.calorieTarget, 1)), 1.0)

                    // Water
                    let waterKey = "waterConsumed_\(uid)_\(f.string(from: dayStart))"
                    let water = UserDefaults.standard.integer(forKey: waterKey)
                    let waterProgress = min(Double(water) / 8.0, 1.0)

                    VStack(spacing: 4) {
                        Text(dayInitials[idx])
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(isToday ? .orange : .secondary)

                        // Three rings
                        GeometryReader { geo in
                            let size = geo.size.width
                            let lw = size * 0.09
                            ZStack {
                                // Outer — Activity (green)
                                Circle().stroke(Color(red: 0.25, green: 0.72, blue: 0.55).opacity(0.2), lineWidth: lw)
                                Circle()
                                    .trim(from: 0, to: hasWorkout ? 1.0 : 0)
                                    .stroke(Color(red: 0.25, green: 0.72, blue: 0.55),
                                            style: StrokeStyle(lineWidth: lw, lineCap: .round))
                                    .rotationEffect(.degrees(-90))

                                // Middle — Nutrition (orange)
                                Circle().stroke(Color.orange.opacity(0.2), lineWidth: lw)
                                    .padding(lw * 1.5)
                                Circle()
                                    .trim(from: 0, to: isFuture ? 0 : calorieProgress)
                                    .stroke(Color.orange,
                                            style: StrokeStyle(lineWidth: lw, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .padding(lw * 1.5)

                                // Inner — Water (blue)
                                Circle().stroke(Color.cyan.opacity(0.2), lineWidth: lw)
                                    .padding(lw * 3.0)
                                Circle()
                                    .trim(from: 0, to: isFuture ? 0 : waterProgress)
                                    .stroke(Color.cyan,
                                            style: StrokeStyle(lineWidth: lw, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .padding(lw * 3.0)

                                // Day number in centre
                                Text("\(dayNum)")
                                    .font(.system(size: size * 0.28,
                                                  weight: isToday ? .black : .regular,
                                                  design: .rounded))
                                    .foregroundColor(isToday ? .orange : isFuture ? .secondary.opacity(0.4) : .primary)
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .onTapGesture {
                        guard !isFuture else { return }
                        selectedDaySnapshot = buildSnapshot(for: dayStart)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func buildSnapshot(for date: Date) -> DaySnapshot {
        let cal = Calendar.current
        let uid = appState.currentUser?.id ?? ""

        let workouts = allExercises.filter {
            $0.isCompleted && cal.startOfDay(for: $0.date) == date
        }

        // Load nutrition for that date
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let logKey = "nutritionLog_\(uid)_\(f.string(from: date))"
        var foods: [LoggedFoodEntry] = []
        var totalCals: Double = 0
        if let data = UserDefaults.standard.data(forKey: logKey),
           let entries = try? JSONDecoder().decode([LoggedFoodEntry].self, from: data) {
            foods = entries
            totalCals = entries.reduce(0) { $0 + $1.foodItem.calories }
        }

        // Load water for that date
        let wKey = "waterConsumed_\(uid)_\(f.string(from: date))"
        let water = UserDefaults.standard.integer(forKey: wKey)

        return DaySnapshot(
            date: date,
            completedWorkouts: workouts,
            totalCalories: totalCals,
            calorieTarget: nutritionManager.calorieTarget,
            loggedFoods: foods,
            waterConsumed: water
        )
    }

    private func weekRangeLabel(monday: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let cal = Calendar.current
        let sunday = cal.date(byAdding: .day, value: 6, to: monday)!
        return "\(f.string(from: monday)) – \(f.string(from: sunday))"
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greeting), \(firstName) 👋")
                    .font(.title2).fontWeight(.bold)
                Text("Let's crush today's goals")
                    .font(.subheadline).foregroundColor(.gray)
            }
            Spacer()
            VStack(spacing: 4) {
                ZStack {
                    Circle().stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: calorieProgress)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 44)).foregroundColor(.blue)
                }
                .frame(width: 56, height: 56)
                Button {
                    showSettingsSheet = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16)).foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Settings Dropdown

    private var settingsDropdown: some View {
        VStack(spacing: 0) {
            settingsRow(icon: "person.fill", label: "Edit Profile", color: .primary) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { showSettings = false }
                showSettingsSheet = true
            }
            Divider()
            settingsRow(icon: "gearshape", label: "Settings", color: .primary) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { showSettings = false }
                showSettingsSheet = true
            }
            Divider()
            settingsRow(icon: "rectangle.portrait.and.arrow.right", label: "Log Out", color: .red) {
                Task {
                    try? await AuthService.shared.signOut()
                    appState.signOut()
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(14)
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func settingsRow(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(label)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .foregroundColor(color)
    }

    // MARK: - Calorie Card

    private var calorieCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Calories").font(.headline)
                Spacer()
                Text("\(Int(nutritionManager.totalCalories)) / \(Int(calorieGoal)) kcal")
                    .font(.subheadline).foregroundColor(.gray)
            }
            ProgressView(value: calorieProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .scaleEffect(x: 1, y: 2)
            HStack(spacing: 0) {
                MacroCard(value: Int(nutritionManager.totalProtein), label: "Protein", color: .blue)
                Divider().frame(height: 40)
                MacroCard(value: Int(nutritionManager.totalCarbs), label: "Carbs", color: .green)
                Divider().frame(height: 40)
                MacroCard(value: Int(nutritionManager.totalFat), label: "Fat", color: .red)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Water Card

    private var waterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Water Intake", systemImage: "drop.fill")
                    .font(.headline).foregroundColor(.blue)
                Spacer()
                Text("\(waterConsumed) / \(waterGoal) glasses")
                    .font(.subheadline).foregroundColor(.gray)
                Button {
                    showWaterGoalPicker = true
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.blue.opacity(0.6))
                }
            }
            HStack(spacing: 8) {
                ForEach(0..<waterGoal, id: \.self) { index in
                    Image(systemName: index < waterConsumed ? "drop.fill" : "drop")
                        .foregroundColor(index < waterConsumed ? .blue : .gray.opacity(0.3))
                        .font(.title3)
                }
                Spacer()
                Button {
                    if waterConsumed > 0 {
                        waterConsumed -= 1
                        UserDefaults.standard.set(waterConsumed, forKey: waterKey)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill").font(.title2).foregroundColor(.gray)
                }
                Button {
                    if waterConsumed < waterGoal {
                        waterConsumed += 1
                        UserDefaults.standard.set(waterConsumed, forKey: waterKey)
                    }
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
        .sheet(isPresented: $showWaterGoalPicker) {
            WaterGoalSheet(waterGoal: $waterGoal, waterConsumed: $waterConsumed)
        }
    }

    // MARK: - Weight Card

    private var weightCard: some View {
        Button {
            showWeightSheet = true
        } label: {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weight")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                        Text("\(Int(latestWeight ?? appState.currentUser?.weightLbs ?? 0)) lbs")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Quick Stats Bar

    private var quickStatsBar: some View {
        HStack(spacing: 0) {
            QuickStatCell(value: "\(workoutStreak)",    label: "Day Streak",  icon: "flame.fill",              color: .orange)
            Divider().frame(height: 40)
            QuickStatCell(value: "\(activeThisWeek)",  label: "Active Days", icon: "calendar.badge.checkmark", color: .green)
            Divider().frame(height: 40)
            QuickStatCell(value: "\(workoutsThisMonth)", label: "This Month", icon: "chart.bar.fill",           color: .blue)
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Today's Workouts Card

    private var todaysWorkoutsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Today's Workouts", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                if !completedWorkouts.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("\(totalBurnedToday) kcal burned")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            if completedWorkouts.isEmpty {
                // Empty state
                HStack(spacing: 12) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 28))
                        .foregroundColor(.gray.opacity(0.35))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No workouts completed yet")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                        Text("Mark exercises as done in Activity Log")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else {
                ForEach(completedWorkouts) { workout in
                    HStack(spacing: 12) {
                        // Category icon
                        ZStack {
                            Circle()
                                .fill(workout.category.color.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: workout.category.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(workout.category.color)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.name)
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text(workout.category.rawValue)
                                .font(.caption)
                                .foregroundColor(workout.category.color)
                        }

                        Spacer()

                        // Calories badge
                        if workout.caloriesBurned > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                                Text("\(workout.caloriesBurned) kcal")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Capsule())
                        }

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(workout.category.color)
                            .font(.system(size: 18))
                    }
                    .padding(10)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Food Log Preview

    private var foodLogPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Today's Food Log", systemImage: "fork.knife").font(.headline)
            ForEach(nutritionManager.loggedFoods.suffix(3)) { food in
                HStack {
                    Text(food.description).font(.subheadline).lineLimit(1)
                    Spacer()
                    Text("\(Int(food.calories)) kcal").font(.caption).foregroundColor(.orange)
                }
            }
            if nutritionManager.loggedFoods.count > 3 {
                Text("+ \(nutritionManager.loggedFoods.count - 3) more items")
                    .font(.caption).foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Quick Stat Cell

struct QuickStatCell: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold)).foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded)).foregroundColor(.primary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray).textCase(.uppercase).tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Macro Card

struct MacroCard: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)g").font(.title3).fontWeight(.bold).foregroundColor(color)
            Text(label).font(.caption).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Water Goal Sheet

struct WaterGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var waterGoal: Int
    @Binding var waterConsumed: Int
    @State private var tempGoal: Int = 8

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()

                // Drop icon
                Image(systemName: "drop.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.blue)

                // Big number
                Text("\(tempGoal)")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text("glasses per day")
                    .font(.subheadline).foregroundColor(.secondary)

                // Stepper buttons
                HStack(spacing: 40) {
                    Button {
                        if tempGoal > 1 { tempGoal -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    Button {
                        if tempGoal < 20 { tempGoal += 1 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                    }
                }

                // Reset to default
                if tempGoal != 8 {
                    Button("Reset to default (8)") {
                        tempGoal = 8
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()
            }
            .navigationTitle("Daily Water Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        waterGoal = tempGoal
                        // Clamp consumed to new goal
                        if waterConsumed > waterGoal { waterConsumed = waterGoal }
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { tempGoal = waterGoal }
    }
}

#Preview {
    DashboardView()
        .environment(NutritionManager())
        .environment(AppState())
}
