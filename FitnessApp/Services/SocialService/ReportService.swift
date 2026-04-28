//
//  ReportService.swift
//  FitnessApp
//
//  Supabase service for the reports table.
//  Handles reporting users and auto-suspension after threshold.
//

import Foundation
import Supabase

// MARK: - Codable Rows

struct ReportRow: Codable, Identifiable {
    let id: UUID
    let reporter_id: UUID
    let reported_id: UUID
    let reason: String
    let created_at: Date?
}

struct ReportInsert: Codable {
    let reporter_id: UUID
    let reported_id: UUID
    let reason: String
}

// MARK: - ReportService

final class ReportService {
    static let shared = ReportService()
    private init() {}

    private struct ProfileReportFields: Codable {
        let report_count: Int?
    }

    private struct ProfileReportUpdate: Codable {
        let report_count: Int
        var is_suspended: Bool? = nil
    }

    // MARK: - Report User

    func reportUser(reporterId: UUID, reportedId: UUID, reason: String) async throws {
        // Insert report row
        let insert = ReportInsert(reporter_id: reporterId, reported_id: reportedId, reason: reason)
        try await supabase
            .from("reports")
            .insert(insert)
            .execute()

        // Fetch current report_count
        let profile: ProfileReportFields = try await supabase
            .from("profiles")
            .select("report_count")
            .eq("id", value: reportedId.uuidString)
            .single()
            .execute()
            .value

        let currentCount = profile.report_count ?? 0
        let newCount = currentCount + 1

        // Update report_count and suspend if >= 3
        var update = ProfileReportUpdate(report_count: newCount)
        if newCount >= 3 {
            update.is_suspended = true
        }

        try await supabase
            .from("profiles")
            .update(update)
            .eq("id", value: reportedId.uuidString)
            .execute()
    }

    // MARK: - Has Already Reported

    func hasAlreadyReported(reporterId: UUID, reportedId: UUID) async throws -> Bool {
        let rows: [ReportRow] = try await supabase
            .from("reports")
            .select()
            .eq("reporter_id", value: reporterId.uuidString)
            .eq("reported_id", value: reportedId.uuidString)
            .execute()
            .value
        return !rows.isEmpty
    }
}
