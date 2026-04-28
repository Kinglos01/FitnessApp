//
//  CommunitiesView.swift
//  FitnessApp
//
//  Group chats by interest from Supabase via CommunityService.
//

import SwiftUI

struct CommunitiesView: View {

    @Environment(AppState.self) var appState
    @State private var myCommunities: [CommunityRecord] = []
    @State private var allCommunities: [CommunityRecord] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = true
    @State private var showCreateSheet: Bool = false
    @State private var selectedCommunity: CommunityRecord? = nil
    @State private var refreshTimer: Timer? = nil
    @State private var blockedIds: Set<UUID> = []

    private var userId: UUID? { UUID(uuidString: appState.currentUser?.id ?? "") }

    private var myIds: Set<UUID> { Set(myCommunities.map { $0.id }) }

    private var discoverCommunities: [CommunityRecord] {
        let notJoined = allCommunities.filter { !myIds.contains($0.id) }
        if searchText.isEmpty { return notJoined }
        return notJoined.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                searchBar

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 30)
                } else {
                    if !myCommunities.isEmpty { yourSection }
                    discoverSection
                }

                createButton
                Spacer(minLength: 40)
            }.padding(.vertical, 8)
        }
        .sheet(isPresented: $showCreateSheet, onDismiss: { loadData(showLoading: false) }) {
            CreateCommunitySheet().environment(appState)
        }
        .sheet(item: $selectedCommunity, onDismiss: { loadData(showLoading: false) }) { community in
            CommunityChatView(community: community).environment(appState)
        }
        .refreshable { loadData(showLoading: false) }
        .onAppear {
            loadData(showLoading: true)
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in loadData(showLoading: false) }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    private func loadData(showLoading: Bool = false) {
        guard let uid = userId else { return }
        if showLoading { isLoading = true }
        Task {
            do {
                let blocked = try await BlockService.shared.fetchBlockedIds(userId: uid)
                blockedIds = Set(blocked)
                myCommunities = try await CommunityService.shared.fetchMyCommunities(userId: uid)
                allCommunities = try await CommunityService.shared.fetchAllCommunities()
            } catch { print("CommunitiesView load error: \(error)") }
            isLoading = false
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .medium)).foregroundColor(.secondary)
            TextField("Search communities...", text: $searchText).font(.system(size: 15, design: .rounded)).autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    private var yourSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.3.fill").font(.system(size: 13)).foregroundColor(.blue)
                Text("Your Communities").font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Text("\(myCommunities.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.blue).padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.blue.opacity(0.12)).clipShape(Capsule())
            }.padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(myCommunities.enumerated()), id: \.element.id) { index, community in
                    Button { selectedCommunity = community } label: {
                        CommunityRowView(community: community, isJoined: true, onJoin: {}, onLeave: { leave(community) })
                    }
                    .buttonStyle(.plain)
                    if index < myCommunities.count - 1 { Divider().padding(.leading, 70) }
                }
            }.background(Color(.systemGray6)).cornerRadius(14).padding(.horizontal, 16)
        }
    }

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "safari.fill").font(.system(size: 13)).foregroundColor(.orange)
                Text("Discover").font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Text("\(discoverCommunities.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.orange).padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12)).clipShape(Capsule())
            }.padding(.horizontal, 16)

            if discoverCommunities.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "globe").font(.system(size: 36)).foregroundColor(.gray.opacity(0.4))
                    Text("No communities to discover").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(.secondary)
                    Text("Create one to get started").font(.system(size: 13)).foregroundColor(.gray)
                }.frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(discoverCommunities.enumerated()), id: \.element.id) { index, community in
                        CommunityRowView(community: community, isJoined: false, onJoin: { join(community) }, onLeave: {})
                        if index < discoverCommunities.count - 1 { Divider().padding(.leading, 70) }
                    }
                }.background(Color(.systemGray6)).cornerRadius(14).padding(.horizontal, 16)
            }
        }
    }

    private var createButton: some View {
        Button { showCreateSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.system(size: 18))
                Text("Create a Community").font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundColor(.brandLime).frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 14).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8])).foregroundColor(.brandLime.opacity(0.3)))
        }.padding(.horizontal, 16)
    }

    private func join(_ community: CommunityRecord) {
        guard let uid = userId else { return }
        Task {
            do { try await CommunityService.shared.joinCommunity(communityId: community.id, userId: uid); loadData() }
            catch { print("Join error: \(error)") }
        }
    }

    private func leave(_ community: CommunityRecord) {
        guard let uid = userId else { return }
        Task {
            do { try await CommunityService.shared.leaveCommunity(communityId: community.id, userId: uid); loadData() }
            catch { print("Leave error: \(error)") }
        }
    }
}

// MARK: - Community Row

struct CommunityRowView: View {
    let community: CommunityRecord
    let isJoined: Bool
    let onJoin: () -> Void
    let onLeave: () -> Void

    private var accentColor: Color { isJoined ? .blue : .orange }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 4, height: 40)
                .padding(.trailing, 12)

            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(accentColor.opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: "person.3.fill").font(.system(size: 16, weight: .medium)).foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(community.name).font(.system(size: 15, weight: .semibold, design: .rounded))
                if let desc = community.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }.padding(.leading, 12)

            Spacer()

            if isJoined {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill").font(.system(size: 10))
                    Text("\(community.member_count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color(.systemGray5)).clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                    .padding(.leading, 8)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill").font(.system(size: 10))
                    Text("\(community.member_count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color(.systemGray5)).clipShape(Capsule())

                Button { onJoin() } label: {
                    Text("Join").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.blue)
                        .padding(.horizontal, 16).padding(.vertical, 6)
                        .overlay(Capsule().stroke(Color.blue, lineWidth: 1.5))
                }.padding(.leading, 8)
            }
        }.padding(.horizontal, 14).padding(.vertical, 14)
    }
}

