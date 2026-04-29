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
    @State private var showProfile: Bool = false
    @State private var latestWeight: Double? = nil

    private var userId: String { appState.currentUser?.id ?? "" }

    private var activeProfile: Profile? { appState.profileStore.profile }

    private var dashboardDisplayName: String {
        activeProfile?.displayName ?? appState.currentUser?.name ?? ""
    }

    private var dashboardProfileImageData: Data? { activeProfile?.profileImageData }

    private var dashboardInitials: String {
        let parts = dashboardDisplayName.split(separator: " ").prefix(2)
        let joined = parts.map { String($0.prefix(1)) }.joined()
        return joined.isEmpty ? "?" : joined.uppercased()
    }

    private var firstName: String {
        let full = dashboardDisplayName
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
                $0.isCompleted(on: checkDate)
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
            return allExercises.contains { $0.isCompleted(on: day) }
        }.count
    }

    var workoutsThisMonth: Int {
        let cal = Calendar.current
        let now = Date()
        let month = cal.component(.month, from: now)
        let year = cal.component(.year, from: now)
        return allExercises.filter { entry in
            let entryDate = cal.startOfDay(for: entry.date)
            return entry.isCompleted(on: entryDate) &&
                cal.component(.month, from: entry.date) == month &&
                cal.component(.year, from: entry.date) == year
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
            ZStack {
                Color.brandNavy.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        greetingHeader
                        todayPromptCard
                        weeklyRingsCard
                        calorieCard
                        waterCard
                        quickStatsBar
                        weightThumbnailCard
                        todaysWorkoutsCard
                        Spacer(minLength: 70)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.brandNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            appState.syncProfileStoreFromCurrentUser()
            reloadAll()
        }
        .onChange(of: appState.currentUser?.id) { _, newId in
            guard newId != nil else { return }
            reloadAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            reloadAll()
        }
        .task {
            await nutritionManager.loadFromSupabase()
            await refreshLatestWeight()
        }
        .onChange(of: showWeightTracker) { _, isShowing in
            if !isShowing { Task { await refreshLatestWeight() } }
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView().environment(appState)
        }
        .sheet(isPresented: $showWeightTracker, onDismiss: {
            Task { await loadWeightEntries() }
        }) {
            WeightTrackerSheet()
                .environment(appState)
                .presentationBackground(Color(.systemBackground))
        }
        .sheet(isPresented: $showProfile) {
            ProfileView().environment(appState)
        }
    }

    private func reloadAll() {
        appState.syncProfileStoreFromCurrentUser()
        let uid = appState.currentUser?.id ?? ""
        let key = "savedExercises_\(uid)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ActivityEntry].self, from: data) {
            allExercises = decoded
        } else {
            allExercises = []
        }
        let today = Calendar.current.startOfDay(for: Date())
        completedWorkouts = allExercises.filter { $0.isCompleted(on: today) }
        Task {
            await loadTodayLog()
            // Also fetch from Supabase to ensure cross-device sync
            if let remoteExercises = try? await WorkoutService.shared.fetchWorkouts(userId: uid) {
                await MainActor.run {
                    allExercises = remoteExercises
                    if let data = try? JSONEncoder().encode(remoteExercises) {
                        UserDefaults.standard.set(data, forKey: "savedExercises_\(uid)")
                    }
                    completedWorkouts = allExercises.filter { $0.isCompleted(on: today) }
                }
            }
        }
        nutritionManager.configure(userId: uid, user: appState.currentUser)
        nutritionManager.reloadBurnedCalories()

        let completedAll = allExercises.filter { entry in
            let entryDate = Calendar.current.startOfDay(for: entry.date)
            return entry.isCompleted(on: entryDate)
        }
        let totalBurned = completedAll.reduce(0) { $0 + $1.caloriesBurned }
        let cal = Calendar.current
        let hasEarlyBird = completedAll.contains { cal.component(.hour, from: $0.date) < 7 }
        let hasNightOwl = completedAll.contains { cal.component(.hour, from: $0.date) >= 21 }
        let hasLunch = completedAll.contains {
            let h = cal.component(.hour, from: $0.date)
            return h >= 12 && h < 14
        }
        let hasDouble = Dictionary(grouping: completedAll) {
            cal.startOfDay(for: $0.date)
        }.values.contains { $0.count >= 2 }
        let longestMins = completedAll.compactMap { $0.duration }.max() ?? 0
        let hasZeroCal = completedAll.contains { $0.caloriesBurned == 0 }
        let hasSame5 = Dictionary(grouping: completedAll, by: { $0.name }).values.contains { $0.count >= 5 }
        let sortedDates = completedAll.map { cal.startOfDay(for: $0.date) }.sorted()
        let hadBreak = zip(sortedDates, sortedDates.dropFirst()).contains {
            (cal.dateComponents([.day], from: $0, to: $1).day ?? 0) >= 7
        }
        let daysFromMon = (cal.component(.weekday, from: Date()) + 5) % 7
        let monday = cal.date(byAdding: .day, value: -daysFromMon, to: cal.startOfDay(for: Date())) ?? Date()
        let thisWeek = completedAll.filter { $0.date >= monday }
        let categoriesThisWeek = Set(thisWeek.map { $0.category.rawValue })
        let satCount = thisWeek.filter { cal.component(.weekday, from: $0.date) == 7 }.count
        let sunCount = thisWeek.filter { cal.component(.weekday, from: $0.date) == 1 }.count
        let weekendCount = (satCount > 0 ? 1 : 0) + (sunCount > 0 ? 1 : 0)
        let cardioCount = completedAll.filter { $0.category == .cardio }.count
        let coreCount = completedAll.filter { $0.category == .flexibility }.count
        let strengthCount = completedAll.filter { $0.category == .strength }.count

        Task {
            await AchievementService.shared.evaluateAndUnlock(
                userId: uid,
                workoutStreak: workoutStreak,
                totalWorkouts: completedAll.count,
                totalCaloriesBurned: totalBurned,
                waterGoalDaysHit: waterConsumed >= waterGoal ? 1 : 0,
                weightEntries: [],
                targetWeightLbs: appState.currentUser?.targetWeightLbs,
                hasEarlyBirdWorkout: hasEarlyBird,
                hasNightOwlWorkout: hasNightOwl,
                hasLunchBreakWorkout: hasLunch,
                hadBreakBeforeReturn: hadBreak,
                hasZeroCalWorkout: hasZeroCal,
                hasSameWorkout5Times: hasSame5,
                hasDoubleSessionDay: hasDouble,
                longestWorkoutMinutes: longestMins,
                categoriesThisWeek: categoriesThisWeek,
                weekendWorkoutsThisWeek: weekendCount,
                cardioWorkouts: cardioCount,
                coreWorkouts: coreCount,
                strengthWorkouts: strengthCount,
                hasLogged30DaysAny: workoutStreak >= 30
            )
        }
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greeting), \(firstName)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.brandCream)
                Text("Let's keep today moving.")
                    .font(.subheadline)
                    .foregroundColor(Color.brandCream.opacity(0.5))
            }
            Spacer()
            HStack(spacing: 8) {
                Button {
                    showProfile = true
                } label: {
                    ProfileAvatar(
                        imageData: dashboardProfileImageData,
                        initials: dashboardInitials
                    )
                    .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                Button {
                    showSettingsSheet = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.brandCream.opacity(0.06))
                            .frame(width: 48, height: 48)
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.brandLime)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Today Prompt Card

    private var todayPromptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles").foregroundColor(.brandLime)
                Text("Today's Check-In")
                    .font(.headline)
                    .foregroundColor(.brandCream)
                Spacer()
            }
            Text(dashboardMessage)
                .font(.subheadline)
                .foregroundColor(Color.brandCream.opacity(0.6))
            HStack(spacing: 10) {
                statusPill(title: "Workout", complete: didLogWorkoutToday, color: Color(red: 0.25, green: 0.72, blue: 0.55))
                statusPill(title: "Food", complete: didLogFoodToday, color: .brandOrange)
                statusPill(title: "Water", complete: didMeetWaterHalfway, color: .brandBlue)
            }
        }
        .padding()
        .background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func statusPill(title: String, complete: Bool, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: complete ? "checkmark.circle.fill" : "circle")
            Text(title)
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundColor(complete ? .brandNavy : color)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule().fill(complete ? color : color.opacity(0.15)))
    }

    // MARK: - Calorie Card

    private var calorieCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Calories")
                    .font(.headline)
                    .foregroundColor(.brandCream)
                Spacer()
                Text("\(Int(nutritionManager.totalCalories)) / \(Int(calorieGoal)) kcal")
                    .font(.subheadline)
                    .foregroundColor(Color.brandCream.opacity(0.5))
            }
            ProgressView(value: calorieProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .brandOrange))
                .scaleEffect(x: 1, y: 2)
            HStack(spacing: 0) {
                MacroCard(value: Int(nutritionManager.totalProtein), label: "Protein", color: .brandBlue)
                Divider().frame(height: 40).background(Color.brandCream.opacity(0.12))
                MacroCard(value: Int(nutritionManager.totalCarbs), label: "Carbs", color: Color(red: 0.25, green: 0.72, blue: 0.55))
                Divider().frame(height: 40).background(Color.brandCream.opacity(0.12))
                MacroCard(value: Int(nutritionManager.totalFat), label: "Fat", color: .brandOrange)
            }
        }
        .padding()
        .background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Water Card

    private var waterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Water Intake", systemImage: "drop.fill")
                    .font(.headline)
                    .foregroundColor(.brandBlue)
                Spacer()
                Text("\(waterConsumed) / \(waterGoal) glasses")
                    .font(.subheadline)
                    .foregroundColor(Color.brandCream.opacity(0.5))
                Button {
                    tempWaterGoal = waterGoal
                    showWaterGoalEditor = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.brandBlue.opacity(0.7))
                }
            }

            ProgressView(value: Double(waterConsumed), total: Double(max(waterGoal, 1)))
                .progressViewStyle(LinearProgressViewStyle(tint: .brandBlue))
                .scaleEffect(x: 1, y: 2)

            HStack(spacing: 8) {
                Button {
                    if waterConsumed > 0 {
                        waterConsumed -= 1
                        syncDailyLog()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color.brandCream.opacity(0.4))
                }
                Spacer()
                Text("\(waterConsumed) of \(waterGoal) glasses today")
                    .font(.caption)
                    .foregroundColor(Color.brandCream.opacity(0.5))
                Spacer()
                Button {
                    if waterConsumed < waterGoal {
                        waterConsumed += 1
                        syncDailyLog()
                        print("💧 Water incremented to \(waterConsumed), syncing to Supabase")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.brandBlue)
                }
            }
        }
        .padding()
        .background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
        .cornerRadius(16)
        .padding(.horizontal)
        .sheet(isPresented: $showWaterGoalEditor) {
            waterGoalEditorSheet
        }
    }

    private var waterGoalEditorSheet: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()
            VStack(spacing: 32) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.brandCream.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)

                Text("Daily Water Goal")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.brandCream)

                Text("How many glasses of water do you want to drink per day?")
                    .font(.subheadline)
                    .foregroundColor(Color.brandCream.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text("\(tempWaterGoal)")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundColor(.brandLime)

                Text("glasses / day")
                    .font(.subheadline)
                    .foregroundColor(Color.brandCream.opacity(0.5))

                HStack(spacing: 48) {
                    Button {
                        if tempWaterGoal > 1 { tempWaterGoal -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(tempWaterGoal > 1 ? .brandCream.opacity(0.4) : Color.brandCream.opacity(0.15))
                    }
                    .disabled(tempWaterGoal <= 1)

                    Button {
                        if tempWaterGoal < 20 { tempWaterGoal += 1 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.brandLime)
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
                                .foregroundColor(tempWaterGoal == preset ? .brandNavy : .brandLime)
                                .frame(width: 48, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(tempWaterGoal == preset ? Color.brandLime : Color.brandLime.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    waterGoal = tempWaterGoal
                    if waterConsumed > waterGoal {
                        waterConsumed = waterGoal
                    }
                    syncDailyLog()
                    showWaterGoalEditor = false
                } label: {
                    Text("Save Goal")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.brandNavy)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.brandLime)
                        .cornerRadius(14)
                }
                .padding(.horizontal)

                Spacer()
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Quick Stats Bar

    private var quickStatsBar: some View {
        HStack(spacing: 0) {
            QuickStatCell(value: "\(workoutStreak)", label: "Day Streak", icon: "flame.fill", color: .brandOrange)
            Divider().frame(height: 40).background(Color.brandCream.opacity(0.12))
            QuickStatCell(value: "\(activeThisWeek)", label: "Active Days", icon: "calendar.badge.checkmark", color: Color(red: 0.25, green: 0.72, blue: 0.55))
            Divider().frame(height: 40).background(Color.brandCream.opacity(0.12))
            QuickStatCell(value: "\(workoutsThisMonth)", label: "This Month", icon: "chart.bar.fill", color: .brandBlue)
        }
        .padding(.vertical, 12)
        .background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Weekly Rings Card

    private var weeklyRingsCard: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let daysFromMon = (cal.component(.weekday, from: today) + 5) % 7
        let monday = cal.date(byAdding: .day, value: -daysFromMon, to: today) ?? today
        let weekDays = (0...6).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
        let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]
        let calorieTarget = nutritionManager.calorieTarget
        let uid = appState.currentUser?.id ?? ""

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("This Week", systemImage: "circle.grid.3x3.fill")
                    .font(.headline)
                    .foregroundColor(.brandCream)
                Spacer()
                HStack(spacing: 10) {
                    weekLegendItem(color: .brandLime,   label: "Activity")
                    weekLegendItem(color: .brandOrange, label: "Nutrition")
                    weekLegendItem(color: .brandBlue,   label: "Water")
                }
            }

            HStack(spacing: 6) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { idx, date in
                    VStack(spacing: 6) {
                        WeekDayRing(
                            date: date,
                            userId: uid,
                            calorieTarget: calorieTarget,
                            waterGoal: waterGoal,
                            allExercises: allExercises
                        )
                        Text(dayLetters[idx])
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(
                                cal.isDateInToday(date)
                                    ? .brandLime
                                    : Color.brandCream.opacity(0.4)
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func weekLegendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color.brandCream.opacity(0.5))
        }
    }

    // MARK: - Weight Thumbnail Card

    private var weightThumbnailCard: some View {
        let isLose     = appState.currentUser?.primaryGoal == "Lose Weight"
        let lineColor: Color = isLose ? .brandOrange : .brandLime
        let current    = weightEntries.last?.weightLbs ?? 0
        let start      = weightEntries.first?.weightLbs ?? 0
        let delta      = current - start
        let deltaPositive = delta >= 0
        let deltaColor: Color = abs(delta) < 0.05
            ? Color.brandCream.opacity(0.5)
            : (isLose
               ? (delta < 0 ? .brandLime : .brandOrange)
               : (delta > 0 ? .brandLime : .brandOrange))
        let hasChartData = weightEntries.count >= 2

        return Button {
            showWeightTracker = true
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Weight", systemImage: "scalemass.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.brandCream.opacity(0.5))

                    if isLoadingWeight {
                        ProgressView()
                            .tint(.brandLime)
                            .scaleEffect(0.7)
                            .frame(height: 30)
                    } else {
                        Text("\(Int(latestWeight ?? appState.currentUser?.weightLbs ?? 0)) lbs")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.brandCream)

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
                            .background(deltaColor.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                }
                .frame(width: 110, alignment: .leading)

                Group {
                    if isLoadingWeight {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.brandCream.opacity(0.06))
                            .overlay(ProgressView().tint(.brandLime).scaleEffect(0.7))
                    } else if !hasChartData {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(lineColor.opacity(0.08))
                            .overlay(
                                VStack(spacing: 4) {
                                    Circle().fill(lineColor).frame(width: 10, height: 10)
                                    Text("Log more to\nsee your trend")
                                        .font(.system(size: 9))
                                        .foregroundColor(Color.brandCream.opacity(0.4))
                                        .multilineTextAlignment(.center)
                                }
                            )
                    } else {
                        let ws   = weightEntries.map { $0.weightLbs }
                        let yMin = (ws.min() ?? 100) - 2
                        let yMax = (ws.max() ?? 200) + 2
                        Chart {
                            ForEach(weightEntries) { e in
                                AreaMark(x: .value("Date", e.chartLabel), y: .value("Weight", e.weightLbs))
                                    .foregroundStyle(lineColor.opacity(0.08))
                                    .interpolationMethod(.linear)
                            }
                            ForEach(weightEntries) { e in
                                LineMark(x: .value("Date", e.chartLabel), y: .value("Weight", e.weightLbs))
                                    .foregroundStyle(lineColor)
                                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                                    .interpolationMethod(.linear)
                            }
                            ForEach(weightEntries) { e in
                                PointMark(x: .value("Date", e.chartLabel), y: .value("Weight", e.weightLbs))
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
                    .foregroundColor(Color.brandCream.opacity(0.3))
            }
            .padding()
            .background(Color.brandCream.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
            .cornerRadius(16)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Today's Workouts Card

    private var todaysWorkoutsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Today's Workouts", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundColor(.brandCream)
                Spacer()
                if !completedWorkouts.isEmpty {
                    Text("\(totalBurnedToday) kcal burned")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.brandOrange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.brandOrange.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            if completedWorkouts.isEmpty {
                Text("No workouts completed yet. Once you mark one done, it shows up here.")
                    .font(.subheadline)
                    .foregroundColor(Color.brandCream.opacity(0.5))
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
                                .foregroundColor(.brandCream)
                            if let duration = workout.duration {
                                Text("\(duration) min • \(workout.caloriesBurned) kcal")
                                    .font(.caption)
                                    .foregroundColor(Color.brandCream.opacity(0.5))
                            } else {
                                Text("\(workout.sets) sets × \(workout.reps) reps")
                                    .font(.caption)
                                    .foregroundColor(Color.brandCream.opacity(0.5))
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func refreshLatestWeight() async {
        isLoadingWeight = true
        let entries = await WeightLogService.shared.fetchEntries(userId: userId)
        weightEntries = entries
        latestWeight = entries.last?.weightLbs
        isLoadingWeight = false
    }

    private func loadWeightEntries() async {
        weightEntries = await WeightLogService.shared.fetchEntries(userId: userId)
        latestWeight = weightEntries.last?.weightLbs
    }

    private func loadTodayLog() async {
        guard !userId.isEmpty else { return }
        print("🔍 Loading daily log for userId: \(userId)")
        if let log = try? await DailyLogService.shared.fetchTodayLog(userId: userId) {
            print("💧 Loaded water from Supabase: \(log.water_consumed)")
            waterConsumed = log.water_consumed
        } else {
            print("💧 No daily log found for today")
        }
    }

    private func syncDailyLog() {
        guard !userId.isEmpty else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let todayWorkouts = allExercises.filter { $0.isCompleted(on: today) }
        let burned = todayWorkouts.reduce(0) { $0 + $1.caloriesBurned }
        let count = todayWorkouts.count
        let caloriesEaten = nutritionManager.totalCalories
        print("💧 Syncing water=\(waterConsumed) to daily_logs")
        Task {
            try? await DailyLogService.shared.upsertLog(
                userId: userId,
                waterConsumed: waterConsumed,
                waterGoal: waterGoal,
                caloriesEaten: caloriesEaten,
                caloriesBurned: burned,
                workoutsCompleted: count
            )
        }
    }

}

// MARK: - MacroCard

private struct MacroCard: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)g")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.brandCream)
            Text(label)
                .font(.caption)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - QuickStatCell

private struct QuickStatCell: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.brandCream)
            Text(label)
                .font(.caption2)
                .foregroundColor(Color.brandCream.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - WeekDayRing

private struct WeekDayRing: View {
    let date: Date
    let userId: String
    let calorieTarget: Int
    let waterGoal: Int
    let allExercises: [ActivityEntry]

    private var cal: Calendar { Calendar.current }
    private var isToday: Bool  { cal.isDateInToday(date) }
    private var isFuture: Bool { date > cal.startOfDay(for: Date()) }
    private var dayNum: Int    { cal.component(.day, from: date) }

    private var hasActivity: Bool {
        let day = cal.startOfDay(for: date)
        return allExercises.contains { $0.isCompleted(on: day) }
    }

    private var calorieProgress: Double {
        guard calorieTarget > 0, !isFuture else { return 0 }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let key = "nutritionLog_\(userId)_\(f.string(from: date))"
        guard let data = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONDecoder().decode([LoggedFoodEntry].self, from: data)
        else { return 0 }
        let total = entries.reduce(0.0) { $0 + $1.foodItem.calories }
        return min(total / Double(calorieTarget), 1.0)
    }

    private var waterProgress: Double {
        guard waterGoal > 0, !isFuture else { return 0 }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let key = "waterConsumed_\(userId)_\(f.string(from: date))"
        let consumed = UserDefaults.standard.integer(forKey: key)
        return min(Double(consumed) / Double(waterGoal), 1.0)
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size.width
            let lineW = size * 0.09
            let pad   = size * 0.06

            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isToday ? Color.brandLime.opacity(0.08) : Color.brandCream.opacity(0.03))

                if !isFuture {
                    // Outer — Activity (lime)
                    ZStack {
                        Circle().stroke(Color.brandLime.opacity(0.18), lineWidth: lineW)
                        Circle()
                            .trim(from: 0, to: hasActivity ? 1.0 : 0)
                            .stroke(Color.brandLime, style: StrokeStyle(lineWidth: lineW, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .padding(pad)

                    // Middle — Nutrition (orange)
                    ZStack {
                        Circle().stroke(Color.brandOrange.opacity(0.18), lineWidth: lineW)
                        Circle()
                            .trim(from: 0, to: calorieProgress)
                            .stroke(Color.brandOrange, style: StrokeStyle(lineWidth: lineW, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .padding(pad + lineW * 1.4)

                    // Inner — Water (blue)
                    ZStack {
                        Circle().stroke(Color.brandBlue.opacity(0.18), lineWidth: lineW)
                        Circle()
                            .trim(from: 0, to: waterProgress)
                            .stroke(Color.brandBlue, style: StrokeStyle(lineWidth: lineW, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .padding(pad + lineW * 2.8)
                }

                if isToday {
                    RoundedRectangle(cornerRadius: 6).stroke(Color.brandLime, lineWidth: 1.5)
                }

                Text("\(dayNum)")
                    .font(.system(size: size * 0.22, weight: isToday ? .black : .regular, design: .rounded))
                    .foregroundColor(
                        isFuture    ? Color.brandCream.opacity(0.2) :
                        isToday     ? Color.brandLime :
                        hasActivity ? Color.brandLime : Color.brandCream.opacity(0.6)
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
