struct Exercise: Codable, Identifiable, Equatable {
    let bodyPart: String
    let equipment: String
    let id: String
    let name: String
    let target: String
    let secondaryMuscles: [String]
    let instructions: [String]
    let description: String
    let difficulty: String
    let category: String
}
