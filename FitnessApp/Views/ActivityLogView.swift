import SwiftUI
internal import Combine

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
    case strength    = "Strength"
    case cardio      = "Cardio"
    case sports      = "Sports"
    case flexibility = "Flexibility"

    var icon: String {
        switch self {
        case .strength:    return "dumbbell.fill"
        case .cardio:      return "figure.run"
        case .sports:      return "sportscourt.fill"
        case .flexibility: return "figure.flexibility"
        }
    }

    var color: Color {
        switch self {
        case .strength:    return Color(red: 0.96, green: 0.35, blue: 0.35)
        case .cardio:      return Color(red: 0.25, green: 0.72, blue: 0.55)
        case .sports:      return Color(red: 0.65, green: 0.35, blue: 0.95)
        case .flexibility: return Color(red: 0.40, green: 0.60, blue: 0.95)
        }
    }
}

// MARK: - Cardio Activity Type

enum CardioActivityType: String, CaseIterable {
    case walk   = "Walk"
    case run    = "Run"
    case sprint = "Sprint"

    var icon: String {
        switch self {
        case .walk:   return "figure.walk"
        case .run:    return "figure.run"
        case .sprint: return "hare.fill"
        }
    }

    var met: Double {
        switch self {
        case .walk:   return 3.5
        case .run:    return 9.8
        case .sprint: return 19.0
        }
    }

    var typicalSpeedMph: Double {
        switch self {
        case .walk:   return 3.5
        case .run:    return 6.0
        case .sprint: return 10.0
        }
    }
}

// MARK: - Sports Activity Type

enum SportsActivityType: String, CaseIterable {
    case football   = "Football"
    case soccer     = "Soccer"
    case baseball   = "Baseball"
    case basketball = "Basketball"

    var icon: String {
        switch self {
        case .football:   return "american.football.fill"
        case .soccer:     return "soccerball"
        case .baseball:   return "baseball.fill"
        case .basketball: return "basketball.fill"
        }
    }

    // MET values for recreational/competitive play
    var met: Double {
        switch self {
        case .football:   return 8.0   // competitive football
        case .soccer:     return 7.0   // recreational soccer
        case .baseball:   return 5.0   // baseball/softball
        case .basketball: return 6.5   // recreational basketball
        }
    }
}

// MARK: - Flexibility Activity Type

enum FlexibilityActivityType: String, CaseIterable {
    case yoga    = "Yoga"
    case pilates = "Pilates"

    var icon: String {
        switch self {
        case .yoga:    return "figure.yoga"
        case .pilates: return "figure.pilates"
        }
    }

    // MET values
    var met: Double {
        switch self {
        case .yoga:    return 2.5
        case .pilates: return 3.0
        }
    }
}

// MARK: - Cardio Calorie Calculator

struct CardioCalorieCalculator: View {
    @Binding var calories: String
    @Binding var duration: String
    @Environment(AppState.self) var appState

    @State private var activityType: CardioActivityType = .run
    @State private var distanceText: String = ""
    @State private var estimatedCalories: Int? = nil
    @State private var estimatedMinutes: Int? = nil

    private var user: User? { appState.currentUser }

