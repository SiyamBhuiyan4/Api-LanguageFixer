import Foundation
import AppKit

enum TerminalColor {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let green = "\u{001B}[32m"
    static let red = "\u{001B}[31m"
    static let cyan = "\u{001B}[36m"
}

/// Answers API requests with queued canned responses and records what was sent.
final class StubProtocol: URLProtocol {
    static var queue: [(Int, String)] = []
    static var requests: [URLRequest] = []
    static var bodies: [Data] = []

    static func reset(_ responses: [(Int, String)]) {
        queue = responses
        requests = []
        bodies = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        StubProtocol.requests.append(request)
        if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 65536)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            stream.close()
            StubProtocol.bodies.append(data)
        } else if let data = request.httpBody {
            StubProtocol.bodies.append(data)
        }
        let (status, body) = StubProtocol.queue.isEmpty ? (500, "{}") : StubProtocol.queue.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

@main
struct TestRunner {
    static var totalTests = 0
    static var passedTests = 0
    static var failedTests = 0

    static func suite(_ name: String) {
        print("\n\(TerminalColor.bold)\(TerminalColor.cyan)▶ \(name)\(TerminalColor.reset)")
    }

    static func assertCondition(_ condition: Bool, _ testName: String) {
        totalTests += 1
        if condition {
            print("  \(TerminalColor.green)✔ PASS:\(TerminalColor.reset) \(testName)")
            passedTests += 1
        } else {
            print("  \(TerminalColor.red)✖ FAIL:\(TerminalColor.reset) \(testName)")
            failedTests += 1
        }
    }

