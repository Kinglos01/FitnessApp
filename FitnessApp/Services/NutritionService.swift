//
//  NutritionService.swift
//  SimplyFit
//

import Foundation
import Observation

// MARK: - Models

struct FoodSearchResponse: Codable {
    let foods: [FoodItem]
}

struct FoodItem: Codable, Identifiable {
    let fdcId: Int
    let description: String
    let foodNutrients: [FoodNutrient]

    var id: Int { fdcId }

    var calories: Double {
        foodNutrients.first(where: { $0.nutrientId == 1008 })?.value ?? 0
    }
    var protein: Double {
        foodNutrients.first(where: { $0.nutrientId == 1003 })?.value ?? 0
    }
    var carbs: Double {
        foodNutrients.first(where: { $0.nutrientId == 1005 })?.value ?? 0
    }
    var fat: Double {
        foodNutrients.first(where: { $0.nutrientId == 1004 })?.value ?? 0
    }
}

struct FoodNutrient: Codable {
    let nutrientId: Int
    let value: Double?
}

// MARK: - Service

@Observable
class NutritionService {
    var results: [FoodItem] = []

    private let apiKey = "jlo70WgRLc1hM2DgZiBg4IuSKHb7G4I5o1NVMOat"
    private let baseURL = "https://api.nal.usda.gov/fdc/v1"

    func searchFoods(query: String) async throws -> [FoodItem] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)/foods/search?query=\(encoded)&api_key=\(apiKey)&pageSize=20"

        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(FoodSearchResponse.self, from: data)
        return response.foods
    }
}
