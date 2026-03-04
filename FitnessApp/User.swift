import Foundation

struct User: Codable, Identifiable {
    var id: String        // Supabase UID
    var email: String
    var name: String
    var weight: Double
    var height: Double
    var birthDate: Date
    var gender: String

    var age: Int {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return ageComponents.year ?? 0
    }
}