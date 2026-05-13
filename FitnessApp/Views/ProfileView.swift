import SwiftUI

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
    @State private var showAchievements = false
    @State private var unlockedAchievements: [UnlockedAchievement] = []
    @State private var isLoadingAchievements = false
    @State private var dayStreak: Int = 0
    @State private var todayWorkoutCount: Int = 0

    private var userId: String { appState.currentUser?.id ?? "" }

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
                    statsRow
                    editButton
                    achievementsCard
                } else {
                    ProgressView().tint(.brandLime).padding(.top, 40)
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
            SettingsView().environment(appState)
        }
        .sheet(isPresented: $showAchievements) {
            AchievementsView().environment(appState)
        }
        .onAppear {
            appState.syncProfileStoreFromCurrentUser()
            Task { await loadAchievements() }
            Task { await loadWorkoutStats() }
        }
        .onChange(of: appState.currentUser?.id) { _, _ in
            appState.syncProfileStoreFromCurrentUser()
            Task { await loadAchievements() }
            Task { await loadWorkoutStats() }
        }
        .background(Color.brandNavy.ignoresSafeArea())
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                ZStack {
                    Circle().fill(Color.brandCream.opacity(0.06)).frame(width: 42, height: 42)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.brandCream)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button { showSettings = true } label: {
                ZStack {
                    Circle().fill(Color.brandCream.opacity(0.06)).frame(width: 42, height: 42)
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.brandCream)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: - Hero Card

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
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.brandCream.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.brandCream.opacity(0.07), lineWidth: 1))
    }

    // MARK: - Edit Button

    private var editButton: some View {
        Button { showEdit = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil.circle.fill").foregroundColor(.brandNavy)
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

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.brandOrange)
                    Text("\(dayStreak)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.brandCream)
                }
                Text("Day Streak")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color.brandCream.opacity(0.5))
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 40).background(Color.brandCream.opacity(0.12))

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.brandLime)
                    Text("\(todayWorkoutCount)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.brandCream)
                }
                Text("Workouts Today")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color.brandCream.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
        .cornerRadius(16)
    }

    // MARK: - Load Workout Stats

    @MainActor
    private func loadWorkoutStats() async {
        guard !userId.isEmpty else { return }
        do {
            let workouts = try await WorkoutService.shared.fetchWorkouts(userId: userId)
            let cal = Calendar.current
            let todayStart = cal.startOfDay(for: Date())

            // Today's workout count
            todayWorkoutCount = workouts.filter {
                $0.isCompleted(on: todayStart)
            }.count

            // Day streak: consecutive days backwards from today with at least 1 workout
            var streak = 0
            var checkDate = todayStart
            while true {
                let hasWorkout = workouts.contains {
                    $0.isCompleted(on: checkDate)
                }
                if hasWorkout {
                    streak += 1
                    checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                } else {
                    break
                }
            }
            dayStreak = streak
        } catch {
            print("Failed to load workout stats: \(error)")
        }
    }

    // MARK: - Achievements Card

    private var achievementsCard: some View {
        Button { showAchievements = true } label: {
            VStack(alignment: .leading, spacing: 14) {
                achievementsHeader
                if unlockedAchievements.isEmpty && !isLoadingAchievements {
                    achievementsEmpty
                } else {
                    achievementsPreview
                }
            }
            .padding(16)
            .background(Color.brandCream.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.08), lineWidth: 1))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    private var achievementsHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "FFB800"))
                Text("Achievements")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.brandCream)
            }
            Spacer()
            HStack(spacing: 6) {
                if isLoadingAchievements {
                    ProgressView().tint(.brandLime).scaleEffect(0.7)
                } else {
                    Text("\(unlockedAchievements.count) / 41")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.brandLime)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.brandCream.opacity(0.3))
            }
        }
    }

    private var achievementsEmpty: some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy")
                .foregroundColor(Color.brandCream.opacity(0.3))
            Text("No achievements unlocked yet — keep going!")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(Color.brandCream.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var achievementsPreview: some View {
        VStack(spacing: 8) {
            ForEach(Array(unlockedAchievements.prefix(3))) { achievement in
                AchievementPreviewRow(achievement: achievement)
            }
            if unlockedAchievements.count > 3 {
                Text("+ \(unlockedAchievements.count - 3) more — tap to view all")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.brandLime.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Load Achievements

    @MainActor
    private func loadAchievements() async {
        guard !userId.isEmpty else { return }
        isLoadingAchievements = true
        if let fetched = try? await AchievementService.shared.fetchUnlocked(userId: userId) {
            unlockedAchievements = fetched
        }
        isLoadingAchievements = false
    }
}

// MARK: - Achievement Preview Row

private struct AchievementPreviewRow: View {
    let achievement: UnlockedAchievement

    private var definition: AchievementDefinition? {
        AchievementDefinition.all.first { $0.id == achievement.id }
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(definition?.tier.ringColor.opacity(0.18) ?? Color.brandCream.opacity(0.06))
                    .frame(width: 36, height: 36)
                Image(systemName: definition?.category.icon ?? "trophy.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(definition?.tier.ringColor ?? .brandLime)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(definition?.title ?? "Achievement")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.brandCream)
                Text(definition?.description ?? "")
                    .font(.system(size: 11))
                    .foregroundColor(Color.brandCream.opacity(0.45))
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
