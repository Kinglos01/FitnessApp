//
//  WeightLogService.swift
//  SimplyFit
//

import Foundation
import Supabase

final class WeightLogService {
    static let shared = WeightLogService()
    private init() {}

    // MARK: - Log weight (appends to profiles.weight_history + updates weight_lbs)
    func logWeight(userId: String, weightLbs: Double) async {
        do {
            try await ProfileService.shared.appendWeightEntry(userId: userId, weightLbs: weightLbs)
        } catch {
            print("⚠️ Weight log error: \(error)")
        }
    }

    // MARK: - Delete a single weight entry from profiles.weight_history
    func deleteEntry(userId: String, date: Date, weightLbs: Double) async {
        do {
            var history = try await ProfileService.shared.fetchWeightHistory(userId: userId)
            if let idx = history.firstIndex(where: {
                abs($0.date.timeIntervalSince(date)) < 1 && abs($0.weight_lbs - weightLbs) < 0.01
            }) {
                history.remove(at: idx)
            }
            try await ProfileService.shared.updateWeightHistory(userId: userId, history: history)
        } catch {
            print("⚠️ Weight delete error: \(error)")
        }
    }

    // MARK: - Fetch all weight entries from profiles.weight_history
    func fetchEntries(userId: String) async -> [WeightEntry] {
        do {
            let history = try await ProfileService.shared.fetchWeightHistory(userId: userId)
            return history.map {
                WeightEntry(date: $0.date, weightLbs: $0.weight_lbs)
            }
        } catch {
            print("⚠️ Weight log decode error: \(error)")
            return []
        }
    }
}
