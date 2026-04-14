import SwiftUI
import Combine

// MARK: - Models

struct ActivityEntry: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: ExerciseCategory
    var sets: Int
    var reps: Int
    var weight: Double?
    var duration: Int?
    var caloriesBurned: Int
    var notes: String
    var date: Date
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        name: String,
        category: ExerciseCategory,
        sets: Int = 3,
        reps: Int = 10,
        weight: Double? = nil,
        duration: Int? = nil,
        caloriesBurned: Int = 0,
        notes: String = "",
        date: Date = Date(),
        isCompleted: Bool = false
    ) {
        self.id             = id
        self.name           = name
        self.category       = category
        self.sets           = sets
        self.reps           = reps
        self.weight         = weight
        self.duration       = duration
        self.caloriesBurned = caloriesBurned
        self.notes          = notes
        self.date           = date
        self.isCompleted    = isCompleted
    }
}

enum ExerciseCategory: String, CaseIterable, Codable {
    case strength    = "Strength"
    case cardio      = "Cardio"
    case sports      = "Sports"
    case flexibility = "Flexibility"
    case outdoor     = "Outdoor"

    var icon: String {
        switch self {
        case .strength:    return "dumbbell.fill"
        case .cardio:      return "figure.run"
        case .sports:      return "sportscourt.fill"
        case .flexibility: return "figure.cooldown"
        case .outdoor:     return "sun.max.fill"
        }
    }

    var color: Color {
        switch self {
        case .strength:    return Color(red: 0.96, green: 0.35, blue: 0.35)
        case .cardio:      return Color(red: 0.25, green: 0.72, blue: 0.55)
        case .sports:      return Color(red: 0.65, green: 0.35, blue: 0.95)
        case .flexibility: return Color(red: 0.40, green: 0.60, blue: 0.95)
        case .outdoor:     return Color(red: 0.95, green: 0.78, blue: 0.22)
        }
    }

    var suggestedExercises: [String] {
        switch self {
        case .strength:    return ["Bench Press", "Squat", "Deadlift", "Shoulder Press", "Lat Pulldown", "Bicep Curl", "Leg Press"]
        case .cardio:      return ["Walk", "Jog", "Run", "Treadmill", "Elliptical", "Bike", "Stairmaster"]
        case .sports:      return ["Basketball", "Soccer", "Football", "Rock Climbing"]
        case .flexibility: return ["Yoga", "Pilates", "Stretching", "Mobility Flow"]
        case .outdoor:     return ["Hike", "Outdoor Run", "Cycling", "Trail Walk", "Stadium Steps"]
        }
    }

    var usesDuration: Bool {
        switch self {
        case .cardio, .sports, .flexibility, .outdoor: return true
        case .strength:                                return false
        }
    }
}

// MARK: - ViewModel

final class ActivityLogViewModel: ObservableObject {
    @Published var exercises: [ActivityEntry] = []
    @Published var showingAddSheet = false
    @Published var selectedFilter: ExerciseCategory? = nil
    @Published var editingExercise: ActivityEntry? = nil
    @Published var preselectedCategory: ExerciseCategory = .strength
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false

    let userId: String
    private var storageKey: String { "savedExercises_\(userId)" }

    private var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    init(userId: String) {
        self.userId = userId
        loadFromCache()
        Task { await loadFromSupabase() }
    }

    var filteredExercises: [ActivityEntry] {
        let sorted = exercises.sorted { $0.date > $1.date }
        let categoryFiltered: [ActivityEntry] = selectedFilter == nil
            ? sorted
            : sorted.filter { $0.category == selectedFilter }
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return categoryFiltered
        }
        return categoryFiltered.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.notes.localizedCaseInsensitiveContains(searchText)
        }
    }

    var totalCaloriesToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return exercises
            .filter { Calendar.current.startOfDay(for: $0.date) == today && $0.isCompleted }
            .reduce(0) { $0 + $1.caloriesBurned }
    }

    var totalWorkoutsToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return exercises.filter {
            Calendar.current.startOfDay(for: $0.date) == today && $0.isCompleted
        }.count
    }

    var totalMinutesToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return exercises
            .filter { Calendar.current.startOfDay(for: $0.date) == today && $0.isCompleted }
            .compactMap { $0.duration }
            .reduce(0, +)
    }

    var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = cal.startOfDay(for: Date())
        while true {
            let hasWorkout = exercises.contains {
                $0.isCompleted && cal.startOfDay(for: $0.date) == checkDate
            }
            if hasWorkout {
                streak += 1
                checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else { break }
        }
        return streak
    }

    var recentFavorites: [String] {
        let names = exercises.map { $0.name }
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }.prefix(6).map { $0 }
    }

    func add(_ exercise: ActivityEntry) {
        exercises.append(exercise)
        saveToCache()
        Task { try? await WorkoutService.shared.upsertWorkout(exercise, userId: userId) }
        syncDailyLog()
    }

    func update(_ exercise: ActivityEntry) {
        if let idx = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[idx] = exercise
            saveToCache()
            Task { try? await WorkoutService.shared.upsertWorkout(exercise, userId: userId) }
            syncDailyLog()
        }
    }

    func deleteEntry(_ entry: ActivityEntry) {
        exercises.removeAll { $0.id == entry.id }
        saveToCache()
        Task { try? await WorkoutService.shared.deleteWorkout(id: entry.id) }
        syncDailyLog()
    }

    func toggleComplete(_ entry: ActivityEntry) {
        if let idx = exercises.firstIndex(where: { $0.id == entry.id }) {
            let newValue = !exercises[idx].isCompleted
            exercises[idx].isCompleted = newValue
            if newValue { exercises[idx].date = Date() }
            let updated = exercises[idx]
            saveToCache()
            Task { try? await WorkoutService.shared.upsertWorkout(updated, userId: userId) }
            syncDailyLog()
        }
    }

    @MainActor
    func loadFromSupabase() async {
        guard !userId.isEmpty else { return }
        isLoading = true
        if let remote = try? await WorkoutService.shared.fetchWorkouts(userId: userId) {
            exercises = remote
            saveToCache()
        }
        isLoading = false
    }

    private func syncDailyLog() {
        guard !userId.isEmpty else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let todayWorkouts = exercises.filter {
            $0.isCompleted && Calendar.current.startOfDay(for: $0.date) == today
        }
        let burned        = todayWorkouts.reduce(0) { $0 + $1.caloriesBurned }
        let count         = todayWorkouts.count
        let waterKey      = "waterConsumed_\(userId)_\(todayString)"
        let waterConsumed = UserDefaults.standard.integer(forKey: waterKey)
        let waterGoal     = UserDefaults.standard.integer(forKey: "waterGoal")
        let nutritionKey  = "nutritionLog_\(userId)_\(todayString)"
        var caloriesEaten: Double = 0
        if let data    = UserDefaults.standard.data(forKey: nutritionKey),
           let entries = try? JSONDecoder().decode([LoggedFoodEntry].self, from: data) {
            caloriesEaten = entries.reduce(0) { $0 + $1.foodItem.calories }
        }
        Task {
            try? await DailyLogService.shared.upsertLog(
                userId: userId,
                waterConsumed: waterConsumed,
                waterGoal: waterGoal == 0 ? 8 : waterGoal,
                caloriesEaten: caloriesEaten,
                caloriesBurned: burned,
                workoutsCompleted: count
            )
        }
    }

    private func saveToCache() {
        if let data = try? JSONEncoder().encode(exercises) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadFromCache() {
        if let data    = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ActivityEntry].self, from: data) {
            exercises = decoded
        }
    }
}