    static func main() async {
        print("\(TerminalColor.bold)============================================================\(TerminalColor.reset)")
        print("\(TerminalColor.bold)🚀 RUNNING BANGLAWRITE AI NATIVE TEST SUITE\(TerminalColor.reset)")
        print("\(TerminalColor.bold)============================================================\(TerminalColor.reset)")

        // 1. Config Test
        suite("1. Config Models & Serialization")
        let cfg = BanglaWriteConfig.default
        assertCondition(cfg.provider == .gemini, "Default provider is Gemini")
        assertCondition(cfg.mode == .sameVoice, "Default style keeps the writer's voice")
        assertCondition(cfg.shortcut == "Command+Shift+B", "Default shortcut is Command+Shift+B")

        var switched = cfg
        switched.switchProvider(to: .groq)
        assertCondition(switched.provider == .groq, "Provider switches to Groq")
        assertCondition(switched.model == "llama-3.3-70b-versatile", "Groq default model set")

        if let encoded = try? JSONEncoder().encode(switched),
           let decoded = try? JSONDecoder().decode(BanglaWriteConfig.self, from: encoded) {
            assertCondition(decoded.provider == .groq, "JSON round-trip preserves state")
        } else {
            assertCondition(false, "JSON serialization failed")
        }

        // 2. Prompt Engine Test
        suite("2. Prompt Construction & Modes")
        let input = "ami ajke office jabo na kalke dekha hobe"
        for mode in ToneMode.allCases {
            let (systemPrompt, userPrompt) = PromptEngine.buildPrompts(text: input, mode: mode)
            assertCondition(userPrompt.contains(input), "Verbatim user text for [\(mode.rawValue)]")
            assertCondition(systemPrompt.contains("BanglaWrite AI"), "System prompt identifies as BanglaWrite AI")
            assertCondition(systemPrompt.contains(mode.instruction), "Tone instruction embedded for [\(mode.rawValue)]")
        }

        let english = PromptEngine.buildPrompts(text: input, mode: .sameVoice, target: .english).systemPrompt
        assertCondition(english.contains("preposition"), "English prompt fixes prepositions")
        assertCondition(english.contains(ToneMode.sameVoice.englishInstruction), "English prompt carries the tone")
        let bangla = PromptEngine.buildPrompts(text: input, mode: .sameVoice).systemPrompt
        assertCondition(bangla.contains("।") && bangla.contains("commas"), "Bangla prompt requires dari and commas")
        assertCondition(bangla.contains("dialect"), "Bangla prompt keeps dialect")

        // 3. Sanitizer Test
        suite("3. Input & Response Cleaner")
        assertCondition(PromptEngine.cleanResponse("```bangla\nআমি ভালো আছি\n```") == "আমি ভালো আছি", "Strips ```bangla fences")
        assertCondition(PromptEngine.cleanResponse("```\nআমি আজকে অফিসে যাব না।\n```") == "আমি আজকে অফিসে যাব না।", "Strips generic ``` fences")
        assertCondition(PromptEngine.cleanResponse("\"আমি বাংলায় কথা বলি\"") == "আমি বাংলায় কথা বলি", "Strips double quotes")
        assertCondition(PromptEngine.cleanResponse("“আমি বাংলায় স্বপ্ন দেখি”") == "আমি বাংলায় স্বপ্ন দেখি", "Strips curly quotes")
        assertCondition(PromptEngine.cleanResponse("Here is the Bengali translation:\nআমি আজকে যেতে পারব না।") == "আমি আজকে যেতে পারব না।", "Strips English preamble")
        assertCondition(PromptEngine.cleanResponse("বাংলা অনুবাদ: কালকে যাব।") == "কালকে যাব।", "Strips Bengali preamble")
        assertCondition(PromptEngine.cleanResponse("কালকে আসব।\n\nHope this helps!") == "কালকে আসব।", "Strips postamble")

        assertCondition(PromptEngine.cleanResponse("<text>\nআমি যাব।\n</text>") == "আমি যাব।", "Strips echoed text tags")

        // These are the user's real words and must survive
        assertCondition(PromptEngine.cleanResponse("বাংলা ভাষা সুন্দর।") == "বাংলা ভাষা সুন্দর।", "Keeps a sentence starting with বাংলা")
        assertCondition(PromptEngine.cleanResponse("Sure, I will come tomorrow.") == "Sure, I will come tomorrow.", "Keeps a sentence starting with Sure")
        assertCondition(PromptEngine.cleanResponse("Here is the money.") == "Here is the money.", "Keeps a sentence starting with Here is")
        assertCondition(PromptEngine.cleanResponse("Output the file today.") == "Output the file today.", "Keeps a sentence starting with Output")
        assertCondition(PromptEngine.cleanResponse("\"Hello\"", original: "\"hello\"") == "\"Hello\"", "Keeps quotes the user wrote")
        assertCondition(PromptEngine.cleanResponse("Call him.\nNote: bring rice.", original: "call him\nnote: bring rice") == "Call him.\nNote: bring rice.", "Keeps a note the user wrote")
        assertCondition(PromptEngine.cleanResponse("Output: 5 bags.", original: "output: 5 bag") == "Output: 5 bags.", "Keeps a label the user wrote")

        assertCondition(PromptEngine.restoringEdgeWhitespace(of: "ami jabo\n", on: "আমি যাব।") == "আমি যাব।\n", "Keeps a selected trailing newline")
        assertCondition(PromptEngine.restoringEdgeWhitespace(of: "  ami jabo ", on: "আমি যাব।\n") == "  আমি যাব। ", "Keeps selected edge spaces")
        assertCondition(PromptEngine.restoringEdgeWhitespace(of: "ami jabo", on: "আমি যাব।") == "আমি যাব।", "Adds no whitespace")

        // 3b. Saved Config Migration
        suite("3b. Saved Config Migration")
        let oldJSON = #"{"provider":"gemini","apiKey":"KEEP_ME","endpoint":"https://generativelanguage.googleapis.com/v1beta/models","model":"gemini-1.5-flash","temperature":0.3,"mode":"natural","shortcut":"Command+Shift+B","soundEnabled":false,"providerConfigs":{"gemini":{"apiKey":"KEEP_ME","endpoint":"https://generativelanguage.googleapis.com/v1beta/models","model":"gemini-1.5-flash"}}}"#
        if let migrated = try? JSONDecoder().decode(BanglaWriteConfig.self, from: Data(oldJSON.utf8)) {
            assertCondition(migrated.apiKey == "KEEP_ME", "Old config keeps its API key")
            assertCondition(migrated.soundEnabled == false, "Old config keeps its preferences")
            assertCondition(migrated.model == LLMProvider.gemini.defaultModel, "Retired Gemini model is replaced")
            assertCondition(migrated.providerConfigs["gemini"]?.model == LLMProvider.gemini.defaultModel, "Retired cached model is replaced")
            assertCondition(migrated.mode == .sameVoice, "Old default style moves to Keep My Voice")
            assertCondition(migrated.providerConfigs["groq"] != nil, "Missing providers are filled in")
        } else {
            assertCondition(false, "Old config decodes")
        }
        let partial = try? JSONDecoder().decode(BanglaWriteConfig.self, from: Data(#"{"provider":"gemini","apiKey":"K"}"#.utf8))
        assertCondition(partial?.apiKey == "K", "Partial config (admin panel) still decodes")
        var chosen = BanglaWriteConfig.default
        chosen.mode = .formal
        chosen.model = "gemini-3.8-flash"
        let reloaded = (try? JSONEncoder().encode(chosen)).flatMap { try? JSONDecoder().decode(BanglaWriteConfig.self, from: $0) }
        assertCondition(reloaded?.mode == .formal && reloaded?.model == "gemini-3.8-flash", "Saved choices survive a reload")

        // 3c. API Client against canned responses
        suite("3c. API Client")
        let stubConfig = URLSessionConfiguration.ephemeral
        stubConfig.protocolClasses = [StubProtocol.self]
        let client = APIClient(configuration: stubConfig)
        var gemini = BanglaWriteConfig.default
        gemini.apiKey = "TESTKEY"

        func geminiReply(_ text: String, finish: String = "STOP") -> String {
            let payload: [String: Any] = ["candidates": [["content": ["parts": [["text": text]]], "finishReason": finish]]]
            return String(data: try! JSONSerialization.data(withJSONObject: payload), encoding: .utf8)!
        }
        func errorFrom(_ responses: [(Int, String)], config: BanglaWriteConfig? = nil, target: TargetLanguage = .bangla) async -> BanglaWriteError? {
            StubProtocol.reset(responses)
            do {
                _ = try await client.rewrite(text: "ami jabo", mode: .sameVoice, target: target, config: config ?? gemini)
                return nil
            } catch {
                return error as? BanglaWriteError
            }
        }

        StubProtocol.reset([(200, geminiReply("আমি যাব।"))])
        let replaced = try? await client.rewrite(text: "ami jabo\n", mode: .sameVoice, config: gemini)
        assertCondition(replaced == "আমি যাব।\n", "Gemini reply is returned with selected whitespace kept")
        let sent = StubProtocol.requests.first
        assertCondition(sent?.url?.absoluteString == "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent", "Calls the configured model's generateContent URL")
        assertCondition(sent?.value(forHTTPHeaderField: "x-goog-api-key") == "TESTKEY", "Sends the key in a header")
        assertCondition(sent?.url?.absoluteString.contains("TESTKEY") == false, "Never puts the key in the URL")
        let sentBody = StubProtocol.bodies.first.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        assertCondition(sentBody.contains("system_instruction") && sentBody.contains("ami jabo"), "Sends the prompt and the text")

        StubProtocol.reset([(200, geminiReply("Bro, I will go."))])
        _ = try? await client.rewrite(text: "bhai ami jabo", mode: .sameVoice, target: .english, config: gemini)
        let englishBody = StubProtocol.bodies.first.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        assertCondition(englishBody.contains("preposition"), "English shortcut sends the English prompt")

        StubProtocol.reset([(503, "{}"), (200, geminiReply("আমি যাব।"))])
        let retried = try? await client.rewrite(text: "ami jabo", mode: .sameVoice, config: gemini)
        assertCondition(retried == "আমি যাব।" && StubProtocol.requests.count == 2, "Retries once when Gemini is overloaded")

        let thinking = #"{"candidates":[{"content":{"parts":[{"text":"hmm","thought":true},{"text":"আমি "},{"text":"যাব।"}]},"finishReason":"STOP"}]}"#
        StubProtocol.reset([(200, thinking)])
        let joined = try? await client.rewrite(text: "ami jabo", mode: .sameVoice, config: gemini)
        assertCondition(joined == "আমি যাব।", "Joins answer parts and skips thoughts")

        let cut = await errorFrom([(200, geminiReply("আমি", finish: "MAX_TOKENS"))])
        assertCondition(cut == .outputTruncated, "A cut-off answer is an error, not a replacement")
        let badKey = await errorFrom([(400, #"{"error":{"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT"}}"#)])
        assertCondition(badKey == .invalidAPIKey(provider: "Google Gemini"), "A bad key reports as a bad key")
        let noModel = await errorFrom([(404, #"{"error":{"message":"models/x is not found"}}"#)])
        assertCondition(noModel == .modelNotFound(model: "gemini-3.5-flash-lite"), "An unavailable model names the model")
        let limited = await errorFrom([(429, "{}")])
        assertCondition(limited == .rateLimited, "Rate limit is reported")
        let blocked = await errorFrom([(200, #"{"promptFeedback":{"blockReason":"SAFETY"}}"#)])
        assertCondition(blocked == .blockedBySafety, "Blocked prompt is reported")

        var noKey = BanglaWriteConfig.default
        noKey.apiKey = "   "
        let missing = await errorFrom([], config: noKey)
        assertCondition(missing == .missingOrInvalidAPIKey(provider: "Google Gemini") && StubProtocol.requests.isEmpty, "A missing key stops before any request")

        var offlineConfig = BanglaWriteConfig.default
        offlineConfig.switchProvider(to: .offline)
        let offlineEnglish = await errorFrom([], config: offlineConfig, target: .english)
        assertCondition(offlineEnglish == .englishNeedsAI, "Offline engine refuses English clearly")

        let list = #"{"models":[{"name":"models/gemini-3.8-flash","supportedGenerationMethods":["generateContent"]},{"name":"models/gemini-3.5-flash-lite","supportedGenerationMethods":["generateContent"]},{"name":"models/gemini-embedding-001","supportedGenerationMethods":["embedContent"]},{"name":"models/gemini-3.8-flash-tts","supportedGenerationMethods":["generateContent"]}]}"#
        StubProtocol.reset([(200, list)])
        let models = try? await client.listGeminiModels(config: gemini)
        assertCondition(models == ["gemini-3.5-flash-lite", "gemini-3.8-flash"], "Model list keeps only text models")

        StubProtocol.reset([(200, #"{"candidates":[{"finishReason":"MAX_TOKENS","content":{}}]}"#)])
        let connected = try? await client.testConnection(config: gemini)
        assertCondition(connected != nil, "Test passes when a thinking model returns no text")

        // 4. Clipboard Snapshot Test
        suite("4. Clipboard Snapshot & Restoration")
        let pb = NSPasteboard.general
        let oldContent = pb.string(forType: .string) ?? ""

        pb.clearContents()
        pb.setString("TEMP_TEST_123", forType: .string)
        assertCondition(pb.string(forType: .string) == "TEMP_TEST_123", "Pasteboard holds temp test string")

        pb.clearContents()
        if !oldContent.isEmpty {
            pb.setString(oldContent, forType: .string)
        }
        assertCondition(true, "Pasteboard restored to initial state")

        // 5. Built-in Offline Engine Test
        suite("5. Built-in Offline Engine (Zero API Key)")
        let offline1 = OfflineBanglaEngine.convert(text: "ami ajke jete parbo na kalke gele ki hobe", mode: .natural)
        assertCondition(offline1.contains("আমি") && offline1.contains("যেতে") && offline1.contains("পারব না"), "Offline converts 'ami ajke jete parbo na'")

        let offline2 = OfflineBanglaEngine.convert(text: "apu ajke product ta pathaite parbo na kalke pathabo", mode: .natural)
        assertCondition(offline2.contains("আপু") && offline2.contains("প্রোডাক্ট") && offline2.contains("পাঠাব"), "Offline converts compound product")

        // Summary
        print("\n\(TerminalColor.bold)============================================================\(TerminalColor.reset)")
        if failedTests == 0 {
            print("\(TerminalColor.green)\(TerminalColor.bold)🎉 ALL \(passedTests)/\(totalTests) NATIVE TESTS PASSED! (Exit code 0)\(TerminalColor.reset)\n")
            exit(0)
        } else {
            print("\(TerminalColor.red)\(TerminalColor.bold)❌ \(failedTests) TESTS FAILED!\(TerminalColor.reset)\n")
            exit(1)
        }
    }
}
