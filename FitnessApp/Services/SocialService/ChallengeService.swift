//
//  ChallengeService.swift
//  SimplyFit
//
//  Supabase service for challenges + challenge_participants tables.
//  Handles creating challenges, joining, updating progress, and fetching.
//

import Foundation
import Supabase

// MARK: - Codable Rows

struct ChallengeRow: Codable, Identifiable {
    let id: UUID
    let creator_id: UUID
    let title: String
    let goal_type: String
    let target_value: Int
    let start_date: String
    let end_date: String
    let created_at: Date?
}

struct ChallengeInsert: Codable {
    let creator_id: UUID
    let title: String
    let goal_type: String
    let target_value: Int
    let start_date: String
    let end_date: String
}

struct ParticipantRow: Codable, Identifiable {
    let id: UUID
    let challenge_id: UUID
    let user_id: UUID
    let current_value: Int
    let joined_at: Date?
}

struct ParticipantInsert: Codable {
    let challenge_id: UUID
    let user_id: UUID
}

struct ParticipantProgressUpdate: Codable {
    let current_value: Int
}

// MARK: - ChallengeService

final class ChallengeService {
    static let shared = ChallengeService()
    private init() {}

    // MARK: - Create a challenge (creator auto-joins)
    func createChallenge(creatorId: UUID, title: String, goalType: String, targetValue: Int, durationDays: Int) async throws -> ChallengeRow {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let startDate = formatter.string(from: Date())
        let endDate = formatter.string(from: Calendar.current.date(byAdding: .day, value: durationDays, to: Date()) ?? Date())

        let insert = ChallengeInsert(
            creator_id: creatorId,
            title: title,
            goal_type: goalType,
            target_value: targetValue,
            start_date: startDate,
            end_date: endDate
        )

        let challenge: ChallengeRow = try await supabase
            .from("challenges")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value

        // Auto-join the creator as a participant
        try await joinChallenge(challengeId: challenge.id, userId: creatorId)

        return challenge
    }

    // MARK: - Join a challenge
    func joinChallenge(challengeId: UUID, userId: UUID) async throws {
        let insert = ParticipantInsert(challenge_id: challengeId, user_id: userId)
        try await supabase
            .from("challenge_participants")
            .insert(insert)
            .execute()
    }

    // MARK: - Leave a challenge
    func leaveChallenge(challengeId: UUID, userId: UUID) async throws {
        try await supabase
            .from("challenge_participants")
            .delete()
            .eq("challenge_id", value: challengeId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Update progress
    func updateProgress(challengeId: UUID, userId: UUID, newValue: Int) async throws {
        try await supabase
            .from("challenge_participants")
            .update(ParticipantProgressUpdate(current_value: newValue))
            .eq("challenge_id", value: challengeId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Fetch all challenges
    func fetchAllChallenges() async throws -> [ChallengeRow] {
        let rows: [ChallengeRow] = try await supabase
            .from("challenges")
            .select()
            .order("end_date", ascending: true)
            .execute()
            .value
        return rows
    }

    // MARK: - Fetch challenges the user is in
    func fetchMyChallenges(userId: UUID) async throws -> [ChallengeRow] {
        // Get challenge IDs the user participates in
        let participants: [ParticipantRow] = try await supabase
            .from("challenge_participants")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let challengeIds = participants.map { $0.challenge_id.uuidString }
        guard !challengeIds.isEmpty else { return [] }

        let challenges: [ChallengeRow] = try await supabase
            .from("challenges")
            .select()
            .in("id", values: challengeIds)
            .order("end_date", ascending: true)
            .execute()
            .value

        return challenges
    }

    // MARK: - Fetch participants for a challenge
    func fetchParticipants(challengeId: UUID) async throws -> [ParticipantRow] {
        let rows: [ParticipantRow] = try await supabase
            .from("challenge_participants")
            .select()
            .eq("challenge_id", value: challengeId.uuidString)
            .execute()
            .value
        return rows
    }

    // MARK: - Fetch user's progress in a specific challenge
    func fetchMyProgress(challengeId: UUID, userId: UUID) async throws -> ParticipantRow? {
        let rows: [ParticipantRow] = try await supabase
            .from("challenge_participants")
            .select()
            .eq("challenge_id", value: challengeId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return rows.first
    }

    // MARK: - Delete a challenge (creator only, cascades participants)
    func deleteChallenge(challengeId: UUID) async throws {
        try await supabase
            .from("challenges")
            .delete()
            .eq("id", value: challengeId.uuidString)
            .execute()
    }
}
