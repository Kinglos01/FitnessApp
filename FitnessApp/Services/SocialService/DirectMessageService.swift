//
//  DirectMessageService.swift
//  SimplyFit
//
//  Supabase service for the direct_messages table.
//  Handles sending DMs, fetching conversation threads,
//  and marking messages as read.
//

import Foundation
import Supabase

// MARK: - Codable Rows

struct DirectMessageRow: Codable, Identifiable {
    let id: UUID
    let sender_id: UUID
    let receiver_id: UUID
    let body: String
    let is_read: Bool
    let created_at: Date?
}

struct DirectMessageInsert: Codable {
    let sender_id: UUID
    let receiver_id: UUID
    let body: String
}

struct DirectMessageReadUpdate: Codable {
    let is_read: Bool
}

/// A conversation preview for the messages list
struct ConversationPreview: Identifiable {
    let id: UUID           // the other person's user ID
    let friendName: String
    let lastMessage: String
    let lastMessageDate: Date
    let unreadCount: Int
}

// MARK: - DirectMessageService

final class DirectMessageService {
    static let shared = DirectMessageService()
    private init() {}

    // MARK: - Send a DM
    func sendMessage(senderId: UUID, receiverId: UUID, body: String) async throws {
        let insert = DirectMessageInsert(sender_id: senderId, receiver_id: receiverId, body: body)
        try await supabase
            .from("direct_messages")
            .insert(insert)
            .execute()
    }

    // MARK: - Fetch conversation thread between two users
    func fetchThread(userId: UUID, friendId: UUID, limit: Int = 50) async throws -> [DirectMessageRow] {
        // Messages where user is sender and friend is receiver, or vice versa
        let sent: [DirectMessageRow] = try await supabase
            .from("direct_messages")
            .select()
            .eq("sender_id", value: userId.uuidString)
            .eq("receiver_id", value: friendId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        let received: [DirectMessageRow] = try await supabase
            .from("direct_messages")
            .select()
            .eq("sender_id", value: friendId.uuidString)
            .eq("receiver_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        // Merge and sort by date (oldest first for chat display)
        let all = (sent + received).sorted { ($0.created_at ?? .distantPast) < ($1.created_at ?? .distantPast) }
        return all
    }

    // MARK: - Fetch all DMs for a user (for building conversation list)
    func fetchAllMessages(userId: UUID) async throws -> [DirectMessageRow] {
        let rows: [DirectMessageRow] = try await supabase
            .from("direct_messages")
            .select()
            .or("sender_id.eq.\(userId.uuidString),receiver_id.eq.\(userId.uuidString)")
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows
    }

    // MARK: - Build conversation previews from all messages
    func fetchConversationPreviews(userId: UUID, friendProfiles: [UserSearchResult]) async throws -> [ConversationPreview] {
        let allMessages = try await fetchAllMessages(userId: userId)

        // Group by the other person's ID
        var grouped: [UUID: [DirectMessageRow]] = [:]
        for msg in allMessages {
            let otherId = msg.sender_id == userId ? msg.receiver_id : msg.sender_id
            grouped[otherId, default: []].append(msg)
        }

        // Build previews
        var previews: [ConversationPreview] = []
        for (friendId, messages) in grouped {
            guard let latest = messages.first else { continue }  // already sorted desc
            let name = friendProfiles.first(where: { $0.id == friendId })?.name ?? "Unknown"
            let unread = messages.filter { $0.receiver_id == userId && !$0.is_read }.count

            previews.append(ConversationPreview(
                id: friendId,
                friendName: name,
                lastMessage: latest.body,
                lastMessageDate: latest.created_at ?? Date(),
                unreadCount: unread
            ))
        }

        return previews.sorted { $0.lastMessageDate > $1.lastMessageDate }
    }

    // MARK: - Mark messages as read (all from a specific sender)
    func markAsRead(from senderId: UUID, to receiverId: UUID) async throws {
        try await supabase
            .from("direct_messages")
            .update(DirectMessageReadUpdate(is_read: true))
            .eq("sender_id", value: senderId.uuidString)
            .eq("receiver_id", value: receiverId.uuidString)
            .eq("is_read", value: false)
            .execute()
    }

    // MARK: - Delete entire conversation between two users
    func deleteConversation(userId: UUID, friendId: UUID) async throws {
        // Delete messages sent by user to friend
        try await supabase
            .from("direct_messages")
            .delete()
            .eq("sender_id", value: userId.uuidString)
            .eq("receiver_id", value: friendId.uuidString)
            .execute()

        // Delete messages sent by friend to user
        try await supabase
            .from("direct_messages")
            .delete()
            .eq("sender_id", value: friendId.uuidString)
            .eq("receiver_id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Get unread count for a user
    func unreadCount(userId: UUID) async throws -> Int {
        let rows: [DirectMessageRow] = try await supabase
            .from("direct_messages")
            .select()
            .eq("receiver_id", value: userId.uuidString)
            .eq("is_read", value: false)
            .execute()
            .value
        return rows.count
    }
}
