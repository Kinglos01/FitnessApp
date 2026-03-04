import SwiftUI
internal import Combine

// MARK: - Models

struct ActivityEntry: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: ExerciseCategory
    var sets: Int
    var reps: Int
    var weight: Double?       // kg
    var duration: Int?        // minutes
    var caloriesBurned: Int
    var notes: String
    var date: Date

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
        date: Date = Date()
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
    }
}

enum ExerciseCategory: String, CaseIterable, Codable {
    case strength = "Strength"
    case cardio = "Cardio"
    case flexibility = "Flexibility"
    case hiit = "HIIT"
    case sports = "Sports"
    case recovery = "Recovery"

    var icon: String {
        switch self {
        case .strength:    return "dumbbell.fill"
        case .cardio:      return "figure.run"
        case .flexibility: return "figure.flexibility"
        case .hiit:        return "bolt.fill"
        case .sports:      return "sportscourt.fill"
        case .recovery:    return "heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .strength:    return Color(red: 0.96, green: 0.35, blue: 0.35)
        case .cardio:      return Color(red: 0.25, green: 0.72, blue: 0.55)
        case .flexibility: return Color(red: 0.40, green: 0.60, blue: 0.95)
        case .hiit:        return Color(red: 1.00, green: 0.65, blue: 0.10)
        case .sports:      return Color(red: 0.65, green: 0.35, blue: 0.95)
        case .recovery:    return Color(red: 0.95, green: 0.45, blue: 0.75)
        }
    }
}

// MARK: - ViewModel

class ActivityLogViewModel: ObservableObject {
    @Published var exercises: [ActivityEntry] = []
    @Published var showingAddSheet = false
    @Published var selectedFilter: ExerciseCategory? = nil
    @Published var editingExercise: ActivityEntry? = nil

    private let storageKey = "savedExercises"

    init() {
        load()
    }

    var filteredExercises: [ActivityEntry] {
        let sorted = exercises.sorted { $0.date > $1.date }
        if let filter = selectedFilter {
            return sorted.filter { $0.category == filter }
        }
        return sorted
    }

    var totalCaloriesToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return exercises
            .filter { Calendar.current.startOfDay(for: $0.date) == today }
            .reduce(0) { $0 + $1.caloriesBurned }
    }

    var totalWorkoutsToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return exercises.filter { Calendar.current.startOfDay(for: $0.date) == today }.count
    }

    var totalMinutesToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return exercises
            .filter { Calendar.current.startOfDay(for: $0.date) == today }
            .compactMap { $0.duration }
            .reduce(0, +)
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

    func delete(at offsets: IndexSet) {
        let ids = offsets.map { filteredExercises[$0].id }
        exercises.removeAll { ids.contains($0.id) }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(exercises) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ActivityEntry].self, from: data) {
            exercises = decoded
        } else {
            // Sample data
            exercises = [
                ActivityEntry(name: "Bench Press", category: .strength, sets: 4, reps: 8, weight: 80, caloriesBurned: 120, date: Date()),
                ActivityEntry(name: "Morning Run", category: .cardio, sets: 1, reps: 1, duration: 30, caloriesBurned: 310, date: Date()),
                ActivityEntry(name: "Yoga Flow", category: .flexibility, sets: 1, reps: 1, duration: 20, caloriesBurned: 90,
                         date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
            ]
        }
    }
}

// MARK: - Main Activity Log View

struct ActivityLogView: View {
    @StateObject private var vm = ActivityLogViewModel()
    @State private var animateStats = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Today's Stats
                    statsStrip

                    // Category Filter
                    categoryFilter

                    // Exercise List
                    exerciseList