    var body: some View {
        VStack(spacing: 14) {
            userWeightBadge

            // Activity selector
            HStack(spacing: 8) {
                ForEach(CardioActivityType.allCases, id: \.self) { type in
                    Button {
                        withAnimation { activityType = type }
                        recalculate()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.system(size: 18, weight: .semibold))
                            Text(type.rawValue)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(activityType == type ? .white : ExerciseCategory.cardio.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(activityType == type
                                      ? ExerciseCategory.cardio.color
                                      : ExerciseCategory.cardio.color.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Distance input
            VStack(alignment: .leading, spacing: 4) {
                Text("Distance (miles)")
                    .font(.caption).foregroundColor(.gray).textCase(.uppercase)
                TextField("e.g. 3.1", text: $distanceText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .keyboardType(.decimalPad)
                    .padding(12)
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                    .onChange(of: distanceText) { _ in recalculate() }
            }

            resultAndFillRow
        }
        .padding()
        .background(ExerciseCategory.cardio.color.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ExerciseCategory.cardio.color.opacity(0.2), lineWidth: 1))
        .cornerRadius(14)
    }

    private var userWeightBadge: some View {
        Group {
            if let user = user {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill").font(.caption).foregroundColor(.gray)
                    Text("Using your saved weight: \(Int(user.weightLbs)) lbs")
                        .font(.caption).foregroundColor(.gray)
                    Spacer()
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle").font(.caption).foregroundColor(.orange)
                    Text("No profile weight found — update your profile.")
                        .font(.caption).foregroundColor(.orange)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var resultAndFillRow: some View {
        if let cal = estimatedCalories, let mins = estimatedMinutes {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    resultBadge(value: "\(cal)", label: "Calories", icon: "flame.fill", color: .orange)
                    resultBadge(value: "\(mins) min", label: "Est. Duration", icon: "clock.fill", color: .blue)
                }
                autofillButton(calories: cal, minutes: mins, color: ExerciseCategory.cardio.color)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    private func recalculate() {
        guard let user = user, let distance = Double(distanceText), distance > 0 else {
            estimatedCalories = nil; estimatedMinutes = nil; return
        }
        withAnimation(.easeOut(duration: 0.2)) {
            estimatedCalories = user.caloriesBurnedByDistance(
                met: activityType.met, speedMph: activityType.typicalSpeedMph, distanceMiles: distance)
            estimatedMinutes = user.estimatedDurationMinutes(
                distanceMiles: distance, speedMph: activityType.typicalSpeedMph)
        }
    }

    private func autofillButton(calories: Int, minutes: Int, color: Color) -> some View {
        Button {
            self.calories = "\(calories)"
            self.duration = "\(minutes)"
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                Text("Auto-fill Calories & Duration")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color)
            .cornerRadius(10)
        }
    }

    private func resultBadge(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(color).font(.system(size: 14))
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 17, weight: .black, design: .rounded)).foregroundColor(.primary)
                Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.systemGray5))
        .cornerRadius(10)
    }
}

// MARK: - Strength Calorie Calculator

struct StrengthCalorieCalculator: View {
    @Binding var calories: String
    @Binding var setsBinding: Int
    @Binding var repsBinding: Int
    @Binding var weightBinding: String
    @Environment(AppState.self) var appState

    @State private var setsText: String = ""
    @State private var repsText: String = ""
    @State private var liftWeightText: String = ""
    @State private var estimatedCalories: Int? = nil

    private var user: User? { appState.currentUser }

    // Formula: Calories = sets × reps × liftWeight(lbs) × 0.0003604
    private func calculate() {
        guard
            let user = user,
            let sets = Double(setsText), sets > 0,
            let reps = Double(repsText), reps > 0,
            let liftWeight = Double(liftWeightText), liftWeight > 0
        else {
            estimatedCalories = nil; return
        }
        let volume = sets * reps * liftWeight
        let bodyWeightFactor = user.weightLbs * 0.001
        let raw = (volume * 0.0003604) + bodyWeightFactor
        withAnimation(.easeOut(duration: 0.2)) {
            estimatedCalories = max(1, Int(raw.rounded()))
        }
        // Sync values back to the parent form fields
        if let s = Int(setsText)    { setsBinding = s }
        if let r = Int(repsText)    { repsBinding = r }
        weightBinding = liftWeightText
    }

    var body: some View {
        VStack(spacing: 14) {
            // Weight badge
            if let user = user {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill").font(.caption).foregroundColor(.gray)
                    Text("Body weight factored in: \(Int(user.weightLbs)) lbs")
                        .font(.caption).foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal, 4)
            }

            // Sets / Reps / Lift Weight row
            HStack(spacing: 10) {
                calcField(label: "Sets", placeholder: "e.g. 4", text: $setsText)
                calcField(label: "Reps", placeholder: "e.g. 10", text: $repsText)
                calcField(label: "Weight (lbs)", placeholder: "e.g. 135", text: $liftWeightText)
            }

            Button {
                calculate()
            } label: {
                Text("Calculate Calories")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ExerciseCategory.strength.color)
                    .cornerRadius(10)
            }

            if let cal = estimatedCalories {
                VStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill").foregroundColor(.orange).font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(cal) kcal")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundColor(.primary)
                            Text("Estimated Calories Burned")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray).textCase(.uppercase)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(.systemGray5))
                    .cornerRadius(10)

                    Button {
                        calories = "\(cal)"
                        if let s = Int(setsText)    { setsBinding = s }
                        if let r = Int(repsText)    { repsBinding = r }
                        weightBinding = liftWeightText
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Auto-fill Calories")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(ExerciseCategory.strength.color)
                        .cornerRadius(10)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding()
        .background(ExerciseCategory.strength.color.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ExerciseCategory.strength.color.opacity(0.2), lineWidth: 1))
        .cornerRadius(14)
    }

