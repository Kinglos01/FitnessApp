//
//  FriendsView.swift
//  FitnessApp
//
//  Search users by name from DB, send friend requests,
//  view pending requests, and streak leaderboard from workouts.
//

import SwiftUI
import Supabase

// MARK: - FriendsView

struct FriendsView: View {

    @Environment(AppState.self) var appState
    @State private var searchText: String = ""
    @State private var searchResults: [UserSearchResult] = []
    @State private var friends: [UserSearchResult] = []
    @State private var pendingIncoming: [FriendshipRow] = []
    @State private var pendingSentIds: Set<String> = []
    @State private var friendshipRows: [FriendshipRow] = []
    @State private var friendStreaks: [UUID: Int] = [:]
    @State private var isSearching: Bool = false
    @State private var isLoading: Bool = true
    @State private var friendToRemove: UserSearchResult? = nil
    @State private var showRemoveAlert: Bool = false
    @State private var showMyProfile: Bool = false
    @State private var myBio: String?
    @State private var mySocialLabel: String?
    @State private var selectedProfileUserId: UUID? = nil

    private var userId: UUID? {
        UUID(uuidString: appState.currentUser?.id ?? "")
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                yourProfileCard

                searchBar

                if !searchText.isEmpty {
                    searchResultsSection
                }

                if !pendingIncoming.isEmpty {
                    pendingRequestsSection
                }

                if !friends.isEmpty {
                    yourFriendsSection
                }

                leaderboardSection
            }
            .padding(.vertical, 8)
        }
        .alert("Remove Friend", isPresented: $showRemoveAlert, presenting: friendToRemove) { friend in
            Button("Remove", role: .destructive) { removeFriend(friend) }
            Button("Cancel", role: .cancel) {}
        } message: { friend in
            Text("Are you sure you want to remove \(friend.name ?? "this friend")?")
        }
        .sheet(isPresented: $showMyProfile) {
            if let uid = userId {
                SocialProfileView(userId: uid, isCurrentUser: true)
                    .environment(appState)
            }
        }
        .sheet(item: $selectedProfileUserId) { profileId in
            SocialProfileView(userId: profileId, isCurrentUser: profileId == userId)
                .environment(appState)
        }
        .onAppear { loadData() }
    }

    // MARK: - Your Profile Card

    private var yourProfileCard: some View {
        Button { showMyProfile = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.brandLime.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text(makeInitials(appState.currentUser?.name ?? "?"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.brandLime)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.currentUser?.name ?? "Your Profile")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.brandCream)
                    Text(mySocialLabel ?? "Set your label")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color.brandCream.opacity(0.5))
                    Text(myBio?.components(separatedBy: "\n").first ?? "Add a bio")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(Color.brandCream.opacity(0.4))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.brandCream.opacity(0.3))
            }
            .padding(14)
            .background(Color.brandNavy)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandCream.opacity(0.12), lineWidth: 1))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Load Data

    private func loadData() {
        guard let uid = userId else { return }
        isLoading = true
        Task {
            do {
                friends = try await FriendService.shared.fetchFriends(userId: uid)
                pendingIncoming = try await FriendService.shared.fetchPendingRequests(userId: uid)
                let allRows: [FriendshipRow] = try await supabase
                    .from("friendships")
                    .select()
                    .eq("status", value: "accepted")
                    .or("requester_id.eq.\(uid.uuidString),addressee_id.eq.\(uid.uuidString)")
                    .execute()
                    .value
                friendshipRows = allRows
                let sent = try await FriendService.shared.fetchSentRequests(userId: uid)
                pendingSentIds = Set(sent.map { $0.addressee_id.uuidString })

                for friend in friends {
                    let streak = try await calculateStreak(userId: friend.id.uuidString)
                    friendStreaks[friend.id] = streak
                }
                let myStreak = try await calculateStreak(userId: uid.uuidString)
                friendStreaks[uid] = myStreak
            } catch {
                print("❌ FriendsView load error: \(error)")
            }
            isLoading = false
            fetchMyProfileMeta()
        }
    }

    private func fetchMyProfileMeta() {
        guard let uid = userId else { return }
        Task {
            struct MiniProfile: Codable {
                let bio: String?
                let social_label: String?
            }
            if let row: MiniProfile = try? await supabase
                .from("profiles")
                .select("bio, social_label")
                .eq("id", value: uid.uuidString)
                .single()
                .execute()
                .value {
                await MainActor.run {
                    myBio = row.bio
                    mySocialLabel = row.social_label
                }
            }
        }
    }

    private func calculateStreak(userId: String) async throws -> Int {
        let workouts = try await WorkoutService.shared.fetchWorkouts(userId: userId)
        let cal = Calendar.current
        var streak = 0
        var checkDate = cal.startOfDay(for: Date())
        while true {
            let hasWorkout = workouts.contains {
                $0.isCompleted && cal.startOfDay(for: $0.date) == checkDate
            }
            if hasWorkout {
                streak += 1
                checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else { break }
        }
        return streak
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
            TextField("Search users by name...", text: $searchText)
                .font(.system(size: 15, design: .rounded))
                .autocorrectionDisabled()
                .onChange(of: searchText) { _, newValue in
                    performSearch(query: newValue)
                }
            if !searchText.isEmpty {
                Button { searchText = ""; searchResults = [] } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16)).foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    private func performSearch(query: String) {
        guard query.count >= 2 else { searchResults = []; return }
        isSearching = true
        Task {
            do {
                let results = try await FriendService.shared.searchUsers(query: query)
                let friendIds = Set(friends.map { $0.id })
                searchResults = results.filter { $0.id != userId && !friendIds.contains($0.id) }
            } catch { print("❌ Search error: \(error)") }
            isSearching = false
        }
    }

    // MARK: - Search Results Section

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.badge.plus").font(.system(size: 13)).foregroundColor(.blue)
                Text("Search Results").font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
            }.padding(.horizontal, 16)

            if isSearching {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if searchResults.isEmpty {
                Text("No users found")
                    .font(.system(size: 14, design: .rounded)).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, user in
                        SearchResultRow(user: user, alreadySent: pendingSentIds.contains(user.id.uuidString)) {
                            sendRequest(to: user)
                        }
                        if index < searchResults.count - 1 { Divider().padding(.leading, 60) }
                    }
                }
                .background(Color(.systemGray6)).cornerRadius(14).padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Pending Requests Section

    private var pendingRequestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "bell.badge.fill").font(.system(size: 13)).foregroundColor(.orange)
                Text("Friend Requests").font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Text("\(pendingIncoming.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.orange).padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12)).clipShape(Capsule())
            }.padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(pendingIncoming.enumerated()), id: \.element.id) { index, request in
                    PendingRequestRow(request: request, onAccept: { acceptRequest(request) }, onDecline: { declineRequest(request) })
                    if index < pendingIncoming.count - 1 { Divider().padding(.leading, 60) }
                }
            }
            .background(Color(.systemGray6)).cornerRadius(14).padding(.horizontal, 16)
        }
    }

    // MARK: - Your Friends Section

    private var yourFriendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.2.fill").font(.system(size: 13)).foregroundColor(.green)
                Text("Your Friends").font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Text("\(friends.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.green).padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.green.opacity(0.12)).clipShape(Capsule())
            }.padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(friends.enumerated()), id: \.element.id) { index, friend in
                    Button { selectedProfileUserId = friend.id } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.green.opacity(0.15)).frame(width: 40, height: 40)
                                Text(makeInitials(friend.name ?? "?"))
                                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.green)
                            }
                            Text(friend.name ?? "Unknown")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            friendToRemove = friend
                            showRemoveAlert = true
                        } label: {
                            Label("Remove Friend", systemImage: "person.badge.minus")
                        }
                    }
                    if index < friends.count - 1 { Divider().padding(.leading, 60) }
                }
            }
            .background(Color(.systemGray6)).cornerRadius(14).padding(.horizontal, 16)
        }
    }

    // MARK: - Leaderboard Section

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "flame.fill").font(.system(size: 14)).foregroundColor(.orange)
                Text("Streak Leaderboard").font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Text("\(friends.count) friends")
                    .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(.secondary)
            }.padding(.horizontal, 16)

            if isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 30)
            } else if friends.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash").font(.system(size: 36)).foregroundColor(.gray.opacity(0.4))
                    Text("No friends yet").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(.secondary)
                    Text("Search for users above to add friends").font(.system(size: 13)).foregroundColor(.gray)
                }.frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                let entries = buildLeaderboardEntries()
                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        Button {
                            if entry.id == userId {
                                showMyProfile = true
                            } else {
                                selectedProfileUserId = entry.id
                            }
                        } label: {
                            LeaderboardEntryRow(rank: index + 1, entry: entry, isCurrentUser: entry.id == userId)
                        }
                        .buttonStyle(.plain)
                        if index < entries.count - 1 { Divider().padding(.leading, 70) }
                    }
                }
                .background(Color(.systemGray6)).cornerRadius(14).padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Build Leaderboard Entries

    struct LeaderboardEntry: Identifiable {
        let id: UUID
        let name: String
        let initials: String
        let streak: Int
        let color: Color
    }

    private func buildLeaderboardEntries() -> [LeaderboardEntry] {
        let colors: [Color] = [
            Color(red: 0.25, green: 0.72, blue: 0.55), .orange,
            Color(red: 0.85, green: 0.35, blue: 0.25), .purple, .pink
        ]
        var entries: [LeaderboardEntry] = []
        for (i, friend) in friends.enumerated() {
            let name = friend.name ?? "Unknown"
            entries.append(LeaderboardEntry(id: friend.id, name: name, initials: makeInitials(name), streak: friendStreaks[friend.id] ?? 0, color: colors[i % colors.count]))
        }
        if let uid = userId {
            let myName = appState.currentUser?.name ?? "You"
            entries.append(LeaderboardEntry(id: uid, name: "You", initials: makeInitials(myName), streak: friendStreaks[uid] ?? 0, color: .blue))
        }
        return entries.sorted { $0.streak > $1.streak }
    }

    private func makeInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let f = parts.first?.prefix(1) ?? ""
        let l = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(f)\(l)".uppercased()
    }

    // MARK: - Actions

    private func sendRequest(to user: UserSearchResult) {
        guard let uid = userId else { return }
        Task {
            do { try await FriendService.shared.sendRequest(from: uid, to: user.id); pendingSentIds.insert(user.id.uuidString) }
            catch { print("❌ Send request error: \(error)") }
        }
    }

    private func acceptRequest(_ request: FriendshipRow) {
        Task {
            do { try await FriendService.shared.acceptRequest(friendshipId: request.id); loadData() }
            catch { print("❌ Accept error: \(error)") }
        }
    }

    private func removeFriend(_ friend: UserSearchResult) {
        guard let row = friendshipRows.first(where: {
            ($0.requester_id == friend.id || $0.addressee_id == friend.id)
        }) else { return }
        Task {
            do {
                try await FriendService.shared.removeFriend(friendshipId: row.id)
                loadData()
            } catch { print("❌ Remove friend error: \(error)") }
        }
    }

    private func declineRequest(_ request: FriendshipRow) {
        Task {
            do { try await FriendService.shared.declineRequest(friendshipId: request.id); pendingIncoming.removeAll { $0.id == request.id } }
            catch { print("❌ Decline error: \(error)") }
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let user: UserSearchResult
    let alreadySent: Bool
    let onSendRequest: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.blue.opacity(0.15)).frame(width: 40, height: 40)
                Text(initials(from: user.name ?? "?"))
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.blue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name ?? "Unknown").font(.system(size: 15, weight: .semibold, design: .rounded))
                if let email = user.email {
                    Text(email).font(.system(size: 12, design: .rounded)).foregroundColor(.secondary)
                }
            }
            Spacer()
            Button { onSendRequest() } label: {
                Text(alreadySent ? "Sent" : "Add")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(alreadySent ? .secondary : .white)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(alreadySent ? Color(.systemGray4) : Color.blue).clipShape(Capsule())
            }.disabled(alreadySent)
        }.padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let f = parts.first?.prefix(1) ?? ""; let l = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(f)\(l)".uppercased()
    }
}

