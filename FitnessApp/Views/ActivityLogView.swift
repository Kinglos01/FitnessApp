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
        self.id = id
        self.name = name
        self.category = category
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.duration = duration
        self.caloriesBurned = caloriesBurned
        self.notes = notes
        self.date = date
        self.isCompleted = isCompleted
    }
}

enum ExerciseCategory: String, CaseIterable, Codable {
    case strength = "Strength"
    case cardio = "Cardio"
    case sports = "Sports"
    case flexibility = "Flexibility"
    case core = "Core"
    case recovery = "Recovery"
    case outdoor = "Outdoor"

    var icon: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .cardio: return "figure.run"
        case .sports: return "sportscourt.fill"
        case .flexibility: return "figure.cooldown"
        case .core: return "bolt.heart.fill"
        case .recovery: return "heart.text.square.fill"
        case .outdoor: return "sun.max.fill"
        }
    }

    var color: Color {
        switch self {
        case .strength: return Color(red: 0.96, green: 0.35, blue: 0.35)
        case .cardio: return Color(red: 0.25, green: 0.72, blue: 0.55)
        case .sports: return Color(red: 0.65, green: 0.35, blue: 0.95)
        case .flexibility: return Color(red: 0.40, green: 0.60, blue: 0.95)
        case .core: return Color(red: 0.96, green: 0.60, blue: 0.20)
        case .recovery: return Color(red: 0.25, green: 0.70, blue: 0.80)
        case .outdoor: return Color(red: 0.95, green: 0.78, blue: 0.22)
        }
    }

    var suggestedExercises: [String] {
        switch self {
        case .strength:
            return ["Bench Press", "Squat", "Deadlift", "Shoulder Press", "Lat Pulldown", "Bicep Curl", "Leg Press"]
        case .cardio:
            return ["Walk", "Jog", "Run", "Treadmill", "Elliptical", "Bike", "Stairmaster"]
        case .sports:
            return ["Basketball", "Soccer", "Football", "Baseball", "Tennis", "Volleyball"]
        case .flexibility:
            return ["Yoga", "Stretching", "Pilates", "Mobility Flow"]
        case .core:
            return ["Sit-Ups", "Crunches", "Plank", "Russian Twists", "Leg Raises", "Mountain Climbers"]
        case .recovery:
            return ["Foam Rolling", "Recovery Walk", "Breathing Session", "Light Stretch", "Sauna Session"]
        case .outdoor:
            return ["Hike", "Outdoor Run", "Cycling", "Trail Walk", "Stadium Steps"]
        }
    }

    var usesDuration: Bool {
        switch self {
        case .cardio, .sports, .flexibility, .recovery, .outdoor:
            return true
        case .strength, .core:
            return false
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

    private let userId: String
    private var storageKey: String { "savedExercises_\(userId)" }

    init(userId: String) {
        self.userId = userId
        load()
    }

    var filteredExercises: [ActivityEntry] {
        let sorted = exercises.sorted { $0.date > $1.date }

        let categoryFiltered: [ActivityEntry]
        if let selectedFilter {
            categoryFiltered = sorted.filter { $0.category == selectedFilter }
        } else {
            categoryFiltered = sorted
        }

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
            } else {
                break
            }
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
        save()
    }

    func update(_ exercise: ActivityEntry) {
        if let idx = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[idx] = exercise
            save()
        }
    }

    func deleteEntry(_ entry: ActivityEntry) {
        exercises.removeAll { $0.id == entry.id }
        save()
    }

    func toggleComplete(_ entry: ActivityEntry) {
        if let idx = exercises.firstIndex(where: { $0.id == entry.id }) {
            let newValue = !exercises[idx].isCompleted
            exercises[idx].isCompleted = newValue

            if newValue {
                exercises[idx].date = Date()
            }

            save()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(exercises) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ActivityEntry].self, from: data) {
            let today = Calendar.current.startOfDay(for: Date())

            exercises = decoded.map { entry in
                var updated = entry
                if updated.isCompleted && Calendar.current.startOfDay(for: updated.date) != today {
                    updated.isCompleted = false
                }
                return updated
            }

            save()
        }
    }
}

// MARK: - Main View