    private func calcField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.gray).textCase(.uppercase)
            TextField(placeholder, text: text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .keyboardType(.decimalPad)
                .padding(10)
                .background(Color(.systemGray5))
                .cornerRadius(10)
                .onChange(of: text.wrappedValue) { _ in calculate() }
        }
    }
}

// MARK: - Sports Calorie Calculator

struct SportsCalorieCalculator: View {
    @Binding var calories: String
    @Binding var duration: String
    @Environment(AppState.self) var appState

    @State private var activityType: SportsActivityType = .basketball
    @State private var durationText: String = ""
    @State private var estimatedCalories: Int? = nil

    private var user: User? { appState.currentUser }

    var body: some View {
        VStack(spacing: 14) {
            // Weight badge
            if let user = user {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill").font(.caption).foregroundColor(.gray)
                    Text("Using your saved weight: \(Int(user.weightLbs)) lbs")
                        .font(.caption).foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal, 4)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle").font(.caption).foregroundColor(.orange)
                    Text("No profile weight found — update your profile.")
                        .font(.caption).foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal, 4)
            }

            // Sport selector — 2×2 grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(SportsActivityType.allCases, id: \.self) { type in
                    Button {
                        withAnimation { activityType = type }
                        recalculate()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: type.icon)
                                .font(.system(size: 16, weight: .semibold))
                            Text(type.rawValue)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(activityType == type ? .white : ExerciseCategory.sports.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(activityType == type
                                      ? ExerciseCategory.sports.color
                                      : ExerciseCategory.sports.color.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Duration input
            VStack(alignment: .leading, spacing: 4) {
                Text("Duration (minutes)")
                    .font(.caption).foregroundColor(.gray).textCase(.uppercase)
                TextField("e.g. 60", text: $durationText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .keyboardType(.numberPad)
                    .padding(12)
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                    .onChange(of: durationText) { _ in recalculate() }
            }

            if let cal = estimatedCalories, let mins = Int(durationText), mins > 0 {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        resultBadge(value: "\(cal)", label: "Calories", icon: "flame.fill", color: .orange)
                        resultBadge(value: "\(mins) min", label: "Duration", icon: "clock.fill", color: .purple)
                    }
                    Button {
                        calories = "\(cal)"
                        duration = "\(mins)"
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Auto-fill Calories & Duration")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(ExerciseCategory.sports.color)
                        .cornerRadius(10)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding()
        .background(ExerciseCategory.sports.color.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ExerciseCategory.sports.color.opacity(0.2), lineWidth: 1))
        .cornerRadius(14)
    }

    private func recalculate() {
        guard
            let user = user,
            let mins = Double(durationText), mins > 0
        else { estimatedCalories = nil; return }
        withAnimation(.easeOut(duration: 0.2)) {
            estimatedCalories = user.caloriesBurned(met: activityType.met, durationMinutes: Int(mins))
        }
    }

    private func resultBadge(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(color).font(.system(size: 14))
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 17, weight: .black, design: .rounded)).foregroundColor(.primary)
                Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.systemGray5))
        .cornerRadius(10)
    }
}

// MARK: - Flexibility Calorie Calculator

struct FlexibilityCalorieCalculator: View {
    @Binding var calories: String
    @Binding var duration: String
    @Environment(AppState.self) var appState

    @State private var activityType: FlexibilityActivityType = .yoga
    @State private var durationText: String = ""
    @State private var estimatedCalories: Int? = nil

    private var user: User? { appState.currentUser }

