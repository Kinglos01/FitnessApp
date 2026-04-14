import SwiftUI
import Charts

struct DashboardView: View {

    @Environment(NutritionManager.self) var nutritionManager
    @Environment(AppState.self) var appState

    @AppStorage("waterGoal") private var waterGoal: Int = 8

    @State private var waterConsumed: Int = 0
    @State private var completedWorkouts: [ActivityEntry] = []
    @State private var allExercises: [ActivityEntry] = []
    @State private var showSettingsSheet: Bool = false
    @State private var showWeightTracker: Bool = false
    @State private var weightEntries: [WeightEntry] = []
    @State private var showWaterGoalEditor: Bool = false
    @State private var tempWaterGoal: Int = 8
    @State private var isLoadingWeight: Bool = true
    @State private var latestWeight: Double? = nil

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

    private var calorieGoal: Double { Double(nutritionManager.calorieTarget) }

    private var calorieProgress: Double {
        min(nutritionManager.totalCalories / max(calorieGoal, 1), 1.0)
    }

    private var totalBurnedToday: Int {
        completedWorkouts.reduce(0) { $0 + $1.caloriesBurned }
    }

    private var didLogWorkoutToday: Bool { !completedWorkouts.isEmpty }
    private var didLogFoodToday: Bool { nutritionManager.totalCalories > 0 }
    private var didMeetWaterHalfway: Bool { waterConsumed >= max(waterGoal / 2, 1) }

    private var dashboardMessage: String {
        if !didLogWorkoutToday && !didLogFoodToday {
            return "You still haven't logged food or a workout today. A quick check-in would make the dashboard feel way more complete."
        } else if !didLogWorkoutToday {
            return "Nutrition looks started, but your workout is still missing for today."
        } else if !didLogFoodToday {
            return "Nice job moving today. Now log your meals so your calorie progress is accurate."
        } else if !didMeetWaterHalfway {
            return "You're doing good so far. Drink a little more water and keep the momentum going."
        } else {
            return "You're on a good track today. Keep stacking those small wins."
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
            } else { break }
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
                    weightThumbnailCard
                    todaysWorkoutsCard
                    Spacer(minLength: 70)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
        }
        .onAppear { reloadAll() }
        .onChange(of: appState.currentUser?.id) { _, newId in
            guard newId != nil else { return }
            reloadAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            reloadAll()
        }
        .task { await refreshLatestWeight() }
        .onChange(of: showWeightTracker) { _, isShowing in
            if !isShowing { Task { await refreshLatestWeight() } }
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView().environment(appState)
        }
        .sheet(isPresented: $showWeightTracker, onDismiss: {
            Task { await loadWeightEntries() }
        }) {
            WeightTrackerSheet().environment(appState)
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
        Task { await loadWeightEntries() }
    }

    @MainActor
    private func loadWeightEntries() async {
        guard !userId.isEmpty else {
            print("loadWeightEntries: userId is empty, skipping")
            isLoadingWeight = false
            return
        }
        isLoadingWeight = true
        do {
            let entries = try await WeightLogService.shared.fetchEntries(userId: userId)
            weightEntries = entries
            print("loadWeightEntries: loaded \(entries.count) entries")
        } catch {
            print("loadWeightEntries error: \(error)")
        }
        isLoadingWeight = false
    }

    @MainActor
    private func refreshLatestWeight() async {
        guard !userId.isEmpty else { return }
        do {
            let entries = try await WeightLogService.shared.fetchEntries(userId: userId)
            if let latest = entries.last {
                latestWeight = latest.weightLbs
            }
        } catch {
            print("Failed to fetch weight: \(error)")
        }
    }

