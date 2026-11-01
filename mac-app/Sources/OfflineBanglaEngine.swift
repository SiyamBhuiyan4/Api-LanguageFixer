import Foundation

// MARK: - Offline Bangla Phonetic & Dictionary Engine
/// A 100% native, zero-dependency, local Banglish-to-Bengali transliteration
/// and dictionary engine that runs completely offline with zero API keys,
/// 0.0% idle CPU, and sub-millisecond response time.
public struct OfflineBanglaEngine {

    // MARK: - Top-Frequency Banglish Dictionary
    private static let dictionary: [String: String] = [
        // Pronouns
        "ami": "আমি",
        "amar": "আমার",
        "amake": "আমাকে",
        "amader": "আমাদের",
        "tumi": "তুমি",
        "tomar": "তোমার",
        "tomake": "তোমাকে",
        "tomader": "তোমাদের",
        "apni": "আপনি",
        "apnar": "আপনার",
        "apnake": "আপনাকে",
        "apnader": "আপনাদের",
        "tui": "তুই",
        "tor": "তোর",
        "toke": "তোকে",
        "toder": "তোদের",
        "se": "সে",
        "tar": "তার",
        "take": "তাকে",
        "tara": "তারা",
        "tader": "তাদের",
        "tini": "তিনি",
        "tanr": "তাঁর",
        "tanke": "তাঁকে",
        "ini": "ইনি",
        "uni": "উনি",
        "unader": "ওনাদের",
        "unake": "ওনাকে",
        "e": "এ",
        "o": "ও",
        "ora": "ওরা",
        "era": "এরা",
        "ke": "কে",
        "kara": "কারা",
        "kake": "কাকে",

        // Time & Days
        "ajke": "আজকে",
        "aaj": "আজ",
        "kalke": "কালকে",
        "kaal": "কাল",
        "agamikal": "আগামীকাল",
        "gotokal": "গতকাল",
        "porshu": "পরশু",
        "tarpor": "তারপর",
        "ekhon": "এখন",
        "tokhon": "তখন",
        "kokhon": "কখন",
        "shobshomoy": "সবসময়",
        "majhemajhe": "মাঝে মাঝে",
        "protidin": "প্রতিদিন",
        "shokal": "সকাল",
        "dupurbela": "দুপুরবেলা",
        "dupur": "দুপুর",
        "bikal": "বিকাল",
        "shondha": "সন্ধ্যা",
        "raat": "রাত",
        "raate": "রাতে",
        "din": "দিন",
        "mash": "মাস",
        "bochor": "বছর",
        "shoptaho": "সপ্তাহ",
        "deri": "দেরি",
        "taratari": "তাড়াতাড়ি",
        "druto": "দ্রুত",

        // Common Verbs & Conjugations
        "jete": "যেতে",
        "parbo": "পারব",
        "parbona": "পারব না",
        "parbe": "পারবে",
        "parbena": "পারবে না",
        "parben": "পারবেন",
        "parbenna": "পারবেন না",
        "hobe": "হবে",
        "hobena": "হবে না",
        "hobe?": "হবে?",
        "hoye": "হয়ে",
        "hoyeche": "হয়েছে",
        "hoyni": "হয়নি",
        "korte": "করতে",
        "korbo": "করব",
        "korbona": "করব না",
        "koro": "করো",
        "koren": "করেন",
        "korben": "করবেন",
        "kore": "করে",
        "koresi": "করেছি",
        "korechi": "করেছি",
        "korenni": "করেননি",
        "korsi": "করেছি",
        "jani": "জানি",
        "janina": "জানি না",
        "janen": "জানেন",
        "jano": "জানো",
        "jabo": "যাব",
        "jaben": "যাবেন",
        "jawa": "যাওয়া",
        "jacchi": "যাচ্ছি",
        "gelam": "গেলাম",
        "gechi": "গেছি",
        "geche": "গেছে",
        "gele": "গেলে",
        "ashbo": "আসব",
        "ashben": "আসবেন",
        "asho": "আসো",
        "ashun": "আসুন",
        "ashte": "আসতে",
        "ashche": "আসছে",
        "elam": "এলাম",
        "eshechi": "এসেছি",
        "bolbo": "বলব",
        "bolte": "বলতে",
        "bolo": "বলো",
        "bolen": "বলেন",
        "bolben": "বলবেন",
        "bollam": "বললাম",
        "dekha": "দেখা",
        "dekhe": "দেখে",
        "dekho": "দেখো",
        "dekhun": "দেখুন",
        "dekhbo": "দেখব",
        "pathate": "পাঠাতে",
        "pathabo": "পাঠাব",
        "pathaite": "পাঠাতে",
        "pathiye": "পাঠিয়ে",
        "pathaben": "পাঠাবেন",
        "dibo": "দেব",
        "debo": "দেব",
        "dao": "দাও",
        "nite": "নিতে",
        "nebo": "নেব",
        "nibo": "নেব",
        "nen": "নেন",
        "nao": "নাও",
        "thakbo": "থাকব",
        "thaken": "থাকেন",
        "thako": "থাকো",
        "thakte": "থাকতে",
        "ache": "আছে",
        "achen": "আছেন",
        "acho": "আছো",
        "achi": "আছি",
        "nei": "নেই",
        "chilo": "ছিল",
        "chhilam": "ছিলাম",
        "chilam": "ছিলাম",
        "bujhte": "বুঝতে",
        "bujhi": "বুঝি",
        "bujhina": "বুঝি না",
        "bujhechi": "বুঝেছি",
        "shunte": "শুনতে",
        "shunbo": "শুনব",
        "shuno": "শুনো",
        "shunun": "শুনুন",

        // Question & Conjunction Words
        "ki": "কি",
        "keno": "কেন",
        "kivabe": "কিভাবে",
        "kothay": "কোথায়",
        "kobe": "কবে",
        "koto": "কত",
        "kemon": "কেমন",
        "kar": "কার",
        "kintu": "কিন্তু",
        "ebong": "এবং",
        "ar": "আর",
        "othoba": "অথবা",
        "karon": "কারণ",
        "jodi": "যদি",
        "tobe": "তবে",
        "tai": "তাই",
        "ba": "বা",
        "nahole": "তাহলে",
        "tahole": "তাহলে",

        // Courtesy, Relations, Everyday Words
        "vai": "ভাই",
        "bhai": "ভাই",
        "bhaiya": "ভাইয়া",
        "apu": "আপু",
        "dada": "দাদা",
        "didi": "দিদি",
        "sir": "স্যার",
        "madam": "ম্যাডাম",
        "bondhu": "বন্ধু",
        "shobai": "সবাই",
        "shobar": "সবার",
        "bhalo": "ভালো",
        "kharap": "খারাপ",
        "shundor": "সুন্দর",
        "thik": "ঠিক",
        "bhul": "ভুল",
        "dhonnobad": "ধন্যবাদ",
        "shagotom": "স্বাগতম",
        "salam": "সালাম",
        "nomoshkar": "নমস্কার",
        "plz": "দয়া করে",
        "please": "দয়া করে",
        "sorry": "দুঃখিত",
        "welcome": "স্বাগতম",
        "shomossha": "সমস্যা",
        "somossa": "সমস্যা",
        "kaj": "কাজ",
        "kajta": "কাজটা",
        "kajti": "কাজটি",
        "office": "অফিস",
        "basha": "বাসা",
        "bari": "বাড়ি",
        "dokan": "দোকান",
        "taka": "টাকা",
        "poisa": "পয়সা",
        "product": "প্রোডাক্ট",
        "productta": "প্রোডাক্টটা",
        "message": "মেসেজ",
        "phone": "ফোন",
        "number": "নম্বর",
        "somoy": "সময়",
        "shathe": "সাথে",
        "jonno": "জন্য",
        "moto": "মতো",
        "shob": "সব",
        "kichu": "কিছু",
        "ektu": "একটু",
        "onek": "অনেক",
        "khub": "খুব",
        "beshi": "বেশি",
        "kom": "কম",
        "matro": "মাত্র",
        "sudhu": "শুধু",
        "shudhu": "শুধু",
        "abar": "আবার",
        "aro": "আরও",
        "ar o": "আরও",
        "sob": "সব",
        "na": "না",
        "ha": "হ্যাঁ",
        "hae": "হ্যাঁ",
        "ji": "জি",
        "jee": "জি",
        "ok": "ঠিক আছে",
        "thikache": "ঠিক আছে",
        "thik ache": "ঠিক আছে",
        "ta": "তা",
        "to": "তো",
        "ti": "টি",
        "te": "তে",
        "gulo": "গুলো",
        "gulor": "গুলোর",
        "khana": "খানা",
        "khani": "খানি"
    ]

