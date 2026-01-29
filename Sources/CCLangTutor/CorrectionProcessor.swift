import Foundation
import SwiftUI
import os

private let logger = Logger(subsystem: "sh.saqoo.cclangtutor", category: "Processor")

enum APIError: Error {
    case noAPIKey
    case invalidResponse
    case httpError(statusCode: Int)
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
                ]
            )
        }

        let response: String
        logger.info("Calling \(provider.displayName) API...")
        switch provider {
        case .claudeAPI:
            response = try await callClaudeAPI(prompt: prompt.prompt, apiKey: apiKey, systemPrompt: systemPrompt)
        case .gemini:
            response = try await callGeminiAPI(prompt: prompt.prompt, apiKey: apiKey, systemPrompt: systemPrompt)
        case .openAI:
            response = try await callOpenAIAPI(prompt: prompt.prompt, apiKey: apiKey, systemPrompt: systemPrompt)
        }
        logger.info("API response received, length: \(response.count)")

        let correction = parseResponse(response, from: prompt)
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
        UserDefaults.standard.string(forKey: "systemPrompt") ?? SettingsView.defaultSystemPrompt
    }

    private func getAPIKey(for provider: AIProvider) -> String? {
        KeychainHelper.load(service: provider.keychainService)
    }

    // MARK: - Claude API

    private func callClaudeAPI(prompt: String, apiKey: String, systemPrompt: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let fullSystemPrompt = systemPrompt + "\n\n" + responseFormatPrompt

        let body: [String: Any] = [
            "model": "claude-3-5-haiku-20241022",
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
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        return decoded.content.first?.text ?? ""
    }

    // MARK: - Gemini API

    private func callGeminiAPI(prompt: String, apiKey: String, systemPrompt: String) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)")!
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
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        return decoded.candidates?.first?.content?.parts?.first?.text ?? ""
    }

    // MARK: - OpenAI API

    private func callOpenAIAPI(prompt: String, apiKey: String, systemPrompt: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let fullSystemPrompt = systemPrompt + "\n\n" + responseFormatPrompt

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
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
            throw APIError.httpError(statusCode: httpResponse.statusCode)
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
          "isPerfect": true/false (true if no errors found)
        }

        If the text is already perfect, return isPerfect: true with an empty errors array.
        """
    }

    private func parseResponse(_ text: String, from prompt: PendingPrompt) -> Correction {
        guard let jsonString = extractJSON(from: text),
              let jsonData = jsonString.data(using: .utf8),
              let result = try? JSONDecoder().decode(CorrectionResult.self, from: jsonData) else {
            return Correction(
                from: prompt,
                corrected: prompt.prompt,
                errors: []
            )
        }

        let errors = result.errors.map {
            CorrectionError(
                original: $0.original,
                corrected: $0.corrected,
                explanation: $0.explanation
            )
        }

        return Correction(
            from: prompt,
            corrected: result.corrected,
            errors: errors
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
}

struct ErrorItem: Decodable {
    let original: String
    let corrected: String
    let explanation: String
}
