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
    var completedDates: [Date]
    var isTemporary: Bool

    func isCompleted(on day: Date) -> Bool {
        let cal = Calendar.current
        return completedDates.contains { cal.isDate($0, inSameDayAs: day) }
    }

    var isCompleted: Bool { isCompleted(on: Date()) }

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
        completedDates: [Date] = [],
        isTemporary: Bool = false
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
        self.completedDates = completedDates
        self.isTemporary    = isTemporary
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

// MARK: - Calculator Result

struct CalculatorResult {
    var calories: Int
    var duration: Int?
    var sets: Int?
    var reps: Int?
    var weightLbs: Double?
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
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    var isHistoryMode: Bool { !Calendar.current.isDateInToday(selectedDate) }

    var selectedDateString: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: selectedDate)
    }

    let userId: String
    private var storageKey: String { "savedExercises_\(userId)" }

    private var todayString: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    init(userId: String) {
        self.userId = userId
        loadFromCache()
        Task { await loadFromSupabase() }
    }

    var filteredExercises: [ActivityEntry] {
        let base: [ActivityEntry]
        if isHistoryMode {
            base = exercises.filter { $0.isCompleted(on: selectedDate) }
        } else {
            let today = Calendar.current.startOfDay(for: Date())
            base = exercises.filter { entry in
                if entry.isTemporary { return Calendar.current.isDate(entry.date, inSameDayAs: today) }
                return true
            }
        }
        let categoryFiltered: [ActivityEntry] = selectedFilter == nil ? base : base.filter { $0.category == selectedFilter }
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return categoryFiltered.sorted { $0.name < $1.name }
        }
        return categoryFiltered.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.notes.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.name < $1.name }
    }

    var daysWithActivity: [Date] {
        var days = Set<Date>()
        let cal = Calendar.current
        for entry in exercises {
            for date in entry.completedDates { days.insert(cal.startOfDay(for: date)) }
        }
        return days.sorted(by: >)
    }

    func goToPreviousActiveDay() {
        let cal = Calendar.current
        let current = cal.startOfDay(for: selectedDate)
        if let prev = daysWithActivity.first(where: { $0 < current }) {
            withAnimation(.easeInOut(duration: 0.2)) { selectedDate = prev }
        }
    }

    func goToToday() {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedDate = Calendar.current.startOfDay(for: Date())
        }
    }

    var hasPreviousActiveDay: Bool {
        let cal = Calendar.current
        let current = cal.startOfDay(for: selectedDate)
        return daysWithActivity.contains { $0 < current }
    }

    var totalCaloriesForDay: Int {
        exercises.filter { $0.isCompleted(on: selectedDate) }.reduce(0) { $0 + $1.caloriesBurned }
    }

    var totalWorkoutsForDay: Int {
        exercises.filter { $0.isCompleted(on: selectedDate) }.count
    }

    var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = cal.startOfDay(for: Date())
        while true {
            if exercises.contains(where: { $0.isCompleted(on: checkDate) }) {
                streak += 1
                checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else { break }
        }
        return streak
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
        guard let idx = exercises.firstIndex(where: { $0.id == entry.id }) else { return }
        let cal = Calendar.current
        let day = cal.startOfDay(for: selectedDate)
        if exercises[idx].isCompleted(on: day) {
            exercises[idx].completedDates.removeAll { cal.isDate($0, inSameDayAs: day) }
        } else {
            exercises[idx].completedDates.append(day)
        }
        let updated = exercises[idx]
        saveToCache()
        Task { try? await WorkoutService.shared.upsertWorkout(updated, userId: userId) }
        syncDailyLog()
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
        let burned = exercises.filter { $0.isCompleted(on: today) }.reduce(0) { $0 + $1.caloriesBurned }
        let count  = exercises.filter { $0.isCompleted(on: today) }.count
        Task {
            try? await DailyLogService.shared.upsertLog(
                userId: userId,
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
            ZStack {
                Color.brandNavy.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        dateNavigationBar
                        if vm.isHistoryMode { historyBanner }
                        statsStrip
                        if !vm.isHistoryMode { searchBar }
                        if !vm.isHistoryMode { categorySection }
                        exerciseList
                        Spacer(minLength: 120)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Activity Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.brandNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAIAssistant = true } label: {
                        ZStack {
                            Circle().fill(Color.brandOrange).frame(width: 32, height: 32)
                            RobotIcon().frame(width: 20, height: 20)
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if !vm.isHistoryMode { floatingAddButton }
            }
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

    // MARK: - Date Nav Bar

    private var dateNavigationBar: some View {
        let cal = Calendar.current
        let isToday     = cal.isDateInToday(vm.selectedDate)
        let isYesterday = cal.isDateInYesterday(vm.selectedDate)

        return HStack {
            Button { vm.goToPreviousActiveDay() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(vm.hasPreviousActiveDay ? Color.brandCream.opacity(0.6) : Color.brandCream.opacity(0.15))
                    .frame(width: 36, height: 36)
            }
            .disabled(!vm.hasPreviousActiveDay)

            Spacer()

            VStack(spacing: 2) {
                Text(isToday ? "Today" : isYesterday ? "Yesterday" : {
                    let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
                    return f.string(from: vm.selectedDate)
                }())
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.brandCream)

                if vm.isHistoryMode {
                    Text("\(vm.totalWorkoutsForDay) completed")
                        .font(.system(size: 10))
                        .foregroundColor(Color.brandLime.opacity(0.7))
                }
            }

            Spacer()

            Button { vm.goToToday() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isToday ? .clear : Color.brandCream.opacity(0.6))
                    .frame(width: 36, height: 36)
            }
            .disabled(isToday)
        }
        .padding(.horizontal)
    }

    // MARK: - History Banner

    private var historyBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.brandLime)
            Text("Viewing history — showing completed exercises only")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.brandCream.opacity(0.6))
            Spacer()
            Button("Back to Today") { vm.goToToday() }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.brandLime)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.brandLime.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandLime.opacity(0.2), lineWidth: 1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        HStack(spacing: 12) {
            StatCard(value: "\(vm.totalWorkoutsForDay)", label: vm.isHistoryMode ? "Completed" : "Done Today", icon: "checkmark.circle.fill", color: Color(red: 0.25, green: 0.72, blue: 0.55), animate: animateStats)
            StatCard(value: "\(vm.totalCaloriesForDay)", label: "Calories", icon: "flame.fill", color: .brandOrange, animate: animateStats)
            StatCard(value: "\(vm.currentStreak)", label: "Streak", icon: "bolt.fill", color: .brandLime, animate: animateStats)
        }
        .padding(.horizontal)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundColor(Color.brandCream.opacity(0.4))
            ZStack(alignment: .leading) {
                if vm.searchText.isEmpty {
                    Text("Search exercises...").foregroundColor(Color.brandCream.opacity(0.3)).allowsHitTesting(false)
                }
                TextField("", text: $vm.searchText).foregroundColor(.brandCream).textInputAutocapitalization(.words)
            }
            if !vm.searchText.isEmpty {
                Button { vm.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Color.brandCream.opacity(0.4))
                }
            }
        }
        .padding(12)
        .background(Color.brandCream.opacity(0.07))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandCream.opacity(0.18), lineWidth: 1))
        .cornerRadius(14)
        .padding(.horizontal)
    }

    // MARK: - Category Filter

    private var categorySection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(label: "All", icon: "square.grid.2x2.fill", color: .brandLime, isSelected: vm.selectedFilter == nil) {
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

    // MARK: - Exercise List

    private var exerciseList: some View {
        LazyVStack(spacing: 12) {
            if vm.isLoading && vm.exercises.isEmpty {
                ProgressView().tint(.brandLime).padding(.top, 40)
            } else if vm.filteredExercises.isEmpty {
                emptyState
            } else {
                ForEach(vm.filteredExercises) { exercise in
                    ExerciseRow(
                        exercise: exercise,
                        selectedDate: vm.selectedDate,
                        isReadOnly: vm.isHistoryMode,
                        onDelete: { if !vm.isHistoryMode { withAnimation { vm.deleteEntry(exercise) } } },
                        onToggleComplete: {
                            if !vm.isHistoryMode {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { vm.toggleComplete(exercise) }
                            }
                        }
                    )
                    .onTapGesture { if !vm.isHistoryMode { vm.editingExercise = exercise } }
                    .contextMenu {
                        if !vm.isHistoryMode {
                            Button { vm.editingExercise = exercise } label: { Label("Edit", systemImage: "pencil") }
                            Button(role: .destructive) { vm.deleteEntry(exercise) } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: vm.isHistoryMode ? "calendar.badge.exclamationmark" : "figure.strengthtraining.traditional")
                .font(.system(size: 52)).foregroundColor(Color.brandCream.opacity(0.15))
            Text(vm.isHistoryMode ? "No workouts logged this day" : "No exercises yet")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(Color.brandCream.opacity(0.5))
            Text(vm.isHistoryMode ? "Use the arrows to find a day with activity." : "Tap the button below to add your first exercise.")
                .font(.system(size: 14)).foregroundColor(Color.brandCream.opacity(0.35)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60).padding(.horizontal)
    }

    // MARK: - Floating Add Button

    private var floatingAddButton: some View {
        Button {
            vm.preselectedCategory = vm.selectedFilter ?? .strength
            vm.showingAddSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("Add Exercise")
            }
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(.brandNavy)
            .padding(.horizontal, 28).padding(.vertical, 16)
            .background(Color.brandLime)
            .clipShape(Capsule())
            .shadow(color: Color.brandLime.opacity(0.3), radius: 10, x: 0, y: 4)
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
                .foregroundColor(.brandCream)
                .scaleEffect(animate ? 1.0 : 0.5).opacity(animate ? 1.0 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: animate)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundColor(Color.brandCream.opacity(0.5)).textCase(.uppercase)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 18)
        .background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
        .cornerRadius(16)
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
            .foregroundColor(isSelected ? .brandNavy : Color.brandCream.opacity(0.7))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(isSelected ? color : Color.brandCream.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exercise Row

struct ExerciseRow: View {
    let exercise: ActivityEntry
    let selectedDate: Date
    let isReadOnly: Bool
    let onDelete: () -> Void
    let onToggleComplete: () -> Void

    private var completedOnDay: Bool { exercise.isCompleted(on: selectedDate) }
    private var completionCount: Int { exercise.completedDates.count }

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
                    .fill(completedOnDay ? exercise.category.color : exercise.category.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: completedOnDay ? "checkmark" : exercise.category.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(completedOnDay ? .white : exercise.category.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundColor(completedOnDay ? Color.brandCream.opacity(0.4) : .brandCream)
                        .strikethrough(completedOnDay)
                    if exercise.isTemporary {
                        Text("ONE-TIME")
                            .font(.system(size: 8, weight: .bold)).foregroundColor(.brandOrange)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.brandOrange.opacity(0.15)).clipShape(Capsule())
                    }
                }
                Text(subtitleText).font(.caption).foregroundColor(Color.brandCream.opacity(0.5))
                if !isReadOnly && completionCount > 0 {
                    Text("Completed \(completionCount)x total").font(.caption2).foregroundColor(Color.brandLime.opacity(0.6))
                }
                if !exercise.notes.isEmpty {
                    Text(exercise.notes).font(.caption2).foregroundColor(Color.brandCream.opacity(0.35)).lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(exercise.category.rawValue)
                    .font(.system(size: 10, weight: .bold)).foregroundColor(exercise.category.color)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(exercise.category.color.opacity(0.15)).clipShape(Capsule())

                if !isReadOnly {
                    Button { onToggleComplete() } label: {
                        Text(completedOnDay ? "Done" : "Mark Done")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(completedOnDay ? .brandNavy : exercise.category.color)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(completedOnDay ? exercise.category.color : exercise.category.color.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(exercise.category.color).font(.system(size: 20))
                }
            }
        }
        .padding()
        .background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
        .cornerRadius(16)
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
            ZStack {
                Color.brandNavy.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        categoryPickerSection
                        suggestedExercisesSection
                        detailsSection
                        notesSection
                        if !isEditing { saveButtons } else { editSaveButton }
                    }
                    .padding()
                }
            }
            .navigationTitle(isEditing ? "Edit Exercise" : "Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.brandNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.brandCream.opacity(0.6))
                }
                if isEditing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            if let e = editingExercise { vm.deleteEntry(e) }
                            dismiss()
                        } label: { Image(systemName: "trash").foregroundColor(.brandOrange) }
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
            ) { result in
                // Fill ALL fields from calculator result
                calories = "\(result.calories)"
                if let d = result.duration, d > 0 { duration = "\(d)" }
                if let s = result.sets,    s > 0 { sets = s }
                if let r = result.reps,    r > 0 { reps = r }
                if let w = result.weightLbs, w > 0 {
                    weight = isImperial ? "\(Int(w))" : "\(Int(w * 0.453592))"
                }
            }
        }
    }

    // MARK: - Save buttons

    private var saveButtons: some View {
        VStack(spacing: 12) {
            Button { saveExercise(temporary: false) } label: {
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "bookmark.fill")
                        Text("Save Permanently").font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.brandNavy)
                    Text("Appears every day in your exercise list").font(.system(size: 11)).foregroundColor(Color.brandNavy.opacity(0.6))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.brandLime).cornerRadius(14)
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button { saveExercise(temporary: true) } label: {
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                        Text("Log Once").font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.brandOrange)
                    Text("Only shows today, won't carry over").font(.system(size: 11)).foregroundColor(Color.brandOrange.opacity(0.7))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.brandOrange.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandOrange.opacity(0.4), lineWidth: 1))
                .cornerRadius(14)
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var editSaveButton: some View {
        Button { saveExercise(temporary: editingExercise?.isTemporary ?? false) } label: {
            Text("Save Changes").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.brandNavy)
                .frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.brandLime).cornerRadius(14)
        }
        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var categoryPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category").font(.caption).fontWeight(.bold).foregroundColor(Color.brandCream.opacity(0.5)).textCase(.uppercase).tracking(1.2)
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
                            .foregroundColor(category == cat ? .brandNavy : cat.color)
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
            Text("Exercise Name").font(.caption).fontWeight(.bold).foregroundColor(Color.brandCream.opacity(0.5)).textCase(.uppercase).tracking(1.2)
            ZStack(alignment: .leading) {
                if name.isEmpty { Text("Enter exercise name").foregroundColor(Color.brandCream.opacity(0.3)).padding(12) }
                TextField("", text: $name).foregroundColor(.brandCream).padding(12)
            }
            .background(Color.brandCream.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandCream.opacity(0.18), lineWidth: 1))
            .cornerRadius(12)

            Text("Quick picks").font(.subheadline).fontWeight(.semibold).foregroundColor(.brandCream)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                ForEach(category.suggestedExercises, id: \.self) { suggestion in
                    Button { name = suggestion } label: {
                        Text(suggestion).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(.brandCream)
                            .frame(maxWidth: .infinity).padding(.vertical, 10).padding(.horizontal, 10)
                            .background(Color.brandCream.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details").font(.caption).fontWeight(.bold).foregroundColor(Color.brandCream.opacity(0.5)).textCase(.uppercase).tracking(1.2)
            if category.usesDuration {
                brandDetailField(title: "Duration (minutes)", text: $duration, keyboard: .numberPad)
            } else {
                // Sets — clamp at 1
                Stepper("Sets: \(sets)", value: Binding(
                    get: { sets },
                    set: { sets = max(1, $0) }
                ), in: 1...100).foregroundColor(.brandCream)

                // Reps — clamp at 1
                Stepper("Reps: \(reps)", value: Binding(
                    get: { reps },
                    set: { reps = max(1, $0) }
                ), in: 1...500).foregroundColor(.brandCream)

                brandDetailField(title: "Weight (lbs)", text: $weight, keyboard: .decimalPad)
            }
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Calories Burned").font(.caption).foregroundColor(Color.brandCream.opacity(0.5))
                    ZStack(alignment: .leading) {
                        if calories.isEmpty { Text("e.g. 300").foregroundColor(Color.brandCream.opacity(0.3)).padding(10) }
                        TextField("", text: $calories)
                            .foregroundColor(.brandCream).keyboardType(.numberPad).padding(10)
                            .onChange(of: calories) { _, newVal in
                                // Prevent negatives
                                if let v = Int(newVal), v < 0 { calories = "0" }
                            }
                    }
                    .background(Color.brandCream.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brandCream.opacity(0.18), lineWidth: 1))
                    .cornerRadius(10)
                }
                Button { showCalcSheet = true } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "flame.fill").font(.system(size: 14, weight: .semibold))
                        Text("Calc").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.brandNavy).frame(width: 52, height: 40).background(category.color).cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
        .cornerRadius(14)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes").font(.caption).fontWeight(.bold).foregroundColor(Color.brandCream.opacity(0.5)).textCase(.uppercase).tracking(1.2)
            ZStack(alignment: .topLeading) {
                if notes.isEmpty { Text("Add a quick note...").foregroundColor(Color.brandCream.opacity(0.3)).padding(12) }
                TextField("", text: $notes, axis: .vertical).foregroundColor(.brandCream).lineLimit(3...5).padding(12)
            }
            .background(Color.brandCream.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandCream.opacity(0.18), lineWidth: 1))
            .cornerRadius(12)
        }
    }

    private func brandDetailField(title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(Color.brandCream.opacity(0.5))
            TextField("", text: text)
                .foregroundColor(.brandCream).keyboardType(keyboard).padding(10)
                .background(Color.brandCream.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brandCream.opacity(0.18), lineWidth: 1))
                .cornerRadius(10)
                .onChange(of: text.wrappedValue) { _, newVal in
                    if let v = Double(newVal), v < 0 { text.wrappedValue = "0" }
                }
        }
    }

    private func populateIfNeeded() {
        category = editingExercise?.category ?? initialCategory
        guard let exercise = editingExercise else { return }
        name     = exercise.name
        sets     = max(1, exercise.sets)
        reps     = max(1, exercise.reps)
        weight   = exercise.weight.map { String(Int(max(0, $0))) } ?? ""
        duration = exercise.duration.map { String(max(0, $0)) } ?? ""
        calories = String(max(0, exercise.caloriesBurned))
        notes    = exercise.notes
    }

    private func saveExercise(temporary: Bool) {
        let cal = max(0, Int(calories) ?? 0)
        let dur = duration.isEmpty ? nil : max(0, Int(duration) ?? 0)
        let wt: Double? = category.usesDuration ? nil : {
            guard let v = Double(weight) else { return nil }
            return max(0, v)
        }()

        let entry = ActivityEntry(
            id:             editingExercise?.id ?? UUID(),
            name:           name.trimmingCharacters(in: .whitespacesAndNewlines),
            category:       category,
            sets:           category.usesDuration ? 0 : max(1, sets),
            reps:           category.usesDuration ? 0 : max(1, reps),
            weight:         wt,
            duration:       dur,
            caloriesBurned: cal,
            notes:          notes,
            date:           editingExercise?.date ?? Date(),
            completedDates: editingExercise?.completedDates ?? [],
            isTemporary:    temporary
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
    let onResult: (CalculatorResult) -> Void
    @Environment(\.dismiss) private var dismiss

    private var displayWeight: String {
        isImperial ? String(format: "%.1f lbs", userWeightKg * 2.20462) : String(format: "%.1f kg", userWeightKg)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.brandNavy.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill").foregroundColor(Color.brandCream.opacity(0.5))
                            Text("Your weight: \(displayWeight)").font(.caption).foregroundColor(Color.brandCream.opacity(0.5))
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.brandCream.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
                        .cornerRadius(10)

                        switch category {
                        case .strength:
                            StrengthCalculator(userWeightKg: userWeightKg, isImperial: isImperial) { result in onResult(result); dismiss() }
                        case .cardio:
                            CardioCalculator(userWeightKg: userWeightKg, isImperial: isImperial, workoutName: workoutName) { result in onResult(result); dismiss() }
                        case .sports:
                            SportsCalculator(userWeightKg: userWeightKg, isImperial: isImperial, workoutName: workoutName) { result in onResult(result); dismiss() }
                        case .flexibility:
                            FlexibilityCalculator(userWeightKg: userWeightKg, isImperial: isImperial, workoutName: workoutName) { result in onResult(result); dismiss() }
                        case .outdoor:
                            OutdoorCalculator(userWeightKg: userWeightKg, isImperial: isImperial, workoutName: workoutName) { result in onResult(result); dismiss() }
                        }
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Calorie Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.brandNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color.brandCream.opacity(0.6))
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
            Text(label).font(.caption).foregroundColor(Color.brandCream.opacity(0.5))
            HStack {
                Button {
                    value = max(range.lowerBound, value - step)
                } label: {
                    Image(systemName: "minus.circle.fill").font(.system(size: 28)).foregroundColor(Color.brandCream.opacity(0.3))
                }
                Spacer()
                Text("\(value)").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.brandCream)
                Spacer()
                Button {
                    value = min(range.upperBound, value + step)
                } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 28)).foregroundColor(.brandLime)
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
            Text(label).font(.caption).foregroundColor(Color.brandCream.opacity(0.5))
            ZStack(alignment: .leading) {
                if text.isEmpty { Text(placeholder).foregroundColor(Color.brandCream.opacity(0.3)).padding(12) }
                TextField("", text: $text)
                    .foregroundColor(.brandCream).keyboardType(keyboard).padding(12)
                    .onChange(of: text) { _, newVal in
                        if let v = Double(newVal), v < 0 { text = "0" }
                    }
            }
            .background(Color.brandCream.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brandCream.opacity(0.18), lineWidth: 1))
            .cornerRadius(10)
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
                    Image(systemName: expanded ? "info.circle.fill" : "info.circle").font(.system(size: 13)).foregroundColor(.brandBlue)
                    Text("How we calculate this").font(.system(size: 12, weight: .semibold)).foregroundColor(.brandBlue)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.system(size: 11)).foregroundColor(Color.brandCream.opacity(0.4))
                }
            }
            .buttonStyle(.plain)
            if expanded {
                Text(formula).font(.system(size: 12)).foregroundColor(Color.brandCream.opacity(0.6))
                    .padding(12).background(Color.brandBlue.opacity(0.08)).cornerRadius(10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
        .cornerRadius(10)
    }
}

