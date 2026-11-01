import Foundation

// MARK: - Bengali Tone Mode

public enum ToneMode: String, CaseIterable, Codable, Sendable {
    case sameVoice = "same_voice"
    case natural = "natural"
    case polite = "polite"
    case professional = "professional"
    case casual = "casual"
    case formal = "formal"
    case short = "short"
    case fixGrammar = "fix_grammar"

    public var displayName: String {
        switch self {
        case .sameVoice: return "Keep My Voice (যেমন লিখেছি তেমন)"
        case .natural: return "Natural Bangla (স্বাভাবিক চলিত)"
        case .polite: return "Polite (নম্র ও শ্রদ্ধাশীল)"
        case .professional: return "Professional (পেশাদার)"
        case .casual: return "Casual (অনানুষ্ঠানিক / বন্ধুমহল)"
        case .formal: return "Formal (দাপ্তরিক ও প্রাতিষ্ঠানিক)"
        case .short: return "Short (সংক্ষিপ্ত ও সারসংক্ষেপ)"
        case .fixGrammar: return "Fix Grammar (বানান ও ব্যাকরণ)"
        }
    }

    public var instruction: String {
        switch self {
        case .sameVoice:
            return "Keep the writer's exact voice: same words, same dialect or regional accent, same level of formality, same pronouns (তুই/তুমি/আপনি), same mood. Never make it more formal or standardize the dialect. Change only what is actually wrong: spelling, grammar, and punctuation."
        case .natural:
            return "Convert the input into natural, fluent, and human-sounding everyday colloquial Bengali (প্রমিত চলিত বাংলা). Keep it authentic and effortless without being overly stiff."
        case .polite:
            return "Make the text polite, respectful, and courteous (always using 'আপনি' and respectful Bengali phrasing like 'দয়া করে', 'অনুরোধ করছি', or 'আপু/ভাইয়া' where contextually fitting) without sounding groveling."
        case .casual:
            return "Convert into relaxed, friendly, and informal conversational Bengali (using 'তুমি' or 'তুই' where appropriate), suitable for chatting with friends or close peers."
        case .professional:
            return "Rewrite with a polished, courteous, business-appropriate Bengali tone suitable for work, email, clients, or colleagues. Maintain clarity and professionalism."
        case .formal:
            return "Use standard, official, dignified, and grammatically precise formal Bengali (প্রমিত সাধু/চলিত দাপ্তরিক ভাষা) suitable for official announcements or formal letters."
        case .short:
            return "Make the message concise, direct, and crisp in Bengali while preserving 100% of the core actionable information, numbers, dates, and URLs."
        case .fixGrammar:
            return "Preserve the exact wording, style, vocabulary, and pronouns as much as possible; only fix spelling mistakes, phonetic typos, Bengali script conversion, and punctuation."
        }
    }

    /// The same tone expressed for English output.
    public var englishInstruction: String {
        switch self {
        case .sameVoice:
            return "Keep the writer's exact voice: same mood, same level of casualness or formality, same directness. A casual chat message stays a casual chat message. Do not make it fancier, longer, or more formal."
        case .natural:
            return "Use natural, fluent, everyday English."
        case .polite:
            return "Use polite, respectful, courteous English without sounding groveling."
        case .casual:
            return "Use relaxed, friendly, conversational English suitable for friends."
        case .professional:
            return "Use polished, courteous, business-appropriate English."
        case .formal:
            return "Use formal, dignified English suitable for official letters."
        case .short:
            return "Make it concise and direct while keeping all actionable information, numbers, dates, and URLs."
        case .fixGrammar:
            return "Stay as close to the writer's wording as correct English allows; only fix what is wrong."
        }
    }
}

// MARK: - Output Language

public enum TargetLanguage: String, CaseIterable, Sendable {
    case bangla
    case english

    public var displayName: String {
        switch self {
        case .bangla: return "Bangla"
        case .english: return "English"
        }
    }
}

// MARK: - LLM Provider

public enum LLMProvider: String, CaseIterable, Codable, Sendable {
    case offline = "offline"
    case gemini = "gemini"
    case groq = "groq"
    case openai = "openai"
    case ollama = "ollama"
    case custom = "custom"

    public var displayName: String {
        switch self {
        case .offline: return "Built-in Offline Engine (No Key Needed)"
        case .gemini: return "Google Gemini"
        case .groq: return "Groq Cloud (Fast)"
        case .openai: return "OpenAI"
        case .ollama: return "Ollama (Local Offline)"
        case .custom: return "Custom OpenAI-Compatible"
        }
    }

