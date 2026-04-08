//
//  CalendarView.swift
//  FitnessApp
//
//  Created by Carlos Berio on 3/27/26.
//
import SwiftUI

// MARK: - Calendar Data Engine

struct DaySnapshot: Identifiable {
    var id: Date { date }
    let date: Date
    let completedWorkouts: [ActivityEntry]
    let totalCalories: Double
    let calorieTarget: Int
    let loggedFoods: [LoggedFoodEntry]
    let waterConsumed: Int
    let waterGoal: Int

    var hasActivity: Bool { !completedWorkouts.isEmpty }
    var calorieProgress: Double {
        guard calorieTarget > 0 else { return 0 }
        return min(totalCalories / Double(calorieTarget), 1.0)
    }
    var activityIntensity: Double {
        let totalCals = completedWorkouts.reduce(0) { $0 + $1.caloriesBurned }
        return min(Double(totalCals) / 500.0, 1.0)
    }
    var isToday: Bool { Calendar.current.isDateInToday(date) }
    var isFuture: Bool { date > Calendar.current.startOfDay(for: Date()) }
}

@Observable
private class CalendarDataEngine {
    var snapshots: [Date: DaySnapshot] = [:]

    private var userId: String = ""
    private var calorieTarget: Int = 2000
    private var waterGoal: Int = 8

    func load(userId: String, calorieTarget: Int, waterGoal: Int) {
        self.userId        = userId
        self.calorieTarget = calorieTarget
        self.waterGoal     = waterGoal
        buildSnapshots()
        Task { await fetchFromSupabase() }
    }

    func reload() {
        buildSnapshots()
        Task { await fetchFromSupabase() }
    }

    private func buildSnapshots() {
        let cal = Calendar.current
        guard let start = cal.date(from: DateComponents(year: 2026, month: 1, day: 1)),
              let end   = cal.date(from: DateComponents(year: 2026, month: 12, day: 31))
        else { return }

        let allExercises = loadExercises()
        var result: [Date: DaySnapshot] = [:]
        var current = cal.startOfDay(for: start)
        let endDay  = cal.startOfDay(for: end)

        while current <= endDay {
            let workouts = allExercises.filter {
                cal.startOfDay(for: $0.date) == current && $0.isCompleted
            }
            let (calories, foods) = loadNutrition(for: current)
            let water = loadWater(for: current)
            result[current] = DaySnapshot(
                date: current,
                completedWorkouts: workouts,
                totalCalories: calories,
                calorieTarget: calorieTarget,
                loggedFoods: foods,
                waterConsumed: water,
                waterGoal: waterGoal
            )
            current = cal.date(byAdding: .day, value: 1, to: current)!
        }
        snapshots = result
    }

    // Fetches from Supabase and overlays water data on top of local snapshots
    @MainActor
    private func fetchFromSupabase() async {
        guard !userId.isEmpty,
              let start = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1)),
              let end   = Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 31))
        else { return }

        guard let logs = try? await DailyLogService.shared.fetchLogs(
            userId: userId, from: start, to: end
        ) else { return }

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"

        for log in logs {
            guard let date = f.date(from: log.date) else { continue }
            let day = Calendar.current.startOfDay(for: date)
            guard let snapshot = snapshots[day] else { continue }
            snapshots[day] = DaySnapshot(
                date: snapshot.date,
                completedWorkouts: snapshot.completedWorkouts,
                totalCalories: log.calories_eaten > 0 ? log.calories_eaten : snapshot.totalCalories,
                calorieTarget: snapshot.calorieTarget,
                loggedFoods: snapshot.loggedFoods,
                waterConsumed: log.water_consumed,
                waterGoal: log.water_goal
            )
        }
    }

    private func loadExercises() -> [ActivityEntry] {
        let key = "savedExercises_\(userId)"
        guard let data    = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ActivityEntry].self, from: data)
        else { return [] }
        return decoded
    }

    private func loadNutrition(for date: Date) -> (Double, [LoggedFoodEntry]) {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let key = "nutritionLog_\(userId)_\(f.string(from: date))"
        guard let data    = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONDecoder().decode([LoggedFoodEntry].self, from: data)
        else { return (0, []) }
        let total = entries.reduce(0.0) { $0 + $1.foodItem.calories }
        return (total, entries)
    }

    private func loadWater(for date: Date) -> Int {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let key = "waterConsumed_\(userId)_\(f.string(from: date))"
        return UserDefaults.standard.integer(forKey: key)
    }
}

// MARK: - Main Calendar View

struct CalendarView: View {
    @Environment(AppState.self) var appState
    @Environment(NutritionManager.self) var nutritionManager
    @AppStorage("waterGoal") private var waterGoal: Int = 8

    @State private var engine = CalendarDataEngine()
    @State private var selectedDay: DaySnapshot? = nil

    private let columns          = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekDayInitials  = ["M", "T", "W", "T", "F", "S", "S"]

