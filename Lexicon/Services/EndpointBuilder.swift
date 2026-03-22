import Foundation

enum EndpointError: LocalizedError {
    case invalidBaseURL

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return L10n.text("error.endpoint.invalid_base_url")
        }
    }
}

struct EndpointBuilder {
    private static let invisibleScalars = CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{2060}\u{FEFF}")

    static func buildURL(baseURL: String, apiType: APIType) throws -> URL {
        var candidate = normalize(baseURL: baseURL)
        candidate = candidate.isEmpty ? "https://api.openai.com" : candidate

        if !candidate.contains("://") {
            candidate = "https://" + candidate
        }

        // Handle duplicated schemes such as "https://https://api.openai.com"
        while candidate.lowercased().hasPrefix("https://https://") {
            candidate.removeFirst("https://".count)
        }
        while candidate.lowercased().hasPrefix("http://http://") {
            candidate.removeFirst("http://".count)
        }

        guard var components = URLComponents(string: candidate) else {
            throw EndpointError.invalidBaseURL
        }
        guard let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty else {
            throw EndpointError.invalidBaseURL
        }

        let endpointPath = apiType.endpointPath
        var path = components.path
        if path.isEmpty || path == "/" {
            path = "/v1"
        }

        if path.hasSuffix(endpointPath) {
            path.removeLast(endpointPath.count)
        }
        while path.hasSuffix("/") && path.count > 1 {
            path.removeLast()
        }

        components.path = path
        components.query = nil
        components.fragment = nil

        guard let base = components.url else {
            throw EndpointError.invalidBaseURL
        }

        return base.appendingPathComponent(endpointPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    private static func normalize(baseURL: String) -> String {
        var candidate = baseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

        // Normalize common full-width punctuation copied from Chinese input methods.
        candidate = candidate
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "／", with: "/")
            .replacingOccurrences(of: "。", with: ".")
            .replacingOccurrences(of: "．", with: ".")
            .replacingOccurrences(of: "﹕", with: ":")

        // Strip invisible characters and whitespace that can break DNS resolution.
        candidate = candidate.unicodeScalars
            .filter { scalar in
                !CharacterSet.whitespacesAndNewlines.contains(scalar) && !invisibleScalars.contains(scalar)
            }
            .map(String.init)
            .joined()

        return candidate
    }
}
