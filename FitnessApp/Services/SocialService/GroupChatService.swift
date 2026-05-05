//
//  GroupChatService.swift
//  SimplyFit
//
//  Supabase service for group_chats, group_chat_members,
//  and group_chat_messages tables.
//

import Foundation
import Supabase

// MARK: - Codable Rows

struct GroupChatRow: Codable, Identifiable {
    let id: UUID
    let name: String
    let creator_id: UUID
    let created_at: Date?
}

struct GroupChatMemberRow: Codable, Identifiable {
    let id: UUID
    let group_id: UUID
    let user_id: UUID
    let joined_at: Date?
}

struct GroupChatMessageRow: Codable, Identifiable {
    let id: UUID
    let group_id: UUID
    let sender_id: UUID
    let body: String
    let created_at: Date?
}

struct GroupChatInsert: Codable {
    let name: String
    let creator_id: UUID
}

struct GroupChatMemberInsert: Codable {
    let group_id: UUID
    let user_id: UUID
}

struct GroupChatMessageInsert: Codable {
    let group_id: UUID
    let sender_id: UUID
    let body: String
}

private struct GroupChatNameUpdate: Codable {
    let name: String
}

// MARK: - GroupChatService

final class GroupChatService {
    static let shared = GroupChatService()
    private init() {}

    // MARK: - Create Group

    func createGroup(creatorId: UUID, name: String, memberIds: [UUID]) async throws -> GroupChatRow {
        let insert = GroupChatInsert(name: name, creator_id: creatorId)
        let group: GroupChatRow = try await supabase
            .from("group_chats")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        // Add creator as member
        try await supabase
            .from("group_chat_members")
            .insert(GroupChatMemberInsert(group_id: group.id, user_id: creatorId))
            .execute()

        // Add each additional member
        for memberId in memberIds {
            try await supabase
                .from("group_chat_members")
                .insert(GroupChatMemberInsert(group_id: group.id, user_id: memberId))
                .execute()
        }

        return group
    }

    // MARK: - Fetch My Groups

    func fetchMyGroups(userId: UUID) async throws -> [GroupChatRow] {
        let memberRows: [GroupChatMemberRow] = try await supabase
            .from("group_chat_members")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let groupIds = memberRows.map { $0.group_id }
        guard !groupIds.isEmpty else { return [] }

        let groups: [GroupChatRow] = try await supabase
            .from("group_chats")
            .select()
            .in("id", values: groupIds.map { $0.uuidString })
            .order("created_at", ascending: false)
            .execute()
            .value

        return groups
    }

    // MARK: - Fetch Members

    func fetchMembers(groupId: UUID) async throws -> [GroupChatMemberRow] {
        try await supabase
            .from("group_chat_members")
            .select()
            .eq("group_id", value: groupId.uuidString)
            .execute()
            .value
    }

    // MARK: - Add Member

    func addMember(groupId: UUID, userId: UUID) async throws {
        let insert = GroupChatMemberInsert(group_id: groupId, user_id: userId)
        try await supabase
            .from("group_chat_members")
            .insert(insert)
            .execute()
    }

    // MARK: - Remove Member

    func removeMember(groupId: UUID, userId: UUID) async throws {
        try await supabase
            .from("group_chat_members")
            .delete()
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Rename Group

    func renameGroup(groupId: UUID, newName: String) async throws {
        try await supabase
            .from("group_chats")
            .update(GroupChatNameUpdate(name: newName))
            .eq("id", value: groupId.uuidString)
            .execute()
    }

    // MARK: - Delete Group

    func deleteGroup(groupId: UUID) async throws {
        try await supabase
            .from("group_chats")
            .delete()
            .eq("id", value: groupId.uuidString)
            .execute()
    }

    // MARK: - Fetch Messages

    func fetchMessages(groupId: UUID) async throws -> [GroupChatMessageRow] {
        try await supabase
            .from("group_chat_messages")
            .select()
            .eq("group_id", value: groupId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    // MARK: - Send Message

    func sendMessage(groupId: UUID, senderId: UUID, body: String) async throws {
        let insert = GroupChatMessageInsert(group_id: groupId, sender_id: senderId, body: body)
        try await supabase
            .from("group_chat_messages")
            .insert(insert)
            .execute()
    }

    // MARK: - Fetch Latest Message

    func fetchLatestMessage(groupId: UUID) async throws -> GroupChatMessageRow? {
        let rows: [GroupChatMessageRow] = try await supabase
            .from("group_chat_messages")
            .select()
            .eq("group_id", value: groupId.uuidString)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }
}