struct ActivityLogView: View {
    @StateObject private var vm: ActivityLogViewModel
    @State private var animateStats = false
    //AI
    @State private var showAIAssistant = false 

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
            .navigationTitle("Activity Log") //AI
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAIAssistant = true } label: {
                        VStack(spacing: 2) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 38, height: 38)
                                RobotIcon()
                             }
                            Text("Ask AI")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.orange)
            }
        }
    }
}
            .overlay(alignment: .bottom) { floatingAddButton }
            .navigationTitle("Activity Log")
            .overlay(alignment: .bottom) {
                floatingAddButton
            }
            .sheet(isPresented: $vm.showingAddSheet) {
                AddExerciseSheet(
                    vm: vm,
                    editingExercise: nil,
                    initialCategory: vm.preselectedCategory
                )
            }
            .sheet(item: $vm.editingExercise) { exercise in
                AddExerciseSheet(
                    vm: vm,
                    editingExercise: exercise,
                    initialCategory: exercise.category
                )
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateStats = true
            }
            //AI
            .sheet(isPresented: $showAIAssistant) {  
                                                   AIAssistantSheet()
                .environment(appState)
            }
        }
    }

    private var statsStrip: some View {
        HStack(spacing: 12) {
            StatCard(
                value: "\(vm.totalWorkoutsToday)",
                label: "Workouts",
                icon: "checkmark.circle.fill",
                color: .green,
                animate: animateStats
            )

            StatCard(
                value: "\(vm.totalCaloriesToday)",
                label: "Calories",
                icon: "flame.fill",
                color: .orange,
                animate: animateStats
            )

            StatCard(
                value: "\(vm.currentStreak)",
                label: "Streak",
                icon: "bolt.fill",
                color: .blue,
                animate: animateStats
            )
        }
        .padding(.horizontal)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("Search workouts or notes", text: $vm.searchText)
                .textInputAutocapitalization(.words)

            if !vm.searchText.isEmpty {
                Button {
                    vm.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
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
                FilterChip(
                    label: "All",
                    icon: "square.grid.2x2.fill",
                    color: .blue,
                    isSelected: vm.selectedFilter == nil
                ) {
                    withAnimation {
                        vm.selectedFilter = nil
                    }
                }

                ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                    FilterChip(
                        label: cat.rawValue,
                        icon: cat.icon,
                        color: cat.color,
                        isSelected: vm.selectedFilter == cat
                    ) {
                        withAnimation {
                            vm.selectedFilter = vm.selectedFilter == cat ? nil : cat
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }

    private var favoritesSection: some View {
        Group {
            if !vm.recentFavorites.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Quick Add")
                        .font(.headline)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(vm.recentFavorites, id: \.self) { name in
                                Button {
                                    vm.preselectedCategory = .strength
                                    vm.showingAddSheet = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "sparkles")
                                        Text(name)
                                            .lineLimit(1)
                                    }
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
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
            if vm.filteredExercises.isEmpty {
                emptyState
            } else {
                ForEach(vm.filteredExercises) { exercise in
                    ExerciseRow(
                        exercise: exercise,
                        onDelete: {
                            withAnimation {
                                vm.deleteEntry(exercise)
                            }
                        },
                        onToggleComplete: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                vm.toggleComplete(exercise)
                            }
                        }
                    )
                    .onTapGesture {
                        vm.editingExercise = exercise
                    }
                    .contextMenu {
                        Button {
                            vm.editingExercise = exercise
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            vm.deleteEntry(exercise)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 52))
                .foregroundColor(.gray.opacity(0.3))

            Text("No workouts yet")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.gray)

            Text("Tap the button below and log something for today.")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
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
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
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
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(.primary)
                .scaleEffect(animate ? 1.0 : 0.5)
                .opacity(animate ? 1.0 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: animate)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
                .textCase(.uppercase)
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
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
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
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(exercise.isCompleted ? .gray : .primary)
                    .strikethrough(exercise.isCompleted)

                Text(subtitleText)
                    .font(.caption)
                    .foregroundColor(.gray)

                if !exercise.notes.isEmpty {
                    Text(exercise.notes)
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.75))
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(exercise.category.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(exercise.category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(exercise.category.color.opacity(0.15))
                    .clipShape(Capsule())

                Button {
                    onToggleComplete()
                } label: {
                    Text(exercise.isCompleted ? "Done" : "Mark Done")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(exercise.isCompleted ? .white : exercise.category.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(
                                exercise.isCompleted
                                ? exercise.category.color
                                : exercise.category.color.opacity(0.12)
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(exercise.isCompleted ? Color(.systemGray6).opacity(0.6) : Color(.systemGray6))
        )
    }
}

// MARK: - Add / Edit Sheet

struct AddExerciseSheet: View {
    @ObservedObject var vm: ActivityLogViewModel
    let editingExercise: ActivityEntry?
    let initialCategory: ExerciseCategory

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: ExerciseCategory = .strength
    @State private var sets = 3
    @State private var reps = 10
    @State private var weight = ""
    @State private var duration = ""
    @State private var calories = ""
    @State private var notes = ""

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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if isEditing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            if let editingExercise {
                                vm.deleteEntry(editingExercise)
                            }
                            dismiss()
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
        .onAppear {
            populateIfNeeded()
        }
    }

    private var categoryPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.caption)
                .foregroundColor(.gray)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                        Button {
                            category = cat
                            if name.isEmpty {
                                name = cat.suggestedExercises.first ?? ""
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: cat.icon)
                                Text(cat.rawValue)
                            }
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(category == cat ? .white : cat.color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(category == cat ? cat.color : cat.color.opacity(0.12))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var suggestedExercisesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workout Name")
                .font(.caption)
                .foregroundColor(.gray)
                .textCase(.uppercase)

            TextField("Enter workout name", text: $name)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)

            Text("Quick picks")
                .font(.subheadline)
                .fontWeight(.semibold)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                ForEach(category.suggestedExercises, id: \.self) { suggestion in
                    Button {
                        name = suggestion
                    } label: {
                        Text(suggestion)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.caption)
                .foregroundColor(.gray)
                .textCase(.uppercase)

            if category.usesDuration {
                detailField(title: "Duration (minutes)", text: $duration, keyboard: .numberPad)
                detailField(title: "Calories Burned", text: $calories, keyboard: .numberPad)
            } else {
                Stepper("Sets: \(sets)", value: $sets, in: 1...20)
                Stepper("Reps: \(reps)", value: $reps, in: 1...100)
                detailField(title: "Weight (lbs)", text: $weight, keyboard: .decimalPad)
                detailField(title: "Calories Burned", text: $calories, keyboard: .numberPad)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes")
                .font(.caption)
                .foregroundColor(.gray)
                .textCase(.uppercase)

            TextField("This is another workout for the user, maybe add a quick note here.", text: $notes, axis: .vertical)
                .lineLimit(3...5)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }

    private var saveButton: some View {
        Button {
            saveExercise()
        } label: {
            Text(isEditing ? "Save Changes" : "Add Workout")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(category.color)
                .cornerRadius(14)
        }
        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func detailField(title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)

            TextField(title, text: text)
                .keyboardType(keyboard)
                .padding(10)
                .background(Color.white.opacity(0.7))
                .cornerRadius(10)
        }
    }

    private func populateIfNeeded() {
        category = editingExercise?.category ?? initialCategory

        guard let exercise = editingExercise else { return }

        name = exercise.name
        sets = exercise.sets
        reps = exercise.reps
        weight = exercise.weight.map { String(Int($0)) } ?? ""
        duration = exercise.duration.map { String($0) } ?? ""
        calories = String(exercise.caloriesBurned)
        notes = exercise.notes
    }

    private func saveExercise() {
        let entry = ActivityEntry(
            id: editingExercise?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            sets: category.usesDuration ? 0 : sets,
            reps: category.usesDuration ? 0 : reps,
            weight: category.usesDuration ? nil : Double(weight),
            duration: category.usesDuration ? Int(duration) : nil,
            caloriesBurned: Int(calories) ?? 0,
            notes: notes,
            date: editingExercise?.date ?? Date(),
            isCompleted: editingExercise?.isCompleted ?? false
        )

        if isEditing {
            vm.update(entry)
        } else {
            vm.add(entry)
        }

        dismiss()
    }
}

// MARK: - Preview

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
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.orange.opacity(0.3), lineWidth: 0.5))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                Divider()
                HStack(spacing: 10) {
                    TextField("Ask about your workouts...", text: $messageText)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                    Button { messageText = "" } label: {
                        ZStack {
                            Circle().fill(Color.orange).frame(width: 34, height: 34)
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
.navigationBarHidden(true)
.safeAreaInset(edge: .top) {
    HStack(spacing: 12) {
        ZStack {
            Circle().fill(Color.orange).frame(width: 44, height: 44)
            RobotIcon().frame(width: 28, height: 28)
        }
        VStack(alignment: .leading, spacing: 2) {
            Text("AI Fitness Assistant")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
            Text("Powered by your workout data")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        Spacer()
        Button("Done") { dismiss() }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.orange)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
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