    private func syncDailyLog() {
        guard !userId.isEmpty else { return }
        let burned = completedWorkouts.reduce(0) { $0 + $1.caloriesBurned }
        let workoutCount = completedWorkouts.count
        Task {
            try? await DailyLogService.shared.upsertLog(
                userId: userId,
                waterConsumed: waterConsumed,
                waterGoal: waterGoal,
                caloriesEaten: nutritionManager.totalCalories,
                caloriesBurned: burned,
                workoutsCompleted: workoutCount
            )
        }
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greeting), \(firstName) 👋")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Let's keep today moving.")
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

    // MARK: - Today Prompt Card

    private var todayPromptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles").foregroundColor(.orange)
                Text("Today's Check-In").font(.headline)
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
        .background(Capsule().fill(complete ? color : color.opacity(0.12)))
    }

    // MARK: - Calorie Card

    private var calorieCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Calories").font(.headline)
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

    // MARK: - Water Card

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
                Button {
                    tempWaterGoal = waterGoal
                    showWaterGoalEditor = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue.opacity(0.7))
                }
            }

            ProgressView(value: Double(waterConsumed), total: Double(max(waterGoal, 1)))
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(x: 1, y: 2)

            HStack(spacing: 8) {
                Button {
                    if waterConsumed > 0 {
                        waterConsumed -= 1
                        UserDefaults.standard.set(waterConsumed, forKey: waterKey)
                        syncDailyLog()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                Spacer()
                Text("\(waterConsumed) of \(waterGoal) glasses today")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    if waterConsumed < waterGoal {
                        waterConsumed += 1
                        UserDefaults.standard.set(waterConsumed, forKey: waterKey)
                        syncDailyLog()
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
        .sheet(isPresented: $showWaterGoalEditor) {
            waterGoalEditorSheet
        }
    }

    private var waterGoalEditorSheet: some View {
        VStack(spacing: 32) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(.systemGray4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            Text("Daily Water Goal")
                .font(.system(size: 18, weight: .bold))

            Text("How many glasses of water do you want to drink per day?")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("\(tempWaterGoal)")
                .font(.system(size: 72, weight: .black, design: .rounded))
                .foregroundColor(.blue)

            Text("glasses / day")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 48) {
                Button {
                    if tempWaterGoal > 1 { tempWaterGoal -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(tempWaterGoal > 1 ? .blue : Color(.systemGray4))
                }
                .disabled(tempWaterGoal <= 1)

                Button {
                    if tempWaterGoal < 20 { tempWaterGoal += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                }
                .disabled(tempWaterGoal >= 20)
            }

            HStack(spacing: 10) {
                ForEach([6, 8, 10, 12], id: \.self) { preset in
                    Button {
                        tempWaterGoal = preset
                    } label: {
                        Text("\(preset)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(tempWaterGoal == preset ? .white : .blue)
                            .frame(width: 48, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(tempWaterGoal == preset ? Color.blue : Color.blue.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                waterGoal = tempWaterGoal
                if waterConsumed > waterGoal {
                    waterConsumed = waterGoal
                    UserDefaults.standard.set(waterConsumed, forKey: waterKey)
                }
                syncDailyLog()
                showWaterGoalEditor = false
            } label: {
                Text("Save Goal")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.blue)
                    .cornerRadius(14)
            }
            .padding(.horizontal)

            Spacer()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Quick Stats Bar

    private var quickStatsBar: some View {
        HStack(spacing: 0) {
            QuickStatCell(value: "\(workoutStreak)", label: "Day Streak", icon: "flame.fill", color: .orange)
            Divider().frame(height: 40)
            QuickStatCell(value: "\(activeThisWeek)", label: "Active Days", icon: "calendar.badge.checkmark", color: .green)
            Divider().frame(height: 40)
            QuickStatCell(value: "\(workoutsThisMonth)", label: "This Month", icon: "chart.bar.fill", color: .blue)
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Weight Thumbnail Card

    private var weightThumbnailCard: some View {
        let isLose     = appState.currentUser?.primaryGoal == "Lose Weight"
        let lineColor: Color = isLose ? .red : Color(red: 0.25, green: 0.72, blue: 0.55)
        let current    = weightEntries.last?.weightLbs ?? 0
        let start      = weightEntries.first?.weightLbs ?? 0
        let delta      = current - start
        let deltaPositive = delta >= 0
        let deltaColor: Color = abs(delta) < 0.05
            ? .secondary
            : (isLose
               ? (delta < 0 ? Color(red: 0.25, green: 0.72, blue: 0.55) : .red)
               : (delta > 0 ? Color(red: 0.25, green: 0.72, blue: 0.55) : .red))

        // Need at least 2 entries to draw a meaningful chart line
        let hasChartData = weightEntries.count >= 2

        return Button {
            showWeightTracker = true
        } label: {
            HStack(spacing: 14) {

                // Left — weight info
                VStack(alignment: .leading, spacing: 6) {
                    Label("Weight", systemImage: "scalemass.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    if isLoadingWeight {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(height: 30)
                    } else {
                        Text("\(Int(latestWeight ?? appState.currentUser?.weightLbs ?? 0)) lbs")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.primary)

                        if weightEntries.count >= 2 {
                            HStack(spacing: 4) {
                                Image(systemName: deltaPositive ? "arrow.up" : "arrow.down")
                                    .font(.system(size: 10, weight: .bold))
                                Text(String(format: "%.1f lb", abs(delta)))
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(deltaColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(deltaColor.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
                .frame(width: 110, alignment: .leading)

                // Right — chart or status
                Group {
                    if isLoadingWeight {
                        // Show placeholder while fetching
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.7)
                            )
                    } else if !hasChartData {
                        // Single entry — show a simple dot indicator instead of chart
                        RoundedRectangle(cornerRadius: 8)
                            .fill(lineColor.opacity(0.08))
                            .overlay(
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(lineColor)
                                        .frame(width: 10, height: 10)
                                    Text("Log more to\nsee your trend")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            )
                    } else {
                        // 2+ entries — render the chart safely with .linear interpolation
                        let ws   = weightEntries.map { $0.weightLbs }
                        let yMin = (ws.min() ?? 100) - 2
                        let yMax = (ws.max() ?? 200) + 2

                        Chart {
                            ForEach(weightEntries) { e in
                                AreaMark(
                                    x: .value("Date", e.chartLabel),
                                    y: .value("Weight", e.weightLbs)
                                )
                                .foregroundStyle(lineColor.opacity(0.08))
                                .interpolationMethod(.linear)
                            }
                            ForEach(weightEntries) { e in
                                LineMark(
                                    x: .value("Date", e.chartLabel),
                                    y: .value("Weight", e.weightLbs)
                                )
                                .foregroundStyle(lineColor)
                                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                                .interpolationMethod(.linear)
                            }
                            ForEach(weightEntries) { e in
                                PointMark(
                                    x: .value("Date", e.chartLabel),
                                    y: .value("Weight", e.weightLbs)
                                )
                                .foregroundStyle(e.id == weightEntries.last?.id ? lineColor : lineColor.opacity(0.4))
                                .symbolSize(e.id == weightEntries.last?.id ? 48 : 16)
                            }
                        }
                        .chartYScale(domain: yMin...yMax)
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Today's Workouts Card

    private var todaysWorkoutsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Today's Workouts", systemImage: "checkmark.seal.fill").font(.headline)
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
            Image(systemName: icon).foregroundColor(color)
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
