//
//  MessagesView.swift
//  FitnessApp
//
//  DM list — only shows conversations with accepted friends.
//  Pulls from direct_messages table via DirectMessageService.
//

import SwiftUI

struct MessagesView: View {

    @Environment(AppState.self) var appState
    @State private var conversations: [ConversationPreview] = []
    @State private var friends: [UserSearchResult] = []
    @State private var isLoading: Bool = true
    @State private var selectedFriendId: UUID? = nil
    @State private var convoToDelete: ConversationPreview? = nil
    @State private var showDeleteAlert: Bool = false

    private var userId: UUID? {
        UUID(uuidString: appState.currentUser?.id ?? "")
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                sectionHeader

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 30)
                } else if conversations.isEmpty {
                    emptyState
                } else {
                    messageList
                }

                newMessageSection

                Spacer(minLength: 40)
            }
            .padding(.vertical, 8)
        }
        .sheet(item: $selectedFriendId) { friendId in
            ChatThreadView(friendId: friendId, friendName: friendName(for: friendId))
                .environment(appState)
        }
        .alert("Delete Conversation", isPresented: $showDeleteAlert, presenting: convoToDelete) { convo in
            Button("Delete", role: .destructive) { deleteConversation(with: convo.id) }
            Button("Cancel", role: .cancel) {}
        } message: { convo in
            Text("Delete your entire conversation with \(convo.friendName)? This cannot be undone.")
        }
        .onAppear { loadData() }
    }

    // MARK: - Load Data

    private func loadData() {
        guard let uid = userId else { return }
        isLoading = true
        Task {
            do {
                friends = try await FriendService.shared.fetchFriends(userId: uid)
                conversations = try await DirectMessageService.shared.fetchConversationPreviews(userId: uid, friendProfiles: friends)
            } catch {
                print("❌ MessagesView load error: \(error)")
            }
            isLoading = false
        }
    }

    private func deleteConversation(with friendId: UUID) {
        guard let uid = userId else { return }
        Task {
            do {
                try await DirectMessageService.shared.deleteConversation(userId: uid, friendId: friendId)
                loadData()
            } catch { print("❌ Delete conversation error: \(error)") }
        }
    }

    private func friendName(for id: UUID) -> String {
        friends.first(where: { $0.id == id })?.name ?? "Friend"
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 13)).foregroundColor(.blue)
            Text("Direct Messages")
                .font(.system(size: 15, weight: .bold, design: .rounded))
            Spacer()
        }.padding(.horizontal, 16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bubble.left").font(.system(size: 42)).foregroundColor(.gray.opacity(0.3))
            Text("No messages yet").font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundColor(.secondary)
            Text("Start a conversation with a friend below")
                .font(.system(size: 13, design: .rounded)).foregroundColor(.gray)
        }.frame(maxWidth: .infinity).padding(.vertical, 50)
    }

    // MARK: - Message List

    private var messageList: some View {
        VStack(spacing: 0) {
            ForEach(Array(conversations.enumerated()), id: \.element.id) { index, convo in
                Button {
                    selectedFriendId = convo.id
                } label: {
                    ConversationRow(convo: convo)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        convoToDelete = convo
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Conversation", systemImage: "trash")
                    }
                }
                if index < conversations.count - 1 { Divider().padding(.leading, 70) }
            }
        }
        .background(Color(.systemGray6)).cornerRadius(14).padding(.horizontal, 16)
    }

    // MARK: - New Message (pick a friend)

    private var newMessageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "plus.bubble.fill").font(.system(size: 13)).foregroundColor(.blue)
                Text("Start a Conversation").font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
            }.padding(.horizontal, 16)

            let existingConvoIds = Set(conversations.map { $0.id })
            let availableFriends = friends.filter { !existingConvoIds.contains($0.id) }

            if availableFriends.isEmpty {
                Text("You\u{2019}ve messaged all your friends")
                    .font(.system(size: 13, design: .rounded)).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(availableFriends.enumerated()), id: \.element.id) { index, friend in
                        Button { selectedFriendId = friend.id } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(Color.blue.opacity(0.15)).frame(width: 36, height: 36)
                                    Text(makeInitials(friend.name ?? "?"))
                                        .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.blue)
                                }
                                Text(friend.name ?? "Unknown")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                        }.buttonStyle(.plain)
                        if index < availableFriends.count - 1 { Divider().padding(.leading, 60) }
                    }
                }
                .background(Color(.systemGray6)).cornerRadius(14).padding(.horizontal, 16)
            }
        }
    }

    private func makeInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let f = parts.first?.prefix(1) ?? ""; let l = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(f)\(l)".uppercased()
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let convo: ConversationPreview

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.blue.opacity(0.15)).frame(width: 44, height: 44)
                Text(makeInitials(convo.friendName))
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.blue)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(convo.friendName).font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(convo.lastMessage).font(.system(size: 13, design: .rounded)).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(timeAgo(convo.lastMessageDate)).font(.system(size: 12, design: .rounded)).foregroundColor(.gray)
                if convo.unreadCount > 0 {
                    Text("\(convo.unreadCount)")
                        .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.white)
                        .frame(minWidth: 20, minHeight: 20).background(Color.blue).clipShape(Circle())
                }
            }
        }.padding(.horizontal, 14).padding(.vertical, 12)
    }

    private func makeInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let f = parts.first?.prefix(1) ?? ""; let l = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(f)\(l)".uppercased()
    }

    private func timeAgo(_ date: Date) -> String {
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "now" }
        if mins < 60 { return "\(mins)m" }
        let hours = mins / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
}

// MARK: - Chat Thread View

struct ChatThreadView: View {
    let friendId: UUID
    let friendName: String

    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [DirectMessageRow] = []
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
                        Text("Say hi to \(friendName)!")
                            .font(.system(size: 13, design: .rounded)).foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(messages) { msg in
                                    MessageBubble(message: msg, isMine: msg.sender_id == userId)
                                        .id(msg.id)
                                }
                            }.padding(16)
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
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
                            .frame(width: 36, height: 36).background(Color.blue).clipShape(Circle())
                    }.disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.systemBackground))
                .overlay(Divider(), alignment: .top)
            }
            .navigationTitle(friendName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { loadThread() }
    }

    private func loadThread() {
        guard let uid = userId else { return }
        isLoading = true
        Task {
            do {
                messages = try await DirectMessageService.shared.fetchThread(userId: uid, friendId: friendId)
                try await DirectMessageService.shared.markAsRead(from: friendId, to: uid)
            } catch { print("❌ Load thread error: \(error)") }
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
                try await DirectMessageService.shared.sendMessage(senderId: uid, receiverId: friendId, body: body)
                messages = try await DirectMessageService.shared.fetchThread(userId: uid, friendId: friendId)
            } catch { print("❌ Send message error: \(error)") }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: DirectMessageRow
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 60) }
            Text(message.body)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(isMine ? .white : .primary)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(isMine ? Color.blue : Color(.systemGray5))
                .cornerRadius(18)
            if !isMine { Spacer(minLength: 60) }
        }
    }
}

// MARK: - UUID Identifiable for sheet

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
