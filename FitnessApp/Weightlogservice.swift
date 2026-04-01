//
//  WeightLogService.swift
//  FitnessApp
//

 
import Foundation
 
struct WeightLogService {
    static let shared = WeightLogService()
    private init() {}
 
    private var baseURL: String {
        SupabaseConfig.url + "/rest/v1/weight_logs"
    }

 
    private func makeRequest(
        path: String = "",
        method: String,
        body: Data? = nil
    ) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw URLError(.badURL)
        }
        var request        = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(
            "Bearer \(AuthService.shared.accessToken ?? "")",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json",     forHTTPHeaderField: "Content-Type")
        request.httpBody   = body
        return request
    }
 
    // ── Fetch all entries for the current user ────────────────────────────────
 
    func fetchEntries() async throws -> [WeightEntry] {
        let request = try makeRequest(
            path: "?order=logged_at.asc",
            method: "GET"
        )
 
        let (data, response) = try await URLSession.shared.data(for: request)
 
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
 
        let decoder                  = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let rows = try decoder.decode([WeightLogRow].self, from: data)
 
        return rows.map {
            WeightEntry(id: $0.id, date: $0.logged_at, weightLbs: $0.weight_lbs)
        }
    }
 
    func insertEntry(weightLbs: Double) async throws {
        let body = try JSONEncoder().encode(["weight_lbs": weightLbs])
 
        var request = try makeRequest(method: "POST", body: body)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
 
        let (_, response) = try await URLSession.shared.data(for: request)
 
        guard (response as? HTTPURLResponse)?.statusCode == 201 else {
            throw URLError(.badServerResponse)
        }
    }
}

 
private struct WeightLogRow: Codable {
    let id         : UUID
    let weight_lbs : Double
    let logged_at  : Date
}
public struct WeightEntry: Identifiable, Codable, Equatable {
    public let id: UUID
    public let date: Date
    public let weightLbs: Double

    public init(id: UUID, date: Date, weightLbs: Double) {
        self.id = id
        self.date = date
        self.weightLbs = weightLbs
    }
}