    public var defaultModel: String {
        switch self {
        case .offline: return "offline-phonetic-v1"
        case .gemini: return "gemini-3.5-flash-lite"
        case .groq: return "llama-3.3-70b-versatile"
        case .openai: return "gpt-4o-mini"
        case .ollama: return "llama3.2"
        case .custom: return "custom-model"
        }
    }

    public var defaultEndpoint: String {
        switch self {
        case .offline: return "local://offline"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta/models"
        case .groq: return "https://api.groq.com/openai/v1/chat/completions"
        case .openai: return "https://api.openai.com/v1/chat/completions"
        case .ollama: return "http://localhost:11434/v1/chat/completions"
        case .custom: return "http://localhost:8080/v1/chat/completions"
        }
    }

    public var requiresAPIKey: Bool {
        switch self {
        case .offline, .ollama: return false
        default: return true
        }
    }
}

// MARK: - Provider Configuration

public struct ProviderConfig: Codable, Equatable, Sendable {
    public var apiKey: String
    public var endpoint: String
    public var model: String

    public init(apiKey: String = "", endpoint: String, model: String) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.model = model
    }
}

// MARK: - Main Application Configuration

public struct BanglaWriteConfig: Codable, Equatable, Sendable, CustomStringConvertible {
    public var provider: LLMProvider
    public var apiKey: String
    public var endpoint: String
    public var model: String
    public var temperature: Double
    public var mode: ToneMode
    public var shortcut: String
    public var soundEnabled: Bool
    public var providerConfigs: [String: ProviderConfig]
    public var configVersion: Int

    public static let currentConfigVersion = 2

    public static let `default` = BanglaWriteConfig(
        provider: .gemini,
        apiKey: "",
        endpoint: LLMProvider.gemini.defaultEndpoint,
        model: LLMProvider.gemini.defaultModel,
        temperature: 0.3,
        mode: .sameVoice,
        shortcut: "Command+Shift+B",
        soundEnabled: true,
        providerConfigs: [
            LLMProvider.offline.rawValue: ProviderConfig(apiKey: "", endpoint: LLMProvider.offline.defaultEndpoint, model: LLMProvider.offline.defaultModel),
            LLMProvider.gemini.rawValue: ProviderConfig(apiKey: "", endpoint: LLMProvider.gemini.defaultEndpoint, model: LLMProvider.gemini.defaultModel),
            LLMProvider.groq.rawValue: ProviderConfig(apiKey: "", endpoint: LLMProvider.groq.defaultEndpoint, model: LLMProvider.groq.defaultModel),
            LLMProvider.openai.rawValue: ProviderConfig(apiKey: "", endpoint: LLMProvider.openai.defaultEndpoint, model: LLMProvider.openai.defaultModel),
            LLMProvider.ollama.rawValue: ProviderConfig(apiKey: "", endpoint: LLMProvider.ollama.defaultEndpoint, model: LLMProvider.ollama.defaultModel),
            LLMProvider.custom.rawValue: ProviderConfig(apiKey: "", endpoint: LLMProvider.custom.defaultEndpoint, model: LLMProvider.custom.defaultModel)
        ],
        configVersion: BanglaWriteConfig.currentConfigVersion
    )

    /// Gemini model families Google has shut down; requests to them can only fail.
    public static func isRetiredGeminiModel(_ model: String) -> Bool {
        return model.hasPrefix("gemini-1.") || model.hasPrefix("gemini-pro") || model.hasPrefix("gemini-2.0")
    }

    public mutating func switchProvider(to newProvider: LLMProvider) {
        // Save current active credentials into provider cache
        var currentEntry = providerConfigs[provider.rawValue] ?? ProviderConfig(endpoint: endpoint, model: model)
        currentEntry.apiKey = apiKey
        currentEntry.endpoint = endpoint
        currentEntry.model = model
        providerConfigs[provider.rawValue] = currentEntry

        // Switch to target provider
        provider = newProvider
        if let target = providerConfigs[newProvider.rawValue] {
            endpoint = target.endpoint
            model = target.model
            apiKey = target.apiKey
        } else {
            endpoint = newProvider.defaultEndpoint
            model = newProvider.defaultModel
            apiKey = ""
        }
    }