// MARK: - Community Chat View

struct CommunityChatView: View {
    let community: CommunityRecord

    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [CommunityMessageRow] = []
    @State private var senderNames: [UUID: String] = [:]
    @State private var messageText: String = ""
    @State private var isLoading: Bool = true
    @State private var showDeleteAlert: Bool = false
    @State private var showMembers: Bool = false
    @State private var members: [UserSearchResult] = []
    @State private var isLoadingMembers: Bool = false

    private var userId: UUID? {
        UUID(uuidString: appState.currentUser?.id ?? "")
    }

    private var isCreator: Bool {
        guard let uid = userId else { return false }
        return community.creator_id == uid
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if messages.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 42)).foregroundColor(.gray.opacity(0.3))
                        Text("No messages yet")
                            .font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundColor(.secondary)
                        Text("Start the conversation!")
                            .font(.system(size: 13, design: .rounded)).foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(messages) { msg in
                                    CommunityMessageBubble(
                                        message: msg,
                                        isMine: msg.sender_id == userId,
                                        senderName: senderNames[msg.sender_id] ?? "Unknown"
                                    )
                                    .id(msg.id)
                                }
                            }.padding(16)
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                        .onAppear {
                            if let last = messages.last {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }

                if isCreator {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.fill").font(.system(size: 13))
                            Text("Delete Community").font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                }

                // Input bar
                HStack(spacing: 10) {
                    TextField("Message...", text: $messageText)
                        .font(.system(size: 15, design: .rounded))
                        .padding(10).background(Color(.systemGray6)).cornerRadius(20)
                    Button { sendMessage() } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                            .frame(width: 36, height: 36).background(Color.blue).clipShape(Circle())
                    }.disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.systemBackground))
                .overlay(Divider(), alignment: .top)
            }
            .navigationTitle(community.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { loadMembers(); showMembers = true } label: {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 14))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showMembers) {
                CommunityMembersSheet(
                    communityName: community.name,
                    creatorId: community.creator_id,
                    members: members,
                    isLoading: isLoadingMembers
                )
            }
            .alert("Delete Community?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { deleteCommunity() }
            } message: {
                Text("This will permanently delete the community, all members, and all messages. This cannot be undone.")
            }
        }
        .onAppear { loadMessages() }
    }

    private func loadMessages() {
        isLoading = true
        Task {
            do {
                messages = try await CommunityService.shared.fetchMessages(communityId: community.id)
                // Fetch sender names for messages that aren't ours
                let uniqueSenderIds = Set(messages.map { $0.sender_id }).filter { $0 != userId }
                for senderId in uniqueSenderIds {
                    if let profile = try? await ProfileService.shared.fetchProfile(userId: senderId.uuidString) {
                        senderNames[senderId] = profile.name
                    }
                }
            } catch { print("Load community messages error: \(error)") }
            isLoading = false
        }
    }

    private func sendMessage() {
        guard let uid = userId else { return }
        let body = messageText.trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else { return }
        messageText = ""
        Task {
            do {
                try await CommunityService.shared.sendMessage(communityId: community.id, senderId: uid, body: body)
                messages = try await CommunityService.shared.fetchMessages(communityId: community.id)
            } catch { print("Send community message error: \(error)") }
        }
    }

    private func loadMembers() {
        isLoadingMembers = true
        Task {
            do {
                members = try await CommunityService.shared.fetchMembers(communityId: community.id)
            } catch { print("Load members error: \(error)") }
            isLoadingMembers = false
        }
    }

    private func deleteCommunity() {
        Task {
            do {
                try await CommunityService.shared.deleteCommunity(communityId: community.id)
                dismiss()
            } catch { print("Delete community error: \(error)") }
        }
    }
}

// MARK: - Community Message Bubble

struct CommunityMessageBubble: View {
    let message: CommunityMessageRow
    let isMine: Bool
    let senderName: String

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 60) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                if !isMine {
                    Text(senderName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Text(message.body)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(isMine ? .white : .primary)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(isMine ? Color.blue : Color(.systemGray5))
                    .cornerRadius(18)
            }
            if !isMine { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Community Members Sheet

struct CommunityMembersSheet: View {
    let communityName: String
    let creatorId: UUID
    let members: [UserSearchResult]
    let isLoading: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if members.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "person.3").font(.system(size: 36)).foregroundColor(.gray.opacity(0.4))
                        Text("No members").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(members) { member in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.blue.opacity(0.15)).frame(width: 40, height: 40)
                                Text(makeInitials(member.name ?? "?"))
                                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.blue)
                            }
                            Text(member.name ?? "Unknown")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            if member.id == creatorId {
                                Text("Creator")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            Spacer()
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func makeInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let f = parts.first?.prefix(1) ?? ""
        let l = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(f)\(l)".uppercased()
    }
}

// MARK: - Create Community Sheet

struct CreateCommunitySheet: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var isCreating: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section("Community Details") {
                    TextField("Community name", text: $name).font(.system(size: 15, design: .rounded))
                    TextField("Description (optional)", text: $description).font(.system(size: 15, design: .rounded))
                }
                Section(footer: Text("Anyone can find and join your community.")) { EmptyView() }
            }
            .navigationTitle("New Community").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") { create() }.font(.system(size: 15, weight: .bold)).disabled(name.isEmpty || isCreating)
                }
            }
        }
    }

    private func create() {
        guard let uid = UUID(uuidString: appState.currentUser?.id ?? "") else { return }
        isCreating = true
        Task {
            do { _ = try await CommunityService.shared.createCommunity(creatorId: uid, name: name, description: description); dismiss() }
            catch { print("Create community error: \(error)") }
            isCreating = false
        }
    }
}