// MARK: - Main View

struct ActivityLogView: View {
    @StateObject private var vm: ActivityLogViewModel
    @State private var animateStats = false
    @State private var showAIAssistant = false
    @Environment(AppState.self) var appState

    init(userId: String) {
        _vm = StateObject(wrappedValue: ActivityLogViewModel(userId: userId))
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    statsStrip
                    searchBar
                    categorySection
                    favoritesSection
                    exerciseList
                    Spacer(minLength: 120)
                }
                .padding(.vertical)
            }
            .navigationTitle("Activity Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAIAssistant = true } label: {
                        VStack(spacing: 2) {
                            ZStack {
                                Circle().fill(Color.orange).frame(width: 38, height: 38)
                                RobotIcon()
                            }
                            Text("Ask AI").font(.system(size: 9, weight: .bold)).foregroundColor(.orange)
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) { floatingAddButton }
            .sheet(isPresented: $vm.showingAddSheet) {
                AddExerciseSheet(
                    vm: vm,
                    editingExercise: nil,
                    initialCategory: vm.preselectedCategory,
                    userWeightKg: appState.currentUser?.weightKg ?? 70,
                    isImperial: appState.currentUser?.units == "Imperial"
                )
            }
            .sheet(item: $vm.editingExercise) { exercise in
                AddExerciseSheet(
                    vm: vm,
                    editingExercise: exercise,
                    initialCategory: exercise.category,
                    userWeightKg: appState.currentUser?.weightKg ?? 70,
                    isImperial: appState.currentUser?.units == "Imperial"
                )
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { animateStats = true }
        }
        .sheet(isPresented: $showAIAssistant) {
            AIAssistantSheet().environment(appState)
        }
    }

    private var statsStrip: some View {
        HStack(spacing: 12) {
            StatCard(value: "\(vm.totalWorkoutsToday)", label: "Workouts", icon: "checkmark.circle.fill", color: .green,  animate: animateStats)
            StatCard(value: "\(vm.totalCaloriesToday)", label: "Calories",  icon: "flame.fill",            color: .orange, animate: animateStats)
            StatCard(value: "\(vm.currentStreak)",      label: "Streak",    icon: "bolt.fill",             color: .blue,   animate: animateStats)
        }
        .padding(.horizontal)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("Search workouts or notes", text: $vm.searchText)
                .textInputAutocapitalization(.words)
            if !vm.searchText.isEmpty {
                Button { vm.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(14)
        .padding(.horizontal)
    }

    private var categorySection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(label: "All", icon: "square.grid.2x2.fill", color: .blue, isSelected: vm.selectedFilter == nil) {
                    withAnimation { vm.selectedFilter = nil }
                }
                ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                    FilterChip(label: cat.rawValue, icon: cat.icon, color: cat.color, isSelected: vm.selectedFilter == cat) {
                        withAnimation { vm.selectedFilter = vm.selectedFilter == cat ? nil : cat }
                    }
                }
            }
            .padding(.horizontal).padding(.vertical, 4)
        }
    }

    private var favoritesSection: some View {
        Group {
            if !vm.recentFavorites.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Quick Add").font(.headline).padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(vm.recentFavorites, id: \.self) { name in
                                Button {
                                    vm.preselectedCategory = .strength
                                    vm.showingAddSheet = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "sparkles")
                                        Text(name).lineLimit(1)
                                    }
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(Color(.systemGray6)).cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    private var exerciseList: some View {
        LazyVStack(spacing: 12) {
            if vm.isLoading && vm.exercises.isEmpty {
                ProgressView().padding(.top, 40)
            } else if vm.filteredExercises.isEmpty {
                emptyState
            } else {
                ForEach(vm.filteredExercises) { exercise in
                    ExerciseRow(
                        exercise: exercise,
                        onDelete: { withAnimation { vm.deleteEntry(exercise) } },
                        onToggleComplete: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                vm.toggleComplete(exercise)
                            }
                        }
                    )
                    .onTapGesture { vm.editingExercise = exercise }
                    .contextMenu {
                        Button { vm.editingExercise = exercise } label: { Label("Edit", systemImage: "pencil") }
                        Button(role: .destructive) { vm.deleteEntry(exercise) } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 52)).foregroundColor(.gray.opacity(0.3))
            Text("No workouts yet")
                .font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundColor(.gray)
            Text("Tap the button below and log something for today.")
                .font(.system(size: 14)).foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    private var floatingAddButton: some View {
        Button {
            vm.preselectedCategory = vm.selectedFilter ?? .strength
            vm.showingAddSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("Log Workout")
            }
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 28).padding(.vertical, 16)
            .background(Color.blue)
            .clipShape(Capsule())
            .shadow(color: Color.blue.opacity(0.35), radius: 10, x: 0, y: 4)
        }
        .padding(.bottom, 30)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    let animate: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(.primary)
                .scaleEffect(animate ? 1.0 : 0.5)
                .opacity(animate ? 1.0 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: animate)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)))
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(label).font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(isSelected ? color : Color(.systemGray5)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exercise Row

struct ExerciseRow: View {
    let exercise: ActivityEntry
    let onDelete: () -> Void
    let onToggleComplete: () -> Void

    private var subtitleText: String {
        if let duration = exercise.duration {
            return "\(duration) min • \(exercise.caloriesBurned) kcal"
        } else {
            let weightText = exercise.weight.map { " • \(Int($0)) lbs" } ?? ""
            return "\(exercise.sets) sets × \(exercise.reps) reps\(weightText)"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(exercise.isCompleted ? exercise.category.color : exercise.category.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: exercise.isCompleted ? "checkmark" : exercise.category.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(exercise.isCompleted ? .white : exercise.category.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(exercise.isCompleted ? .gray : .primary)
                    .strikethrough(exercise.isCompleted)
                Text(subtitleText).font(.caption).foregroundColor(.gray)
                if !exercise.notes.isEmpty {
                    Text(exercise.notes).font(.caption2).foregroundColor(.gray.opacity(0.75)).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Text(exercise.category.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(exercise.category.color)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(exercise.category.color.opacity(0.15))
                    .clipShape(Capsule())
                Button { onToggleComplete() } label: {
                    Text(exercise.isCompleted ? "Done" : "Mark Done")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(exercise.isCompleted ? .white : exercise.category.color)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(exercise.isCompleted ? exercise.category.color : exercise.category.color.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(exercise.isCompleted ? Color(.systemGray6).opacity(0.6) : Color(.systemGray6)))
    }
}

// MARK: - Add / Edit Sheet

struct AddExerciseSheet: View {
    @ObservedObject var vm: ActivityLogViewModel
    let editingExercise: ActivityEntry?
    let initialCategory: ExerciseCategory
    let userWeightKg: Double
    let isImperial: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: ExerciseCategory = .strength
    @State private var sets = 3
    @State private var reps = 10
    @State private var weight = ""
    @State private var duration = ""
    @State private var calories = ""
    @State private var notes = ""
    @State private var showCalcSheet = false

    private var isEditing: Bool { editingExercise != nil }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    categoryPickerSection
                    suggestedExercisesSection
                    detailsSection
                    notesSection
                    saveButton
                }
                .padding()
            }
            .navigationTitle(isEditing ? "Edit Workout" : "Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                if isEditing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            if let e = editingExercise { vm.deleteEntry(e) }
                            dismiss()
                        } label: { Image(systemName: "trash") }
                    }
                }
            }
        }
        .onAppear { populateIfNeeded() }
        .sheet(isPresented: $showCalcSheet) {
            CalorieCalculatorSheet(
                category: category,
                workoutName: name,
                userWeightKg: userWeightKg,
                isImperial: isImperial
            ) { calculatedCalories, calculatedDuration in
                calories = "\(calculatedCalories)"
                if let d = calculatedDuration { duration = "\(d)" }
            }
        }
    }

    private var categoryPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category").font(.caption).foregroundColor(.gray).textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                        Button {
                            category = cat
                            if name.isEmpty { name = cat.suggestedExercises.first ?? "" }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: cat.icon)
                                Text(cat.rawValue)
                            }
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(category == cat ? .white : cat.color)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Capsule().fill(category == cat ? cat.color : cat.color.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var suggestedExercisesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workout Name").font(.caption).foregroundColor(.gray).textCase(.uppercase)
            TextField("Enter workout name", text: $name)
                .padding(12).background(Color(.systemGray6)).cornerRadius(12)
            Text("Quick picks").font(.subheadline).fontWeight(.semibold)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                ForEach(category.suggestedExercises, id: \.self) { suggestion in
                    Button { name = suggestion } label: {
                        Text(suggestion)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10).padding(.horizontal, 10)
                            .background(Color(.systemGray6)).cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details").font(.caption).foregroundColor(.gray).textCase(.uppercase)

            if category.usesDuration {
                detailField(title: "Duration (minutes)", text: $duration, keyboard: .numberPad)
            } else {
                Stepper("Sets: \(sets)", value: $sets, in: 1...20)
                Stepper("Reps: \(reps)", value: $reps, in: 1...100)
                detailField(title: "Weight (lbs)", text: $weight, keyboard: .decimalPad)
            }

            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Calories Burned").font(.caption).foregroundColor(.gray)
                    TextField("e.g. 300", text: $calories)
                        .keyboardType(.numberPad)
                        .padding(10)
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(10)
                }
                Button { showCalcSheet = true } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "flame.fill").font(.system(size: 14, weight: .semibold))
                        Text("Calc").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 52, height: 40)
                    .background(category.color)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding().background(Color(.systemGray6)).cornerRadius(14)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes").font(.caption).foregroundColor(.gray).textCase(.uppercase)
            TextField("Add a quick note...", text: $notes, axis: .vertical)
                .lineLimit(3...5).padding(12).background(Color(.systemGray6)).cornerRadius(12)
        }
    }

    private var saveButton: some View {
        Button { saveExercise() } label: {
            Text(isEditing ? "Save Changes" : "Add Workout")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(category.color).cornerRadius(14)
        }
        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func detailField(title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(.gray)
            TextField(title, text: text)
                .keyboardType(keyboard).padding(10)
                .background(Color.white.opacity(0.7)).cornerRadius(10)
        }
    }

    private func populateIfNeeded() {
        category = editingExercise?.category ?? initialCategory
        guard let exercise = editingExercise else { return }
        name     = exercise.name
        sets     = exercise.sets
        reps     = exercise.reps
        weight   = exercise.weight.map { String(Int($0)) } ?? ""
        duration = exercise.duration.map { String($0) } ?? ""
        calories = String(exercise.caloriesBurned)
        notes    = exercise.notes
    }

    private func saveExercise() {
        let entry = ActivityEntry(
            id:             editingExercise?.id ?? UUID(),
            name:           name.trimmingCharacters(in: .whitespacesAndNewlines),
            category:       category,
            sets:           category.usesDuration ? 0 : sets,
            reps:           category.usesDuration ? 0 : reps,
            weight:         category.usesDuration ? nil : Double(weight),
            duration:       category.usesDuration ? Int(duration) : nil,
            caloriesBurned: Int(calories) ?? 0,
            notes:          notes,
            date:           editingExercise?.date ?? Date(),
            isCompleted:    editingExercise?.isCompleted ?? false
        )
        if isEditing { vm.update(entry) } else { vm.add(entry) }
        dismiss()
    }
}

