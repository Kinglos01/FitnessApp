import Foundation

// MARK: - UserProfile model
// Lightweight profile used by the ProfileView/EditProfileView. It is intentionally
// separate from the broader `User` model so the screen is previewable without a backend.
struct UserProfile: Identifiable, Codable, Equatable {
    let id: String                     // matches AppState.currentUser?.id
    var displayName: String
    var email: String                  // read-only in UI
    var bio: String
    var profileImageData: Data?        // optional local image data
    var achievements: [String]         // simple list of achievement titles

    init(id: String,
         displayName: String,
         email: String,
         bio: String = "",
         profileImageData: Data? = nil,
         achievements: [String] = []) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.bio = bio
        self.profileImageData = profileImageData
        self.achievements = achievements
    }

    // Convenience: initials for placeholder avatar
    var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined().uppercased()
    }

    // Mock profile for previews
    static let mock = UserProfile(
        id: "preview-user",
        displayName: "Alex Johnson",
        email: "alex@example.com",
        bio: "Training for a half marathon. Love strength days & good coffee.",
        achievements: ["5-Day Streak", "First 5K", "Logged 100 Workouts"]
    )
}
