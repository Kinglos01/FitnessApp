//
//  GroupChatThreadView.swift
//  SimplyFit
//
//  Full-screen group chat thread and settings views.
//

import SwiftUI

// MARK: - GroupChatThreadView

struct GroupChatThreadView: View {
    let group: GroupChatRow

    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [GroupChatMessageRow] = []
    @State private var senderNames: [UUID: String] = [:]
    @State private var newMessage: String = ""
    @State private var isLoading: Bool = true
    @State private var showSettings: Bool = false
    @State private var refreshTimer: Timer? = nil
    @State private var groupDeleted: Bool = false

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
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                        Text("Start the conversation!")
                            .font(.system(size: 13, design: .rounded)).foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(messages) { msg in
                                    GroupThreadBubble(
                                        message: msg,
                                        isMine: msg.sender_id == userId,
                                        senderName: senderNames[msg.sender_id] ?? "Unknown"
                                    )
                                    .id(msg.id)
                                }
                            }.padding(16)
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let last = messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
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
                    TextField("Message...", text: $newMessage)
                        .font(.system(size: 15, design: .rounded))
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                    Button { sendMessage() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.brandLime)
                    }
                    .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.systemBackground))
                .overlay(Divider(), alignment: .top)
            }
            .navigationTitle(group.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            if groupDeleted { dismiss() } else { loadMessages() }
        }) {
            GroupChatSettingsView(group: group, groupDeleted: $groupDeleted)
                .environment(appState)
        }
        .onAppear {
            loadMessages()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
                loadMessages()
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    private func loadMessages() {
        Task {
            do {
                messages = try await GroupChatService.shared.fetchMessages(groupId: group.id)
                let uniqueSenderIds = Set(messages.map { $0.sender_id })
                for senderId in uniqueSenderIds where senderNames[senderId] == nil {
                    if senderId == userId {
                        senderNames[senderId] = "You"
                    } else if let profile = try? await ProfileService.shared.fetchProfile(userId: senderId.uuidString) {
                        senderNames[senderId] = profile.name
                    }
                }
            } catch {
                print("Load group messages error: \(error)")
            }
            isLoading = false
        }
    }

    private func sendMessage() {
        guard let uid = userId else { return }
        let body = newMessage.trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else { return }
        newMessage = ""
        Task {
            do {
                try await GroupChatService.shared.sendMessage(groupId: group.id, senderId: uid, body: body)
                messages = try await GroupChatService.shared.fetchMessages(groupId: group.id)
            } catch {
                print("Send group message error: \(error)")
            }
        }
    }
}

// MARK: - Group Thread Bubble

private struct GroupThreadBubble: View {
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
                        .foregroundColor(.purple)
                }
                Text(message.body)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(isMine ? Color(.darkGray) : .primary)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(isMine ? Color.brandLime : Color(.systemGray5))
                    .cornerRadius(18)
                if let date = message.created_at {
                    Text(relativeTime(date))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
            if !isMine { Spacer(minLength: 60) }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 1 { return "now" }
        if mins < 60 { return "\(mins)m ago" }
        let hours = mins / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days == 1 { return "Yesterday" }
        return "\(days)d ago"
    }
}

// MARK: - Member Profile Action

struct MemberProfileAction: Identifiable {
    let id: UUID
    let name: String
    let isCreator: Bool
}

// MARK: - GroupChatSettingsView

struct GroupChatSettingsView: View {
    let group: GroupChatRow
    @Binding var groupDeleted: Bool

    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @State private var members: [(id: UUID, name: String)] = []
    @State private var selectedMember: MemberProfileAction? = nil
    @State private var friendIds: Set<UUID> = []
    @State private var friends: [UserSearchResult] = []
    @State private var groupName: String
    @State private var isEditing: Bool = false
    @State private var showAddMember: Bool = false
    @State private var memberIdsInGroup: Set<UUID> = []
    @State private var showDeleteAlert: Bool = false
    @State private var showLeaveAlert: Bool = false
    @State private var isLoadingMembers: Bool = true

    private var userId: UUID? {
        UUID(uuidString: appState.currentUser?.id ?? "")
    }

    private var isCreator: Bool {
        userId == group.creator_id
    }

    init(group: GroupChatRow, groupDeleted: Binding<Bool>) {
        self.group = group
        self._groupDeleted = groupDeleted
        self._groupName = State(initialValue: group.name)
    }