// MARK: - Calorie Calculator Sheet

struct CalorieCalculatorSheet: View {
    let category: ExerciseCategory
    let workoutName: String
    let userWeightKg: Double
    let isImperial: Bool
    let onResult: (Int, Int?) -> Void
    @Environment(\.dismiss) private var dismiss

    // Display weight in user's preferred unit
    private var displayWeight: String {
        isImperial
            ? String(format: "%.1f lbs", userWeightKg * 2.20462)
            : String(format: "%.1f kg", userWeightKg)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // User weight banner
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill").foregroundColor(.secondary)
                        Text("Your weight: \(displayWeight)")
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                    switch category {
                    case .strength:
                        StrengthCalculator(userWeightKg: userWeightKg, isImperial: isImperial) { cals, dur in
                            onResult(cals, dur); dismiss()
                        }
                    case .cardio:
                        CardioCalculator(userWeightKg: userWeightKg, isImperial: isImperial, workoutName: workoutName) { cals, dur in
                            onResult(cals, dur); dismiss()
                        }
                    case .sports:
                        SportsCalculator(userWeightKg: userWeightKg, isImperial: isImperial, workoutName: workoutName) { cals, dur in
                            onResult(cals, dur); dismiss()
                        }
                    case .flexibility:
                        FlexibilityCalculator(userWeightKg: userWeightKg, isImperial: isImperial, workoutName: workoutName) { cals, dur in
                            onResult(cals, dur); dismiss()
                        }
                    case .outdoor:
                        OutdoorCalculator(userWeightKg: userWeightKg, isImperial: isImperial, workoutName: workoutName) { cals, dur in
                            onResult(cals, dur); dismiss()
                        }
                    }
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Calorie Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Shared Calculator Components

private struct CalcStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundColor(.secondary)
            HStack {
                Button {
                    if value - step >= range.lowerBound { value -= step }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28)).foregroundColor(Color(.systemGray3))
                }
                Spacer()
                Text("\(value)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Button {
                    if value + step <= range.upperBound { value += step }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28)).foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

