//
//  CommunityService.swift
//  SimplyFit
//
//  Supabase service for communities, community_members,
//  and community_messages tables.
//

import Foundation
import Supabase

// MARK: - Codable Rows

struct CommunityRecord: Codable, Identifiable {
    let id: UUID
    let creator_id: UUID
    let name: String
    let description: String?
    let member_count: Int
    let created_at: Date?
}

struct CommunityInsert: Codable {
    let creator_id: UUID
    let name: String
    let description: String
}

struct CommunityMemberRow: Codable, Identifiable {
    let id: UUID
    let community_id: UUID
    let user_id: UUID
    let joined_at: Date?
}

struct CommunityMemberInsert: Codable {
    let community_id: UUID
    let user_id: UUID
}

struct CommunityMessageRow: Codable, Identifiable {
    let id: UUID
    let community_id: UUID
    let sender_id: UUID
    let body: String
    let created_at: Date?
}

struct CommunityMessageInsert: Codable {
    let community_id: UUID
    let sender_id: UUID
    let body: String
}

// MARK: - CommunityService

final class CommunityService {
    static let shared = CommunityService()
    private init() {}

    // MARK: - Create community (creator auto-joins)
    func createCommunity(creatorId: UUID, name: String, description: String) async throws -> CommunityRecord {
        let insert = CommunityInsert(creator_id: creatorId, name: name, description: description)

        let community: CommunityRecord = try await supabase
            .from("communities")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        // Auto-join the creator (this also syncs member_count)
        let memberInsert = CommunityMemberInsert(community_id: community.id, user_id: creatorId)
        try await supabase
            .from("community_members")
            .insert(memberInsert)
            .execute()
        try await syncMemberCount(communityId: community.id)

        return community
    }

    // MARK: - Fetch all communities (for discover)
    func fetchAllCommunities() async throws -> [CommunityRecord] {
        let rows: [CommunityRecord] = try await supabase
            .from("communities")
            .select()
            .order("member_count", ascending: false)
            .execute()
            .value
        return rows
    }

    // MARK: - Fetch communities the user belongs to
    func fetchMyCommunities(userId: UUID) async throws -> [CommunityRecord] {
        let memberships: [CommunityMemberRow] = try await supabase
            .from("community_members")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let communityIds = memberships.map { $0.community_id.uuidString }
        guard !communityIds.isEmpty else { return [] }

        let communities: [CommunityRecord] = try await supabase
            .from("communities")
            .select()
            .in("id", values: communityIds)
            .order("name", ascending: true)
            .execute()
            .value

        return communities
    }

    // MARK: - Join community
    func joinCommunity(communityId: UUID, userId: UUID) async throws {
        let insert = CommunityMemberInsert(community_id: communityId, user_id: userId)
        try await supabase
            .from("community_members")
            .insert(insert)
            .execute()

        try await syncMemberCount(communityId: communityId)
    }

    // MARK: - Leave community
    func leaveCommunity(communityId: UUID, userId: UUID) async throws {
        try await supabase
            .from("community_members")
            .delete()
            .eq("community_id", value: communityId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()

        try await syncMemberCount(communityId: communityId)
    }

    // MARK: - Sync member_count from actual rows
    private func syncMemberCount(communityId: UUID) async throws {
        let members: [CommunityMemberRow] = try await supabase
            .from("community_members")
            .select()
            .eq("community_id", value: communityId.uuidString)
            .execute()
            .value

        try await supabase
            .from("communities")
            .update(["member_count": members.count])
            .eq("id", value: communityId.uuidString)
            .execute()
    }

    // MARK: - Fetch members of a community
    func fetchMembers(communityId: UUID) async throws -> [UserSearchResult] {
        let members: [CommunityMemberRow] = try await supabase
            .from("community_members")
            .select()
            .eq("community_id", value: communityId.uuidString)
            .execute()
            .value

        guard !members.isEmpty else { return [] }

        let idStrings = members.map { $0.user_id.uuidString }
        let profiles: [UserSearchResult] = try await supabase
            .from("profiles")
            .select("id, name, email")
            .in("id", values: idStrings)
            .execute()
            .value

        return profiles
    }

    // MARK: - Fetch messages for a community
    func fetchMessages(communityId: UUID, limit: Int = 50) async throws -> [CommunityMessageRow] {
        let rows: [CommunityMessageRow] = try await supabase
            .from("community_messages")
            .select()
            .eq("community_id", value: communityId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows.reversed()  // Oldest first for chat display
    }

    // MARK: - Send message to community
    func sendMessage(communityId: UUID, senderId: UUID, body: String) async throws {
        let insert = CommunityMessageInsert(community_id: communityId, sender_id: senderId, body: body)
        try await supabase
            .from("community_messages")
            .insert(insert)
            .execute()
    }

    // MARK: - Delete community (creator only)
    func deleteCommunity(communityId: UUID) async throws {
        try await supabase
            .from("communities")
            .delete()
            .eq("id", value: communityId.uuidString)
            .execute()
    }
}
