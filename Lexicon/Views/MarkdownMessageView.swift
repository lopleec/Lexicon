import AppKit
import SwiftUI

struct MarkdownMessageView: View {
    let text: String
    private let segments: [MarkdownSegment]

    init(text: String) {
        self.text = text
        segments = MarkdownSegmentParser.parse(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case let .markdown(content):
                    MarkdownTextSegmentView(source: content)
                case let .code(language, code):
                    CodeBlockView(language: language, code: code)
                }
            }
        }
    }
}

private struct MarkdownTextSegmentView: View {
    private let fallback: String
    private let attributed: AttributedString?

    init(source: String) {
        fallback = source
        attributed = try? AttributedString(
            markdown: source,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        )
    }

    var body: some View {
        let trimmed = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            EmptyView()
        } else if let attributed {
            Text(attributed)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.textPrimary)
                .lineSpacing(3)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(fallback)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.textPrimary)
                .lineSpacing(3)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CodeBlockView: View {
    let language: String?
    let code: String
    private let displayLanguage: String
    private let highlightedCode: AttributedString

    @State private var didCopy = false
    @State private var resetCopyStateTask: Task<Void, Never>?

    init(language: String?, code: String) {
        self.language = language
        self.code = code

        let normalizedLanguage = language?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        displayLanguage = normalizedLanguage.isEmpty ? L10n.text("markdown.code_fallback") : normalizedLanguage
        highlightedCode = CodeHighlighter.highlight(code: code, language: normalizedLanguage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(displayLanguage.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.accent)
                Spacer()
                copyButton
            }

            ScrollView(.horizontal, showsIndicators: true) {
                Text(highlightedCode)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(Color.dynamic(light: 0x121212, dark: 0x000000, lightAlpha: 0.92, darkAlpha: 0.32))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .onDisappear {
            resetCopyStateTask?.cancel()
            resetCopyStateTask = nil
        }
    }

    private var copyButton: some View {
        Button(action: copyCodeToClipboard) {
            HStack(spacing: 4) {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                Text(didCopy ? L10n.text("common.copied") : L10n.text("common.copy"))
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(didCopy ? Theme.accent : Theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.surfaceStrong)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(L10n.text("markdown.copy_code_help"))
    }

    @MainActor
    private func copyCodeToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)

        didCopy = true
        resetCopyStateTask?.cancel()
        resetCopyStateTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if Task.isCancelled {
                return
            }
            await MainActor.run {
                didCopy = false
            }
        }
    }
}

private enum MarkdownSegment {
    case markdown(String)
    case code(language: String?, code: String)
}

private enum MarkdownSegmentParser {
    private static let fencedCodeRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"(?s)```([A-Za-z0-9_+\-]*)[ \t]*\n(.*?)```"#)

    static func parse(_ text: String) -> [MarkdownSegment] {
        guard !text.isEmpty else { return [.markdown("")] }

        guard let regex = fencedCodeRegex else {
            return [.markdown(text)]
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)

        if matches.isEmpty {
            return [.markdown(text)]
        }

        var segments: [MarkdownSegment] = []
        var cursor = 0

        for match in matches {
            let matchRange = match.range
            if matchRange.location > cursor {
                let markdownRange = NSRange(location: cursor, length: matchRange.location - cursor)
                let markdown = nsText.substring(with: markdownRange)
                segments.append(.markdown(markdown))
            }

            let language = match.range(at: 1).location != NSNotFound ? nsText.substring(with: match.range(at: 1)) : ""
            let code = match.range(at: 2).location != NSNotFound ? nsText.substring(with: match.range(at: 2)) : ""
            segments.append(.code(language: language.isEmpty ? nil : language, code: code))

            cursor = matchRange.location + matchRange.length
        }

        if cursor < nsText.length {
            let tailRange = NSRange(location: cursor, length: nsText.length - cursor)
            segments.append(.markdown(nsText.substring(with: tailRange)))
        }

        return segments
    }
}
