//
//  ExcerciseService.swift
//  FitnessApp
//
//  Created by Nelson Mojica on 2/19/26.
//

import Foundation

// MARK: - Protocol

protocol ExerciseServiceProtocol {
    func fetchExercises(for target: String,
                        completion: @escaping (Result<[Exercise], Error>) -> Void)
}

// MARK: - Live Service

class ExerciseService: ExerciseServiceProtocol {
    
    private let apiKey =  "8ee4cad14amsh899152fc19fbb41p19899fjsn66028495d516"
    
    func fetchTargetList(completion: @escaping (Result<[String], Error>) -> Void) {
        
        guard let url = URL(string: "https://exercisedb.p.rapidapi.com/exercises/targetList") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.setValue("exercisedb.p.rapidapi.com", forHTTPHeaderField: "x-rapidapi-host")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
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
        
        guard let url = URL(string: endpoint) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.setValue("exercisedb.p.rapidapi.com", forHTTPHeaderField: "x-rapidapi-host")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else { return }
            
            do {
                let exercises = try JSONDecoder().decode([Exercise].self, from: data)
                completion(.success(exercises))
            } catch {
                completion(.failure(error))
            }
            
        }.resume()
    }
}

// MARK: - Mock Service (previews only)

class MockExerciseService: ExerciseServiceProtocol {
    private let mockExercises: [Exercise]

    init(exercises: [Exercise] = MockData.exercises) {
        self.mockExercises = exercises
    }

    func fetchExercises(for target: String,
                        completion: @escaping (Result<[Exercise], Error>) -> Void) {
        // Return matching exercises synchronously — no network call.
        let filtered = mockExercises.filter { $0.target.lowercased() == target.lowercased() }
        completion(.success(filtered.isEmpty ? mockExercises : filtered))
    }
}
