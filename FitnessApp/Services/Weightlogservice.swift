//
//  WeightLogService.swift
//  FitnessApp
//

import Foundation
import Supabase

struct WeightLogService {
    static let shared = WeightLogService()
    private init() {}

    // ── Fetch all entries for the current user ──

    func fetchEntries() async throws -> [WeightEntry] {
        let userId = try await supabase.auth.session.user.id

        let rows: [WeightLogRow] = try await supabase
            .from("weight_logs")
            .select()
            .eq("user_id", value: userId)
            .order("logged_at", ascending: true)
            .execute()
            .value

        return rows.map {
            WeightEntry(id: $0.id, date: $0.logged_at, weightLbs: $0.weight_lbs)
        }
    }

    // ── Delete a weight entry ──

    func deleteEntry(id: UUID) async throws {
        let userId = try await supabase.auth.session.user.id

        try await supabase
            .from("weight_logs")
            .delete()
            .eq("id", value: id.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    // ── Insert a new weight entry ──

    func insertEntry(weightLbs: Double) async throws {
        let userId = try await supabase.auth.session.user.id

        try await supabase
            .from("weight_logs")
            .insert(InsertPayload(user_id: userId, weight_lbs: weightLbs))
            .execute()
    }
}

// MARK: - Database Row Models

private struct WeightLogRow: Codable {
    let id: UUID
    let user_id: UUID
    let weight_lbs: Double
    let logged_at: Date
}

private struct InsertPayload: Codable {
    let user_id: UUID
    let weight_lbs: Double
}
