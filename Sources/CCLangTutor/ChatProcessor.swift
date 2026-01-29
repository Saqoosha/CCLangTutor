import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "sh.saqoo.cclangtutor", category: "ChatProcessor")

actor ChatProcessor {
    func sendMessage(_ message: String, correction: Correction, previousMessages: [ChatMessage]) async throws -> String {
        let provider = await getProvider()
        let apiKey = getAPIKey(for: provider)

        logger.info("Chat with provider: \(provider.displayName), hasAPIKey: \(apiKey != nil)")

        guard let apiKey = apiKey, !apiKey.isEmpty else {
            logger.warning("No API key for \(provider.displayName)")
            return "Error: No API key configured. Please set your \(provider.displayName) API key in Settings (⌘,)."
        }

        let systemPrompt = buildSystemPrompt(for: correction)

        logger.info("Calling \(provider.displayName) API for chat")
        let response: String
        switch provider {
        case .claudeAPI:
            response = try await callClaudeAPI(
                message: message,
                previousMessages: previousMessages,
                apiKey: apiKey,
                systemPrompt: systemPrompt,
                model: provider.defaultModel
            )
        case .gemini:
            response = try await callGeminiAPI(
                message: message,
                previousMessages: previousMessages,
                apiKey: apiKey,
                systemPrompt: systemPrompt,
                model: provider.defaultModel
            )
        case .openAI:
            response = try await callOpenAIAPI(
                message: message,
                previousMessages: previousMessages,
                apiKey: apiKey,
                systemPrompt: systemPrompt,
                model: provider.defaultModel
            )
        }
        logger.info("Chat response received, length: \(response.count)")
        return response
    }

    @MainActor
    private func getProvider() -> AIProvider {
        let raw = UserDefaults.standard.string(forKey: "aiProvider") ?? AIProvider.claudeAPI.rawValue
        return AIProvider(rawValue: raw) ?? .claudeAPI
    }

    private func getAPIKey(for provider: AIProvider) -> String? {
        KeychainHelper.load(service: provider.keychainService)
    }

    private func buildSystemPrompt(for correction: Correction) -> String {
        var prompt = """
        You are a friendly English tutor. The user is asking questions about a grammar correction.

        ## Context

        **Original text:**
        \(correction.original)

        **Corrected text:**
        \(correction.corrected)

        """

        if !correction.errors.isEmpty {
            prompt += "**Corrections made:**\n"
            for (index, error) in correction.errors.enumerated() {
                prompt += "\(index + 1). \"\(error.original)\" → \"\(error.corrected)\": \(error.explanation)\n"
            }
        } else {
            prompt += "**No corrections needed** - the original text was perfect.\n"
        }

        prompt += """

        ## Instructions
        - Answer questions about these corrections helpfully
        - Provide examples when useful
        - Keep responses concise but thorough
        """

        let languageCode = UserDefaults.standard.string(forKey: "responseLanguage") ?? ResponseLanguage.english.rawValue
        let language = ResponseLanguage(rawValue: languageCode) ?? .english

        if language == .english {
            prompt += "\n- Use simple, clear English"
        } else {
            prompt += "\n- IMPORTANT: Respond in \(language.languageName)"
        }

        return prompt
    }

    // MARK: - Claude API

    private func callClaudeAPI(
        message: String,
        previousMessages: [ChatMessage],
        apiKey: String,
        systemPrompt: String,
        model: String
    ) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        var messages: [[String: String]] = previousMessages.map { msg in
            ["role": msg.role.rawValue, "content": msg.content]
        }
        messages.append(["role": "user", "content": message])

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": messages
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

    private func callGeminiAPI(
        message: String,
        previousMessages: [ChatMessage],
        apiKey: String,
        systemPrompt: String,
        model: String
    ) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var contents: [[String: Any]] = previousMessages.map { msg in
            let role = msg.role == .user ? "user" : "model"
            return ["role": role, "parts": [["text": msg.content]]]
        }
        contents.append(["role": "user", "parts": [["text": message]]])

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": systemPrompt]]],
            "contents": contents
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

    private func callOpenAIAPI(
        message: String,
        previousMessages: [ChatMessage],
        apiKey: String,
        systemPrompt: String,
        model: String
    ) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var messages: [[String: String]] = [["role": "system", "content": systemPrompt]]
        for msg in previousMessages {
            messages.append(["role": msg.role.rawValue, "content": msg.content])
        }
        messages.append(["role": "user", "content": message])

        let body: [String: Any] = [
            "model": model,
            "messages": messages
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
}
