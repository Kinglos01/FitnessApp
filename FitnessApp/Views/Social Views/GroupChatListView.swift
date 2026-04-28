//
//  GroupChatListView.swift
//  FitnessApp
//
//  Group chat list, creation, and thread views for the Messages tab.
//

import SwiftUI

// MARK: - Group Chat Preview

struct GroupChatPreview: Identifiable {
    let id: UUID
    let group: GroupChatRow
    let memberNames: [String]
    let lastMessage: String?
    let lastMessageTime: Date?
}

// MARK: - GroupChatListView

struct GroupChatListView: View {

    @Environment(AppState.self) var appState
    @State private var groupPreviews: [GroupChatPreview] = []
    @State private var isLoading: Bool = true
    @State private var showCreateSheet: Bool = false
    @State private var selectedGroup: GroupChatRow? = nil

    private var userId: UUID? {
        UUID(uuidString: appState.currentUser?.id ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 13)).foregroundColor(.purple)
                Text("Group Chats")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                if !groupPreviews.isEmpty {
                    Text("\(groupPreviews.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.purple).padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.purple.opacity(0.12)).clipShape(Capsule())
                }
            }.padding(.horizontal, 16)

            if isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if groupPreviews.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.3")
                        .font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                    Text("No group chats yet")
                        .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(groupPreviews.enumerated()), id: \.element.id) { index, preview in
                        Button { selectedGroup = preview.group } label: {
                            GroupChatRowView(preview: preview)
                        }
                        .buttonStyle(.plain)
                        if index < groupPreviews.count - 1 { Divider().padding(.leading, 70) }
                    }
                }
                .background(Color(.systemGray6)).cornerRadius(14).padding(.horizontal, 16)
            }

            // Create button
            Button { showCreateSheet = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 18))
                    Text("New Group Chat").font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundColor(.brandLime).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 14).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8])).foregroundColor(.brandLime.opacity(0.3)))
            }.padding(.horizontal, 16)
        }
        .sheet(item: $selectedGroup) { group in
            GroupChatThreadView(group: group).environment(appState)
        }
        .sheet(isPresented: $showCreateSheet, onDismiss: { loadData() }) {
            CreateGroupChatSheet().environment(appState)
        }
        .onAppear { loadData() }
    }

    private func loadData() {
        guard let uid = userId else { return }
        Task {
            do {
                let groups = try await GroupChatService.shared.fetchMyGroups(userId: uid)
                var previews: [GroupChatPreview] = []
                for group in groups {
                    let members = try await GroupChatService.shared.fetchMembers(groupId: group.id)
                    var names: [String] = []
                    for member in members {
                        if member.user_id == uid {
                            names.insert("You", at: 0)
                        } else if let profile = try? await ProfileService.shared.fetchProfile(userId: member.user_id.uuidString) {
                            names.append(profile.name)
                        } else {
                            names.append("Unknown")
                        }
                    }
                    let latest = try? await GroupChatService.shared.fetchLatestMessage(groupId: group.id)
                    previews.append(GroupChatPreview(
                        id: group.id,
                        group: group,
                        memberNames: names,
                        lastMessage: latest?.body,
                        lastMessageTime: latest?.created_at
                    ))
                }
                groupPreviews = previews
            } catch {
                print("GroupChatListView load error: \(error)")
            }
            isLoading = false
        }
    }
}

// MARK: - Group Chat Row View

private struct GroupChatRowView: View {
    let preview: GroupChatPreview

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.purple.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: "person.3.fill")
                    .font(.system(size: 16, weight: .medium)).foregroundColor(.purple)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(preview.group.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Text(preview.memberNames.joined(separator: ", "))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if let msg = preview.lastMessage {
                    Text(msg)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let time = preview.lastMessageTime {
                Text(timeAgo(time))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.gray)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
    }

    private func timeAgo(_ date: Date) -> String {
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "now" }
        if mins < 60 { return "\(mins)m" }
        let hours = mins / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        if days == 1 { return "Yesterday" }
        return "\(days)d"
    }
}

// MARK: - Group Chat Thread View