    public var description: String {
        let masked = apiKey.count > 8 ? "\(apiKey.prefix(3))...\(apiKey.suffix(3))" : (apiKey.isEmpty ? "<none>" : "******")
        return "BanglaWriteConfig(provider: \(provider.rawValue), model: \(model), apiKey: \(masked), mode: \(mode.rawValue))"
    }
}

// MARK: - Tolerant Decoding

extension BanglaWriteConfig {
    private enum LegacyKeys: String, CodingKey {
        case provider, apiKey, endpoint, model, temperature, mode, shortcut, soundEnabled, providerConfigs, configVersion
    }

    /// Missing keys fall back to defaults, so an older or hand-edited config.json
    /// keeps the user's API key instead of failing to decode and being overwritten.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: LegacyKeys.self)
        let base = BanglaWriteConfig.default

        let savedVersion = (try? c.decodeIfPresent(Int.self, forKey: .configVersion)) ?? nil
        let savedProvider = (try? c.decodeIfPresent(LLMProvider.self, forKey: .provider)) ?? nil

        provider = savedProvider ?? base.provider
        apiKey = ((try? c.decodeIfPresent(String.self, forKey: .apiKey)) ?? nil) ?? ""
        endpoint = ((try? c.decodeIfPresent(String.self, forKey: .endpoint)) ?? nil) ?? provider.defaultEndpoint
        model = ((try? c.decodeIfPresent(String.self, forKey: .model)) ?? nil) ?? provider.defaultModel
        temperature = ((try? c.decodeIfPresent(Double.self, forKey: .temperature)) ?? nil) ?? base.temperature
        mode = ((try? c.decodeIfPresent(ToneMode.self, forKey: .mode)) ?? nil) ?? base.mode
        shortcut = ((try? c.decodeIfPresent(String.self, forKey: .shortcut)) ?? nil) ?? base.shortcut
        soundEnabled = ((try? c.decodeIfPresent(Bool.self, forKey: .soundEnabled)) ?? nil) ?? base.soundEnabled

        var merged = base.providerConfigs
        if let saved = (try? c.decodeIfPresent([String: ProviderConfig].self, forKey: .providerConfigs)) ?? nil {
            merged.merge(saved) { _, new in new }
        }
        providerConfigs = merged
        configVersion = BanglaWriteConfig.currentConfigVersion

        // Configs from before v2 used the rewriting "natural" default; the app now keeps the writer's voice.
        if (savedVersion ?? 1) < 2 {
            mode = .sameVoice
        }

        if provider == .gemini && BanglaWriteConfig.isRetiredGeminiModel(model) {
            model = LLMProvider.gemini.defaultModel
        }
        if let cached = providerConfigs[LLMProvider.gemini.rawValue], BanglaWriteConfig.isRetiredGeminiModel(cached.model) {
            providerConfigs[LLMProvider.gemini.rawValue]?.model = LLMProvider.gemini.defaultModel
        }
    }
}

// MARK: - Error Types

public enum BanglaWriteError: LocalizedError, Sendable, Equatable {
    case noTextSelected
    case missingOrInvalidAPIKey(provider: String)
    case invalidAPIKey(provider: String)
    case modelNotFound(model: String)
    case englishNeedsAI
    case outputTruncated
    case blockedBySafety
    case networkError(message: String)
    case apiTimeout
    case rateLimited
    case missingAccessibilityPermission
    case parseError(message: String)
    case unexpected(message: String)

    public var errorDescription: String? {
        switch self {
        case .noTextSelected:
            return "No text selected to rewrite."
        case .missingOrInvalidAPIKey(let provider):
            return "API key missing for \(provider). Add it in Settings."
        case .invalidAPIKey(let provider):
            return "\(provider) rejected this API key. Check it in Settings."
        case .modelNotFound(let model):
            return "Model \"\(model)\" isn't available for this key. Pick another in Settings."
        case .englishNeedsAI:
            return "English needs an AI provider. Choose Gemini in Settings."
        case .outputTruncated:
            return "The AI's answer was cut off, so your text was left unchanged. Try a shorter selection."
        case .blockedBySafety:
            return "Gemini's safety filter blocked this text, so it was left unchanged."
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiTimeout:
            return "AI request timed out (25 seconds)."
        case .rateLimited:
            return "AI usage limit reached. Wait a moment, or pick another model in Settings."
        case .missingAccessibilityPermission:
            return "Accessibility permission required to capture and replace text."
        case .parseError(let message):
            return "API parse error: \(message)"
        case .unexpected(let message):
            return "Error: \(message)"
        }
    }
}
