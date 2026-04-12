//
//  FriendService.swift
//  FitnessApp
//
//  Supabase service for the friendships table.
//  Handles sending/accepting/declining friend requests,
//  fetching the friends list, and searching users.
//

import Foundation
import Supabase

// MARK: - Codable Rows

struct FriendshipRow: Codable, Identifiable {
    let id: UUID
    let requester_id: UUID
    let addressee_id: UUID
    let status: String
    let created_at: Date?
}

struct FriendshipInsert: Codable {
    let requester_id: UUID
    let addressee_id: UUID
}

struct FriendshipStatusUpdate: Codable {
    let status: String
}

/// Lightweight profile info returned when searching users or fetching friends
struct UserSearchResult: Codable, Identifiable {
    let id: UUID
    let name: String?
    let email: String?
}

// MARK: - FriendService

final class FriendService {
    static let shared = FriendService()
    private init() {}

    // MARK: - Send friend request
    func sendRequest(from requesterId: UUID, to addresseeId: UUID) async throws {
        let insert = FriendshipInsert(requester_id: requesterId, addressee_id: addresseeId)
        try await supabase
            .from("friendships")
            .insert(insert)
            .execute()
    }

    // MARK: - Accept friend request
    func acceptRequest(friendshipId: UUID) async throws {
        try await supabase
            .from("friendships")
            .update(FriendshipStatusUpdate(status: "accepted"))
            .eq("id", value: friendshipId.uuidString)
            .execute()
    }

    // MARK: - Decline friend request
    func declineRequest(friendshipId: UUID) async throws {
        try await supabase
            .from("friendships")
            .update(FriendshipStatusUpdate(status: "declined"))
            .eq("id", value: friendshipId.uuidString)
            .execute()
    }

    // MARK: - Remove friend (delete the row)
    func removeFriend(friendshipId: UUID) async throws {
        try await supabase
            .from("friendships")
            .delete()
            .eq("id", value: friendshipId.uuidString)
            .execute()
    }

    // MARK: - Fetch accepted friends (returns profile info)
    func fetchFriends(userId: UUID) async throws -> [UserSearchResult] {
        // Get all accepted friendships where user is either side
        let rows: [FriendshipRow] = try await supabase
            .from("friendships")
            .select()
            .eq("status", value: "accepted")
            .execute()
            .value

        // Collect the friend IDs (the other person in each friendship)
        let friendIds: [UUID] = rows.compactMap { row in
            if row.requester_id == userId { return row.addressee_id }
            if row.addressee_id == userId { return row.requester_id }
            return nil
        }

        guard !friendIds.isEmpty else { return [] }

        // Fetch profile info for each friend
        let idStrings = friendIds.map { $0.uuidString }
        let profiles: [UserSearchResult] = try await supabase
            .from("profiles")
            .select("id, name, email")
            .in("id", values: idStrings)
            .execute()
            .value

        return profiles
    }

    // MARK: - Fetch pending requests received (incoming)
    func fetchPendingRequests(userId: UUID) async throws -> [FriendshipRow] {
        let rows: [FriendshipRow] = try await supabase
            .from("friendships")
            .select()
            .eq("addressee_id", value: userId.uuidString)
            .eq("status", value: "pending")
            .execute()
            .value
        return rows
    }

    // MARK: - Fetch pending requests sent (outgoing)
    func fetchSentRequests(userId: UUID) async throws -> [FriendshipRow] {
        let rows: [FriendshipRow] = try await supabase
            .from("friendships")
            .select()
            .eq("requester_id", value: userId.uuidString)
            .eq("status", value: "pending")
            .execute()
            .value
        return rows
    }

    // MARK: - Search users by name (for adding friends)
    func searchUsers(query: String) async throws -> [UserSearchResult] {
        let results: [UserSearchResult] = try await supabase
            .from("profiles")
            .select("id, name, email")
            .ilike("name", pattern: "%\(query)%")
            .limit(20)
            .execute()
            .value
        return results
    }
}
