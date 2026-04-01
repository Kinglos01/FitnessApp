//
//  WeightLogService.swift
//  FitnessApp
//
//  Created by Carlos Berio on 4/1/26.
//
//


import Foundation
import Supabase

final class WeightLogService {
    static let shared = WeightLogService()
    private init() {}

    // MARK: - Insert into weight_logs + update profiles.weight_lbs
    func logWeight(userId: String, weightLbs: Double) async throws {
        // 1. Insert into weight_logs table
        let entry = WeightLogInsert(user_id: userId, weight_lbs: weightLbs)
        try await supabase
            .from("weight_logs")
            .insert(entry)
            .execute()

        // 2. Update weight_lbs on the profiles table so it stays in sync
        try await supabase
            .from("profiles")
            .update(["weight_lbs": weightLbs])
            .eq("id", value: userId)
            .execute()
    }

    // MARK: - Fetch all weight log entries for user
    func fetchEntries(userId: String) async throws -> [WeightEntry] {
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
}

// MARK: - Codable helpers

private struct WeightLogInsert: Codable {
    let user_id: String
    let weight_lbs: Double
}

private struct WeightLogRow: Codable {
    let id: UUID
    let user_id: String
    let weight_lbs: Double
    let logged_at: Date
}