private struct ResultBanner: View {
    let calories: Int
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Estimated Burn").font(.caption).foregroundColor(Color.brandCream.opacity(0.5))
                Text("\(calories) kcal").font(.system(size: 28, weight: .black, design: .rounded)).foregroundColor(.brandLime)
            }
            Spacer()
            Image(systemName: "flame.fill").font(.system(size: 32)).foregroundColor(Color.brandLime.opacity(0.3))
        }
        .padding().background(Color.brandLime.opacity(0.08)).cornerRadius(12)
    }
}

private struct UseResultButton: View {
    let result: CalculatorResult
    let onResult: (CalculatorResult) -> Void

    var body: some View {
        Button { onResult(result) } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Use This Result").font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundColor(.brandNavy).frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Color.brandLime).cornerRadius(12)
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
                Text("Calculate Calories").font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundColor(.brandNavy).frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Color.brandOrange).cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Strength Calculator (pre-fills sets, reps, weight, duration, calories)

private struct StrengthCalculator: View {
    let userWeightKg: Double
    let isImperial: Bool
    let onResult: (CalculatorResult) -> Void

    @State private var sets: Int = 3
    @State private var reps: Int = 10
    @State private var liftWeightText: String = "135"
    @State private var durationText: String = "45"
    @State private var result: Int? = nil