    // MARK: - Phonetic Transliteration Fallback
    // Converted character by character using standard Avro/Bangla phonetic maps
    private static let vowels: [String: String] = [
        "aa": "আ", "a": "অ", "i": "ই", "ee": "ঈ", "u": "উ", "oo": "ঊ",
        "rri": "ঋ", "e": "এ", "oi": "ঐ", "o": "ও", "ou": "ঔ"
    ]

    private static let vowelKars: [String: String] = [
        "aa": "া", "i": "ি", "ee": "ী", "u": "ু", "oo": "ূ",
        "rri": "ৃ", "e": "ে", "oi": "ৈ", "o": "ো", "ou": "ৌ"
    ]

    private static let consonants: [(String, String)] = [
        ("kkh", "ক্ষ"), ("kkhyo", "ক্ষ"),
        ("kh", "খ"), ("gh", "ঘ"), ("ng", "ঙ"),
        ("chh", "ছ"), ("ch", "চ"), ("jh", "ঝ"),
        ("th", "থ"), ("dh", "ধ"), ("bh", "ভ"),
        ("ph", "ফ"), ("sh", "শ"), ("ss", "স"),
        ("k", "ক"), ("g", "গ"), ("j", "জ"),
        ("t", "ত"), ("d", "দ"), ("n", "ন"),
        ("p", "প"), ("f", "ফ"), ("b", "ব"),
        ("v", "ভ"), ("m", "ম"), ("r", "র"),
        ("l", "ল"), ("s", "স"), ("h", "হ"),
        ("y", "য়"), ("z", "য"), ("w", "ও")
    ]

