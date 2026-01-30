import Foundation
import SwiftUI
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "sh.saqoo.cclangtutor", category: "Processor")

private enum ScoreDefaults {
    static let perfect = 100
    static let fallback = 70
}

enum APIError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "API key is missing"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from API"
        case .httpError(let statusCode, let message):
            return "HTTP error \(statusCode): \(message ?? "Unknown")"
        case .parseError(let details):
            return "Failed to parse response: \(details)"
        }
    }
}

actor CorrectionProcessor {
    func process(_ prompt: PendingPrompt) async throws -> Correction {
        let provider = await getProvider()
        let apiKey = getAPIKey(for: provider)
        let systemPrompt = await getSystemPrompt()

        logger.info("Processing with provider: \(provider.displayName), hasAPIKey: \(apiKey != nil)")

        guard let apiKey = apiKey, !apiKey.isEmpty else {
            logger.warning("No API key for \(provider.displayName)")
            return Correction(
                from: prompt,
                corrected: prompt.prompt,
                errors: [
                    CorrectionError(
                        original: "API key missing",
                        corrected: "Set API key in Settings",
                        explanation: "Open Settings (⌘,) and enter your \(provider.displayName) API key."
                    )
                ],
                score: 0,
                advice: "Configure your API key in Settings to enable corrections."
            )
        }

        let response: String
        logger.info("Calling \(provider.displayName) API with model: \(provider.defaultModel)")
        switch provider {
        case .claudeAPI:
            response = try await callClaudeAPI(prompt: prompt.prompt, apiKey: apiKey, systemPrompt: systemPrompt, model: provider.defaultModel)
        case .gemini:
            response = try await callGeminiAPI(prompt: prompt.prompt, apiKey: apiKey, systemPrompt: systemPrompt, model: provider.defaultModel)
        case .openAI:
            response = try await callOpenAIAPI(prompt: prompt.prompt, apiKey: apiKey, systemPrompt: systemPrompt, model: provider.defaultModel)
        }
        logger.info("API response received, length: \(response.count)")

        let correction = try parseResponse(response, from: prompt)
        logger.info("Parsed correction: isPerfect=\(correction.isPerfect), errors=\(correction.errors.count)")
        return correction
    }

    @MainActor
    private func getProvider() -> AIProvider {
        let raw = UserDefaults.standard.string(forKey: "aiProvider") ?? AIProvider.claudeAPI.rawValue
        return AIProvider(rawValue: raw) ?? .claudeAPI
    }

    @MainActor
    private func getSystemPrompt() -> String {
        let basePrompt = UserDefaults.standard.string(forKey: "systemPrompt") ?? SettingsView.defaultSystemPrompt
        let language = ResponseLanguage.current

        if language == .english {
            return basePrompt
        }

        return basePrompt + "\n\nIMPORTANT: Write all explanations in \(language.languageName)."
    }

    private func getAPIKey(for provider: AIProvider) -> String? {
        KeychainHelper.load(service: provider.keychainService)
    }

    // MARK: - Claude API

    private func callClaudeAPI(prompt: String, apiKey: String, systemPrompt: String, model: String) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let fullSystemPrompt = systemPrompt + "\n\n" + responseFormatPrompt

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": fullSystemPrompt,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8)
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        return decoded.content.first?.text ?? ""
    }

    // MARK: - Gemini API

    private func callGeminiAPI(prompt: String, apiKey: String, systemPrompt: String, model: String) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let fullSystemPrompt = systemPrompt + "\n\n" + responseFormatPrompt

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": fullSystemPrompt]]],
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8)
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        return decoded.candidates?.first?.content?.parts?.first?.text ?? ""
    }

    // MARK: - OpenAI API

    private func callOpenAIAPI(prompt: String, apiKey: String, systemPrompt: String, model: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let fullSystemPrompt = systemPrompt + "\n\n" + responseFormatPrompt

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": fullSystemPrompt],
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8)
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return decoded.choices?.first?.message?.content ?? ""
    }

    // MARK: - Response Parsing

    private var responseFormatPrompt: String {
        """
        Respond in JSON format only:
        {
          "corrected": "The corrected text with all fixes applied",
          "errors": [
            {
              "original": "the incorrect word or phrase",
              "corrected": "the correction",
              "explanation": "brief explanation of why this is wrong"
            }
          ],
          "isPerfect": true/false (true if no errors found),
          "score": 0-100 (overall English quality score),
          "advice": "Brief advice on how to improve (only if score < 100)"
        }

        IMPORTANT:
        - If the text is already perfect, return isPerfect: true with an empty errors array, score: 100, and advice: null.
        - Only include items in errors where original != corrected (actual changes).
        - Do NOT add entries where original and corrected are the same.
        - In each error entry, "original" must be the EXACT text from the user's input, and "corrected" must be your fix.
        - Example: if user wrote "an advice", error should be {"original": "an advice", "corrected": "advice", ...}
        - Score should reflect overall English quality: 100 = perfect, 80-99 = minor issues, 60-79 = noticeable errors, below 60 = significant problems.
        - If score < 100, provide brief, actionable advice explaining what would make it perfect (e.g., capitalization, punctuation, word choice, sentence structure).
        """
    }

    private func parseResponse(_ text: String, from prompt: PendingPrompt) throws -> Correction {
        guard let jsonString = extractJSON(from: text) else {
            logger.error("Failed to extract JSON from response: \(text.prefix(200))")
            throw APIError.parseError("No JSON found in response")
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw APIError.parseError("Failed to convert JSON to data")
        }

        let result: CorrectionResult
        do {
            result = try JSONDecoder().decode(CorrectionResult.self, from: jsonData)
        } catch {
            logger.error("JSON decode error: \(error.localizedDescription)")
            throw APIError.parseError(error.localizedDescription)
        }

        // Filter out errors where original == corrected (no actual change)
        let errors = result.errors
            .filter { $0.original != $0.corrected }
            .map {
                CorrectionError(
                    original: $0.original,
                    corrected: $0.corrected,
                    explanation: $0.explanation
                )
            }

        let score = result.score ?? (errors.isEmpty ? ScoreDefaults.perfect : ScoreDefaults.fallback)

        return Correction(
            from: prompt,
            corrected: result.corrected,
            errors: errors,
            score: score,
            advice: result.advice
        )
    }

    private func extractJSON(from text: String) -> String? {
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }
        return nil
    }
}

// MARK: - Response Types

struct ClaudeResponse: Decodable {
    let content: [ContentBlock]
}

struct ContentBlock: Decodable {
    let type: String
    let text: String
}

struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]?
}

struct GeminiCandidate: Decodable {
    let content: GeminiContent?
}

struct GeminiContent: Decodable {
    let parts: [GeminiPart]?
}

struct GeminiPart: Decodable {
    let text: String?
}

struct OpenAIResponse: Decodable {
    let choices: [OpenAIChoice]?
}

struct OpenAIChoice: Decodable {
    let message: OpenAIMessage?
}

struct OpenAIMessage: Decodable {
    let content: String?
}

struct CorrectionResult: Decodable {
    let corrected: String
    let errors: [ErrorItem]
    let isPerfect: Bool
    let score: Int?
    let advice: String?
}

struct ErrorItem: Decodable {
    let original: String
    let corrected: String
    let explanation: String
}
