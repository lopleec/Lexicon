import AppKit
import Foundation

struct CodeHighlighter {
    private static let maxHighlightLength = 24_000

    private static let highlightCache: NSCache<NSString, NSAttributedString> = {
        let cache = NSCache<NSString, NSAttributedString>()
        cache.countLimit = 300
        cache.totalCostLimit = 12_000_000
        return cache
    }()

    private static let keywordRegexLock = NSLock()
    private static var keywordRegexCache: [String: NSRegularExpression] = [:]

    private static let numberRegex = try? NSRegularExpression(pattern: #"\b\d+(?:\.\d+)?\b"#)
    private static let stringDoubleQuoteRegex = try? NSRegularExpression(pattern: #"\"(?:\\.|[^\"\\])*\""#)
    private static let stringSingleQuoteRegex = try? NSRegularExpression(pattern: #"'(?:\\.|[^'\\])*'"#)
    private static let slashCommentRegex = try? NSRegularExpression(pattern: #"//.*"#)
    private static let hashCommentRegex = try? NSRegularExpression(pattern: #"#.*"#)
    private static let blockCommentRegex = try? NSRegularExpression(pattern: #"/\*[\s\S]*?\*/"#)

    static func highlight(code: String, language: String?) -> AttributedString {
        if code.isEmpty {
            return AttributedString("")
        }

        if code.utf16.count > maxHighlightLength {
            return plainCode(code)
        }

        let languageKey = normalizedLanguage(language)
        let cacheKey = "\(languageKey)|\(code)" as NSString
        if let cached = highlightCache.object(forKey: cacheKey) {
            return AttributedString(cached)
        }

        let font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
        let base = NSMutableAttributedString(
            string: code,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.white.withAlphaComponent(0.92),
            ]
        )

        let namespace = code as NSString

        let keywordColor = NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.27, alpha: 1.0)
        let stringColor = NSColor(calibratedRed: 0.63, green: 0.85, blue: 0.50, alpha: 1.0)
        let numberColor = NSColor(calibratedRed: 0.56, green: 0.72, blue: 1.00, alpha: 1.0)
        let commentColor = NSColor(calibratedRed: 0.61, green: 0.61, blue: 0.61, alpha: 1.0)

        apply(regex: numberRegex, color: numberColor, to: base, text: namespace)

        apply(regex: stringDoubleQuoteRegex, color: stringColor, to: base, text: namespace)
        apply(regex: stringSingleQuoteRegex, color: stringColor, to: base, text: namespace)

        apply(regex: keywordRegex(for: languageKey), color: keywordColor, to: base, text: namespace)

        apply(regex: slashCommentRegex, color: commentColor, to: base, text: namespace)
        apply(regex: hashCommentRegex, color: commentColor, to: base, text: namespace)
        apply(regex: blockCommentRegex, color: commentColor, to: base, text: namespace)

        let immutable = NSAttributedString(attributedString: base)
        highlightCache.setObject(immutable, forKey: cacheKey, cost: code.utf16.count)
        return AttributedString(immutable)
    }

    private static func apply(regex: NSRegularExpression?, color: NSColor, to text: NSMutableAttributedString, text content: NSString) {
        guard let regex else { return }
        let range = NSRange(location: 0, length: content.length)
        for match in regex.matches(in: content as String, options: [], range: range) {
            text.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }

    private static func normalizedLanguage(_ language: String?) -> String {
        language?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }

    private static func keywordRegex(for languageKey: String) -> NSRegularExpression? {
        keywordRegexLock.lock()
        if let cached = keywordRegexCache[languageKey] {
            keywordRegexLock.unlock()
            return cached
        }
        keywordRegexLock.unlock()

        guard let built = try? NSRegularExpression(pattern: keywordPattern(for: languageKey), options: []) else {
            return nil
        }

        keywordRegexLock.lock()
        keywordRegexCache[languageKey] = built
        keywordRegexLock.unlock()
        return built
    }

    private static func keywordPattern(for languageKey: String) -> String {
        let keywords: [String]

        switch languageKey {
        case "swift":
            keywords = ["import", "let", "var", "func", "class", "struct", "enum", "if", "else", "guard", "return", "switch", "case", "for", "while", "try", "catch", "throw", "async", "await", "in", "where", "extension", "protocol", "init", "private", "fileprivate", "public", "internal"]
        case "python", "py":
            keywords = ["def", "class", "import", "from", "if", "elif", "else", "return", "for", "while", "try", "except", "finally", "with", "as", "lambda", "pass", "break", "continue", "None", "True", "False"]
        case "json":
            keywords = ["true", "false", "null"]
        case "javascript", "js", "typescript", "ts":
            keywords = ["const", "let", "var", "function", "class", "if", "else", "return", "for", "while", "switch", "case", "break", "continue", "import", "export", "from", "async", "await", "try", "catch", "throw", "new", "this", "null", "undefined"]
        case "bash", "sh", "zsh", "shell":
            keywords = ["if", "then", "else", "fi", "for", "do", "done", "case", "esac", "function", "local", "export", "return", "while", "in"]
        default:
            keywords = ["if", "else", "for", "while", "return", "class", "struct", "func", "let", "var", "import", "from", "def", "const", "switch", "case", "break", "continue", "try", "catch", "throw"]
        }

        let escaped = keywords.map(NSRegularExpression.escapedPattern(for:))
        return #"\b(?:"# + escaped.joined(separator: "|") + #")\b"#
    }

    private static func plainCode(_ code: String) -> AttributedString {
        AttributedString(
            NSAttributedString(
                string: code,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular),
                    .foregroundColor: NSColor.white.withAlphaComponent(0.92),
                ]
            )
        )
    }
}
