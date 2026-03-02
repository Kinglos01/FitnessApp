//
//  ExcerciseService.swift
//  FitnessApp
//
//  Created by Nelson Mojica on 2/19/26.
//

import Foundation

// MARK: - Protocol
protocol ExerciseServiceProtocol {
    func fetchTargetList(completion: @escaping (Result<[String], Error>) -> Void)
    func fetchExercises(for target: String,
                        completion: @escaping (Result<[Exercise], Error>) -> Void)
    func fetchExercisesByBodyPart(for bodyPart: String,
                                   completion: @escaping (Result<[Exercise], Error>) -> Void)
}

// MARK: - Live Service
class ExerciseService: ExerciseServiceProtocol {
    
    private let apiKey = "8ee4cad14amsh899152fc19fbb41p19899fjsn66028495d516"
    
    func fetchTargetList(completion: @escaping (Result<[String], Error>) -> Void) {
        
        guard let url = URL(string: "https://exercisedb.p.rapidapi.com/exercises/targetList") else {
            print("❌ Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.setValue("exercisedb.p.rapidapi.com", forHTTPHeaderField: "x-rapidapi-host")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { return }
            do {
                let targets = try JSONDecoder().decode([String].self, from: data)
                completion(.success(targets))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func fetchExercises(for target: String,
                        completion: @escaping (Result<[Exercise], Error>) -> Void) {
        
        let endpoint = "https://exercisedb.p.rapidapi.com/exercises/target/\(target)"
        guard let url = URL(string: endpoint) else {
            print("❌ Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.setValue("exercisedb.p.rapidapi.com", forHTTPHeaderField: "x-rapidapi-host")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { return }
            do {
                let exercises = try JSONDecoder().decode([Exercise].self, from: data)
                completion(.success(exercises))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func fetchExercisesByBodyPart(for bodyPart: String,
                                   completion: @escaping (Result<[Exercise], Error>) -> Void) {
        
        let formattedBodyPart = bodyPart.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bodyPart
        // Add limit=200 to get all exercises not just the default 10
        let endpoint = "https://exercisedb.p.rapidapi.com/exercises/bodyPart/\(formattedBodyPart)?limit=200&offset=0"
        
        print("🌐 Hitting URL: \(endpoint)")
        
        guard let url = URL(string: endpoint) else {
            print("❌ Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.setValue("exercisedb.p.rapidapi.com", forHTTPHeaderField: "x-rapidapi-host")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            if let error = error {
                print("❌ Network error:", error)
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status:", httpResponse.statusCode)
            }
            
            guard let data = data else {
                print("❌ No data returned")
                return
            }
            
            if let rawJSON = String(data: data, encoding: .utf8) {
                print("📦 Raw response:", rawJSON.prefix(300))
            }
            
            do {
                let exercises = try JSONDecoder().decode([Exercise].self, from: data)
                print("✅ Decoded \(exercises.count) exercises")
                completion(.success(exercises))
            } catch {
                print("❌ Decode error:", error)
                completion(.failure(error))
            }
            
        }.resume()
    }
}

// MARK: - Mock Service (previews only)
//class MockExerciseService: ExerciseServiceProtocol {
//    private let mockExercises: [Exercise]
//
//    init(exercises: [Exercise] = MockData.exercises) {
//        self.mockExercises = exercises
//    }
//
//    func fetchTargetList(completion: @escaping (Result<[String], Error>) -> Void) {
//        completion(.success([]))
//    }
//
//    func fetchExercises(for target: String,
//                        completion: @escaping (Result<[Exercise], Error>) -> Void) {
//        let filtered = mockExercises.filter { $0.target.lowercased() == target.lowercased() }
//        completion(.success(filtered.isEmpty ? mockExercises : filtered))
//    }
//
//    func fetchExercisesByBodyPart(for bodyPart: String,
//                                   completion: @escaping (Result<[Exercise], Error>) -> Void) {
//        let filtered = mockExercises.filter { $0.bodyPart.lowercased() == bodyPart.lowercased() }
//        completion(.success(filtered.isEmpty ? mockExercises : filtered))
//    }
//}
