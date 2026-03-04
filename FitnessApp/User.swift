import Foundation

struct User: Codable, Identifiable {
    var id: String        // Supabase UID
    var email: String
    var name: String
    var weight: Double
    var height: Double
    var age: Int
    var gender: String

    // Optional integer-backed fields for precise storage without breaking existing code
    // Defaults to nil so existing initializers continue to compile.
    var heightFeet: Int? = nil
    var heightInches: Int? = nil
    var birthMonth: Int? = nil // 1-12
    var birthYear: Int? = nil  // e.g., 1995
    var weightLbs: Int? = nil  // e.g., 180
}
