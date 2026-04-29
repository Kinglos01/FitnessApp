//
//  SocialProfileView.swift
//  FitnessApp
//
//  Displays a user's social profile: name, label badge, bio, streak, workout count.
//  Current user can edit their label and bio, persisted to Supabase profiles table.
//

import SwiftUI
import Supabase

// MARK: - SocialLabel Enum

enum SocialLabel: String, CaseIterable, Identifiable {
    case newbie       = "Newbie"
    case beginner     = "Beginner"
    case intermediate = "Intermediate"
    case advanced     = "Advanced"
    case trainer      = "Trainer"
    case coach        = "Coach"
    case athlete      = "Athlete"
    case enthusiast   = "Enthusiast"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .newbie:       return "leaf.fill"
        case .beginner:     return "figure.walk"
        case .intermediate: return "figure.run"
        case .advanced:     return "flame.fill"
        case .trainer:      return "dumbbell.fill"
        case .coach:        return "figure.strengthtraining.traditional"
        case .athlete:      return "trophy.fill"
        case .enthusiast:   return "sparkles"
        }
    }
}

// MARK: - Supabase row for social profile fetch

private struct SocialProfileRow: Codable {
    let id: String
    let name: String?
    let bio: String?
    let social_label: String?
    let profile_image_url: String?
}

// MARK: - Supabase update payload

private struct SocialProfileUpdate: Codable {
    let social_label: String?
}

// MARK: - SocialProfileView

struct SocialProfileView: View {

    let userId: UUID
    let isCurrentUser: Bool

    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var bio: String?
    @State private var socialLabel: SocialLabel?
    @State private var streak: Int?
    @State private var workoutCount: Int?

    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var showEditSheet: Bool = false
    @State private var unlockedAchievements: [UnlockedAchievement] = []
    @State private var isLoadingAchievements: Bool = true
    @State private var profileImageUrl: String? = nil