private struct CalcTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .decimalPad

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4), lineWidth: 0.5))
        }
    }
}

private struct FormulaInfoButton: View {
    let formula: String
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: expanded ? "info.circle.fill" : "info.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                    Text("How we calculate this")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                Text(formula)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(12)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

private struct ResultBanner: View {
    let calories: Int
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Estimated Burn").font(.caption).foregroundColor(.secondary)
                Text("\(calories) kcal")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.orange)
            }
            Spacer()
            Image(systemName: "flame.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange.opacity(0.3))
        }
        .padding()
        .background(Color.orange.opacity(0.08))
        .cornerRadius(12)
    }
}

private struct UseResultButton: View {
    let calories: Int
    let duration: Int?
    let onResult: (Int, Int?) -> Void

    var body: some View {
        Button {
            onResult(calories, duration)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Use This Result")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.green)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

private struct CalculateButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                Text("Calculate Calories")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.orange)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Strength Calculator
// Formula: (MET × weight_kg × duration_hrs) + (sets × reps × weight_kg × 0.075)

private struct StrengthCalculator: View {
    let userWeightKg: Double
    let isImperial: Bool
    let onResult: (Int, Int?) -> Void

    @State private var sets: Int = 3
    @State private var reps: Int = 10
    @State private var liftWeightText: String = "135"
    @State private var result: Int? = nil

    private var weightUnit: String { isImperial ? "lbs" : "kg" }

    // Convert lift weight to kg for calculation
    private var liftWeightKg: Double {
        let val = Double(liftWeightText) ?? 0
        return isImperial ? val * 0.453592 : val
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Strength Training").font(.headline)

            CalcStepper(label: "Sets", value: $sets, range: 1...20)
            CalcStepper(label: "Reps per set", value: $reps, range: 1...30)
            CalcTextField(
                label: "Weight lifted (\(weightUnit))",
                placeholder: isImperial ? "e.g. 135" : "e.g. 60",
                text: $liftWeightText
            )

            FormulaInfoButton(formula:
                "Calories = (sets × reps × lift_weight_kg × 0.075) + (MET 6.0 × body_weight_kg × estimated_duration_hrs)\n\n" +
                "• Each rep burns approx 0.075 kcal per kg of weight lifted\n" +
                "• A base MET of 6.0 accounts for the overall metabolic cost of a weight session\n" +
                "• Duration is estimated as sets × reps × 3 seconds rest factor"
            )

            CalculateButton {
                // Per-rep energy: each rep burns ~0.075 kcal per kg lifted
                let repCals = Double(sets * reps) * liftWeightKg * 0.075
                // MET-based session cost: MET 6.0, estimate ~45 sec per set including rest
                let estimatedDurationHrs = Double(sets) * 0.75 / 60.0
                let metCals = 6.0 * userWeightKg * estimatedDurationHrs
                result = max(1, Int(repCals + metCals))
            }

            if let r = result {
                ResultBanner(calories: r)
                UseResultButton(calories: r, duration: nil, onResult: onResult)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Cardio Calculator
// Formula: Calories = MET × weight_kg × (distance / speed)

private struct CardioCalculator: View {
    let userWeightKg: Double
    let isImperial: Bool
    let workoutName: String
    let onResult: (Int, Int?) -> Void

    enum CardioType: String, CaseIterable {
        case walking   = "Walking"
        case running   = "Running"
        case sprinting = "Sprinting"

        var met: Double {
            switch self {
            case .walking:   return 3.5
            case .running:   return 9.8
            case .sprinting: return 14.0
            }
        }
        var defaultSpeedMph: Double {
            switch self {
            case .walking:   return 3.0
            case .running:   return 6.0
            case .sprinting: return 12.0
            }
        }
        var icon: String {
            switch self {
            case .walking:   return "figure.walk"
            case .running:   return "figure.run"
            case .sprinting: return "figure.run"
            }
        }
    }

    @State private var selectedType: CardioType = .running
    @State private var distanceText: String = "3.0"
    @State private var result: Int? = nil
    @State private var calculatedDuration: Int? = nil

    private var distanceUnit: String { isImperial ? "miles" : "km" }

    private var distanceInMiles: Double {
        let val = Double(distanceText) ?? 0
        return isImperial ? val : val * 0.621371
    }

    private var estimatedMins: Int {
        Int((distanceInMiles / selectedType.defaultSpeedMph) * 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cardio").font(.headline)

            HStack(spacing: 8) {
                ForEach(CardioType.allCases, id: \.self) { type in
                    Button { selectedType = type; result = nil } label: {
                        VStack(spacing: 4) {
                            Image(systemName: type.icon).font(.system(size: 16))
                            Text(type.rawValue).font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(selectedType == type ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(
                            selectedType == type ? Color(red: 0.25, green: 0.72, blue: 0.55) : Color(.systemGray5)
                        ))
                    }
                    .buttonStyle(.plain)
                }
            }

            CalcTextField(
                label: "Distance (\(distanceUnit))",
                placeholder: isImperial ? "e.g. 3.0" : "e.g. 5.0",
                text: $distanceText
            )

            HStack(spacing: 6) {
                Image(systemName: "clock").foregroundColor(.secondary).font(.caption)
                Text("Estimated time: ~\(estimatedMins) min at \(String(format: "%.0f", selectedType.defaultSpeedMph)) mph")
                    .font(.caption).foregroundColor(.secondary)
            }

            FormulaInfoButton(formula:
                "Calories = MET × body_weight_kg × duration_hours\n\n" +
                "• Walking MET: 3.5\n" +
                "• Running MET: 9.8\n" +
                "• Sprinting MET: 14.0\n\n" +
                "MET (Metabolic Equivalent of Task) represents energy cost relative to rest. Duration is estimated from distance ÷ typical pace."
            )

            CalculateButton {
                let hours = distanceInMiles / selectedType.defaultSpeedMph
                result = max(1, Int(selectedType.met * userWeightKg * hours))
                calculatedDuration = Int(hours * 60)
            }

            if let r = result {
                ResultBanner(calories: r)
                if let d = calculatedDuration {
                    Text("Estimated duration: \(d) min")
                        .font(.caption).foregroundColor(.secondary)
                }
                UseResultButton(calories: r, duration: calculatedDuration, onResult: onResult)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear {
            if workoutName.lowercased().contains("walk")        { selectedType = .walking }
            else if workoutName.lowercased().contains("sprint") { selectedType = .sprinting }
            else                                                 { selectedType = .running }
        }
    }
}

// MARK: - Sports Calculator
// Formula: Calories = MET × weight_kg × duration_hrs

private struct SportsCalculator: View {
    let userWeightKg: Double
    let isImperial: Bool
    let workoutName: String
    let onResult: (Int, Int?) -> Void

    enum SportType: String, CaseIterable {
        case football     = "Football"
        case basketball   = "Basketball"
        case soccer       = "Soccer"
        case rockClimbing = "Rock Climbing"

        var met: Double {
            switch self {
            case .football:     return 8.0
            case .basketball:   return 8.0
            case .soccer:       return 10.0
            case .rockClimbing: return 7.5
            }
        }
        var icon: String {
            switch self {
            case .football:     return "sportscourt.fill"
            case .basketball:   return "basketball.fill"
            case .soccer:       return "soccerball"
            case .rockClimbing: return "mountain.2.fill"
            }
        }
    }

    @State private var selectedSport: SportType = .basketball
    @State private var durationText: String = "60"
    @State private var result: Int? = nil

    private var durationMins: Int { Int(durationText) ?? 60 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sports").font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(SportType.allCases, id: \.self) { sport in
                    Button { selectedSport = sport; result = nil } label: {
                        HStack(spacing: 6) {
                            Image(systemName: sport.icon).font(.system(size: 13))
                            Text(sport.rawValue).font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(selectedSport == sport ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(
                            selectedSport == sport ? Color(red: 0.65, green: 0.35, blue: 0.95) : Color(.systemGray5)
                        ))
                    }
                    .buttonStyle(.plain)
                }
            }

            CalcTextField(
                label: "Duration (minutes)",
                placeholder: "e.g. 60",
                text: $durationText,
                keyboard: .numberPad
            )

            FormulaInfoButton(formula:
                "Calories = MET × body_weight_kg × (duration_mins ÷ 60)\n\n" +
                "• Football MET: 8.0\n" +
                "• Basketball MET: 8.0\n" +
                "• Soccer MET: 10.0\n" +
                "• Rock Climbing MET: 7.5\n\n" +
                "MET values sourced from the Compendium of Physical Activities (Ainsworth et al.)."
            )

            CalculateButton {
                result = max(1, Int(selectedSport.met * userWeightKg * Double(durationMins) / 60.0))
            }

            if let r = result {
                ResultBanner(calories: r)
                UseResultButton(calories: r, duration: durationMins, onResult: onResult)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear {
            if workoutName.lowercased().contains("football")        { selectedSport = .football }
            else if workoutName.lowercased().contains("basketball") { selectedSport = .basketball }
            else if workoutName.lowercased().contains("soccer")     { selectedSport = .soccer }
            else if workoutName.lowercased().contains("climb")      { selectedSport = .rockClimbing }
        }
    }
}

// MARK: - Flexibility Calculator
// Formula: Calories = MET × intensity_multiplier × weight_kg × duration_hrs

private struct FlexibilityCalculator: View {
    let userWeightKg: Double
    let isImperial: Bool
    let workoutName: String
    let onResult: (Int, Int?) -> Void

    enum FlexType: String, CaseIterable {
        case yoga    = "Yoga"
        case pilates = "Pilates"

        var met: Double {
            switch self {
            case .yoga:    return 3.0
            case .pilates: return 3.5
            }
        }
        var icon: String {
            switch self {
            case .yoga:    return "figure.mind.and.body"
            case .pilates: return "figure.cooldown"
            }
        }
        var description: String {
            switch self {
            case .yoga:    return "Hatha, Vinyasa or restorative"
            case .pilates: return "Mat or reformer Pilates"
            }
        }
    }

    @State private var selectedType: FlexType = .yoga
    @State private var durationText: String = "60"
    @State private var intensityIndex: Int = 1 // 0=Light, 1=Moderate, 2=Intense
    @State private var result: Int? = nil

    private let intensityLabels = ["Light", "Moderate", "Intense"]
    private let intensityMultipliers: [Double] = [0.85, 1.0, 1.2]
    private var durationMins: Int { Int(durationText) ?? 60 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Flexibility").font(.headline)

            HStack(spacing: 8) {
                ForEach(FlexType.allCases, id: \.self) { type in
                    Button { selectedType = type; result = nil } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.icon).font(.system(size: 20))
                            Text(type.rawValue).font(.system(size: 12, weight: .semibold))
                            Text(type.description)
                                .font(.system(size: 9))
                                .multilineTextAlignment(.center)
                                .foregroundColor(selectedType == type ? .white.opacity(0.8) : .secondary)
                        }
                        .foregroundColor(selectedType == type ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(
                            selectedType == type ? Color(red: 0.40, green: 0.60, blue: 0.95) : Color(.systemGray5)
                        ))
                    }
                    .buttonStyle(.plain)
                }
            }

            CalcTextField(
                label: "Duration (minutes)",
                placeholder: "e.g. 60",
                text: $durationText,
                keyboard: .numberPad
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Intensity").font(.caption).foregroundColor(.secondary)
                Picker("Intensity", selection: $intensityIndex) {
                    ForEach(0..<intensityLabels.count, id: \.self) { i in
                        Text(intensityLabels[i]).tag(i)
                    }
                }
                .pickerStyle(.segmented)
            }

            FormulaInfoButton(formula:
                "Calories = MET × intensity_multiplier × body_weight_kg × (duration_mins ÷ 60)\n\n" +
                "• Yoga MET: 3.0 | Pilates MET: 3.5\n" +
                "• Light intensity: ×0.85\n" +
                "• Moderate intensity: ×1.0\n" +
                "• Intense intensity: ×1.2\n\n" +
                "Intensity accounts for faster flows, harder poses, or more challenging sequences."
            )

            CalculateButton {
                let mult = intensityMultipliers[intensityIndex]
                result = max(1, Int(selectedType.met * mult * userWeightKg * Double(durationMins) / 60.0))
            }

            if let r = result {
                ResultBanner(calories: r)
                UseResultButton(calories: r, duration: durationMins, onResult: onResult)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear {
            if workoutName.lowercased().contains("pilates") { selectedType = .pilates }
            else { selectedType = .yoga }
        }
    }
}

// MARK: - Outdoor Calculator
// Formula: Calories = (MET × weight_kg × duration_hrs) + elevation_bonus

private struct OutdoorCalculator: View {
    let userWeightKg: Double
    let isImperial: Bool
    let workoutName: String
    let onResult: (Int, Int?) -> Void

    enum HikeType: String, CaseIterable {
        case uphill   = "Uphill"
        case downhill = "Downhill"

        var met: Double {
            switch self {
            case .uphill:   return 8.0
            case .downhill: return 5.3
            }
        }
        var icon: String {
            switch self {
            case .uphill:   return "arrow.up.right"
            case .downhill: return "arrow.down.right"
            }
        }
        var description: String {
            switch self {
            case .uphill:   return "Ascending, elevation gain"
            case .downhill: return "Descending, less effort"
            }
        }
    }

    @State private var selectedType: HikeType = .uphill
    @State private var distanceText: String = "3.0"
    @State private var durationText: String = "90"
    @State private var elevationText: String = "500"
    @State private var result: Int? = nil

    private var distanceUnit: String { isImperial ? "miles" : "km" }
    private var elevationUnit: String { isImperial ? "ft" : "m" }
    private var durationMins: Int { Int(durationText) ?? 90 }

    // Convert elevation to feet for formula
    private var elevationFt: Double {
        let val = Double(elevationText) ?? 0
        return isImperial ? val : val * 3.28084
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Outdoor").font(.headline)

            HStack(spacing: 8) {
                ForEach(HikeType.allCases, id: \.self) { type in
                    Button { selectedType = type; result = nil } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.icon).font(.system(size: 18))
                            Text(type.rawValue).font(.system(size: 13, weight: .semibold))
                            Text(type.description)
                                .font(.system(size: 9))
                                .multilineTextAlignment(.center)
                                .foregroundColor(selectedType == type ? .white.opacity(0.8) : .secondary)
                        }
                        .foregroundColor(selectedType == type ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(
                            selectedType == type ? Color(red: 0.95, green: 0.78, blue: 0.22) : Color(.systemGray5)
                        ))
                    }
                    .buttonStyle(.plain)
                }
            }

            CalcTextField(
                label: "Distance (\(distanceUnit))",
                placeholder: isImperial ? "e.g. 3.0" : "e.g. 5.0",
                text: $distanceText
            )

            CalcTextField(
                label: "Duration (minutes)",
                placeholder: "e.g. 90",
                text: $durationText,
                keyboard: .numberPad
            )

            if selectedType == .uphill {
                CalcTextField(
                    label: "Elevation gain (\(elevationUnit))",
                    placeholder: isImperial ? "e.g. 500" : "e.g. 150",
                    text: $elevationText,
                    keyboard: .numberPad
                )
            }

            FormulaInfoButton(formula:
                "Calories = (MET × body_weight_kg × duration_hrs) + elevation_bonus\n\n" +
                "• Uphill MET: 8.0\n" +
                "• Downhill MET: 5.3\n\n" +
                "Elevation bonus (uphill only):\n" +
                "= (elevation_ft ÷ 100) × (body_weight_lbs ÷ 100) × 0.35\n\n" +
                "The elevation bonus accounts for the extra energy cost of gaining altitude, approximately 0.35 kcal per 100 ft of gain per 100 lbs of body weight."
            )

            CalculateButton {
                let baseCals  = selectedType.met * userWeightKg * Double(durationMins) / 60.0
                let elevBonus = selectedType == .uphill
                    ? (elevationFt / 100.0) * ((userWeightKg * 2.20462) / 100.0) * 0.35
                    : 0
                result = max(1, Int(baseCals + elevBonus))
            }

            if let r = result {
                ResultBanner(calories: r)
                UseResultButton(calories: r, duration: durationMins, onResult: onResult)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear {
            if workoutName.lowercased().contains("down") { selectedType = .downhill }
            else { selectedType = .uphill }
        }
    }
}

// MARK: - Robot Icon

struct RobotIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 64
            ctx.fill(Path(roundedRect: CGRect(x: 7*s, y: 6*s, width: 50*s, height: 3*s), cornerRadius: 1.5*s), with: .color(.white))
            ctx.fill(Path(roundedRect: CGRect(x: 4*s,    y: 3.5*s, width: 3.5*s, height: 8*s),  cornerRadius: s), with: .color(.white.opacity(0.95)))
            ctx.fill(Path(roundedRect: CGRect(x: 1*s,    y: 3*s,   width: 3*s,   height: 9*s),  cornerRadius: s), with: .color(.white.opacity(0.8)))
            ctx.fill(Path(roundedRect: CGRect(x: -1.5*s, y: 2.5*s, width: 2.5*s, height: 10*s), cornerRadius: s), with: .color(.white.opacity(0.65)))
            ctx.fill(Path(roundedRect: CGRect(x: 56.5*s, y: 3.5*s, width: 3.5*s, height: 8*s),  cornerRadius: s), with: .color(.white.opacity(0.95)))
            ctx.fill(Path(roundedRect: CGRect(x: 60*s,   y: 3*s,   width: 3*s,   height: 9*s),  cornerRadius: s), with: .color(.white.opacity(0.8)))
            ctx.fill(Path(roundedRect: CGRect(x: 63*s,   y: 2.5*s, width: 2.5*s, height: 10*s), cornerRadius: s), with: .color(.white.opacity(0.65)))
            ctx.fill(Path(roundedRect: CGRect(x: 9*s,  y: 5*s, width: 5*s, height: 5*s), cornerRadius: 1.5*s), with: .color(.white))
            ctx.fill(Path(roundedRect: CGRect(x: 50*s, y: 5*s, width: 5*s, height: 5*s), cornerRadius: 1.5*s), with: .color(.white))
            var leftArm = Path(); leftArm.move(to: CGPoint(x: 15*s, y: 42*s))
            leftArm.addQuadCurve(to: CGPoint(x: 12*s, y: 9*s), control: CGPoint(x: 11*s, y: 27*s))
            ctx.stroke(leftArm, with: .color(.white), style: StrokeStyle(lineWidth: 6*s, lineCap: .round))
            var rightArm = Path(); rightArm.move(to: CGPoint(x: 49*s, y: 42*s))
            rightArm.addQuadCurve(to: CGPoint(x: 52*s, y: 9*s), control: CGPoint(x: 53*s, y: 27*s))
            ctx.stroke(rightArm, with: .color(.white), style: StrokeStyle(lineWidth: 6*s, lineCap: .round))
            var body = Path()
            body.move(to: CGPoint(x: 15*s, y: 42*s))
            body.addQuadCurve(to: CGPoint(x: 15*s, y: 60*s), control: CGPoint(x: 13*s, y: 54*s))
            body.addLine(to: CGPoint(x: 49*s, y: 60*s))
            body.addQuadCurve(to: CGPoint(x: 49*s, y: 42*s), control: CGPoint(x: 51*s, y: 54*s))
            body.addQuadCurve(to: CGPoint(x: 15*s, y: 42*s), control: CGPoint(x: 32*s, y: 36*s))
            ctx.fill(body, with: .color(.white.opacity(0.92)))
            ctx.fill(Path(roundedRect: CGRect(x: 27*s, y: 32*s, width: 10*s, height: 7*s), cornerRadius: 2*s), with: .color(.white.opacity(0.88)))
            ctx.fill(Path(roundedRect: CGRect(x: 18*s, y: 16*s, width: 28*s, height: 22*s), cornerRadius: 5*s), with: .color(.white.opacity(0.97)))
            ctx.fill(Path(roundedRect: CGRect(x: 21*s, y: 20*s, width: 8*s, height: 5.5*s), cornerRadius: 2*s), with: .color(.orange))
            ctx.fill(Path(roundedRect: CGRect(x: 35*s, y: 20*s, width: 8*s, height: 5.5*s), cornerRadius: 2*s), with: .color(.orange))
            ctx.fill(Path(roundedRect: CGRect(x: 22*s, y: 20.5*s, width: 2.5*s, height: 2*s), cornerRadius: 0.5*s), with: .color(.white.opacity(0.55)))
            ctx.fill(Path(roundedRect: CGRect(x: 36*s, y: 20.5*s, width: 2.5*s, height: 2*s), cornerRadius: 0.5*s), with: .color(.white.opacity(0.55)))
            var smile = Path(); smile.move(to: CGPoint(x: 24*s, y: 30*s))
            smile.addQuadCurve(to: CGPoint(x: 40*s, y: 30*s), control: CGPoint(x: 32*s, y: 36*s))
            ctx.stroke(smile, with: .color(.orange), style: StrokeStyle(lineWidth: 2.5*s, lineCap: .round))
        }
        .frame(width: 26, height: 26)
    }
}

// MARK: - AI Assistant Sheet

struct AIAssistantSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) var appState
    @State private var messageText = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .bottom, spacing: 8) {
                            ZStack {
                                Circle().fill(Color.orange).frame(width: 32, height: 32)
                                Canvas { ctx, size in
                                    let s = size.width / 64
                                    ctx.fill(Path(roundedRect: CGRect(x: 12*s, y: 14*s, width: 40*s, height: 30*s), cornerRadius: 6*s), with: .color(.white.opacity(0.97)))
                                    ctx.fill(Path(roundedRect: CGRect(x: 18*s, y: 20*s, width: 8*s, height: 5*s), cornerRadius: 2*s), with: .color(.orange))
                                    ctx.fill(Path(roundedRect: CGRect(x: 38*s, y: 20*s, width: 8*s, height: 5*s), cornerRadius: 2*s), with: .color(.orange))
                                    var smile = Path(); smile.move(to: CGPoint(x: 20*s, y: 30*s))
                                    smile.addQuadCurve(to: CGPoint(x: 44*s, y: 30*s), control: CGPoint(x: 32*s, y: 38*s))
                                    ctx.stroke(smile, with: .color(.orange), style: StrokeStyle(lineWidth: 2.5*s, lineCap: .round))
                                }
                                .frame(width: 20, height: 20)
                            }
                            Text("Hey \(appState.currentUser?.name.components(separatedBy: " ").first ?? "there")! Ask me anything about your workouts.")
                                .font(.system(size: 13))
                                .padding(10)
                                .background(Color(.systemGray6))
                                .cornerRadius(14)
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["Show my progress", "Rest day tips", "Calories burned?", "Best exercises"], id: \.self) { chip in
                            Text(chip)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.orange.opacity(0.3), lineWidth: 0.5))
                        }
                    }
                    .padding(.horizontal).padding(.vertical, 8)
                }
                Divider()
                HStack(spacing: 10) {
                    TextField("Ask about your workouts...", text: $messageText)
                        .font(.system(size: 14)).padding(10)
                        .background(Color(.systemGray6)).cornerRadius(20)
                    Button { messageText = "" } label: {
                        ZStack {
                            Circle().fill(Color.orange).frame(width: 34, height: 34)
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal).padding(.vertical, 10)
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.orange).frame(width: 44, height: 44)
                        RobotIcon().frame(width: 28, height: 28)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Fitness Assistant").font(.system(size: 16, weight: .bold)).foregroundColor(.primary)
                        Text("Powered by your workout data").font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Done") { dismiss() }.font(.system(size: 15, weight: .semibold)).foregroundColor(.orange)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color(.systemBackground))
                .overlay(Divider(), alignment: .bottom)
            }
        }
    }
}

#Preview {
    ActivityLogView(userId: "preview")
        .environment(AppState())
}
