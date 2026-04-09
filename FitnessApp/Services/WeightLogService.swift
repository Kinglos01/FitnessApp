//
//  WeightLogService.swift
//  FitnessApp
//

import Foundation
import Supabase

final class WeightLogService {
    static let shared = WeightLogService()
    private init() {}

    // MARK: - Log weight (appends to profiles.weight_history + updates weight_lbs)
    func logWeight(userId: String, weightLbs: Double) async throws {
        try await ProfileService.shared.appendWeightEntry(userId: userId, weightLbs: weightLbs)
    }

    // MARK: - Fetch all weight entries from profiles.weight_history
    func fetchEntries(userId: String) async throws -> [WeightEntry] {
        let history = try await ProfileService.shared.fetchWeightHistory(userId: userId)
        return history.map {
            WeightEntry(id: $0.id, date: $0.date, weightLbs: $0.weight_lbs)
        }
    }
}
