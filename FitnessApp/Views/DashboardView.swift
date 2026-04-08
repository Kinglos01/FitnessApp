import SwiftUI

struct DashboardView: View {

    @Environment(NutritionManager.self) var nutritionManager
    @Environment(AppState.self) var appState

    @AppStorage("waterGoal") private var waterGoal: Int = 8

    @State private var waterConsumed: Int = 0
    @State private var completedWorkouts: [ActivityEntry] = []
    @State private var allExercises: [ActivityEntry] = []
    @State private var selectedDaySnapshot: DaySnapshot? = nil
    @State private var showSettingsSheet: Bool = false
    @State private var showWeightTracker: Bool = false

    private var userId: String { appState.currentUser?.id ?? "" }

    private var waterKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "waterConsumed_\(userId)_\(f.string(from: Date()))"
    }

    private var firstName: String {
        let full = appState.currentUser?.name ?? ""
        let first = full.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? "Friend" : first
    }

    private var calorieGoal: Double {
        Double(nutritionManager.calorieTarget)
    }

    private var calorieProgress: Double {
        min(nutritionManager.totalCalories / max(calorieGoal, 1), 1.0)
    }

    private var totalBurnedToday: Int {
        completedWorkouts.reduce(0) { $0 + $1.caloriesBurned }
    }

    private var didLogWorkoutToday: Bool {
        !completedWorkouts.isEmpty
    }

    private var didLogFoodToday: Bool {
        nutritionManager.totalCalories > 0
    }

    private var didMeetWaterHalfway: Bool {
        waterConsumed >= max(waterGoal / 2, 1)
    }

    private var dashboardMessage: String {
        if !didLogWorkoutToday && !didLogFoodToday {
            return "You still haven’t logged food or a workout today. A quick check-in would make the dashboard feel way more complete."
        } else if !didLogWorkoutToday {
            return "Nutrition looks started, but your workout is still missing for today."
        } else if !didLogFoodToday {
            return "Nice job moving today. Now log your meals so your calorie progress is accurate."
        } else if !didMeetWaterHalfway {
            return "You’re doing good so far. Drink a little more water and keep the momentum going."
        } else {
            return "You’re on a good track today. Keep stacking those small wins."
        }
    }

    var workoutStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = cal.startOfDay(for: Date())

        while true {
            let hasWorkout = allExercises.contains {
                $0.isCompleted && cal.startOfDay(for: $0.date) == checkDate
            }
            if hasWorkout {
                streak += 1
                checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
        }

        return streak
    }

    var activeThisWeek: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let daysFromMonday = (cal.component(.weekday, from: today) + 5) % 7
        let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today

        return (0...daysFromMonday).filter { offset in
            let day = cal.date(byAdding: .day, value: offset, to: monday) ?? today
            return allExercises.contains { $0.isCompleted && cal.startOfDay(for: $0.date) == day }
        }.count
    }

    var workoutsThisMonth: Int {
        let cal = Calendar.current
        let now = Date()
        let month = cal.component(.month, from: now)
        let year = cal.component(.year, from: now)

        return allExercises.filter {
            $0.isCompleted &&
            cal.component(.month, from: $0.date) == month &&
            cal.component(.year, from: $0.date) == year
        }.count
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning" }
        if hour < 17 { return "Good Afternoon" }
        return "Good Evening"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    greetingHeader
                    todayPromptCard
                    calorieCard
                    waterCard
                    quickStatsBar
                    quickActionsCard
                    todaysWorkoutsCard

                    Spacer(minLength: 70)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
        }
        .onAppear {
            reloadAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            reloadAll()
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
                .environment(appState)
        }
    }

    private func reloadAll() {
        let uid = appState.currentUser?.id ?? ""

        let key = "savedExercises_\(uid)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ActivityEntry].self, from: data) {
            allExercises = decoded
        } else {
            allExercises = []
        }

        let today = Calendar.current.startOfDay(for: Date())
        completedWorkouts = allExercises.filter {
            $0.isCompleted && Calendar.current.startOfDay(for: $0.date) == today
        }

        waterConsumed = UserDefaults.standard.integer(forKey: waterKey)

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
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Let’s keep today moving.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button {
                showSettingsSheet = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 48, height: 48)

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal)
    }

    private var todayPromptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.orange)
                Text("Today’s Check-In")
                    .font(.headline)
                Spacer()
            }

            Text(dashboardMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                statusPill(title: "Workout", complete: didLogWorkoutToday, color: .green)
                statusPill(title: "Food", complete: didLogFoodToday, color: .orange)
                statusPill(title: "Water", complete: didMeetWaterHalfway, color: .blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func statusPill(title: String, complete: Bool, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: complete ? "checkmark.circle.fill" : "circle")
            Text(title)
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundColor(complete ? .white : color)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(complete ? color : color.opacity(0.12))
        )
    }

    private var calorieCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Calories")
                    .font(.headline)

                Spacer()

                Text("\(Int(nutritionManager.totalCalories)) / \(Int(calorieGoal)) kcal")
                    .font(.subheadline)
                    .foregroundColor(.gray)
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
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var waterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Water Intake", systemImage: "drop.fill")
                    .font(.headline)
                    .foregroundColor(.blue)

                Spacer()

                Text("\(waterConsumed) / \(waterGoal) glasses")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            ProgressView(value: Double(waterConsumed), total: Double(max(waterGoal, 1)))
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(x: 1, y: 2)

            HStack(spacing: 8) {
                Button {
                    if waterConsumed > 0 {
                        waterConsumed -= 1
                        UserDefaults.standard.set(waterConsumed, forKey: waterKey)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }

                Spacer()

                Text("This is just helping the user stay on track for the day.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    if waterConsumed < waterGoal {
                        waterConsumed += 1
                        UserDefaults.standard.set(waterConsumed, forKey: waterKey)
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var quickStatsBar: some View {
        HStack(spacing: 0) {
            QuickStatCell(value: "\(workoutStreak)", label: "Day Streak",  icon: "flame.fill",              color: .orange)
            Divider().frame(height: 40)
            QuickStatCell(value: "\(activeThisWeek)", label: "Active Days", icon: "calendar.badge.checkmark", color: .green)
            Divider().frame(height: 40)
            QuickStatCell(value: "\(workoutsThisMonth)", label: "This Month", icon: "chart.bar.fill",           color: .blue)
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                Button {
                    showWeightTracker = true
                } label: {
                    quickActionButton(
                        title: "Weight",
                        icon: "scalemass.fill",
                        color: .orange
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showSettingsSheet = true
                } label: {
                    quickActionButton(
                        title: "Settings",
                        icon: "gearshape.fill",
                        color: .blue
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func quickActionButton(title: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.white.opacity(0.7))
        .cornerRadius(14)
    }

    private var todaysWorkoutsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Today’s Workouts", systemImage: "checkmark.seal.fill")
                    .font(.headline)

                Spacer()

                if !completedWorkouts.isEmpty {
                    Text("\(totalBurnedToday) kcal burned")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if completedWorkouts.isEmpty {
                Text("No workouts completed yet. Once the user marks one done, it shows up here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(completedWorkouts) { workout in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(workout.category.color.opacity(0.15))
                                .frame(width: 42, height: 42)

                            Image(systemName: workout.category.icon)
                                .foregroundColor(workout.category.color)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(workout.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            if let duration = workout.duration {
                                Text("\(duration) min • \(workout.caloriesBurned) kcal")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(workout.sets) sets × \(workout.reps) reps")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Helpers

private struct MacroCard: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)g")
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct QuickStatCell: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
