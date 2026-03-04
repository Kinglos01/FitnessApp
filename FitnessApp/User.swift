import Foundation

struct User: Codable, Identifiable {
    var id: String        // Supabase UID
    var email: String
    var name: String
    var weight: Double
    var height: Double
    var age: Int
    var gender: String
}