    // Edit sheet state
    @State private var editLabel: SocialLabel = .newbie
    @State private var isSaving: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.brandNavy.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(.brandLime)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundColor(.brandOrange)
                        Text("Could not load profile")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.brandCream)
                        Text(errorMessage)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(Color.brandCream.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            avatarSection
                            bioSection
                            statsRow
                            achievementsCard

                            if isCurrentUser {
                                Button {
                                    editLabel = socialLabel ?? .newbie
                                    showEditSheet = true
                                } label: {
                                    HStack {
                                        Image(systemName: "pencil")
                                        Text("Edit Profile")
                                    }
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.brandNavy)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color.brandLime)
                                    .cornerRadius(14)
                                }
                                .padding(.horizontal)
                            }

                            Spacer(minLength: 40)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.brandLime)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.brandNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear { fetchProfile() }
            .sheet(isPresented: $showEditSheet) {
                editSheet
            }
        }
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: 12) {
            if let urlString = profileImageUrl, !urlString.isEmpty {
                AsyncImage(url: URL(string: urlString)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Text(makeInitials(name))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.brandLime)
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(Color.brandLime.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Text(makeInitials(name))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.brandLime)
                }
            }

            Text(name)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.brandCream)

            if let label = socialLabel {
                HStack(spacing: 6) {
                    Image(systemName: label.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                    Text(label.rawValue)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundColor(.brandNavy)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.brandLime))
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Bio Section

    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bio")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Color.brandCream.opacity(0.5))

            Text(bio?.isEmpty == false ? bio! : "No bio yet")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(bio?.isEmpty == false ? .brandCream : Color.brandCream.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.brandCream.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
                .cornerRadius(14)
        }
        .padding(.horizontal)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(
                value: streak.map { "\($0)" } ?? "\u{2014}",
                label: "Day Streak",
                icon: "flame.fill",
                color: .brandOrange
            )
            Divider().frame(height: 40).background(Color.brandCream.opacity(0.12))
            statCell(
                // TODO: workout_count is not available for other users via the current schema.
                // For the current user we compute it from local exercises; for friends we show a placeholder.
                value: workoutCount.map { "\($0)" } ?? "\u{2014}",
                label: "Workouts",
                icon: "dumbbell.fill",
                color: .brandLime
            )
        }
        .padding(.vertical, 12)
        .background(Color.brandCream.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.brandCream)
            }
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color.brandCream.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Achievements Card

    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "FFB800"))
                Text("Achievements")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.brandCream)
                Spacer()
                Text("\(unlockedAchievements.count) / \(AchievementDefinition.all.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.brandLime)
            }

            if isLoadingAchievements {
                ProgressView()
                    .tint(.brandLime)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if unlockedAchievements.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "trophy")
                        .font(.system(size: 28))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("No achievements yet")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(Color.brandCream.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                let resolved = unlockedAchievements.compactMap { unlocked -> (def: AchievementDefinition, unlocked: UnlockedAchievement)? in
                    guard let def = AchievementDefinition.find(unlocked.id) else { return nil }
                    return (def, unlocked)
                }

                VStack(spacing: 8) {
                    ForEach(resolved.prefix(3), id: \.def.id) { item in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(item.def.tier.ringColor.opacity(0.18))
                                    .frame(width: 36, height: 36)
                                Image(systemName: item.def.category.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(item.def.tier.ringColor)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.def.title)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.brandCream)
                                Text(item.def.description)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(Color.brandCream.opacity(0.5))
                            }
                            Spacer()
                        }
                    }
                }

                if resolved.count > 3 {
                    Text("+ \(resolved.count - 3) more")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color.brandLime.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(Color.brandCream.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandCream.opacity(0.08), lineWidth: 1))
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }

    // MARK: - Edit Sheet

    private var editSheet: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()

            VStack(spacing: 20) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.brandCream.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)

                Text("Edit Social Profile")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.brandCream)

                // Label picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Social Label")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.brandCream.opacity(0.5))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SocialLabel.allCases) { label in
                                Button {
                                    editLabel = label
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: label.systemImage)
                                            .font(.system(size: 11))
                                        Text(label.rawValue)
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundColor(editLabel == label ? .brandNavy : Color.brandCream.opacity(0.7))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(editLabel == label ? Color.brandLime : Color.brandCream.opacity(0.08)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Save button
                Button {
                    saveProfile()
                } label: {
                    Group {
                        if isSaving {
                            ProgressView().tint(.brandNavy)
                        } else {
                            Text("Save")
                        }
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.brandNavy)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.brandLime)
                    .cornerRadius(14)
                }
                .disabled(isSaving)
                .padding(.horizontal)

                Spacer()
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Fetch

    private func fetchProfile() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let row: SocialProfileRow = try await supabase
                    .from("profiles")
                    .select("id, name, bio, social_label, profile_image_url")
                    .eq("id", value: userId.uuidString)
                    .single()
                    .execute()
                    .value

                await MainActor.run {
                    name = row.name ?? "Unknown"
                    bio = row.bio
                    profileImageUrl = row.profile_image_url
                    if let labelStr = row.social_label {
                        socialLabel = SocialLabel(rawValue: labelStr)
                    }
                }

                // Streak: use WorkoutService (same source FriendsView uses)
                let workouts = try await WorkoutService.shared.fetchWorkouts(userId: userId.uuidString)
                let cal = Calendar.current
                var s = 0
                var checkDate = cal.startOfDay(for: Date())
                while true {
                    let hasWorkout = workouts.contains {
                        $0.isCompleted && cal.startOfDay(for: $0.date) == checkDate
                    }
                    if hasWorkout {
                        s += 1
                        checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                    } else { break }
                }

                // Workout count this month
                let now = Date()
                let month = cal.component(.month, from: now)
                let year = cal.component(.year, from: now)
                let monthCount = workouts.filter {
                    $0.isCompleted &&
                    cal.component(.month, from: $0.date) == month &&
                    cal.component(.year, from: $0.date) == year
                }.count

                await MainActor.run {
                    streak = s
                    if isCurrentUser {
                        workoutCount = monthCount
                    } else {
                        workoutCount = monthCount
                    }
                    isLoading = false
                }

                // Load achievements
                let fetched = try? await AchievementService.shared.fetchUnlocked(userId: userId.uuidString)
                await MainActor.run {
                    unlockedAchievements = fetched ?? []
                    isLoadingAchievements = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Save

    private func saveProfile() {
        guard isCurrentUser else { return }
        isSaving = true
        Task {
            do {
                let update = SocialProfileUpdate(
                    social_label: editLabel.rawValue
                )
                try await supabase
                    .from("profiles")
                    .update(update)
                    .eq("id", value: userId.uuidString)
                    .execute()

                await MainActor.run {
                    socialLabel = editLabel
                    isSaving = false
                    showEditSheet = false
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
                print("Failed to save social profile: \(error)")
            }
        }
    }

    // MARK: - Helpers

    private func makeInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let f = parts.first?.prefix(1) ?? ""
        let l = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(f)\(l)".uppercased()
    }
}
