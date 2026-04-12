//
//  ChallengesView.swift
//  FitnessApp
//
//  Active challenges from Supabase via ChallengeService.
//

import SwiftUI

struct ChallengesView: View {

    @Environment(AppState.self) var appState
    @State private var challenges: [ChallengeRow] = []
    @State private var myProgress: [UUID: ParticipantRow] = [:]
    @State private var participantCounts: [UUID: Int] = [:]
    @State private var isLoading: Bool = true
    @State private var showCreateSheet: Bool = false
    @State private var discoverChallenges: [ChallengeRow] = []
    @State private var discoverParticipantCounts: [UUID: Int] = [:]
    @State private var creatorNames: [UUID: String] = [:]
    @State private var challengeToDelete: ChallengeRow? = nil
    @State private var showDeleteAlert: Bool = false

    private var userId: UUID? { UUID(uuidString: appState.currentUser?.id ?? "") }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                sectionHeader

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 30)
                } else if challenges.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "trophy").font(.system(size: 36)).foregroundColor(.gray.opacity(0.4))
                        Text("No active challenges").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(.secondary)
                        Text("Create one and invite your friends").font(.system(size: 13)).foregroundColor(.gray)
                    }.frame(maxWidth: .infinity).padding(.vertical, 40)
                } else {
                    ForEach(challenges) { challenge in
                        ChallengeCardLive(
                            challenge: challenge,
                            progress: myProgress[challenge.id],
                            participantCount: participantCounts[challenge.id] ?? 0
                        )
                        .contextMenu {
                            if challenge.creator_id == userId {
                                Button(role: .destructive) {
                                    challengeToDelete = challenge
                                    showDeleteAlert = true
                                } label: {
                                    Label("Delete Challenge", systemImage: "trash")
                                }
                            }
                        }
                    }.padding(.horizontal, 16)
                }

                discoverSection

                createButton
                Spacer(minLength: 40)
            }.padding(.vertical, 8)
        }
        .alert("Delete Challenge", isPresented: $showDeleteAlert, presenting: challengeToDelete) { challenge in
            Button("Delete", role: .destructive) { deleteChallenge(challenge) }
            Button("Cancel", role: .cancel) {}
        } message: { challenge in
            Text("Are you sure you want to delete \"\(challenge.title)\"? This cannot be undone.")
        }
        .sheet(isPresented: $showCreateSheet, onDismiss: { loadData() }) {
            CreateChallengeSheet().environment(appState)
        }
        .onAppear { loadData() }
    }

    private func loadData() {
        guard let uid = userId else { return }
        isLoading = true
        Task {
            do {
                challenges = try await ChallengeService.shared.fetchMyChallenges(userId: uid)
                for challenge in challenges {
                    let progress = try await ChallengeService.shared.fetchMyProgress(challengeId: challenge.id, userId: uid)
                    myProgress[challenge.id] = progress
                    let participants = try await ChallengeService.shared.fetchParticipants(challengeId: challenge.id)
                    participantCounts[challenge.id] = participants.count
                }

                // Fetch all challenges and filter out ones the user already joined
                let allChallenges = try await ChallengeService.shared.fetchAllChallenges()
                let myIds = Set(challenges.map { $0.id })
                discoverChallenges = allChallenges.filter { !myIds.contains($0.id) }

                // Fetch participant counts and creator names for discoverable challenges
                for challenge in discoverChallenges {
                    let participants = try await ChallengeService.shared.fetchParticipants(challengeId: challenge.id)
                    discoverParticipantCounts[challenge.id] = participants.count
                    if creatorNames[challenge.creator_id] == nil {
                        if let profile = try? await ProfileService.shared.fetchProfile(userId: challenge.creator_id.uuidString) {
                            creatorNames[challenge.creator_id] = profile.name
                        }
                    }
                }
            } catch { print("❌ ChallengesView load error: \(error)") }
            isLoading = false
        }
    }

    private var sectionHeader: some View {
        HStack {
            Image(systemName: "trophy.fill").font(.system(size: 14)).foregroundColor(.orange)
            Text("Active Challenges").font(.system(size: 15, weight: .bold, design: .rounded))
            Spacer()
        }.padding(.horizontal, 16)
    }

    // MARK: - Discover Section

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkle").font(.system(size: 14)).foregroundColor(.purple)
                Text("Discover Challenges").font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
            }.padding(.horizontal, 16)

            if discoverChallenges.isEmpty {
                Text("No new challenges to discover")
                    .font(.system(size: 13, design: .rounded)).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                ForEach(discoverChallenges) { challenge in
                    DiscoverChallengeCard(
                        challenge: challenge,
                        creatorName: creatorNames[challenge.creator_id] ?? "Unknown",
                        participantCount: discoverParticipantCounts[challenge.id] ?? 0,
                        onJoin: { joinDiscoverChallenge(challenge) }
                    )
                }.padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Actions

    private func joinDiscoverChallenge(_ challenge: ChallengeRow) {
        guard let uid = userId else { return }
        Task {
            do {
                try await ChallengeService.shared.joinChallenge(challengeId: challenge.id, userId: uid)
                loadData()
            } catch { print("❌ Join challenge error: \(error)") }
        }
    }

    private func deleteChallenge(_ challenge: ChallengeRow) {
        Task {
            do {
                try await ChallengeService.shared.deleteChallenge(challengeId: challenge.id)
                loadData()
            } catch { print("❌ Delete challenge error: \(error)") }
        }
    }

    private var createButton: some View {
        Button { showCreateSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.system(size: 18))
                Text("Create a Challenge").font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundColor(.blue).frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 14).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8])).foregroundColor(.blue.opacity(0.3)))
        }.padding(.horizontal, 16)
    }
}

