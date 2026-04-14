import SwiftUI
import PhotosUI

// Resolve ambiguity by aliasing the intended UserProfile type
// If you have multiple modules with UserProfile, qualify it here, e.g., Models.UserProfile
typealias AppUserProfile = Profile

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss

    let profile: AppUserProfile
    let onSave: (AppUserProfile) -> Void

    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var imageData: Data? = nil
    @State private var photosItem: PhotosPickerItem? = nil
    private let bioCharacterLimit = 150

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Photo") {
                    HStack(spacing: 16) {
                        ProfileAvatar(imageData: imageData ?? profile.profileImageData, initials: profile.initials)
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
                    // Read-only per requirements unless there's a separate account flow
                    Text(profile.email).foregroundColor(.secondary)
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
                        .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear { populate() }
    }

    private func populate() {
        displayName = profile.displayName
        bio         = profile.bio
        imageData   = profile.profileImageData
    }

    private func save() {
        var updated = profile
        updated.displayName     = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.bio             = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.profileImageData = imageData
        onSave(updated)
        dismiss()
    }

    private func loadImage(from item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self) {
            await MainActor.run { self.imageData = data }
        }
    }
}

#Preview {
    EditProfileView(profile: AppUserProfile.mock) { _ in }
}