    // MARK: - Main Converter
    public static func convert(text: String, mode: ToneMode = .natural) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        // Split text by lines
        let lines = trimmed.components(separatedBy: "\n")
        var convertedLines: [String] = []

        for line in lines {
            let words = tokenize(line)
            var convertedWords: [String] = []

            for token in words {
                if isPunctuationOrSymbol(token) {
                    convertedWords.append(convertPunctuation(token))
                } else if isPreservedEntity(token) {
                    convertedWords.append(token)
                } else {
                    let banglaWord = convertWord(token.lowercased())
                    convertedWords.append(banglaWord)
                }
            }

            var lineResult = assembleLine(tokens: convertedWords)
            lineResult = applyToneAdjustments(text: lineResult, mode: mode)
            convertedLines.append(lineResult)
        }

        var result = convertedLines.joined(separator: "\n")
        // Ensure standard punctuation
        if !result.hasSuffix("।") && !result.hasSuffix("?") && !result.hasSuffix("!") {
            if result.contains("?") || text.contains("?") {
                result += "?"
            } else {
                result += "।"
            }
        }
        return result
    }

    // MARK: - Word Level Conversion
    private static func convertWord(_ word: String) -> String {
        // 1. Direct dictionary match
        if let direct = dictionary[word] {
            return direct
        }

        // 2. Compound suffix handling (e.g. "product-ta", "kaj-ta", "kaj-ti")
        for suffix in ["ta", "ti", "gulo", "ke", "er", "te", "e", "ra"] {
            if word.hasSuffix(suffix) && word.count > suffix.count + 2 {
                let base = String(word.dropLast(suffix.count))
                if let baseBangla = dictionary[base] {
                    let suffixBangla = convertSuffix(suffix)
                    return baseBangla + suffixBangla
                }
            }
        }

        // 3. Phonetic transliteration parser
        return phoneticTransliterate(word)
    }

    private static func convertSuffix(_ suffix: String) -> String {
        switch suffix {
        case "ta": return "টা"
        case "ti": return "টি"
        case "gulo": return "গুলো"
        case "ke": return "কে"
        case "er": return "ের"
        case "te": return "তে"
        case "e": return "ে"
        case "ra": return "রা"
        default: return ""
        }
    }

    // MARK: - Phonetic Transliteration Algorithm
    private static func phoneticTransliterate(_ input: String) -> String {
        var output = ""
        var idx = input.startIndex
        var isWordStart = true

        while idx < input.endIndex {
            var matched = false

            // Try 2-char consonant
            let remaining = String(input[idx...])
            for (pattern, bangla) in consonants {
                if remaining.hasPrefix(pattern) {
                    output += bangla
                    idx = input.index(idx, offsetBy: pattern.count)
                    matched = true
                    isWordStart = false

                    // Check if followed by vowel
                    if idx < input.endIndex {
                        let afterConsonant = String(input[idx...])
                        var vowelMatched = false
                        for (vPattern, kar) in [("aa", "া"), ("ee", "ী"), ("oo", "ূ"), ("oi", "ৈ"), ("ou", "ৌ"),
                                                ("i", "ি"), ("u", "ু"), ("e", "ে"), ("o", "ো"), ("a", "")] {
                            if afterConsonant.hasPrefix(vPattern) {
                                output += kar
                                idx = input.index(idx, offsetBy: vPattern.count)
                                vowelMatched = true
                                break
                            }
                        }
                        if !vowelMatched && !afterConsonant.isEmpty {
                            // Inherent vowel or conjunct
                        }
                    }
                    break
                }
            }

            if matched { continue }

            // Try vowels at word start
            if isWordStart {
                for (vPattern, banglaVowel) in [("aa", "আ"), ("ee", "ঈ"), ("oo", "ঊ"), ("oi", "ঐ"), ("ou", "ঔ"),
                                                ("a", "অ"), ("i", "ই"), ("u", "উ"), ("e", "এ"), ("o", "ও")] {
                    if remaining.hasPrefix(vPattern) {
                        output += banglaVowel
                        idx = input.index(idx, offsetBy: vPattern.count)
                        matched = true
                        isWordStart = false
                        break
                    }
                }
            }

            if matched { continue }

            // Single character fallback
            let char = input[idx]
            output.append(char)
            idx = input.index(after: idx)
            isWordStart = false
        }

        return output
    }

    // MARK: - Helpers
    private static func tokenize(_ line: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for char in line {
            if char.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else if [",", ".", "?", "!", ":", ";", "(", ")", "\"", "'"].contains(char) {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(String(char))
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }

    private static func isPunctuationOrSymbol(_ str: String) -> Bool {
        return str.count == 1 && [",", ".", "?", "!", ":", ";", "(", ")", "\"", "'", "।"].contains(str.first!)
    }

    private static func convertPunctuation(_ punc: String) -> String {
        if punc == "." { return "।" }
        return punc
    }

    private static func isPreservedEntity(_ str: String) -> Bool {
        // URLs, emails, numbers
        if str.hasPrefix("http://") || str.hasPrefix("https://") || str.contains("@") {
            return true
        }
        if str.allSatisfy({ $0.isNumber }) {
            return true
        }
        return false
    }

    private static func assembleLine(tokens: [String]) -> String {
        var line = ""
        for (i, token) in tokens.enumerated() {
            if isPunctuationOrSymbol(token) {
                line += token
            } else {
                if i > 0 && !line.hasSuffix(" ") && !line.hasSuffix("(") && !line.hasSuffix("\"") {
                    line += " "
                }
                line += token
            }
        }
        return line
    }

    private static func applyToneAdjustments(text: String, mode: ToneMode) -> String {
        var result = text
        switch mode {
        case .polite:
            result = result.replacingOccurrences(of: " তুমি ", with: " আপনি ")
            result = result.replacingOccurrences(of: " তোমার ", with: " আপনার ")
            result = result.replacingOccurrences(of: " পারবা ", with: " পারবেন ")
            result = result.replacingOccurrences(of: " করো ", with: " করুন ")
            result = result.replacingOccurrences(of: " বলো ", with: " বলুন ")
            result = result.replacingOccurrences(of: " ভাই ", with: " ভাইয়া, ")
            result = result.replacingOccurrences(of: " আপু ", with: " আপু, ")
        case .formal:
            result = result.replacingOccurrences(of: "আজকে", with: "আজ")
            result = result.replacingOccurrences(of: "কালকে", with: "আগামীকাল")
            result = result.replacingOccurrences(of: "দেরি", with: "বিলম্ব")
            result = result.replacingOccurrences(of: "তাড়াতাড়ি", with: "দ্রুত")
        default:
            break
        }
        return result
    }
}