    var body: some View {
        VStack(spacing: 14) {
            // Weight badge
            if let user = user {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill").font(.caption).foregroundColor(.gray)
                    Text("Using your saved weight: \(Int(user.weightLbs)) lbs")
                        .font(.caption).foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal, 4)
            }

            // Yoga / Pilates toggle
            HStack(spacing: 8) {
                ForEach(FlexibilityActivityType.allCases, id: \.self) { type in
                    Button {
                        withAnimation { activityType = type }
                        recalculate()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.system(size: 16, weight: .semibold))
                            Text(type.rawValue)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(activityType == type ? .white : ExerciseCategory.flexibility.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(activityType == type
                                      ? ExerciseCategory.flexibility.color
                                      : ExerciseCategory.flexibility.color.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Duration input
            VStack(alignment: .leading, spacing: 4) {
                Text("Duration (minutes)")
                    .font(.caption).foregroundColor(.gray).textCase(.uppercase)
                TextField("e.g. 45", text: $durationText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .keyboardType(.numberPad)
                    .padding(12)
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                    .onChange(of: durationText) { _ in recalculate() }
            }

            if let cal = estimatedCalories, let mins = Int(durationText), mins > 0 {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        resultBadge(value: "\(cal)", label: "Calories", icon: "flame.fill", color: .orange)
                        resultBadge(value: "\(mins) min", label: "Duration", icon: "clock.fill", color: ExerciseCategory.flexibility.color)
                    }
                    Button {
                        calories = "\(cal)"
                        duration = "\(mins)"
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Auto-fill Calories & Duration")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(ExerciseCategory.flexibility.color)
                        .cornerRadius(10)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding()
        .background(ExerciseCategory.flexibility.color.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ExerciseCategory.flexibility.color.opacity(0.2), lineWidth: 1))
        .cornerRadius(14)
    }

    private func recalculate() {
        guard let user = user, let mins = Double(durationText), mins > 0 else {
            estimatedCalories = nil; return
        }
        withAnimation(.easeOut(duration: 0.2)) {
            estimatedCalories = user.caloriesBurned(met: activityType.met, durationMinutes: Int(mins))
        }
    }

    private func resultBadge(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(color).font(.system(size: 14))
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 17, weight: .black, design: .rounded)).foregroundColor(.primary)
                Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(.gray).textCase(.uppercase)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.systemGray5))
        .cornerRadius(10)
    }
}

// MARK: - Activity Log ViewModel

class ActivityLogViewModel: ObservableObject {
    @Published var exercises: [ActivityEntry] = []
    @Published var showingAddSheet = false
    @Published var selectedFilter: ExerciseCategory? = nil
    @Published var editingExercise: ActivityEntry? = nil
    @Published var preselectedCategory: ExerciseCategory = .strength

    private let userId: String
    private var storageKey: String { "savedExercises_\(userId)" }

    init(userId: String) {
        self.userId = userId
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
            .filter { Calendar.current.startOfDay(for: $0.date) == today && $0.isCompleted }
            .reduce(0) { $0 + $1.caloriesBurned }
    }

    var totalWorkoutsToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return exercises.filter { Calendar.current.startOfDay(for: $0.date) == today && $0.isCompleted }.count
    }

    var totalMinutesToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return exercises
            .filter { Calendar.current.startOfDay(for: $0.date) == today && $0.isCompleted }
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

    func deleteEntry(_ entry: ActivityEntry) {
        exercises.removeAll { $0.id == entry.id }
        save()
    }

    func toggleComplete(_ entry: ActivityEntry) {
        if let idx = exercises.firstIndex(where: { $0.id == entry.id }) {
            exercises[idx].isCompleted.toggle()
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
            exercises = decoded.filter { ExerciseCategory.allCases.contains($0.category) }
        }
    }
}

// MARK: - Main View

struct ActivityLogView: View {
    @Environment(AppState.self) var appState
    @StateObject private var vm: ActivityLogViewModel
    @State private var animateStats = false