    private var weightUnit: String { isImperial ? "lbs" : "kg" }
    private var liftWeightKg: Double {
        let v = max(0, Double(liftWeightText) ?? 0)
        return isImperial ? v * 0.453592 : v
    }
    private var durationMins: Int { max(0, Int(durationText) ?? 45) }
    private var liftWeightLbs: Double { liftWeightKg * 2.20462 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Strength Training").font(.headline).foregroundColor(.brandCream)
            CalcStepper(label: "Sets", value: $sets, range: 1...20)
            CalcStepper(label: "Reps per set", value: $reps, range: 1...100)
            CalcTextField(label: "Weight lifted (\(weightUnit))", placeholder: isImperial ? "e.g. 135" : "e.g. 60", text: $liftWeightText)
            CalcTextField(label: "Session duration (minutes)", placeholder: "e.g. 45", text: $durationText, keyboard: .numberPad)
            FormulaInfoButton(formula: "Calories = (sets × reps × lift_weight_kg × 0.075) + (MET 6.0 × body_weight_kg × duration_hrs)\n\nAll fields pre-fill when you use the result.")
            CalculateButton {
                let repCals = Double(sets * reps) * liftWeightKg * 0.075
                let metCals = 6.0 * userWeightKg * (Double(durationMins) / 60.0)
                result = max(1, Int(repCals + metCals))
            }
            if let r = result {
                ResultBanner(calories: r)
                UseResultButton(
                    result: CalculatorResult(
                        calories: r,
                        duration: durationMins,
                        sets: sets,
                        reps: reps,
                        weightLbs: liftWeightLbs
                    ),
                    onResult: onResult
                )
            }
        }
        .padding().background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1)).cornerRadius(16)
    }
}