    private var days: [Date] {
        let cal = Calendar.current
        var comps = DateComponents(year: 2026, month: 1, day: 1)
        guard let start = cal.date(from: comps) else { return [] }
        comps = DateComponents(year: 2026, month: 12, day: 31)
        guard let end = cal.date(from: comps) else { return [] }
        var dates: [Date] = []
        var current = cal.startOfDay(for: start)
        let endDay  = cal.startOfDay(for: end)
        while current <= endDay {
            dates.append(current)
            current = cal.date(byAdding: .day, value: 1, to: current)!
        }
        return dates
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    legend
                    calendarGrid
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Calendar")
            .onAppear { loadData() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                engine.reload()
            }
            .sheet(item: $selectedDay) { day in
                DayDetailSheet(snapshot: day).environment(appState)
            }
        }
    }

    private func loadData() {
        engine.load(
            userId: appState.currentUser?.id ?? "guest",
            calorieTarget: nutritionManager.calorieTarget,
            waterGoal: waterGoal
        )
    }

    // MARK: - Legend
    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: Color(red: 0.25, green: 0.72, blue: 0.55), label: "Activity")
            legendItem(color: .orange, label: "Nutrition")
            legendItem(color: .cyan,   label: "Water")
            Spacer()
            Text("Tap for details").font(.caption2).foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }

    private var monthGroups: [(title: String, days: [Date])] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        var groups: [(title: String, days: [Date])] = []
        var current: [Date] = []
        var currentMonth = -1

        for date in days {
            let month = cal.component(.month, from: date)
            let year  = cal.component(.year,  from: date)
            let key   = year * 100 + month
            if key != currentMonth {
                if !current.isEmpty {
                    groups.append((title: formatter.string(from: current[0]), days: current))
                }
                current = []
                currentMonth = key
            }
            current.append(date)
        }
        if !current.isEmpty {
            groups.append((title: formatter.string(from: current[0]), days: current))
        }
        return groups
    }

    private var calendarGrid: some View {
        VStack(spacing: 20) {
            ForEach(monthGroups, id: \.title) { group in
                monthSection(title: group.title, days: group.days)
            }
        }
    }

    private func monthSection(title: String, days: [Date]) -> some View {
        let cal      = Calendar.current
        let firstDay = days[0]
        let wd       = cal.component(.weekday, from: firstDay)
        let blanks   = (wd + 5) % 7

        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.horizontal, 4)

            HStack(spacing: 4) {
                ForEach(Array(weekDayInitials.enumerated()), id: \.offset) { _, initial in
                    Text(initial)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<blanks, id: \.self) { _ in
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
                ForEach(days, id: \.self) { date in
                    DayCell(snapshot: engine.snapshots[date], date: date)
                        .onTapGesture {
                            if date <= cal.startOfDay(for: Date()),
                               let snap = engine.snapshots[date] {
                                selectedDay = snap
                            }
                        }
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Day Cell

struct DayCell: View {
    let snapshot: DaySnapshot?
    let date: Date

    private var isFuture: Bool { date > Calendar.current.startOfDay(for: Date()) }
    private var isToday: Bool  { Calendar.current.isDateInToday(date) }
    private var dayNum: Int    { Calendar.current.component(.day, from: date) }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size.width
            ZStack {
                RoundedRectangle(cornerRadius: 5).fill(cellBackground)

                if let snap = snapshot, !isFuture {
                    let ringPad = size * 0.06
                    let lineW   = size * 0.07

                    ZStack {
                        Circle().stroke(Color(red: 0.25, green: 0.72, blue: 0.55).opacity(0.18), lineWidth: lineW)
                        Circle()
                            .trim(from: 0, to: snap.hasActivity ? 1.0 : 0)
                            .stroke(Color(red: 0.25, green: 0.72, blue: 0.55), style: StrokeStyle(lineWidth: lineW, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .padding(ringPad)

                    ZStack {
                        Circle().stroke(Color.orange.opacity(0.18), lineWidth: lineW)
                        Circle()
                            .trim(from: 0, to: snap.calorieProgress)
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: lineW, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .padding(ringPad + lineW * 1.4)

                    ZStack {
                        Circle().stroke(Color.cyan.opacity(0.18), lineWidth: lineW)
                        Circle()
                            .trim(from: 0, to: min(Double(snap.waterConsumed) / Double(max(snap.waterGoal, 1)), 1.0))
                            .stroke(Color.cyan, style: StrokeStyle(lineWidth: lineW, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .padding(ringPad + lineW * 2.8)
                }

                if isToday {
                    RoundedRectangle(cornerRadius: 5).stroke(Color.primary, lineWidth: 1.5)
                }

                Text("\(dayNum)")
                    .font(.system(size: size * 0.22, weight: isToday ? .black : .regular, design: .rounded))
                    .foregroundColor(dayNumberColor)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var cellBackground: Color {
        if isFuture { return Color(.systemGray5).opacity(0.3) }
        guard let snap = snapshot else { return Color(.systemGray5) }
        if snap.hasActivity {
            return Color(red: 0.25, green: 0.72, blue: 0.55).opacity(0.15 + snap.activityIntensity * 0.35)
        }
        if snap.totalCalories > 0 { return Color.orange.opacity(0.08) }
        return Color(.systemGray5)
    }

    private var dayNumberColor: Color {
        if isFuture { return .secondary.opacity(0.4) }
        if isToday  { return .primary }
        guard let snap = snapshot else { return .secondary }
        return snap.hasActivity ? Color(red: 0.15, green: 0.55, blue: 0.40) : .secondary
    }
}

// MARK: - Day Detail Sheet

struct DayDetailSheet: View {
    let snapshot: DaySnapshot
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) var appState

    private var dateTitle: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: snapshot.date)
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    summaryBanner
                    if !snapshot.completedWorkouts.isEmpty { workoutsSection }
                    nutritionSection
                    waterSection
                    Spacer(minLength: 40)
                }
                .padding(16)
            }
            .navigationTitle(dateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Summary Banner
    private var summaryBanner: some View {
        HStack(spacing: 0) {
            summaryCell(icon: "checkmark.circle.fill", color: Color(red: 0.25, green: 0.72, blue: 0.55),
                        value: "\(snapshot.completedWorkouts.count)", label: "Workouts")
            Divider().frame(height: 44)
            summaryCell(icon: "flame.fill", color: .orange,
                        value: "\(snapshot.completedWorkouts.reduce(0) { $0 + $1.caloriesBurned })", label: "Burned")
            Divider().frame(height: 44)
            summaryCell(icon: "fork.knife", color: .blue,
                        value: "\(Int(snapshot.totalCalories))", label: "Eaten")
            Divider().frame(height: 44)
            summaryCell(icon: "drop.fill", color: .cyan,
                        value: "\(snapshot.waterConsumed)/\(snapshot.waterGoal)", label: "Water")
        }
        .padding(.vertical, 14)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func summaryCell(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).foregroundColor(color).font(.system(size: 16))
            Text(value).font(.system(size: 18, weight: .black, design: .rounded))
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Workouts Section
    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Workouts", systemImage: "figure.strengthtraining.traditional").font(.headline)
            ForEach(snapshot.completedWorkouts) { workout in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(workout.category.color.opacity(0.15)).frame(width: 38, height: 38)
                        Image(systemName: workout.category.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(workout.category.color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.name).font(.subheadline).fontWeight(.semibold)
                        HStack(spacing: 8) {
                            Text(workout.category.rawValue).font(.caption).foregroundColor(workout.category.color)
                            if let dur = workout.duration {
                                Text("· \(dur) min").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                    if workout.caloriesBurned > 0 {
                        Text("\(workout.caloriesBurned) kcal").font(.caption).fontWeight(.bold).foregroundColor(.orange)
                    }
                    Image(systemName: "checkmark.circle.fill").foregroundColor(workout.category.color)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }

    // MARK: Nutrition Section
    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Nutrition", systemImage: "fork.knife.circle.fill").font(.headline)

            VStack(spacing: 8) {
                HStack {
                    Text("Calories").font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Text("\(Int(snapshot.totalCalories)) / \(snapshot.calorieTarget) kcal")
                        .font(.caption).foregroundColor(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.15)).frame(height: 10)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(snapshot.totalCalories > Double(snapshot.calorieTarget) ? Color.red : Color.orange)
                            .frame(width: geo.size.width * snapshot.calorieProgress, height: 10)
                    }
                }
                .frame(height: 10)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)

            if snapshot.loggedFoods.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "fork.knife.circle").foregroundColor(.gray.opacity(0.4)).font(.system(size: 28))
                    Text("No foods logged this day").font(.subheadline).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14).background(Color(.systemGray6)).cornerRadius(12)
            } else {
                ForEach(NutritionMealType.allCases, id: \.self) { mealType in
                    let entries = snapshot.loggedFoods.filter { $0.mealType == mealType }
                    if !entries.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: mealType.icon).foregroundColor(.orange).font(.caption)
                                Text(mealType.rawValue).font(.caption).fontWeight(.bold)
                                Spacer()
                                let total = entries.reduce(0.0) { $0 + $1.foodItem.calories }
                                Text("\(Int(total)) kcal").font(.caption2).foregroundColor(.secondary)
                            }
                            ForEach(entries) { entry in
                                HStack {
                                    Text(entry.foodItem.description).font(.caption).lineLimit(1)
                                    Spacer()
                                    Text("\(Int(entry.foodItem.calories)) kcal").font(.caption2).foregroundColor(.orange)
                                }
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color(.systemBackground)).cornerRadius(8)
                            }
                        }
                        .padding(10).background(Color(.systemGray6)).cornerRadius(12)
                    }
                }
            }
        }
    }

    // MARK: Water Section
    private var waterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Water", systemImage: "drop.fill").font(.headline).foregroundColor(.cyan)

            VStack(spacing: 8) {
                HStack {
                    Text("Intake").font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Text("\(snapshot.waterConsumed) / \(snapshot.waterGoal) glasses")
                        .font(.caption).foregroundColor(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.15)).frame(height: 10)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.cyan)
                            .frame(width: geo.size.width * min(Double(snapshot.waterConsumed) / Double(max(snapshot.waterGoal, 1)), 1.0), height: 10)
                    }
                }
                .frame(height: 10)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

#Preview {
    CalendarView()
        .environment(AppState())
        .environment(NutritionManager())
}