    init(userId: String) {
        _vm = StateObject(wrappedValue: ActivityLogViewModel(userId: userId))
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    statsStrip
                    categorySection
                    exerciseList
                    Spacer(minLength: 100)
                }
                .padding(.vertical)
            }
            .navigationTitle("Activity Log")
            .overlay(alignment: .bottom) { floatingAddButton }
            .sheet(isPresented: $vm.showingAddSheet) {
                AddExerciseSheet(vm: vm, editingExercise: nil, initialCategory: vm.preselectedCategory)
            }
            .sheet(item: $vm.editingExercise) { exercise in
                AddExerciseSheet(vm: vm, editingExercise: exercise, initialCategory: exercise.category)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { animateStats = true } }
    }

    private var statsStrip: some View {
        HStack(spacing: 12) {
            StatCard(value: "\(vm.totalWorkoutsToday)", label: "Workouts", icon: "checkmark.circle.fill",
                     color: Color(red: 0.25, green: 0.72, blue: 0.55), animate: animateStats)
            StatCard(value: "\(vm.totalCaloriesToday)", label: "Calories", icon: "flame.fill",
                     color: Color(red: 0.96, green: 0.35, blue: 0.35), animate: animateStats)
            StatCard(value: "\(vm.totalMinutesToday)m", label: "Cardio", icon: "clock.fill",
                     color: Color(red: 0.40, green: 0.60, blue: 0.95), animate: animateStats)
        }
        .padding(.horizontal)
    }

    private var categorySection: some View {
        VStack(spacing: 12) {
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

            if let cat = vm.selectedFilter {
                Button {
                    vm.preselectedCategory = cat
                    vm.showingAddSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 15, weight: .bold))
                        Text("Log \(cat.rawValue) Exercise")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(cat.color)
                    .clipShape(Capsule())
                    .shadow(color: cat.color.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var exerciseList: some View {
        LazyVStack(spacing: 12) {
            if vm.filteredExercises.isEmpty {
                emptyState
            } else {
                ForEach(vm.filteredExercises) { exercise in
                    ExerciseRow(exercise: exercise,
                                onDelete: { withAnimation { vm.deleteEntry(exercise) } },
                                onToggleComplete: { withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { vm.toggleComplete(exercise) } })
                    .onTapGesture { vm.editingExercise = exercise }
                    .contextMenu {
                        Button { vm.editingExercise = exercise } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            withAnimation { vm.deleteEntry(exercise) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
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

    private var floatingAddButton: some View {
        Group {
            if vm.selectedFilter == nil {
                Button {
                    vm.preselectedCategory = .strength
                    vm.showingAddSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 16, weight: .bold))
                        Text("Log Exercise").font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .clipShape(Capsule())
                    .shadow(color: Color.blue.opacity(0.35), radius: 10, x: 0, y: 4)
                }
                .padding(.bottom, 32)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
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
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: animate)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
                .textCase(.uppercase)
                .tracking(0.5)
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
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(label).font(.system(size: 13, weight: .semibold, design: .rounded))
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
        if let dur = exercise.duration {
            return "\(dur) min • \(exercise.caloriesBurned) kcal"
        } else {
            let weightStr = exercise.weight.map { " • \(String(format: "%.1f", $0)) lbs" } ?? ""
            return "\(exercise.sets) sets × \(exercise.reps) reps\(weightStr)"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Category icon — dims when completed
            ZStack {
                Circle()
                    .fill(exercise.isCompleted
                          ? exercise.category.color.opacity(0.9)
                          : exercise.category.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: exercise.isCompleted ? "checkmark" : exercise.category.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(exercise.isCompleted ? .white : exercise.category.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .strikethrough(exercise.isCompleted, color: .gray)
                    .foregroundColor(exercise.isCompleted ? .gray : .primary)
                Text(subtitleText).font(.caption).foregroundColor(.gray)
                if !exercise.notes.isEmpty {
                    Text(exercise.notes).font(.caption2).foregroundColor(.gray.opacity(0.7)).lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(exercise.category.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(exercise.category.color)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(exercise.category.color.opacity(0.15))
                    .clipShape(Capsule())

                // Done toggle button
                Button { onToggleComplete() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: exercise.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 15, weight: .semibold))
                        Text(exercise.isCompleted ? "Done" : "Mark Done")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(exercise.isCompleted ? .white : exercise.category.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(exercise.isCompleted
                                       ? exercise.category.color
                                       : exercise.category.color.opacity(0.12))
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
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(exercise.isCompleted ? exercise.category.color.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Add/Edit Exercise Sheet

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

    @State private var showCalorieCalculator = false
    @StateObject private var workoutVM = WorkoutSelectionViewModel()
    @State private var showWorkoutSelector = false

    var isEditing: Bool { editingExercise != nil }
    var nameEntered: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    nameSection
                    lockedContent
                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .navigationTitle(isEditing ? "Edit Exercise" : "Log \(category.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                if isEditing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            if let ex = editingExercise { vm.deleteEntry(ex) }
                            dismiss()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .onAppear(perform: populateIfEditing)
    }

    // MARK: Name Section — always visible, includes quick exercise search
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Exercise Name")
                    .font(.caption).foregroundColor(.gray).textCase(.uppercase)
                Spacer()
                if !nameEntered {
                    Text("Required to continue")
                        .font(.caption).foregroundColor(.orange).fontWeight(.semibold)
                }
            }
            TextField("e.g. Bench Press, Morning Run...", text: $name)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .padding(14)
                .background(Color(.systemGray5))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(nameEntered ? Color.clear : Color.orange.opacity(0.5), lineWidth: 1.5)
                )

            // Quick search — only available for Strength
            if category == .strength {
                Button {
                    withAnimation { showWorkoutSelector.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                        Text(showWorkoutSelector ? "Hide Exercise Search" : "Search Exercises to Fill Name")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Spacer()
                        Image(systemName: showWorkoutSelector ? "chevron.up" : "chevron.down")
                            .font(.caption).foregroundColor(.gray)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                if showWorkoutSelector {
                    WorkoutSelectorInline(vm: workoutVM) { selectedName in
                        name = selectedName
                        withAnimation { showWorkoutSelector = false }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: All other content — dimmed until name is entered
    private var lockedContent: some View {
        VStack(spacing: 20) {
            // Dim overlay hint
            if !nameEntered {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    Text("Enter an exercise name above to fill out the rest")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(10)
            }

            categorySection
            strengthFinderSection
            cardioCalculatorSection
            sportsCalculatorSection
            flexibilityCalculatorSection
            metricsSection
            extrasSection
            saveButton
        }
        .opacity(nameEntered ? 1.0 : 0.35)
        .disabled(!nameEntered)
    }

    private var categorySection: some View {
        formSection(title: "Category") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(ExerciseCategory.allCases, id: \.self) { cat in
                    Button {
                        guard cat != category else { return }
                        withAnimation { category = cat }
                        // Clear all fields when switching category
                        name = ""
                        sets = 3
                        reps = 10
                        weight = ""
                        duration = ""
                        calories = ""
                        notes = ""
                        showWorkoutSelector = false
                        showCalorieCalculator = false
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 18))
                                .foregroundColor(category == cat ? .white : cat.color)
                            Text(cat.rawValue)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(category == cat ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(category == cat ? cat.color : Color(.systemGray5))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var strengthFinderSection: some View {
        if category == .strength {
                formSection(title: "Calorie Calculator") {
                    Button {
                        withAnimation { showCalorieCalculator.toggle() }
                    } label: {
                        HStack {
                            Image(systemName: "flame.fill").foregroundColor(ExerciseCategory.strength.color)
                            Text(showCalorieCalculator ? "Hide Calculator" : "Calculate Calories by Volume")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(ExerciseCategory.strength.color)
                            Spacer()
                            Image(systemName: showCalorieCalculator ? "chevron.up" : "chevron.down")
                                .font(.caption).foregroundColor(.gray)
                        }
                        .padding()
                        .background(ExerciseCategory.strength.color.opacity(0.08))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    if showCalorieCalculator {
                        StrengthCalorieCalculator(
                            calories: $calories,
                            setsBinding: $sets,
                            repsBinding: $reps,
                            weightBinding: $weight
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
        }
    }

    @ViewBuilder
    private var cardioCalculatorSection: some View {
        if category == .cardio {
            formSection(title: "Calorie Calculator") {
                Button {
                    withAnimation { showCalorieCalculator.toggle() }
                } label: {
                    HStack {
                        Image(systemName: "flame.fill").foregroundColor(ExerciseCategory.cardio.color)
                        Text(showCalorieCalculator ? "Hide Calculator" : "Calculate Calories by Distance")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(ExerciseCategory.cardio.color)
                        Spacer()
                        Image(systemName: showCalorieCalculator ? "chevron.up" : "chevron.down")
                            .font(.caption).foregroundColor(.gray)
                    }
                    .padding()
                    .background(ExerciseCategory.cardio.color.opacity(0.08))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                if showCalorieCalculator {
                    CardioCalorieCalculator(calories: $calories, duration: $duration)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    @ViewBuilder
    private var sportsCalculatorSection: some View {
        if category == .sports {
            formSection(title: "Calorie Calculator") {
                Button {
                    withAnimation { showCalorieCalculator.toggle() }
                } label: {
                    HStack {
                        Image(systemName: "flame.fill").foregroundColor(ExerciseCategory.sports.color)
                        Text(showCalorieCalculator ? "Hide Calculator" : "Calculate Calories by Sport & Duration")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(ExerciseCategory.sports.color)
                        Spacer()
                        Image(systemName: showCalorieCalculator ? "chevron.up" : "chevron.down")
                            .font(.caption).foregroundColor(.gray)
                    }
                    .padding()
                    .background(ExerciseCategory.sports.color.opacity(0.08))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                if showCalorieCalculator {
                    SportsCalorieCalculator(calories: $calories, duration: $duration)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    @ViewBuilder
    private var flexibilityCalculatorSection: some View {
        if category == .flexibility {
            formSection(title: "Calorie Calculator") {
                Button {
                    withAnimation { showCalorieCalculator.toggle() }
                } label: {
                    HStack {
                        Image(systemName: "flame.fill").foregroundColor(ExerciseCategory.flexibility.color)
                        Text(showCalorieCalculator ? "Hide Calculator" : "Calculate Calories — Yoga or Pilates")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(ExerciseCategory.flexibility.color)
                        Spacer()
                        Image(systemName: showCalorieCalculator ? "chevron.up" : "chevron.down")
                            .font(.caption).foregroundColor(.gray)
                    }
                    .padding()
                    .background(ExerciseCategory.flexibility.color.opacity(0.08))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                if showCalorieCalculator {
                    FlexibilityCalorieCalculator(calories: $calories, duration: $duration)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    @ViewBuilder
    private var metricsSection: some View {
        switch category {
        case .strength:
            // Strength: sets, reps, weight only — no duration
            HStack(spacing: 12) {
                formSection(title: "Sets") { StepperField(value: $sets, range: 1...20) }
                formSection(title: "Reps") { StepperField(value: $reps, range: 1...100) }
            }
            formSection(title: "Weight (lbs) — optional") {
                StyledTextField(placeholder: "e.g. 135", text: $weight, keyboardType: .decimalPad)
            }
        case .cardio, .sports, .flexibility:
            // Duration-only categories — no sets/reps
            formSection(title: "Duration (minutes)") {
                StyledTextField(placeholder: "e.g. 30", text: $duration, keyboardType: .numberPad)
            }
        }
    }

    private var extrasSection: some View {
        VStack(spacing: 20) {
            formSection(title: "Calories Burned") {
                StyledTextField(placeholder: "e.g. 250", text: $calories, keyboardType: .numberPad)
            }
            formSection(title: "Notes (optional)") {
                StyledTextField(placeholder: "How did it feel?", text: $notes)
            }
        }
    }

    private var saveButton: some View {
        Button(action: saveExercise) {
            Text(isEditing ? "Update Exercise" : "Log Exercise")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(name.isEmpty ? Color.gray.opacity(0.3) : category.color)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(name.isEmpty)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundColor(.gray).textCase(.uppercase)
            content()
        }
    }

    private func saveExercise() {
        let calVal = Int(calories) ?? 0
        let weightVal = Double(weight)
        let durVal = Int(duration)

        if isEditing, var ex = editingExercise {
            ex.name = name; ex.category = category; ex.sets = sets; ex.reps = reps
            ex.weight = weightVal; ex.duration = durVal; ex.caloriesBurned = calVal; ex.notes = notes
            vm.update(ex)
        } else {
            vm.add(ActivityEntry(name: name, category: category, sets: sets, reps: reps,
                                 weight: weightVal, duration: durVal, caloriesBurned: calVal, notes: notes))
        }
        dismiss()
    }

    private func populateIfEditing() {
        if let ex = editingExercise {
            name = ex.name; category = ex.category; sets = ex.sets; reps = ex.reps
            weight = ex.weight.map { String($0) } ?? ""
            duration = ex.duration.map { String($0) } ?? ""
            calories = "\(ex.caloriesBurned)"; notes = ex.notes
        } else {
            category = initialCategory
        }
    }
}

// MARK: - Workout Selector Inline

struct WorkoutSelectorInline: View {
    @ObservedObject var vm: WorkoutSelectionViewModel
    var onSelect: (String) -> Void

    private let bodyPartOptions = ["waist","upper arms","upper legs","lower legs","lower arms","back","chest","shoulders","neck"]

    var body: some View {
        VStack(spacing: 14) {
            selectorRow(label: "Body Part") {
                Menu {
                    ForEach(bodyPartOptions, id: \.self) { option in
                        Button(option.capitalized) { vm.selectedBodyPart = option }
                    }
                } label: { menuLabel(vm.selectedBodyPart.capitalized) }
            }
            selectorRow(label: "Equipment") {
                Menu {
                    ForEach(vm.availableEquipment, id: \.self) { option in
                        Button(option.capitalized) { vm.selectedEquipment = option }
                    }
                } label: { menuLabel(vm.selectedEquipment.capitalized) }
            }
            selectorRow(label: "Target Muscle") {
                Menu {
                    ForEach(vm.availableTargets, id: \.self) { option in
                        Button(option.capitalized) { vm.selectedTarget = option }
                    }
                } label: { menuLabel(vm.selectedTarget.capitalized) }
            }
            Button { vm.showExercises() } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Show Exercises").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Color.blue).foregroundColor(.white).cornerRadius(10)
            }
            if vm.showResults {
                if vm.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Loading…").font(.subheadline).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity).padding()
                } else if vm.exercises.isEmpty {
                    Text("No exercises found. Try adjusting your filters.")
                        .font(.caption).foregroundColor(.gray).frame(maxWidth: .infinity).padding()
                } else {
                    VStack(spacing: 8) {
                        ForEach(vm.exercises) { ex in
                            Button { onSelect(ex.name.capitalized) } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(ex.name.capitalized)
                                            .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                                        HStack(spacing: 6) {
                                            Label(ex.equipment.capitalized, systemImage: "wrench.and.screwdriver.fill")
                                                .font(.caption2).foregroundColor(.blue)
                                            Label(ex.target.capitalized, systemImage: "target")
                                                .font(.caption2).foregroundColor(.orange)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill").foregroundColor(.blue).font(.system(size: 20))
                                }
                                .padding(12).background(Color(.systemGray5)).cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding().background(Color(.systemGray6)).cornerRadius(14)
    }

    @ViewBuilder
    private func selectorRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.gray).textCase(.uppercase)
            content()
        }
    }

    private func menuLabel(_ text: String) -> some View {
        HStack {
            Text(text).foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.up.chevron.down").foregroundColor(.gray).font(.caption)
        }
        .padding(12).background(Color(.systemGray5)).cornerRadius(10)
    }
}

// MARK: - Workout Selection ViewModel

class WorkoutSelectionViewModel: ObservableObject {
    @Published var selectedBodyPart = "waist" {
        didSet { selectedTarget = "any"; selectedEquipment = "any"; showResults = false; fetchExercises() }
    }
    @Published var selectedEquipment = "any" { didSet { showResults = false } }
    @Published var selectedTarget = "any"    { didSet { showResults = false } }
    @Published var exercises: [Exercise] = []
    @Published var isLoading = false
    @Published var showResults = false

    private var allExercises: [Exercise] = []
    private let service: ExerciseService
    private var lastFetchedBodyPart: String = ""

    var availableEquipment: [String] {
        ["any"] + Set(allExercises.map { $0.equipment.lowercased().trimmingCharacters(in: .whitespaces) }).sorted()
    }

    var availableTargets: [String] {
        let filtered = selectedEquipment == "any" ? allExercises : allExercises.filter {
            $0.equipment.lowercased().trimmingCharacters(in: .whitespaces) == selectedEquipment
        }
        return ["any"] + Set(filtered.map { $0.target.lowercased().trimmingCharacters(in: .whitespaces) }).sorted()
    }

    init(service: ExerciseService = ExerciseService()) { self.service = service }

    func showExercises() { filterExercises(); showResults = true }

    func fetchExercises() {
        let bodyPart = selectedBodyPart
        guard bodyPart != lastFetchedBodyPart || allExercises.isEmpty else { return }
        isLoading = true; exercises = []; allExercises = []
        service.fetchExercisesByBodyPart(for: bodyPart) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let fetched): self.lastFetchedBodyPart = bodyPart; self.allExercises = fetched
                case .failure(let error): print("❌ Error:", error); self.allExercises = []; self.exercises = []
                }
            }
        }
    }

    private func filterExercises() {
        let equipment = selectedEquipment.lowercased().trimmingCharacters(in: .whitespaces)
        let target = selectedTarget.lowercased().trimmingCharacters(in: .whitespaces)
        exercises = allExercises.filter { ex in
            (equipment == "any" || ex.equipment.lowercased().trimmingCharacters(in: .whitespaces) == equipment) &&
            (target == "any" || ex.target.lowercased().trimmingCharacters(in: .whitespaces) == target)
        }
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
                Image(systemName: "minus").font(.system(size: 14, weight: .bold)).foregroundColor(.gray)
                    .frame(width: 32, height: 32).background(Color(.systemGray4)).clipShape(Circle())
            }
            Spacer()
            Text("\(value)").font(.system(size: 20, weight: .black, design: .rounded)).foregroundColor(.primary)
            Spacer()
            Button { if value < range.upperBound { value += 1 } } label: {
                Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundColor(.gray)
                    .frame(width: 32, height: 32).background(Color(.systemGray4)).clipShape(Circle())
            }
        }
        .padding(14).background(Color(.systemGray5)).cornerRadius(10)
    }
}

// MARK: - Preview

#Preview {
    ActivityLogView(userId: "preview")
        .environment(AppState())
}
