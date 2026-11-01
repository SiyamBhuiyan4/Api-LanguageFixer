import Foundation

public final class APIClient: Sendable {
    public static let shared = APIClient()

    private let session: URLSession

    private init() {
        self.session = URLSession(configuration: APIClient.makeConfiguration())
    }

    /// For tests: routes requests through a custom configuration.
    init(configuration: URLSessionConfiguration) {
        self.session = URLSession(configuration: configuration)
    }

    private static func makeConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 25.0
        config.timeoutIntervalForResource = 25.0
        return config
    }

    // MARK: - Rewrite API Call

    public func rewrite(text: String, mode: ToneMode, target: TargetLanguage = .bangla, config: BanglaWriteConfig) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BanglaWriteError.noTextSelected
        }

        let provider = config.provider
        let apiKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if provider == .offline {
            guard target == .bangla else { throw BanglaWriteError.englishNeedsAI }
            return PromptEngine.restoringEdgeWhitespace(of: text, on: OfflineBanglaEngine.convert(text: text, mode: mode))
        }
        if provider.requiresAPIKey && apiKey.isEmpty {
            throw BanglaWriteError.missingOrInvalidAPIKey(provider: provider.displayName)
        }

        let (systemPrompt, userPrompt) = PromptEngine.buildPrompts(text: text, mode: mode, target: target)
        let request = try buildRequest(
            provider: provider,
            apiKey: apiKey,
            endpoint: config.endpoint,
            model: config.model,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            temperature: config.temperature,
            maxTokens: 8192
        )

        let (data, statusCode) = try await send(request, retryingServerErrors: true)
        try checkStatus(statusCode, data: data, provider: provider, model: config.model)
        let raw = try parseResponse(data: data, provider: provider)

        let cleaned = PromptEngine.cleanResponse(raw, original: text)
        guard !cleaned.isEmpty else {
            throw BanglaWriteError.parseError(message: "The AI returned an empty answer.")
        }
        return PromptEngine.restoringEdgeWhitespace(of: text, on: cleaned)
    }

    // MARK: - Test Connection Call

    public func testConnection(config: BanglaWriteConfig) async throws -> String {
        let provider = config.provider
        let apiKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if provider == .offline {
            let sample = OfflineBanglaEngine.convert(text: "ami bhalo achi", mode: .natural)
            return "Offline engine ready. Sample: \(sample)"
        }
        if provider.requiresAPIKey && apiKey.isEmpty {
            throw BanglaWriteError.missingOrInvalidAPIKey(provider: provider.displayName)
        }

        // The token cap is generous because thinking models spend tokens before answering.
        // Only the status matters here, so an empty answer still counts as connected.
        let request = try buildRequest(
            provider: provider,
            apiKey: apiKey,
            endpoint: config.endpoint,
            model: config.model,
            systemPrompt: "Reply with 'OK'.",
            userPrompt: "hi",
            temperature: 0.1,
            maxTokens: 256
        )

        let (data, statusCode) = try await send(request, retryingServerErrors: false)
        try checkStatus(statusCode, data: data, provider: provider, model: config.model)
        return "Connected. \(config.model) is working."
    }

    // MARK: - Gemini Model List

    /// Text models this key can use, from Gemini's ListModels endpoint.
    public func listGeminiModels(config: BanglaWriteConfig) async throws -> [String] {
        let apiKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw BanglaWriteError.missingOrInvalidAPIKey(provider: LLMProvider.gemini.displayName)
        }
        let base = config.endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)?pageSize=200") else {
            throw BanglaWriteError.unexpected(message: "Invalid Gemini URL: \(base)")
        }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let (data, statusCode) = try await send(request, retryingServerErrors: false)
        try checkStatus(statusCode, data: data, provider: .gemini, model: config.model)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            throw BanglaWriteError.parseError(message: "Invalid model list.")
        }

        let excluded = ["tts", "image", "audio", "live", "embedding", "robotics", "computer", "vision", "aqa", "learnlm", "customtools"]
        let names: [String] = models.compactMap { model in
            guard let name = model["name"] as? String,
                  let methods = model["supportedGenerationMethods"] as? [String],
                  methods.contains("generateContent") else { return nil }
            let id = name.replacingOccurrences(of: "models/", with: "")
            guard id.hasPrefix("gemini"), !excluded.contains(where: { id.contains($0) }) else { return nil }
            return id
        }
        return names.sorted()
    }

    // MARK: - Transport

    private func send(_ request: URLRequest, retryingServerErrors: Bool) async throws -> (Data, Int) {
        var attempt = 0
        while true {
            attempt += 1
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch let urlError as URLError {
                if urlError.code == .timedOut {
                    throw BanglaWriteError.apiTimeout
                }
                throw BanglaWriteError.networkError(message: urlError.localizedDescription)
            } catch {
                throw BanglaWriteError.networkError(message: error.localizedDescription)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw BanglaWriteError.networkError(message: "Invalid response from server.")
            }

            // Gemini returns 503 when briefly overloaded; one retry usually clears it.
            if retryingServerErrors && attempt == 1 && [500, 502, 503].contains(httpResponse.statusCode) {
                try? await Task.sleep(nanoseconds: 800_000_000)
                continue
            }
            return (data, httpResponse.statusCode)
        }
    }

    // MARK: - Request Builder

    private func buildRequest(
        provider: LLMProvider,
        apiKey: String,
        endpoint: String,
        model: String,
        systemPrompt: String,
        userPrompt: String,
        temperature: Double,
        maxTokens: Int
    ) throws -> URLRequest {
        switch provider {
        case .offline:
            throw BanglaWriteError.unexpected(message: "Offline engine does not use network requests.")
        case .gemini:
            let base = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let urlString = "\(base)/\(model):generateContent"
            guard let url = URL(string: urlString) else {
                throw BanglaWriteError.unexpected(message: "Invalid Gemini URL: \(urlString)")
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

            let payload: [String: Any] = [
                "contents": [
                    ["role": "user", "parts": [["text": userPrompt]]]
                ],
                "system_instruction": [
                    "parts": [["text": systemPrompt]]
                ],
                "generationConfig": [
                    "temperature": temperature,
                    "maxOutputTokens": maxTokens
                ]
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            return request

        case .groq, .openai, .ollama, .custom:
            var base = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !base.hasSuffix("/chat/completions") && !base.hasSuffix("/api/chat") {
                if base.hasSuffix("/v1") {
                    base = "\(base)/chat/completions"
                } else {
                    base = "\(base)/chat/completions"
                }
            }

            guard let url = URL(string: base) else {
                throw BanglaWriteError.unexpected(message: "Invalid URL: \(base)")
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }

            let payload: [String: Any] = [
                "model": model,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": userPrompt]
                ],
                "temperature": temperature,
                "max_tokens": maxTokens
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            return request
        }
    }

    // MARK: - Response Parsing

    private func checkStatus(_ statusCode: Int, data: Data, provider: LLMProvider, model: String) throws {
        if (200...299).contains(statusCode) { return }
        let errorText = extractErrorMessage(data: data)

        // Gemini reports a bad key as HTTP 400 rather than 401.
        let badKey = errorText.contains("API key not valid") || errorText.contains("API_KEY_INVALID")
        if statusCode == 401 || statusCode == 403 || badKey {
            throw BanglaWriteError.invalidAPIKey(provider: provider.displayName)
        }
        if statusCode == 429 {
            throw BanglaWriteError.rateLimited
        }
        if statusCode == 404 {
            throw BanglaWriteError.modelNotFound(model: model)
        }
        throw BanglaWriteError.networkError(message: "HTTP \(statusCode): \(errorText)")
    }

    private func parseResponse(data: Data, provider: LLMProvider) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BanglaWriteError.parseError(message: "Invalid JSON response.")
        }

        switch provider {
        case .offline:
            throw BanglaWriteError.unexpected(message: "Offline engine does not use network requests.")
        case .gemini:
            if let feedback = json["promptFeedback"] as? [String: Any], feedback["blockReason"] != nil {
                throw BanglaWriteError.blockedBySafety
            }
            guard let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first else {
                throw BanglaWriteError.parseError(message: "No candidates in Gemini response.")
            }
            let finishReason = firstCandidate["finishReason"] as? String
            if finishReason == "SAFETY" || finishReason == "PROHIBITED_CONTENT" {
                throw BanglaWriteError.blockedBySafety
            }
            // A cut-off answer must never replace the user's full text.
            if finishReason == "MAX_TOKENS" {
                throw BanglaWriteError.outputTruncated
            }
            guard let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else {
                throw BanglaWriteError.parseError(message: "Empty text parts in Gemini response.")
            }
            let text = parts
                .filter { ($0["thought"] as? Bool) != true }
                .compactMap { $0["text"] as? String }
                .joined()
            guard !text.isEmpty else {
                throw BanglaWriteError.parseError(message: "Empty text parts in Gemini response.")
            }
            return text

        case .groq, .openai, .ollama, .custom:
            if let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let text = message["content"] as? String {
                if (firstChoice["finish_reason"] as? String) == "length" {
                    throw BanglaWriteError.outputTruncated
                }
                return text
            }
            if let message = json["message"] as? [String: Any],
               let text = message["content"] as? String {
                return text
            }
            if let text = json["response"] as? String {
                return text
            }
            throw BanglaWriteError.parseError(message: "No message content found in LLM response.")
        }
    }

    private func extractErrorMessage(data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? [String: Any], let msg = error["message"] as? String {
                return msg
            }
            if let errorMsg = json["error"] as? String {
                return errorMsg
            }
            if let msg = json["message"] as? String {
                return msg
            }
        }
        return String(data: data, encoding: .utf8) ?? "Unknown server error"
    }
}