// MARK: - Pending Request Row

struct PendingRequestRow: View {
    let request: FriendshipRow
    let onAccept: () -> Void
    let onDecline: () -> Void
    @State private var requesterName: String = "Loading..."

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.orange.opacity(0.15)).frame(width: 40, height: 40)
                Text(initials(from: requesterName))
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.orange)
            }
            Text(requesterName).font(.system(size: 15, weight: .semibold, design: .rounded))
            Spacer()
            Button { onAccept() } label: {
                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                    .frame(width: 32, height: 32).background(Color(red: 0.25, green: 0.72, blue: 0.55)).clipShape(Circle())
            }
            Button { onDecline() } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                    .frame(width: 32, height: 32).background(Color.red.opacity(0.8)).clipShape(Circle())
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .onAppear {
            Task {
                if let user = try? await ProfileService.shared.fetchProfile(userId: request.requester_id.uuidString) {
                    requesterName = user.name
                }
            }
        }
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let f = parts.first?.prefix(1) ?? ""; let l = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(f)\(l)".uppercased()
    }
}

// MARK: - Leaderboard Entry Row

struct LeaderboardEntryRow: View {
    let rank: Int
    let entry: FriendsView.LeaderboardEntry
    let isCurrentUser: Bool

    private var rankColor: Color {
        switch rank {
        case 1: return Color(red: 0.85, green: 0.65, blue: 0.13)
        case 2: return .gray
        case 3: return Color(red: 0.72, green: 0.45, blue: 0.20)
        default: return .secondary
        }
    }

    private var streakColor: Color {
        if entry.streak >= 14 { return Color(red: 0.25, green: 0.72, blue: 0.55) }
        if entry.streak >= 7  { return .orange }
        if entry.streak >= 3  { return .blue }
        return .secondary
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(rankColor).frame(width: 24)
            ZStack {
                Circle().fill(entry.color.opacity(0.2)).frame(width: 40, height: 40)
                Text(entry.initials).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(entry.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(isCurrentUser ? "You" : entry.name).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(isCurrentUser ? .blue : .primary)
                Text("\(entry.streak)-day streak").font(.system(size: 12, design: .rounded)).foregroundColor(.secondary)
            }
            Spacer()
            Text("\(entry.streak) \(entry.streak == 1 ? "day" : "days")")
                .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(streakColor)
                .padding(.horizontal, 10).padding(.vertical, 5).background(streakColor.opacity(0.12)).clipShape(Capsule())
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(isCurrentUser ? Color.blue.opacity(0.05) : Color.clear)
    }
}