// MARK: - Cardio Calculator (type + intensity + direct duration)

private struct CardioCalculator: View {
    let userWeightKg: Double
    let isImperial: Bool
    let workoutName: String
    let onResult: (CalculatorResult) -> Void

    enum CardioType: String, CaseIterable {
        case walking = "Walking", running = "Running", cycling = "Cycling", sprinting = "Sprinting"
        var baseMET: Double {
            switch self {
            case .walking:   return 3.5
            case .running:   return 9.8
            case .cycling:   return 7.5
            case .sprinting: return 14.0
            }
        }
        var icon: String {
            switch self {
            case .walking:   return "figure.walk"
            case .running:   return "figure.run"
            case .cycling:   return "bicycle"
            case .sprinting: return "hare.fill"
            }
        }
    }

    enum Intensity: String, CaseIterable {
        case light = "Light", moderate = "Moderate", hard = "Hard"
        var multiplier: Double {
            switch self {
            case .light:    return 0.80
            case .moderate: return 1.00
            case .hard:     return 1.25
            }
        }
        var color: Color {
            switch self {
            case .light:    return Color(red: 0.25, green: 0.72, blue: 0.55)
            case .moderate: return .brandOrange
            case .hard:     return Color(red: 0.96, green: 0.35, blue: 0.35)
            }
        }
    }

