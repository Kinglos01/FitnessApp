import Foundation
import Observation

@Observable
final class ProfileStore {
    var profile: Profile? = nil

    func load(userId: String, displayName: String, email: String) {
        guard !userId.isEmpty else {
            profile = nil
            return
        }

        if var cached = loadFromCache(userId: userId) {
            cached.email = email

            if cached.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cached.displayName = displayName.isEmpty ? "Friend" : displayName
            }

            profile = cached
            saveToCache(cached)
        } else {
            let seeded = Profile(
                id: userId,
                displayName: displayName.isEmpty ? "Friend" : displayName,
                email: email,
                bio: "",
                profileImageData: nil,
                achievements: []
            )
            profile = seeded
            saveToCache(seeded)
        }
    }

    func update(_ updated: Profile) {
        profile = updated
        saveToCache(updated)
    }

    private func key(for userId: String) -> String {
        "user_profile_\(userId)"
    }

    private func saveToCache(_ profile: Profile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key(for: profile.id))
        }
    }

    private func loadFromCache(userId: String) -> Profile? {
        guard
            let data = UserDefaults.standard.data(forKey: key(for: userId)),
            let decoded = try? JSONDecoder().decode(Profile.self, from: data)
        else {
            return nil
        }
        return decoded
    }
}
