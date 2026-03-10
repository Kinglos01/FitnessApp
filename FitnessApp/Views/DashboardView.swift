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

    let calorieGoal: Double = 2200
    let waterGoal: Int = 8
    @State private var waterConsumed: Int = 0
    @State private var showSettings: Bool = false
    @State private var completedWorkouts: [ActivityEntry] = []

    private var firstName: String {
        let full = appState.currentUser?.name ?? ""
        let first = full.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? "Friend" : first
    }

    var calorieProgress: Double {
        min(nutritionManager.totalCalories / calorieGoal, 1.0)
    }

    let workoutStreak: Int = 0

    var activeThisWeek: Int { workoutStreak }
    var workoutsThisMonth: Int { workoutStreak * 5 }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning" }
        else if hour < 17 { return "Good Afternoon" }
        else { return "Good Evening" }
    }

    // Total calories burned from completed workouts today
    private var totalBurnedToday: Int {
        completedWorkouts.reduce(0) { $0 + $1.caloriesBurned }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    greetingHeader
                    if showSettings { settingsDropdown }
                    calorieCard
                    waterCard
                    quickStatsBar
                    todaysWorkoutsCard
                    if !nutritionManager.loggedFoods.isEmpty { foodLogPreview }
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
        }
        .onAppear { reloadWorkouts() }
        // Re-read whenever the app comes back to foreground
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            reloadWorkouts()
        }
    }

    private func reloadWorkouts() {
        let userId = appState.currentUser?.id ?? ""
        completedWorkouts = DashboardWorkoutReader.completedToday(userId: userId)
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
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { showSettings.toggle() }
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
            }
            Divider()
            settingsRow(icon: "gearshape", label: "Settings", color: .primary) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { showSettings = false }
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
            }
            HStack(spacing: 8) {
                ForEach(0..<waterGoal, id: \.self) { index in
                    Image(systemName: index < waterConsumed ? "drop.fill" : "drop")
                        .foregroundColor(index < waterConsumed ? .blue : .gray.opacity(0.3))
                        .font(.title3)
                }
                Spacer()
                Button {
                    if waterConsumed > 0 { waterConsumed -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill").font(.title2).foregroundColor(.gray)
                }
                Button {
                    if waterConsumed < waterGoal { waterConsumed += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
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

#Preview {
    DashboardView()
        .environment(NutritionManager())
        .environment(AppState())
}