    @State private var selectedType: CardioType = .running
    @State private var selectedIntensity: Intensity = .moderate
    @State private var durationText: String = "30"
    @State private var distanceText: String = ""      // optional reference
    @State private var result: Int? = nil

    private var durationMins: Int { max(0, Int(durationText) ?? 0) }
    private var distanceUnit: String { isImperial ? "miles" : "km" }
    private var effectiveMET: Double { selectedType.baseMET * selectedIntensity.multiplier }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cardio").font(.headline).foregroundColor(.brandCream)

            // Activity type
            Text("Activity Type").font(.caption).foregroundColor(Color.brandCream.opacity(0.5))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(CardioType.allCases, id: \.self) { type in
                    Button { selectedType = type; result = nil } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type.icon).font(.system(size: 13))
                            Text(type.rawValue).font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(selectedType == type ? .brandNavy : Color.brandCream.opacity(0.7))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(selectedType == type ? Color.brandLime : Color.brandCream.opacity(0.08)))
                    }.buttonStyle(.plain)
                }
            }

            // Intensity
            VStack(alignment: .leading, spacing: 8) {
                Text("Intensity").font(.caption).foregroundColor(Color.brandCream.opacity(0.5))
                HStack(spacing: 8) {
                    ForEach(Intensity.allCases, id: \.self) { level in
                        Button { selectedIntensity = level; result = nil } label: {
                            Text(level.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(selectedIntensity == level ? .brandNavy : level.color)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(selectedIntensity == level ? level.color : level.color.opacity(0.12)))
                        }.buttonStyle(.plain)
                    }
                }
            }

            // Duration — required
            CalcTextField(label: "Duration (minutes) *", placeholder: "e.g. 30", text: $durationText, keyboard: .numberPad)

            // Distance — optional reference
            CalcTextField(label: "Distance (\(distanceUnit)) — optional", placeholder: "e.g. 3.0", text: $distanceText)

            // MET info
            HStack(spacing: 6) {
                Image(systemName: "info.circle").font(.system(size: 11)).foregroundColor(.brandBlue)
                Text("Effective MET: \(String(format: "%.1f", effectiveMET)) (\(selectedType.rawValue) · \(selectedIntensity.rawValue))")
                    .font(.system(size: 11)).foregroundColor(Color.brandCream.opacity(0.5))
            }

            FormulaInfoButton(formula: "Calories = base_MET × intensity_multiplier × body_weight_kg × (duration_hrs)\n\n• Walking: 3.5 | Running: 9.8 | Cycling: 7.5 | Sprinting: 14.0\n• Light: ×0.80 | Moderate: ×1.00 | Hard: ×1.25")

            CalculateButton {
                guard durationMins > 0 else { return }
                let cals = effectiveMET * userWeightKg * (Double(durationMins) / 60.0)
                result = max(1, Int(cals))
            }

            if let r = result {
                ResultBanner(calories: r)
                UseResultButton(
                    result: CalculatorResult(calories: r, duration: durationMins),
                    onResult: onResult
                )
            }
        }
        .padding().background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1)).cornerRadius(16)
        .onAppear {
            if workoutName.lowercased().contains("walk") { selectedType = .walking }
            else if workoutName.lowercased().contains("sprint") { selectedType = .sprinting }
            else if workoutName.lowercased().contains("cycl") || workoutName.lowercased().contains("bike") { selectedType = .cycling }
            else { selectedType = .running }
        }
    }
}

// MARK: - Sports Calculator

private struct SportsCalculator: View {
    let userWeightKg: Double
    let isImperial: Bool
    let workoutName: String
    let onResult: (CalculatorResult) -> Void

    enum SportType: String, CaseIterable {
        case football = "Football", basketball = "Basketball", soccer = "Soccer", rockClimbing = "Rock Climbing"
        var met: Double { switch self { case .football: return 8.0; case .basketball: return 8.0; case .soccer: return 10.0; case .rockClimbing: return 7.5 } }
        var icon: String { switch self { case .football: return "sportscourt.fill"; case .basketball: return "basketball.fill"; case .soccer: return "soccerball"; case .rockClimbing: return "mountain.2.fill" } }
    }

    @State private var selectedSport: SportType = .basketball
    @State private var durationText: String = "60"
    @State private var result: Int? = nil
    private var durationMins: Int { max(0, Int(durationText) ?? 60) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sports").font(.headline).foregroundColor(.brandCream)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(SportType.allCases, id: \.self) { sport in
                    Button { selectedSport = sport; result = nil } label: {
                        HStack(spacing: 6) {
                            Image(systemName: sport.icon).font(.system(size: 13))
                            Text(sport.rawValue).font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(selectedSport == sport ? .brandNavy : Color.brandCream.opacity(0.7))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(selectedSport == sport ? Color.brandLime : Color.brandCream.opacity(0.08)))
                    }.buttonStyle(.plain)
                }
            }
            CalcTextField(label: "Duration (minutes)", placeholder: "e.g. 60", text: $durationText, keyboard: .numberPad)
            FormulaInfoButton(formula: "Calories = MET × body_weight_kg × (duration_mins ÷ 60)\n\n• Football/Basketball: 8.0 | Soccer: 10.0 | Rock Climbing: 7.5")
            CalculateButton { result = max(1, Int(selectedSport.met * userWeightKg * Double(durationMins) / 60.0)) }
            if let r = result {
                ResultBanner(calories: r)
                UseResultButton(result: CalculatorResult(calories: r, duration: durationMins), onResult: onResult)
            }
        }
        .padding().background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1)).cornerRadius(16)
        .onAppear {
            if workoutName.lowercased().contains("football") { selectedSport = .football }
            else if workoutName.lowercased().contains("basketball") { selectedSport = .basketball }
            else if workoutName.lowercased().contains("soccer") { selectedSport = .soccer }
            else if workoutName.lowercased().contains("climb") { selectedSport = .rockClimbing }
        }
    }
}

// MARK: - Flexibility Calculator