// MARK: - Challenge Card (Live Data)

struct ChallengeCardLive: View {
    let challenge: ChallengeRow
    let progress: ParticipantRow?
    let participantCount: Int

    private var progressPercent: Double {
        guard let p = progress, challenge.target_value > 0 else { return 0 }
        return min(Double(p.current_value) / Double(challenge.target_value), 1.0)
    }

    private var daysLeft: Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let end = formatter.date(from: challenge.end_date) else { return 0 }
        return max(Calendar.current.dateComponents([.day], from: Date(), to: end).day ?? 0, 0)
    }

    private var challengeColor: Color {
        switch challenge.goal_type {
        case "steps": return Color(red: 0.25, green: 0.72, blue: 0.55)
        case "calories": return .purple
        case "workouts": return .blue
        default: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(challenge.title).font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Text("\(daysLeft)d left")
                    .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(challengeColor)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(challengeColor.opacity(0.12)).clipShape(Capsule())
            }
            Text("\(participantCount) participants \u{00B7} \(challenge.goal_type)")
                .font(.system(size: 12, design: .rounded)).foregroundColor(.secondary)

            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color(.systemGray4)).frame(height: 6)
                        RoundedRectangle(cornerRadius: 3).fill(challengeColor)
                            .frame(width: geo.size.width * progressPercent, height: 6)
                    }
                }.frame(height: 6)
                HStack {
                    Text("Your progress").font(.system(size: 11, design: .rounded)).foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(progressPercent * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(challengeColor)
                }
            }
        }
        .padding(14).background(Color(.systemGray6)).cornerRadius(14)
    }
}

// MARK: - Discover Challenge Card

struct DiscoverChallengeCard: View {
    let challenge: ChallengeRow
    let creatorName: String
    let participantCount: Int
    let onJoin: () -> Void

    private var daysLeft: Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let end = formatter.date(from: challenge.end_date) else { return 0 }
        return max(Calendar.current.dateComponents([.day], from: Date(), to: end).day ?? 0, 0)
    }

    private var challengeColor: Color {
        switch challenge.goal_type {
        case "steps": return Color(red: 0.25, green: 0.72, blue: 0.55)
        case "calories": return .purple
        case "workouts": return .blue
        default: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(challenge.title).font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Text("\(daysLeft)d left")
                    .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(challengeColor)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(challengeColor.opacity(0.12)).clipShape(Capsule())
            }
            HStack(spacing: 4) {
                Text("by \(creatorName)").font(.system(size: 12, design: .rounded)).foregroundColor(.secondary)
                Text("\u{00B7}").foregroundColor(.secondary)
                Text("\(participantCount) participants").font(.system(size: 12, design: .rounded)).foregroundColor(.secondary)
                Text("\u{00B7}").foregroundColor(.secondary)
                Text(challenge.goal_type).font(.system(size: 12, design: .rounded)).foregroundColor(.secondary)
            }
            HStack {
                Text("Target: \(challenge.target_value) \(challenge.goal_type)")
                    .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(challengeColor)
                Spacer()
                Button { onJoin() } label: {
                    Text("Join")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(challengeColor).clipShape(Capsule())
                }
            }
        }
        .padding(14).background(Color(.systemGray6)).cornerRadius(14)
    }
}

// MARK: - Create Challenge Sheet

struct CreateChallengeSheet: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var goalType: String = "workouts"
    @State private var target: String = ""
    @State private var duration: Int = 7
    @State private var isCreating: Bool = false

    let goalTypes = ["steps", "calories", "workouts", "active_minutes"]
    let goalLabels = ["Steps", "Calories Burned", "Workouts", "Active Minutes"]

    var body: some View {
        NavigationView {
            Form {
                Section("Challenge Details") {
                    TextField("Challenge name", text: $title).font(.system(size: 15, design: .rounded))
                    Picker("Goal type", selection: $goalType) {
                        ForEach(Array(zip(goalTypes, goalLabels)), id: \.0) { type, label in
                            Text(label).tag(type)
                        }
                    }
                    TextField("Target (e.g. 10000)", text: $target).font(.system(size: 15, design: .rounded)).keyboardType(.numberPad)
                    Stepper("Duration: \(duration) days", value: $duration, in: 1...90).font(.system(size: 15, design: .rounded))
                }
            }
            .navigationTitle("New Challenge").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") { createChallenge() }
                        .font(.system(size: 15, weight: .bold))
                        .disabled(title.isEmpty || target.isEmpty || isCreating)
                }
            }
        }
    }

    private func createChallenge() {
        guard let uid = UUID(uuidString: appState.currentUser?.id ?? ""),
              let targetValue = Int(target) else { return }
        isCreating = true
        Task {
            do {
                _ = try await ChallengeService.shared.createChallenge(creatorId: uid, title: title, goalType: goalType, targetValue: targetValue, durationDays: duration)
                dismiss()
            } catch { print("❌ Create challenge error: \(error)") }
            isCreating = false
        }
    }
}
