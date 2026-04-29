import SwiftUI
import PhotosUI
import Supabase
import UIKit

// Resolve ambiguity by aliasing the intended UserProfile type
// If you have multiple modules with UserProfile, qualify it here, e.g., Models.UserProfile
typealias AppUserProfile = Profile

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) var appState

    // Make profile optional to support guest/placeholder mode
    let profile: AppUserProfile?
    // onSave is optional; in guest mode we may not save
    let onSave: ((AppUserProfile) -> Void)?

    init(profile: AppUserProfile?, onSave: ((AppUserProfile) -> Void)?) {
        self.profile = profile
        self.onSave = onSave
        // Pre-populate state synchronously to avoid waiting on onAppear
        let p: AppUserProfile = profile ?? AppUserProfile(
            id: UUID().uuidString,
            displayName: "Guest",
            email: "",
            bio: "",
            profileImageData: nil
        )
        _displayName = State(initialValue: p.displayName.isEmpty ? "Guest" : p.displayName)
        _bio = State(initialValue: p.bio)
        _imageData = State(initialValue: p.profileImageData)
    }

    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var imageData: Data? = nil
    @State private var photosItem: PhotosPickerItem? = nil
    private let bioCharacterLimit = 150

    // Derived placeholder values for guest/empty state
    private var resolvedProfile: AppUserProfile {
        if let profile { return profile }
        // Provide a minimal placeholder profile for guests
        return AppUserProfile(
            id: UUID().uuidString,
            displayName: "Guest",
            email: "",
            bio: "",
            profileImageData: nil
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Photo") {
                    HStack(spacing: 16) {
                        ProfileAvatar(
                            imageData: imageData ?? resolvedProfile.profileImageData,
                            initials: resolvedProfile.initials
                        )
                        .frame(width: 64, height: 64)
                        PhotosPicker(selection: $photosItem, matching: .images) {
                            Label("Choose Photo", systemImage: "photo.on.rectangle")
                        }
                        .onChange(of: photosItem) { _, newItem in
                            guard let item = newItem else { return }
                            Task { await loadImage(from: item) }
                        }
                    }
                }

                Section("Name") {
                    TextField("Display Name", text: $displayName)
                }

                Section("Email") {
                    Text(resolvedProfile.email.isEmpty ? "No email" : resolvedProfile.email)
                        .foregroundColor(.secondary)
                }

                Section("Bio") {
                    TextField("Tell us a bit about you", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: bio) { _, newValue in
                            if newValue.count > bioCharacterLimit {
                                bio = String(newValue.prefix(bioCharacterLimit))
                            }
                        }

                    HStack {
                        Spacer()
                        Text("\(bio.count)/\(bioCharacterLimit)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(onSave == nil || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        guard var updated = profile ?? Optional(resolvedProfile) else { return }
        updated.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.profileImageData = imageData

        // Save locally first
        if let onSave { onSave(updated) }

        // Then sync to Supabase
        Task {
            let userId = updated.id

            // Upload image to Supabase Storage if imageData exists
            var imageUrl: String? = nil
            if let data = imageData {
                do {
                    let filePath = "\(userId)/avatar.jpg"

                    // Convert to JPEG
                    if let uiImage = UIImage(data: data),
                       let jpegData = uiImage.jpegData(compressionQuality: 0.7) {

                        try await supabase.storage
                            .from("avatars")
                            .upload(
                                path: filePath,
                                file: jpegData,
                                options: FileOptions(
                                    cacheControl: "3600",
                                    contentType: "image/jpeg",
                                    upsert: true
                                )
                            )

                        // Get public URL
                        let publicUrl = try supabase.storage
                            .from("avatars")
                            .getPublicURL(path: filePath)
                        imageUrl = publicUrl.absoluteString
                    }
                } catch {
                    print("Avatar upload error: \(error)")
                }
            }

            // Update bio and profile_image_url in profiles table
            var updateDict: [String: AnyEncodable] = [
                "bio": AnyEncodable(updated.bio)
            ]
            if let url = imageUrl {
                updateDict["profile_image_url"] = AnyEncodable(url)
            }

            do {
                try await supabase
                    .from("profiles")
                    .update(updateDict)
                    .eq("id", value: userId)
                    .execute()
            } catch {
                print("Profile sync error: \(error)")
            }
        }

        dismiss()
    }

    private func loadImage(from item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self) {
            await MainActor.run { self.imageData = data }
        }
    }
}

#Preview {
    Group {
        EditProfileView(profile: AppUserProfile.mock, onSave: { _ in })
        EditProfileView(profile: nil, onSave: nil)
    }
}