private struct FlexibilityCalculator: View {
    let userWeightKg: Double
    let isImperial: Bool
    let workoutName: String
    let onResult: (CalculatorResult) -> Void

    enum FlexType: String, CaseIterable {
        case yoga = "Yoga", pilates = "Pilates"
        var met: Double { switch self { case .yoga: return 3.0; case .pilates: return 3.5 } }
        var icon: String { switch self { case .yoga: return "figure.mind.and.body"; case .pilates: return "figure.cooldown" } }
        var description: String { switch self { case .yoga: return "Hatha, Vinyasa or restorative"; case .pilates: return "Mat or reformer Pilates" } }
    }

    @State private var selectedType: FlexType = .yoga
    @State private var durationText: String = "60"
    @State private var intensityIndex: Int = 1
    @State private var result: Int? = nil
    private let intensityLabels = ["Light", "Moderate", "Intense"]
    private let intensityMultipliers: [Double] = [0.85, 1.0, 1.2]
    private var durationMins: Int { max(0, Int(durationText) ?? 60) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Flexibility").font(.headline).foregroundColor(.brandCream)
            HStack(spacing: 8) {
                ForEach(FlexType.allCases, id: \.self) { type in
                    Button { selectedType = type; result = nil } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.icon).font(.system(size: 20))
                            Text(type.rawValue).font(.system(size: 12, weight: .semibold))
                            Text(type.description).font(.system(size: 9)).multilineTextAlignment(.center)
                                .foregroundColor(selectedType == type ? Color.brandNavy.opacity(0.7) : Color.brandCream.opacity(0.4))
                        }
                        .foregroundColor(selectedType == type ? .brandNavy : Color.brandCream.opacity(0.7))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(selectedType == type ? Color.brandLime : Color.brandCream.opacity(0.08)))
                    }.buttonStyle(.plain)
                }
            }
            CalcTextField(label: "Duration (minutes)", placeholder: "e.g. 60", text: $durationText, keyboard: .numberPad)
            VStack(alignment: .leading, spacing: 8) {
                Text("Intensity").font(.caption).foregroundColor(Color.brandCream.opacity(0.5))
                Picker("Intensity", selection: $intensityIndex) {
                    ForEach(0..<intensityLabels.count, id: \.self) { i in Text(intensityLabels[i]).tag(i) }
                }.pickerStyle(.segmented)
            }
            FormulaInfoButton(formula: "Calories = MET × intensity × body_weight_kg × (duration_mins ÷ 60)")
            CalculateButton { result = max(1, Int(selectedType.met * intensityMultipliers[intensityIndex] * userWeightKg * Double(durationMins) / 60.0)) }
            if let r = result {
                ResultBanner(calories: r)
                UseResultButton(result: CalculatorResult(calories: r, duration: durationMins), onResult: onResult)
            }
        }
        .padding().background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1)).cornerRadius(16)
        .onAppear { if workoutName.lowercased().contains("pilates") { selectedType = .pilates } else { selectedType = .yoga } }
    }
}

// MARK: - Outdoor Calculator

private struct OutdoorCalculator: View {
    let userWeightKg: Double
    let isImperial: Bool
    let workoutName: String
    let onResult: (CalculatorResult) -> Void

    enum HikeType: String, CaseIterable {
        case uphill = "Uphill", downhill = "Downhill"
        var met: Double { switch self { case .uphill: return 8.0; case .downhill: return 5.3 } }
        var icon: String { switch self { case .uphill: return "arrow.up.right"; case .downhill: return "arrow.down.right" } }
        var description: String { switch self { case .uphill: return "Ascending, elevation gain"; case .downhill: return "Descending, less effort" } }
    }

    @State private var selectedType: HikeType = .uphill
    @State private var distanceText: String = "3.0"
    @State private var durationText: String = "90"
    @State private var elevationText: String = "500"
    @State private var result: Int? = nil

    private var distanceUnit: String { isImperial ? "miles" : "km" }
    private var elevationUnit: String { isImperial ? "ft" : "m" }
    private var durationMins: Int { max(0, Int(durationText) ?? 90) }
    private var elevationFt: Double { let v = max(0, Double(elevationText) ?? 0); return isImperial ? v : v * 3.28084 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Outdoor").font(.headline).foregroundColor(.brandCream)
            HStack(spacing: 8) {
                ForEach(HikeType.allCases, id: \.self) { type in
                    Button { selectedType = type; result = nil } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.icon).font(.system(size: 18))
                            Text(type.rawValue).font(.system(size: 13, weight: .semibold))
                            Text(type.description).font(.system(size: 9)).multilineTextAlignment(.center)
                                .foregroundColor(selectedType == type ? Color.brandNavy.opacity(0.7) : Color.brandCream.opacity(0.4))
                        }
                        .foregroundColor(selectedType == type ? .brandNavy : Color.brandCream.opacity(0.7))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(selectedType == type ? Color.brandLime : Color.brandCream.opacity(0.08)))
                    }.buttonStyle(.plain)
                }
            }
            CalcTextField(label: "Distance (\(distanceUnit))", placeholder: isImperial ? "e.g. 3.0" : "e.g. 5.0", text: $distanceText)
            CalcTextField(label: "Duration (minutes)", placeholder: "e.g. 90", text: $durationText, keyboard: .numberPad)
            if selectedType == .uphill {
                CalcTextField(label: "Elevation gain (\(elevationUnit))", placeholder: isImperial ? "e.g. 500" : "e.g. 150", text: $elevationText, keyboard: .numberPad)
            }
            FormulaInfoButton(formula: "Calories = (MET × body_weight_kg × duration_hrs) + elevation_bonus\n\n• Uphill MET: 8.0 | Downhill MET: 5.3")
            CalculateButton {
                let baseCals = selectedType.met * userWeightKg * Double(durationMins) / 60.0
                let elevBonus = selectedType == .uphill ? (elevationFt / 100.0) * ((userWeightKg * 2.20462) / 100.0) * 0.35 : 0
                result = max(1, Int(baseCals + elevBonus))
            }
            if let r = result {
                ResultBanner(calories: r)
                UseResultButton(result: CalculatorResult(calories: r, duration: durationMins), onResult: onResult)
            }
        }
        .padding().background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1)).cornerRadius(16)
        .onAppear { if workoutName.lowercased().contains("down") { selectedType = .downhill } else { selectedType = .uphill } }
    }
}

// MARK: - Robot Icon