struct GroupChatThreadView: View {
    let group: GroupChatRow

    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [GroupChatMessageRow] = []
    @State private var senderNames: [UUID: String] = [:]
    @State private var messageText: String = ""
    @State private var isLoading: Bool = true

    private var userId: UUID? {
        UUID(uuidString: appState.currentUser?.id ?? "")
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
                                    GroupMessageBubble(
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

                // Input bar
                HStack(spacing: 10) {
                    TextField("Message...", text: $messageText)
                        .font(.system(size: 15, design: .rounded))
                        .padding(10).background(Color(.systemGray6)).cornerRadius(20)
                    Button { sendMessage() } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                            .frame(width: 36, height: 36).background(Color.purple).clipShape(Circle())
                    }.disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.systemBackground))
                .overlay(Divider(), alignment: .top)
            }
            .navigationTitle(group.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { loadMessages() }
    }

    private func loadMessages() {
        isLoading = true
        Task {
            do {
                messages = try await GroupChatService.shared.fetchMessages(groupId: group.id)
                let uniqueSenderIds = Set(messages.map { $0.sender_id }).filter { $0 != userId }
                for senderId in uniqueSenderIds {
                    if let profile = try? await ProfileService.shared.fetchProfile(userId: senderId.uuidString) {
                        senderNames[senderId] = profile.name
                    }
                }
                if let uid = userId {
                    senderNames[uid] = "You"
                }
            } catch { print("Load group messages error: \(error)") }
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
                try await GroupChatService.shared.sendMessage(groupId: group.id, senderId: uid, body: body)
                messages = try await GroupChatService.shared.fetchMessages(groupId: group.id)
            } catch { print("Send group message error: \(error)") }
        }
    }
}

// MARK: - Group Message Bubble

private struct GroupMessageBubble: View {
    let message: GroupChatMessageRow
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
                    .background(isMine ? Color.purple : Color(.systemGray5))
                    .cornerRadius(18)
            }
            if !isMine { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Create Group Chat Sheet

struct CreateGroupChatSheet: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @State private var groupName: String = ""
    @State private var friends: [UserSearchResult] = []
    @State private var selectedFriendIds: Set<UUID> = []
    @State private var isCreating: Bool = false
    @State private var isLoadingFriends: Bool = true

    private var userId: UUID? {
        UUID(uuidString: appState.currentUser?.id ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Group Details") {
                    TextField("Group name", text: $groupName)
                        .font(.system(size: 15, design: .rounded))
                }

                Section("Add Friends") {
                    if isLoadingFriends {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if friends.isEmpty {
                        Text("No friends to add")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(friends) { friend in
                            Button {
                                if selectedFriendIds.contains(friend.id) {
                                    selectedFriendIds.remove(friend.id)
                                } else {
                                    selectedFriendIds.insert(friend.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().fill(Color.purple.opacity(0.15)).frame(width: 36, height: 36)
                                        Text(makeInitials(friend.name ?? "?"))
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(.purple)
                                    }
                                    Text(friend.name ?? "Unknown")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: selectedFriendIds.contains(friend.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(selectedFriendIds.contains(friend.id) ? .purple : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("New Group Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") { createGroup() }
                        .font(.system(size: 15, weight: .bold))
                        .disabled(selectedFriendIds.isEmpty || isCreating)
                }
            }
        }
        .onAppear { loadFriends() }
    }

    private func loadFriends() {
        guard let uid = userId else { return }
        Task {
            do {
                friends = try await FriendService.shared.fetchFriends(userId: uid)
            } catch { print("Load friends error: \(error)") }
            isLoadingFriends = false
        }
    }

    private func createGroup() {
        guard let uid = userId else { return }
        isCreating = true
        let name = groupName.trimmingCharacters(in: .whitespaces).isEmpty ? "Group Chat" : groupName
        Task {
            do {
                _ = try await GroupChatService.shared.createGroup(
                    creatorId: uid,
                    name: name,
                    memberIds: Array(selectedFriendIds)
                )
                dismiss()
            } catch { print("Create group error: \(error)") }
            isCreating = false
        }
    }

    private func makeInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let f = parts.first?.prefix(1) ?? ""
        let l = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(f)\(l)".uppercased()
    }
}
