import SwiftUI

// Temporary local model to satisfy view dependencies if a shared model isn't present.
// If you already have a global `Profile` model, remove this and import that module instead.
private struct LocalProfile: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var displayName: String
    var email: String
    var bio: String = ""
    var profileImageData: Data? = nil
    var initials: String { String(displayName.split(separator: " ").compactMap { $0.first }).uppercased() }
    var achievements: [String] = []
}

struct ProfileView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showEmailOnProfile") private var showEmailOnProfile: Bool = true
    private var store: ProfileStore { appState.profileStore }
    
    @State private var showEdit = false
    @State private var showSettings = false

    private var userId: String { appState.currentUser?.id ?? "" }
    private var userName: String { appState.currentUser?.name ?? "" }
    private var userEmail: String { appState.currentUser?.email ?? "" }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                topBar

                if let p = store.profile {
                    let local = LocalProfile(
                        id: p.id,
                        displayName: p.displayName,
                        email: p.email,
                        bio: p.bio,
                        profileImageData: p.profileImageData,
                        achievements: p.achievements
                    )

                    profileHeroCard(profile: local)
                    editButton
                    AchievementsSection(achievements: local.achievements)
                } else {
                    // Guest placeholder content instead of a spinner
                    let guest = LocalProfile(
                        id: UUID().uuidString,
                        displayName: "Guest",
                        email: "",
                        bio: "",
                        profileImageData: nil,
                        achievements: []
                    )

                    profileHeroCard(profile: guest)
                    editButton
                    AchievementsSection(achievements: [])
                }

                Spacer(minLength: 60)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showEdit) {
            if let profile = store.profile {
                EditProfileView(profile: profile) { updated in
                    store.update(updated)
                }
                .environment(appState)
            } else {
                // Guest mode: show editable UI with placeholders; Save disabled
                EditProfileView(profile: nil, onSave: nil)
                    .environment(appState)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(appState)
        }
        .onAppear {
            appState.syncProfileStoreFromCurrentUser()
        }
        .onChange(of: appState.currentUser?.id) { _, _ in
            appState.syncProfileStoreFromCurrentUser()
        }
        .background(Color.brandNavy.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.brandCream.opacity(0.06))
                        .frame(width: 42, height: 42)

                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.brandCream)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                showSettings = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.brandCream.opacity(0.06))
                        .frame(width: 42, height: 42)

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.brandCream)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }
    
    @ViewBuilder
    private func profileHeroCard(profile: LocalProfile) -> some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(spacing: 10) {
                ProfileAvatar(imageData: profile.profileImageData, initials: profile.initials)
                    .frame(width: 88, height: 88)

                Text(profile.displayName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.brandCream)
                    .multilineTextAlignment(.center)

                if showEmailOnProfile {
                    Text(profile.email)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.brandCream.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(width: 150)

            Rectangle()
                .fill(Color.brandCream.opacity(0.10))
                .frame(width: 1.5, height: 110)

            VStack(alignment: .leading, spacing: 10) {
                Text("BIO")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color.brandLime.opacity(0.75))
                    .tracking(1.2)

                Text(
                    profile.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "No bio added yet."
                    : profile.bio
                )
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(Color.brandCream.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.vertical, 6)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.brandCream.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.brandCream.opacity(0.07), lineWidth: 1)
        )
    }
    
    private var editButton: some View {
        Button {
            showEdit = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.brandNavy)

                Text("Edit Profile")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.brandNavy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.brandLime)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Header

private struct ProfileHeaderView: View {
    let profile: LocalProfile

    var body: some View {
        VStack(spacing: 12) {
            ProfileAvatar(imageData: profile.profileImageData, initials: profile.initials)
                .frame(width: 100, height: 100)
                .padding(.top, 8)

            Text(profile.displayName)
                .font(.system(size: 22, weight: .black, design: .rounded))
            Text(profile.email)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !profile.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(profile.bio)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Achievements

private struct AchievementsSection: View {
    let achievements: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Achievements", systemImage: "trophy.fill")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.brandCream)
                Spacer()
            }

            if achievements.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "trophy")
                        .foregroundColor(Color.brandCream.opacity(0.45))

                    Text("No achievements yet")
                        .foregroundColor(Color.brandCream.opacity(0.55))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.brandCream.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.brandCream.opacity(0.06), lineWidth: 1)
                )
                .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(achievements, id: \.self) { title in
                        HStack(spacing: 10) {
                            Image(systemName: "star.circle.fill")
                                .foregroundColor(.brandLime)

                            Text(title)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.brandCream)

                            Spacer()
                        }
                        .padding(12)
                        .background(Color.brandCream.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.brandCream.opacity(0.06), lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