struct RobotIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 64
            ctx.fill(Path(roundedRect: CGRect(x: 7*s, y: 6*s, width: 50*s, height: 3*s), cornerRadius: 1.5*s), with: .color(.white))
            ctx.fill(Path(roundedRect: CGRect(x: 4*s, y: 3.5*s, width: 3.5*s, height: 8*s), cornerRadius: s), with: .color(.white.opacity(0.95)))
            ctx.fill(Path(roundedRect: CGRect(x: 1*s, y: 3*s, width: 3*s, height: 9*s), cornerRadius: s), with: .color(.white.opacity(0.8)))
            ctx.fill(Path(roundedRect: CGRect(x: -1.5*s, y: 2.5*s, width: 2.5*s, height: 10*s), cornerRadius: s), with: .color(.white.opacity(0.65)))
            ctx.fill(Path(roundedRect: CGRect(x: 56.5*s, y: 3.5*s, width: 3.5*s, height: 8*s), cornerRadius: s), with: .color(.white.opacity(0.95)))
            ctx.fill(Path(roundedRect: CGRect(x: 60*s, y: 3*s, width: 3*s, height: 9*s), cornerRadius: s), with: .color(.white.opacity(0.8)))
            ctx.fill(Path(roundedRect: CGRect(x: 63*s, y: 2.5*s, width: 2.5*s, height: 10*s), cornerRadius: s), with: .color(.white.opacity(0.65)))
            ctx.fill(Path(roundedRect: CGRect(x: 9*s, y: 5*s, width: 5*s, height: 5*s), cornerRadius: 1.5*s), with: .color(.white))
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
    @StateObject private var vm = AIAssistantViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                Color.brandNavy.ignoresSafeArea()
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(vm.messages) { msg in AIMessageBubble(message: msg).id(msg.id) }
                                if vm.isLoading { TypingIndicator().id("typing") }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                        }
                        .onChange(of: vm.messages.count) { _, _ in withAnimation { proxy.scrollTo(vm.messages.last?.id ?? "typing", anchor: .bottom) } }
                        .onChange(of: vm.isLoading) { _, _ in withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
                    }

                    if vm.messages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(vm.suggestions, id: \.self) { chip in
                                    Button { vm.send(chip, context: buildContext()) } label: {
                                        Text(chip).font(.system(size: 11, weight: .semibold)).foregroundColor(.brandLime)
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background(Color.brandLime.opacity(0.1)).clipShape(Capsule())
                                            .overlay(Capsule().stroke(Color.brandLime.opacity(0.3), lineWidth: 0.5))
                                    }.buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                        }
                    }

                    Divider().background(Color.brandCream.opacity(0.12))

                    HStack(spacing: 10) {
                        ZStack(alignment: .leading) {
                            if vm.inputText.isEmpty {
                                Text("Ask about your fitness...").foregroundColor(Color.brandCream.opacity(0.3)).font(.system(size: 14)).padding(.leading, 12)
                            }
                            TextField("", text: $vm.inputText, axis: .vertical)
                                .foregroundColor(.brandCream).font(.system(size: 14)).lineLimit(1...4)
                                .padding(.horizontal, 12).padding(.vertical, 10)
                        }
                        .background(Color.brandCream.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.brandCream.opacity(0.18), lineWidth: 1)).cornerRadius(20)

                        Button {
                            let text = vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !text.isEmpty else { return }
                            vm.send(text, context: buildContext())
                        } label: {
                            ZStack {
                                Circle().fill(vm.isLoading ? Color.brandCream.opacity(0.2) : Color.brandLime).frame(width: 36, height: 36)
                                Image(systemName: "paperplane.fill").font(.system(size: 14, weight: .semibold)).foregroundColor(.brandNavy)
                            }
                        }
                        .disabled(vm.isLoading || vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.brandOrange).frame(width: 44, height: 44)
                        RobotIcon().frame(width: 28, height: 28)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Fitness Coach").font(.system(size: 16, weight: .bold)).foregroundColor(.brandCream)
                        Text("Powered by Claude").font(.system(size: 12)).foregroundColor(Color.brandCream.opacity(0.5))
                    }
                    Spacer()
                    Button("Done") { dismiss() }.font(.system(size: 15, weight: .semibold)).foregroundColor(.brandLime)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color.brandNavy)
                .overlay(Divider().background(Color.brandCream.opacity(0.12)), alignment: .bottom)
            }
        }
        .onAppear {
            vm.sendWelcome(userName: (appState.currentUser?.name ?? "").components(separatedBy: " ").first ?? "there")
        }
    }

    private func buildContext() -> String {
        let user = appState.currentUser
        let uid = user?.id ?? ""

        // --- Workouts ---
        let storageKey = "savedExercises_\(uid)"
        var exercises: [ActivityEntry] = []
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ActivityEntry].self, from: data) {
            exercises = decoded
        }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let completedToday = exercises.filter { $0.isCompleted(on: today) }
        let totalCalsBurned = completedToday.reduce(0) { $0 + $1.caloriesBurned }

        // Streak
        var streak = 0
        var checkDate = today
        while exercises.contains(where: { $0.isCompleted(on: checkDate) }) {
            streak += 1
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        // Full workout detail for today
        let workoutDetails = completedToday.map { w -> String in
            if let dur = w.duration {
                return "\(w.name) (\(w.category.rawValue), \(dur) min, \(w.caloriesBurned) kcal)"
            } else {
                let wt = w.weight.map { ", \(Int($0)) lbs" } ?? ""
                return "\(w.name) (\(w.category.rawValue), \(w.sets) sets × \(w.reps) reps\(wt), \(w.caloriesBurned) kcal)"
            }
        }.joined(separator: "\n  • ")

        // --- Nutrition from UserDefaults ---
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let todayKey = "nutritionLog_\(uid)_\(f.string(from: today))"
        var totalCaloriesEaten: Double = 0
        var totalProtein: Double = 0
        var totalCarbs: Double = 0
        var totalFat: Double = 0
        var loggedFoodNames: [String] = []
        if let data = UserDefaults.standard.data(forKey: todayKey),
           let entries = try? JSONDecoder().decode([LoggedFoodEntry].self, from: data) {
            totalCaloriesEaten = entries.reduce(0) { $0 + $1.foodItem.calories }
            totalProtein       = entries.reduce(0) { $0 + $1.foodItem.protein }
            totalCarbs         = entries.reduce(0) { $0 + $1.foodItem.carbs }
            totalFat           = entries.reduce(0) { $0 + $1.foodItem.fat }
            loggedFoodNames    = entries.map { "\($0.foodItem.description) (\(Int($0.foodItem.calories)) kcal)" }
        }

        // --- Water ---
        let waterKey = "waterConsumed_\(uid)_\(f.string(from: today))"
        let waterConsumed = UserDefaults.standard.integer(forKey: waterKey)
        let waterGoal = UserDefaults.standard.integer(forKey: "waterGoal")

        // --- Height formatting (height is stored as total inches) ---
        let totalInches = Int(user?.height ?? 0)
        let heightFt = totalInches / 12
        let heightIn = totalInches % 12
        let heightStr = totalInches > 0 ? "\(heightFt)'\(heightIn)\"" : "Not set"

        // --- Age (computed directly from birthDate) ---
        let ageStr = user != nil ? "\(user!.age) years old" : "Not set"

        // --- BMI (weight lbs / height inches² × 703) ---
        let bmiStr: String = {
            guard let u = user, totalInches > 0 else { return "N/A" }
            let bmi = (u.weight / Double(totalInches * totalInches)) * 703
            return String(format: "%.1f", bmi)
        }()

        // --- BMR ---
        let bmrStr = user != nil ? "\(Int(user!.bmr)) kcal/day" : "N/A"

        return """
        === USER PROFILE ===
        Name: \(user?.name ?? "Unknown")
        Age: \(ageStr)
        Gender: \(user?.gender ?? "Not set")
        Height: \(heightStr)
        Current weight: \(Int(user?.weight ?? 0)) lbs (\(String(format: "%.1f", user?.weightKg ?? 0)) kg)
        Target weight: \(user?.targetWeightLbs.map { "\(Int($0)) lbs" } ?? "Not set")
        BMI: \(bmiStr)
        BMR: \(bmrStr)

        === GOALS & TARGETS ===
        Primary goal: \(user?.primaryGoal ?? "Unknown")
        Activity level: \(user?.activityLevel ?? "Unknown")
        Daily calorie goal: \(user?.calorieGoal ?? 0) kcal
        Units preference: \(user?.units ?? "Imperial")

        === TODAY'S NUTRITION ===
        Calories eaten: \(Int(totalCaloriesEaten)) kcal (goal: \(user?.calorieGoal ?? 0) kcal)
        Protein: \(Int(totalProtein))g | Carbs: \(Int(totalCarbs))g | Fat: \(Int(totalFat))g
        Foods logged today:
          • \(loggedFoodNames.isEmpty ? "Nothing logged yet" : loggedFoodNames.joined(separator: "\n  • "))

        === TODAY'S HYDRATION ===
        Water consumed: \(waterConsumed) / \(waterGoal > 0 ? waterGoal : 8) glasses

        === TODAY'S WORKOUTS ===
        Completed: \(completedToday.count) workout(s)
        Total calories burned: \(totalCalsBurned) kcal
        Details:
          • \(workoutDetails.isEmpty ? "None yet" : workoutDetails)

        === FITNESS STATS ===
        Current streak: \(streak) days
        Total exercises in library: \(exercises.count)
        """
    }
}

