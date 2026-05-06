//
//  BlockService.swift
//  SimplyFit
//
//  Supabase service for the blocks table.
//  Handles blocking/unblocking users and querying block status.
//

import Foundation
import Supabase

// MARK: - Codable Rows

struct BlockRow: Codable, Identifiable {
    let id: UUID
    let blocker_id: UUID
    let blocked_id: UUID
    let created_at: Date?
}

struct BlockInsert: Codable {
    let blocker_id: UUID
    let blocked_id: UUID
}

// MARK: - BlockService

final class BlockService {
    static let shared = BlockService()
    private init() {}

    // MARK: - Block User

    func blockUser(blockerId: UUID, blockedId: UUID) async throws {
        // Insert block row
        let insert = BlockInsert(blocker_id: blockerId, blocked_id: blockedId)
        try await supabase
            .from("blocks")
            .insert(insert)
            .execute()

        // Remove friendship if one exists (either direction)
        let friendships: [FriendshipRow] = try await supabase
            .from("friendships")
            .select()
            .or("and(requester_id.eq.\(blockerId.uuidString),addressee_id.eq.\(blockedId.uuidString)),and(requester_id.eq.\(blockedId.uuidString),addressee_id.eq.\(blockerId.uuidString))")
            .execute()
            .value

        for row in friendships {
            try await supabase
                .from("friendships")
                .delete()
                .eq("id", value: row.id.uuidString)
                .execute()
        }

        // Delete DMs between the two users (both directions)
        try await supabase
            .from("direct_messages")
            .delete()
            .or("and(sender_id.eq.\(blockerId.uuidString),receiver_id.eq.\(blockedId.uuidString)),and(sender_id.eq.\(blockedId.uuidString),receiver_id.eq.\(blockerId.uuidString))")
            .execute()
    }

    // MARK: - Unblock User

    func unblockUser(blockerId: UUID, blockedId: UUID) async throws {
        try await supabase
            .from("blocks")
            .delete()
            .eq("blocker_id", value: blockerId.uuidString)
            .eq("blocked_id", value: blockedId.uuidString)
            .execute()
    }

    // MARK: - Fetch Blocked IDs

    func fetchBlockedIds(userId: UUID) async throws -> [UUID] {
        let rows: [BlockRow] = try await supabase
            .from("blocks")
            .select()
            .eq("blocker_id", value: userId.uuidString)
            .execute()
            .value
        return rows.map { $0.blocked_id }
    }

    // MARK: - Is Blocked

    func isBlocked(blockerId: UUID, blockedId: UUID) async throws -> Bool {
        let rows: [BlockRow] = try await supabase
            .from("blocks")
            .select()
            .eq("blocker_id", value: blockerId.uuidString)
            .eq("blocked_id", value: blockedId.uuidString)
            .execute()
            .value
        return !rows.isEmpty
    }
}
