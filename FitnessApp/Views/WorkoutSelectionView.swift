import SwiftUI
internal import Combine

struct WorkoutSelectionView: View {
    
    @StateObject private var vm = WorkoutSelectionViewModel()
    @State private var showExercisesPressed = false
    
    private let targets = ["abs","biceps","lats","chest","back","legs","shoulders","triceps","forearms","calves","glutes","hamstrings","quadriceps","waist"]
    private let equipmentOptions = ["body weight","barbell","dumbbell","cable","leverage machine","assisted","machine"]
    private let difficultyLevels = ["beginner","intermediate","advanced"]
    
    var body: some View {
        NavigationStack {
            Form {
                
                // Target Picker
                Section(header: Text("Select Target Muscle")) {
                    Picker("Target", selection: $vm.selectedTarget) {
                        ForEach(targets, id: \.self) { t in
                            Text(t.capitalized)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Equipment Picker
                Section(header: Text("Select Equipment")) {
                    Picker("Equipment", selection: $vm.selectedEquipment) {
                        ForEach(equipmentOptions, id: \.self) { eq in
                            Text(eq.capitalized)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Difficulty Picker
                Section(header: Text("Select Difficulty")) {
                    Picker("Difficulty", selection: $vm.selectedDifficulty) {
                        ForEach(difficultyLevels, id: \.self) { level in
                            Text(level.capitalized)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Fetch Button
                Section {
                    Button {
                        withAnimation(.easeInOut(duration: 0.12)) { showExercisesPressed = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.easeInOut(duration: 0.2)) { showExercisesPressed = false }
                        }
                        vm.fetchExercises()
                    } label: {
                        Text("Show Exercises")
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(showExercisesPressed ? Color.blue.opacity(0.65) : Color.blue)
                    .animation(.easeInOut(duration: 0.15), value: showExercisesPressed)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .scaleEffect(showExercisesPressed ? 0.96 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: showExercisesPressed)
                }
                
                // Exercises List
                if !vm.exercises.isEmpty {
                    Section(header: Text("Exercises")) {
                        ForEach(vm.exercises) { ex in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ex.name).bold()
                                Text("\(ex.equipment.capitalized) | \(ex.difficulty.capitalized)")
                                    .font(.caption)
                                Text("Target: \(ex.target.capitalized)")
                                    .font(.caption2)
                                Text("Body Part: \(ex.bodyPart.capitalized)")
                                    .font(.caption2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    Section {
                        Text("No exercises found for selected options.")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Workout Selector")
            .onAppear {
                vm.fetchExercises()
            }
        }
    }
}

// MARK: - ViewModel for WorkoutSelectionView
class WorkoutSelectionViewModel: ObservableObject {
    
    @Published var selectedTarget = "abs" { didSet { fetchExercises() } }
    @Published var selectedEquipment = "body weight" { didSet { filterExercises() } }
    @Published var selectedDifficulty = "beginner" { didSet { filterExercises() } }
    
    @Published var exercises: [Exercise] = []
    
    private var allExercises: [Exercise] = []
    private let service = ExerciseService()
    
    func fetchExercises() {
        service.fetchExercises(for: selectedTarget) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fetched):
                    self?.allExercises = fetched
                    self?.filterExercises()
                case .failure(let error):
                    print("❌ Error fetching exercises:", error)
                    self?.allExercises = []
                    self?.exercises = []
                }
            }
        }
    }
    
    private func filterExercises() {
        exercises = allExercises.filter { ex in
            ex.equipment.lowercased().trimmingCharacters(in: .whitespaces) == selectedEquipment.lowercased().trimmingCharacters(in: .whitespaces) &&
            ex.difficulty.lowercased().trimmingCharacters(in: .whitespaces) == selectedDifficulty.lowercased().trimmingCharacters(in: .whitespaces)
        }
    }
}

#Preview {
    WorkoutSelectionView()
}