                    Spacer(minLength: 100)
                }
                .padding(.vertical)
            }
            .navigationTitle("Activity Log")
            .overlay(alignment: .bottom) { floatingAddButton }
            .sheet(isPresented: $vm.showingAddSheet) {
                AddExerciseSheet(vm: vm, editingExercise: nil)
            }
            .sheet(item: $vm.editingExercise) { exercise in
                AddExerciseSheet(vm: vm, editingExercise: exercise)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { animateStats = true } }
    }

    // MARK: Stats Strip
    private var statsStrip: some View {
        HStack(spacing: 12) {
            StatCard(value: "\(vm.totalWorkoutsToday)", label: "Workouts", icon: "checkmark.circle.fill",
                     color: Color(red: 0.25, green: 0.72, blue: 0.55), animate: animateStats)
            StatCard(value: "\(vm.totalCaloriesToday)", label: "Calories", icon: "flame.fill",
                     color: Color(red: 0.96, green: 0.35, blue: 0.35), animate: animateStats)
            StatCard(value: "\(vm.totalMinutesToday)m", label: "Minutes", icon: "clock.fill",
                     color: Color(red: 0.40, green: 0.60, blue: 0.95), animate: animateStats)
        }
        .padding(.horizontal)
    }

    // MARK: Category Filter
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(label: "All", icon: "square.grid.2x2.fill",
                           color: .blue, isSelected: vm.selectedFilter == nil) {
                    withAnimation { vm.selectedFilter = nil }
                }
                ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                    FilterChip(label: cat.rawValue, icon: cat.icon,
                               color: cat.color, isSelected: vm.selectedFilter == cat) {
                        withAnimation { vm.selectedFilter = (vm.selectedFilter == cat) ? nil : cat }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }

    // MARK: Exercise List
    private var exerciseList: some View {
        LazyVStack(spacing: 12) {
            if vm.filteredExercises.isEmpty {
                emptyState
            } else {
                ForEach(vm.filteredExercises) { exercise in
                    ExerciseRow(exercise: exercise)
                        .onTapGesture { vm.editingExercise = exercise }
                        .contextMenu {
                            Button(role: .destructive) {
                                if let idx = vm.filteredExercises.firstIndex(where: { $0.id == exercise.id }) {
                                    vm.delete(at: IndexSet(integer: idx))
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)))
                }
            }
        }
        .padding(.horizontal)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 52))
                .foregroundColor(.gray.opacity(0.3))
            Text("No exercises yet")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.gray)
            Text("Tap + to log your first workout")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: Floating Button
    private var floatingAddButton: some View {
        Button {
            vm.showingAddSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                Text("Log Exercise")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(Color.blue)
            .clipShape(Capsule())
            .shadow(color: Color.blue.opacity(0.35), radius: 10, x: 0, y: 4)
        }
        .padding(.bottom, 32)
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
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: animate)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
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
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : Color(.systemGray5))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exercise Row

struct ExerciseRow: View {
    let exercise: ActivityEntry