    var body: some View {
        NavigationView {
            List {
                // Group Name
                Section("Group Name") {
                    if isEditing {
                        HStack {
                            TextField("Group name", text: $groupName)
                                .font(.system(size: 15, design: .rounded))
                                .autocorrectionDisabled()
                            Button("Save") { saveGroupName() }
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.brandLime)
                        }
                    } else {
                        HStack {
                            Text(groupName)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                            Spacer()
                            Button("Edit") { isEditing = true }
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.brandLime)
                        }
                    }
                }

                // Members
                Section {
                    if isLoadingMembers {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        ForEach(members, id: \.id) { member in
                            Button {
                                if member.id != userId {
                                    selectedMember = MemberProfileAction(id: member.id, name: member.name, isCreator: member.id == group.creator_id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.purple.opacity(0.15))
                                            .frame(width: 36, height: 36)
                                        Text(makeInitials(member.name))
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(.purple)
                                    }
                                    Text(member.id == userId ? "You" : member.name)
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                    if member.id == group.creator_id {
                                        Text("Admin")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8).padding(.vertical, 3)
                                            .background(Color.purple).clipShape(Capsule())
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if isCreator && member.id != userId {
                                    Button(role: .destructive) {
                                        removeMember(member.id)
                                    } label: {
                                        Label("Remove from Group", systemImage: "person.badge.minus")
                                    }
                                }
                            }
                        }

                        // Leave group button
                        Button(role: .destructive) {
                            showLeaveAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Leave Group")
                            }
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.red)
                        }
                    }
                } header: {
                    HStack {
                        Text("Members")
                        Spacer()
                        Text("\(members.count)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.purple)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color.purple.opacity(0.12)).clipShape(Capsule())
                    }
                }

                // Add Members
                Section {
                    Button { showAddMember = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 16))
                            Text("Add Members")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.brandLime)
                    }
                }

                // Danger Zone (creator only)
                if isCreator {
                    Section("Danger Zone") {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash.fill")
                                Text("Delete Group")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Group Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showAddMember, onDismiss: { loadMembers() }) {
            AddGroupMemberSheet(group: group, memberIdsInGroup: memberIdsInGroup)
                .environment(appState)
        }
        .sheet(item: $selectedMember) { member in
            MemberProfileSheet(
                member: member,
                currentUserId: userId,
                groupId: group.id
            )
            .environment(appState)
        }
        .alert("Leave Group", isPresented: $showLeaveAlert) {
            Button("Leave", role: .destructive) { leaveGroup() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to leave this group chat?")
        }
        .alert("Delete Group", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { deleteGroup() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the group and all messages. This cannot be undone.")
        }
        .onAppear { loadMembers(); loadFriends() }
    }

    private func loadMembers() {
        Task {
            do {
                let memberRows = try await GroupChatService.shared.fetchMembers(groupId: group.id)
                var result: [(id: UUID, name: String)] = []
                var ids: Set<UUID> = []
                for row in memberRows {
                    ids.insert(row.user_id)
                    if let profile = try? await ProfileService.shared.fetchProfile(userId: row.user_id.uuidString) {
                        result.append((id: row.user_id, name: profile.name))
                    } else {
                        result.append((id: row.user_id, name: "Unknown"))
                    }
                }
                members = result
                memberIdsInGroup = ids
            } catch {
                print("Load members error: \(error)")
            }
            isLoadingMembers = false
        }
    }

    private func loadFriends() {
        guard let uid = userId else { return }
        Task {
            do {
                friends = try await FriendService.shared.fetchFriends(userId: uid)
            } catch {
                print("Load friends error: \(error)")
            }
        }
    }

    private func saveGroupName() {
        let trimmed = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        groupName = trimmed
        isEditing = false
        Task {
            do {
                try await GroupChatService.shared.renameGroup(groupId: group.id, newName: trimmed)
            } catch {
                print("Rename group error: \(error)")
            }
        }
    }

    private func removeMember(_ memberId: UUID) {
        Task {
            do {
                try await GroupChatService.shared.removeMember(groupId: group.id, userId: memberId)
                loadMembers()
            } catch {
                print("Remove member error: \(error)")
            }
        }
    }

    private func leaveGroup() {
        guard let uid = userId else { return }
        Task {
            do {
                try await GroupChatService.shared.removeMember(groupId: group.id, userId: uid)
                dismiss()
            } catch {
                print("Leave group error: \(error)")
            }
        }
    }

    private func deleteGroup() {
        Task {
            do {
                try await GroupChatService.shared.deleteGroup(groupId: group.id)
                groupDeleted = true
                dismiss()
            } catch {
                print("Delete group error: \(error)")
            }
        }
    }

    private func makeInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let f = parts.first?.prefix(1) ?? ""
        let l = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(f)\(l)".uppercased()
    }
}

// MARK: - Member Profile Sheet

