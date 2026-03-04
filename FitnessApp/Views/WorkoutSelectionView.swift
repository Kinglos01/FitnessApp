import SwiftUI
internal import Combine

struct WorkoutSelectionView: View {
    
    @StateObject private var vm = WorkoutSelectionViewModel()
    
    private let bodyPartOptions = ["waist","upper arms","upper legs","lower legs","lower arms","back","chest","shoulders","neck"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Workout Selector")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Find the right exercise for you")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Filters Card
                    VStack(spacing: 16) {
                        
                        Label("Filter Exercises", systemImage: "line.3.horizontal.decrease.circle.fill")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Body Part
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Body Part")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .textCase(.uppercase)
                            Menu {
                                ForEach(bodyPartOptions, id: \.self) { option in
                                    Button(option.capitalized) {
                                        vm.selectedBodyPart = option
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(vm.selectedBodyPart.capitalized)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                                .padding()
                                .background(Color(.systemGray5))
                                .cornerRadius(10)
                            }
                        }
                        
                        // Equipment
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Equipment")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .textCase(.uppercase)
                            Menu {
                                ForEach(vm.availableEquipment, id: \.self) { option in
                                    Button(option.capitalized) {
                                        vm.selectedEquipment = option
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(vm.selectedEquipment.capitalized)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                                .padding()
                                .background(Color(.systemGray5))
                                .cornerRadius(10)
                            }
                        }
                        
                        // Target Muscle
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Target Muscle")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .textCase(.uppercase)
                            Menu {
                                ForEach(vm.availableTargets, id: \.self) { option in
                                    Button(option.capitalized) {
                                        vm.selectedTarget = option
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(vm.selectedTarget.capitalized)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                                .padding()
                                .background(Color(.systemGray5))
                                .cornerRadius(10)
                            }
                        }
                        
                        // Show Exercises Button
                        Button {
                            vm.showExercises()
                        } label: {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("Show Exercises")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // MARK: - Results
                    if vm.showResults {
                        if vm.isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Loading exercises...")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                            .padding(.horizontal)
                            
                        } else if vm.exercises.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("No exercises found")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Text("Try adjusting your filters")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                            .padding(.horizontal)
                            
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                
                                Label("Exercises (\(vm.exercises.count))", systemImage: "list.bullet.clipboard.fill")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal)
                                
                                ForEach(vm.exercises) { ex in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(ex.name.capitalized)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                        
                                        HStack(spacing: 8) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "wrench.and.screwdriver.fill")
                                                    .font(.caption2)
                                                Text(ex.equipment.capitalized)
                                                    .font(.caption)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.15))
                                            .foregroundColor(.blue)
                                            .cornerRadius(8)
                                            
                                            HStack(spacing: 4) {
                                                Image(systemName: "target")
                                                    .font(.caption2)
                                                Text(ex.target.capitalized)
                                                    .font(.caption)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.orange.opacity(0.15))
                                            .foregroundColor(.orange)
                                            .cornerRadius(8)
                                        }
                                        
                                        if !ex.secondaryMuscles.isEmpty {
                                            Text("Secondary: \(ex.secondaryMuscles.joined(separator: ", ").capitalized)")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - ViewModel
class WorkoutSelectionViewModel: ObservableObject {
    
    @Published var selectedBodyPart = "waist" {
        didSet {
            selectedTarget = "any"
            selectedEquipment = "any"
            showResults = false
            fetchExercises()
        }
    }
    @Published var selectedEquipment = "any" {
        didSet { showResults = false }
    }
    @Published var selectedTarget = "any" {
        didSet { showResults = false }
    }
    @Published var exercises: [Exercise] = []
    @Published var isLoading = false
    @Published var showResults = false
    
    private var allExercises: [Exercise] = []
    private let service: ExerciseService
    private var lastFetchedBodyPart: String = ""
    
    var availableEquipment: [String] {
        let equipment = Set(allExercises.map {
            $0.equipment.lowercased().trimmingCharacters(in: .whitespaces)
        })
        return ["any"] + equipment.sorted()
    }
    
    var availableTargets: [String] {
        let filtered = selectedEquipment == "any" ? allExercises : allExercises.filter {
            $0.equipment.lowercased().trimmingCharacters(in: .whitespaces) == selectedEquipment
        }
        let targets = Set(filtered.map {
            $0.target.lowercased().trimmingCharacters(in: .whitespaces)
        })
        return ["any"] + targets.sorted()
    }
    
    init(service: ExerciseService = ExerciseService()) {
        self.service = service
    }
    
    func showExercises() {
        filterExercises()
        showResults = true
    }
    
    func fetchExercises() {
        let bodyPart = selectedBodyPart
        
        if bodyPart == lastFetchedBodyPart && !allExercises.isEmpty {
            return
        }
        
        isLoading = true
        exercises = []
        allExercises = []
        
        service.fetchExercisesByBodyPart(for: bodyPart) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let fetched):
                    self.lastFetchedBodyPart = bodyPart
                    self.allExercises = fetched
                case .failure(let error):
                    print("❌ Error:", error)
                    self.allExercises = []
                    self.exercises = []
                }
            }
        }
    }
    
    private func filterExercises() {
        let equipment = selectedEquipment.lowercased().trimmingCharacters(in: .whitespaces)
        let target = selectedTarget.lowercased().trimmingCharacters(in: .whitespaces)
        
        exercises = allExercises.filter { ex in
            let equipmentMatch = equipment == "any" ||
                ex.equipment.lowercased().trimmingCharacters(in: .whitespaces) == equipment
            let targetMatch = target == "any" ||
                ex.target.lowercased().trimmingCharacters(in: .whitespaces) == target
            return equipmentMatch && targetMatch
        }
    }
}

// MARK: - Preview
#Preview {
    WorkoutSelectionView()
}