    private var subtitleText: String {
        if let dur = exercise.duration {
            return "\(dur) min • \(exercise.caloriesBurned) kcal"
        } else {
            let weightStr = exercise.weight.map { " • \(String(format: "%.1f", $0)) kg" } ?? ""
            return "\(exercise.sets) sets × \(exercise.reps) reps\(weightStr)"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Category Icon
            ZStack {
                Circle()
                    .fill(exercise.category.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: exercise.category.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(exercise.category.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text(subtitleText)
                    .font(.caption)
                    .foregroundColor(.gray)
                if !exercise.notes.isEmpty {
                    Text(exercise.notes)
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(exercise.category.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(exercise.category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(exercise.category.color.opacity(0.15))
                    .clipShape(Capsule())
                Text(exercise.date, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Add/Edit Exercise Sheet

struct AddExerciseSheet: View {
    @ObservedObject var vm: ActivityLogViewModel
    let editingExercise: ActivityEntry?
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: ExerciseCategory = .strength
    @State private var sets = 3
    @State private var reps = 10
    @State private var weight = ""
    @State private var duration = ""
    @State private var calories = ""
    @State private var notes = ""
    @State private var isCardioMode = false

    var isEditing: Bool { editingExercise != nil }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Exercise Name
                    formSection(title: "Exercise Name") {
                        StyledTextField(placeholder: "e.g. Bench Press, Running", text: $name)
                    }

                    // Category
                    formSection(title: "Category") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                            ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                                Button {
                                    withAnimation { category = cat }
                                    isCardioMode = (cat == .cardio || cat == .flexibility || cat == .recovery)
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: cat.icon)
                                            .font(.system(size: 20))
                                            .foregroundColor(category == cat ? .white : cat.color)
                                        Text(cat.rawValue)
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundColor(category == cat ? .white : .primary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(category == cat ? cat.color : Color(.systemGray5))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Mode Toggle
                    formSection(title: "Type") {
                        HStack(spacing: 0) {
                            modeButton(title: "Sets & Reps", selected: !isCardioMode) {
                                withAnimation { isCardioMode = false }
                            }
                            modeButton(title: "Duration", selected: isCardioMode) {
                                withAnimation { isCardioMode = true }
                            }
                        }
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                    }

                    // Sets/Reps or Duration
                    if isCardioMode {
                        formSection(title: "Duration (minutes)") {
                            StyledTextField(placeholder: "30", text: $duration, keyboardType: .numberPad)
                        }
                    } else {
                        HStack(spacing: 12) {
                            formSection(title: "Sets") {
                                StepperField(value: $sets, range: 1...20)
                            }
                            formSection(title: "Reps") {
                                StepperField(value: $reps, range: 1...100)
                            }
                        }
                        formSection(title: "Weight (kg) — optional") {
                            StyledTextField(placeholder: "e.g. 60", text: $weight, keyboardType: .decimalPad)
                        }
                    }

                    // Calories
                    formSection(title: "Calories Burned") {
                        StyledTextField(placeholder: "e.g. 250", text: $calories, keyboardType: .numberPad)
                    }

                    // Notes
                    formSection(title: "Notes (optional)") {
                        StyledTextField(placeholder: "How did it feel?", text: $notes)
                    }

                    // Save Button
                    Button(action: saveExercise) {
                        Text(isEditing ? "Update Exercise" : "Log Exercise")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(name.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(name.isEmpty)
                    .padding(.top, 4)

                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .navigationTitle(isEditing ? "Edit Exercise" : "Log Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear(perform: populateIfEditing)
    }

    @ViewBuilder
    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .textCase(.uppercase)
            content()
        }
    }

    private func modeButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(selected ? .primary : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(selected ? Color(.systemGray6) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func saveExercise() {
        let calVal = Int(calories) ?? 0
        let weightVal = Double(weight)
        let durVal = Int(duration)

        if isEditing, var ex = editingExercise {
            ex.name = name
            ex.category = category
            ex.sets = sets
            ex.reps = reps
            ex.weight = weightVal
            ex.duration = durVal
            ex.caloriesBurned = calVal
            ex.notes = notes
            vm.update(ex)
        } else {
            let exercise = ActivityEntry(
                name: name,
                category: category,
                sets: sets,
                reps: reps,
                weight: weightVal,
                duration: durVal,
                caloriesBurned: calVal,
                notes: notes
            )
            vm.add(exercise)
        }
        dismiss()
    }

    private func populateIfEditing() {
        guard let ex = editingExercise else { return }
        name = ex.name
        category = ex.category
        sets = ex.sets
        reps = ex.reps
        weight = ex.weight.map { String($0) } ?? ""
        duration = ex.duration.map { String($0) } ?? ""
        calories = "\(ex.caloriesBurned)"
        notes = ex.notes
        isCardioMode = ex.duration != nil
    }
}

// MARK: - Styled Text Field

struct StyledTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .keyboardType(keyboardType)
            .padding(14)
            .background(Color(.systemGray5))
            .cornerRadius(10)
    }
}

// MARK: - Stepper Field

struct StepperField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Button { if value > range.lowerBound { value -= 1 } } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray4))
                    .clipShape(Circle())
            }
            Spacer()
            Text("\(value)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.primary)
            Spacer()
            Button { if value < range.upperBound { value += 1 } } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray4))
                    .clipShape(Circle())
            }
        }
        .padding(14)
        .background(Color(.systemGray5))
        .cornerRadius(10)
    }
}

// MARK: - Preview

#Preview {
    ActivityLogView()
}
