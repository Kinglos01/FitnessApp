import Foundation

struct GeminiRequest: Codable {
    struct Content: Codable {
        struct Part: Codable {
            let text: String
        }
        let parts: [Part]
    }
    let contents: [Content]
}

struct GeminiResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}

class GeminiService {
    
    private let apiKey = "AIzaSyApu0ef7P3FLraqT28KjCvDrBBRuS24NXM"
    private let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
    
    func generateWorkout(prompt: String, completion: @escaping (String?) -> Void) {
        
        guard let url = URL(string: "\(urlString)?key=\(apiKey)") else {
            completion(nil)
            return
        }
        
        let requestBody = GeminiRequest(
            contents: [
                GeminiRequest.Content(
                    parts: [
                        GeminiRequest.Content.Part(text: prompt)
                    ]
                )
            ]
        )
        
        guard let jsonData = try? JSONEncoder().encode(requestBody) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            if let decodedResponse = try? JSONDecoder().decode(GeminiResponse.self, from: data) {
                let text = decodedResponse.candidates.first?.content.parts.first?.text
                DispatchQueue.main.async {
                    completion(text)
                }
            } else {
                completion(nil)
            }
            
        }.resume()
    }
}

import UIKit

class ViewController: UIViewController {
    
    let geminiService = GeminiService()
    
    @IBOutlet weak var resultLabel: UILabel!
    
    @IBAction func generateWorkoutTapped(_ sender: UIButton) {
        
        let prompt = """
        Create a 30-minute beginner workout plan 
        for fat loss and muscle toning.
        """
        
        geminiService.generateWorkout(prompt: prompt) { response in
            if let response = response {
                self.resultLabel.text = response
            } else {
                self.resultLabel.text = "Error generating workout."
            }
        }
    }
}
