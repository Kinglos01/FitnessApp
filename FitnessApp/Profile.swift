import Foundation

public struct Profile: Identifiable, Codable, Equatable {
    public var id: String
    public var displayName: String
    public var email: String
    public var bio: String
    public var profileImageData: Data?
    public var achievements: [String]

    public init(
        id: String = UUID().uuidString,
        displayName: String,
        email: String,
        bio: String = "",
        profileImageData: Data? = nil,
        achievements: [String] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.bio = bio
        self.profileImageData = profileImageData
        self.achievements = achievements
    }

    public var initials: String {
        let parts = displayName.split(separator: " ")
        let first = parts.first?.first.map { String($0) } ?? ""
        let last = parts.dropFirst().first?.first.map { String($0) } ?? ""
        return (first + last).uppercased()
    }
}

public extension Profile {
    static let mock = Profile(
        displayName: "Taylor Appleseed",
        email: "taylor@example.com",
        bio: "Lifelong learner and fitness enthusiast.",
        achievements: [
            "Completed 10K Run",
            "7-Day Streak",
            "Personal Best: 50 Push-ups"
        ]
    )
}