// MARK: - Message Model

struct AIMessage: Identifiable {
    let id = UUID().uuidString
    let role: String
    let content: String
}

// MARK: - AI ViewModel

@MainActor
class AIAssistantViewModel: ObservableObject {
    @Published var messages: [AIMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false

    let suggestions = ["How do I improve my streak?", "What should I eat today?", "Best exercises for weight loss?", "How many rest days do I need?", "Tips to hit my calorie goal"]
    private let apiKey = ""
    private let systemPrompt = """
    You are a knowledgeable, friendly fitness coach built into a fitness tracking app.
    Keep responses concise and practical — ideally 2-4 sentences unless more detail is needed.
    Always be encouraging and positive. Use the user's fitness data provided in context to give personalized advice.
    Only answer fitness, health, nutrition, and wellness related questions.
    """

    func sendWelcome(userName: String) {
        messages.append(AIMessage(role: "assistant", content: "Hey \(userName)! 💪 I'm your AI fitness coach. Ask me anything about your workouts, nutrition, recovery, or how to reach your goals."))
    }

    func send(_ text: String, context: String) {
        messages.append(AIMessage(role: "user", content: text))
        inputText = ""
        isLoading = true
        Task {
            do {
                let reply = try await callClaude(userText: text, context: context)
                messages.append(AIMessage(role: "assistant", content: reply))
            } catch {
                messages.append(AIMessage(role: "assistant", content: "Sorry, I couldn't connect right now. Please try again."))
            }
            isLoading = false
        }
    }

    private func callClaude(userText: String, context: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        var apiMessages: [[String: String]] = []
        apiMessages.append(["role": "user", "content": "Here is my fitness data:\n\(context)"])
        apiMessages.append(["role": "assistant", "content": "Got it! I have your fitness data loaded. How can I help you today?"])
        for msg in messages.dropFirst() { apiMessages.append(["role": msg.role, "content": msg.content]) }
        let body: [String: Any] = ["model": "claude-sonnet-4-5", "max_tokens": 1024, "system": systemPrompt, "messages": apiMessages]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let error = json?["error"] as? [String: Any], let message = error["message"] as? String { return "Error: \(message)" }
        let content = (json?["content"] as? [[String: Any]])?.first?["text"] as? String
        return content ?? "I couldn't generate a response. Please try again."
    }
}

// MARK: - AI Message Bubble

struct AIMessageBubble: View {
    let message: AIMessage
    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 48) }
            if !isUser {
                ZStack {
                    Circle().fill(Color.brandOrange).frame(width: 28, height: 28)
                    RobotIcon().frame(width: 18, height: 18)
                }
            }
            Text(message.content).font(.system(size: 14))
                .foregroundColor(isUser ? .brandNavy : .brandCream)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(isUser ? Color.brandLime : Color.brandCream.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(isUser ? Color.clear : Color.brandCream.opacity(0.12), lineWidth: 1))
                .cornerRadius(18)
                .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            if isUser {
                ZStack {
                    Circle().fill(Color.brandLime.opacity(0.2)).frame(width: 28, height: 28)
                    Image(systemName: "person.fill").font(.system(size: 13)).foregroundColor(.brandLime)
                }
            }
            if !isUser { Spacer(minLength: 48) }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle().fill(Color.brandOrange).frame(width: 28, height: 28)
                RobotIcon().frame(width: 18, height: 18)
            }
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Color.brandCream.opacity(0.5)).frame(width: 7, height: 7)
                        .offset(y: animate ? -4 : 0)
                        .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: animate)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
            .background(Color.brandCream.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.brandCream.opacity(0.12), lineWidth: 1)).cornerRadius(18)
            Spacer(minLength: 48)
        }
        .onAppear { animate = true }
    }
}

#Preview {
    ActivityLogView(userId: "preview")
        .environment(AppState())
}