private struct MemberProfileSheet: View {
    let member: MemberProfileAction
    let currentUserId: UUID?
    let groupId: UUID

    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @State private var isFriend: Bool = false
    @State private var requestSent: Bool = false
    @State private var isLoadingFriend: Bool = true
    @State private var alreadyReported: Bool = false
    @State private var showReportOptions: Bool = false
    @State private var reportSubmitted: Bool = false

    private func makeInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let f = parts.first?.prefix(1) ?? ""
        let l = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(f)\(l)".uppercased()
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle().fill(Color.purple.opacity(0.15)).frame(width: 72, height: 72)
                        Text(makeInitials(member.name))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.purple)
                    }
                    HStack(spacing: 8) {
                        Text(member.name)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        if member.isCreator {
                            Text("Creator")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.brandOrange).clipShape(Capsule())
                        }
                    }
                }
                .padding(.top, 20)

                VStack(spacing: 12) {
                    if isLoadingFriend {
                        ProgressView()
                    } else if !isFriend {
                        Button {
                            guard let uid = currentUserId else { return }
                            Task {
                                try? await FriendService.shared.sendRequest(from: uid, to: member.id)
                                requestSent = true
                            }
                        } label: {
                            Label(requestSent ? "Request Sent" : "Add Friend", systemImage: requestSent ? "checkmark" : "person.badge.plus")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(requestSent ? .secondary : .white)
                                .frame(maxWidth: .infinity).frame(height: 48)
                                .background(requestSent ? Color(.systemGray4) : Color.blue)
                                .cornerRadius(12)
                        }
                        .disabled(requestSent)
                        .padding(.horizontal, 24)
                    }

                    Button {
                        showReportOptions = true
                    } label: {
                        Label(alreadyReported ? "Already Reported" : "Report User", systemImage: "exclamationmark.triangle")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(alreadyReported ? .secondary : .red)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    .disabled(alreadyReported)
                    .padding(.horizontal, 24)

                    if reportSubmitted {
                        Text("Report submitted. Thank you.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Report \(member.name)", isPresented: $showReportOptions, titleVisibility: .visible) {
                Button("Spam", role: .destructive) { submitReport("Spam") }
                Button("Harassment", role: .destructive) { submitReport("Harassment") }
                Button("Inappropriate Content", role: .destructive) { submitReport("Inappropriate Content") }
                Button("Other", role: .destructive) { submitReport("Other") }
                Button("Cancel", role: .cancel) {}
            }
        }
        .onAppear {
            guard let uid = currentUserId else { isLoadingFriend = false; return }
            Task {
                let friends = (try? await FriendService.shared.fetchFriends(userId: uid)) ?? []
                isFriend = friends.contains(where: { $0.id == member.id })
                alreadyReported = (try? await ReportService.shared.hasAlreadyReported(reporterId: uid, reportedId: member.id)) ?? false
                isLoadingFriend = false
            }
        }
    }

    private func submitReport(_ reason: String) {
        guard let uid = currentUserId else { return }
        Task {
            try? await ReportService.shared.reportUser(reporterId: uid, reportedId: member.id, reason: reason)
            alreadyReported = true
            reportSubmitted = true
        }
    }
}

// MARK: - Add Group Member Sheet

private struct AddGroupMemberSheet: View {
    let group: GroupChatRow
    let memberIdsInGroup: Set<UUID>

    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [UserSearchResult] = []
    @State private var isLoading: Bool = true

    private var userId: UUID? {
        UUID(uuidString: appState.currentUser?.id ?? "")
    }

    private var availableFriends: [UserSearchResult] {
        friends.filter { !memberIdsInGroup.contains($0.id) }
    }

    var body: some View {
        NavigationView {
            List {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if availableFriends.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "person.3")
                            .font(.system(size: 32)).foregroundColor(.gray.opacity(0.3))
                        Text("All your friends are already in this group")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(availableFriends) { friend in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.purple.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    Text(makeInitials(friend.name ?? "?"))
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(.purple)
                                }
                                Text(friend.name ?? "Unknown")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                Spacer()
                                Button("Add") { addMember(friend.id) }
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.brandLime)
                            }
                        }
                    } footer: {
                        Text("Added members who aren't friends with everyone in the group can add each other from settings.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
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
            } catch {
                print("Load friends error: \(error)")
            }
            isLoading = false
        }
    }

    private func addMember(_ friendId: UUID) {
        Task {
            do {
                try await GroupChatService.shared.addMember(groupId: group.id, userId: friendId)
                dismiss()
            } catch {
                print("Add member error: \(error)")
            }
        }
    }

    private func makeInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let f = parts.first?.prefix(1) ?? ""
        let l = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(f)\(l)".uppercased()
    }
}
