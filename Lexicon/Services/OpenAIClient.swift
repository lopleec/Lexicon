import Foundation

struct OutboundMessage {
    let role: ChatRole
    let text: String
    let images: [ImageAttachment]
}

enum OpenAIClientError: LocalizedError {
    case missingAPIKey
    case missingModel
    case invalidResponse
    case cannotFindHost(String)
    case cannotConnectToHost(String)
    case timeout
    case offline
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return L10n.text("error.openai.missing_api_key")
        case .missingModel:
            return L10n.text("error.openai.missing_model")
        case .invalidResponse:
            return L10n.text("error.openai.invalid_response")
        case let .cannotFindHost(host):
            return L10n.format("error.network.cannot_find_host", host)
        case let .cannotConnectToHost(host):
            return L10n.format("error.network.cannot_connect_host", host)
        case .timeout:
            return L10n.text("error.network.timeout")
        case .offline:
            return L10n.text("error.network.offline")
        case let .apiError(message):
            return message
        }
    }
}

final class OpenAIClient {
    private let decoder = JSONDecoder()

    func streamReply(
        settings: SettingsSnapshot,
        messages: [OutboundMessage],
        onDelta: @escaping @MainActor (String) -> Void
    ) async throws {
        let key = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw OpenAIClientError.missingAPIKey
        }

        let model = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else {
            throw OpenAIClientError.missingModel
        }

        let url = try EndpointBuilder.buildURL(baseURL: settings.baseURL, apiType: settings.apiType)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let body: [String: Any]
        switch settings.apiType {
        case .chatCompletions:
            body = makeChatCompletionsBody(settings: settings, messages: messages, model: model)
        case .responses:
            body = makeResponsesBody(settings: settings, messages: messages, model: model)
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        if settings.stream {
            try await streamRequest(request, apiType: settings.apiType, onDelta: onDelta)
        } else {
            let text = try await oneShotRequest(request, apiType: settings.apiType)
            onDelta(text)
        }
    }

    private func oneShotRequest(_ request: URLRequest, apiType: APIType) async throws -> String {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw mapTransportError(error, request: request)
        }

        guard let http = response as? HTTPURLResponse else {
            throw OpenAIClientError.invalidResponse
        }

        guard (200 ... 299).contains(http.statusCode) else {
            throw mapAPIError(data: data, statusCode: http.statusCode)
        }

        switch apiType {
        case .chatCompletions:
            let parsed = try decoder.decode(ChatCompletionsResponse.self, from: data)
            return parsed.choices.first?.message.content ?? ""
        case .responses:
            let parsed = try decoder.decode(ResponsesResponse.self, from: data)
            if let outputText = parsed.outputText, !outputText.isEmpty {
                return outputText
            }
            return parsed.output
                .flatMap { $0.content }
                .filter { $0.type == "output_text" || $0.type == "text" }
                .compactMap { $0.text }
                .joined()
        }
    }

    private func streamRequest(
        _ request: URLRequest,
        apiType: APIType,
        onDelta: @escaping @MainActor (String) -> Void
    ) async throws {
        let bytes: URLSession.AsyncBytes
        let response: URLResponse

        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch {
            throw mapTransportError(error, request: request)
        }

        guard let http = response as? HTTPURLResponse else {
            throw OpenAIClientError.invalidResponse
        }

        guard (200 ... 299).contains(http.statusCode) else {
            var data = Data()
            for try await line in bytes.lines {
                if line.hasPrefix("data:") {
                    let raw = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                    if raw != "[DONE]", let lineData = raw.data(using: .utf8) {
                        data.append(lineData)
                        data.append(Data([0x0A]))
                    }
                }
            }
            throw mapAPIError(data: data, statusCode: http.statusCode)
        }

        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.hasPrefix("data:") else {
                continue
            }

            let payload = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" {
                break
            }

            guard let data = payload.data(using: .utf8) else {
                continue
            }

            switch apiType {
            case .chatCompletions:
                if let chunk = try? decoder.decode(ChatCompletionsStreamChunk.self, from: data),
                   let delta = chunk.choices.first?.delta.content,
                   !delta.isEmpty {
                    onDelta(delta)
                }
            case .responses:
                if let chunk = try? decoder.decode(ResponsesStreamChunk.self, from: data) {
                    if chunk.type == "response.output_text.delta", let delta = chunk.delta, !delta.isEmpty {
                        onDelta(delta)
                    }

                    if chunk.type == "response.delta", let nested = chunk.deltaObject {
                        let possible = nested.outputTextDelta
                        if !possible.isEmpty {
                            onDelta(possible)
                        }
                    }
                }
            }
        }
    }

    private func makeChatCompletionsBody(settings: SettingsSnapshot, messages: [OutboundMessage], model: String) -> [String: Any] {
        var payloadMessages: [[String: Any]] = []
        let resolvedSystemPrompt = effectiveSystemPrompt(settings: settings, model: model)

        if !resolvedSystemPrompt.isEmpty {
            payloadMessages.append([
                "role": "system",
                "content": resolvedSystemPrompt,
            ])
        }

        payloadMessages.append(contentsOf: messages.map { message in
            if message.images.isEmpty {
                return [
                    "role": message.role.rawValue,
                    "content": message.text,
                ]
            }

            var parts: [[String: Any]] = []
            if !message.text.isEmpty {
                parts.append([
                    "type": "text",
                    "text": message.text,
                ])
            }
            parts.append(contentsOf: message.images.map { image in
                [
                    "type": "image_url",
                    "image_url": ["url": image.dataURL],
                ]
            })

            return [
                "role": message.role.rawValue,
                "content": parts,
            ]
        })

        return [
            "model": model,
            "messages": payloadMessages,
            "temperature": settings.temperature,
            "top_p": settings.topP,
            "stream": settings.stream,
        ]
    }

    private func makeResponsesBody(settings: SettingsSnapshot, messages: [OutboundMessage], model: String) -> [String: Any] {
        var input: [[String: Any]] = []
        let resolvedSystemPrompt = effectiveSystemPrompt(settings: settings, model: model)

        if !resolvedSystemPrompt.isEmpty {
            input.append([
                "role": "system",
                "content": [[
                    "type": "input_text",
                    "text": resolvedSystemPrompt,
                ]],
            ])
        }

        input.append(contentsOf: messages.map { message in
            var content: [[String: Any]] = []

            if !message.text.isEmpty {
                content.append([
                    "type": "input_text",
                    "text": message.text,
                ])
            }

            content.append(contentsOf: message.images.map { image in
                [
                    "type": "input_image",
                    "image_url": image.dataURL,
                ]
            })

            return [
                "role": message.role.rawValue,
                "content": content,
            ]
        })

        return [
            "model": model,
            "input": input,
            "temperature": settings.temperature,
            "top_p": settings.topP,
            "stream": settings.stream,
        ]
    }

    private func effectiveSystemPrompt(settings: SettingsSnapshot, model: String) -> String {
        let visiblePrompt = settings.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let hiddenPrompt = """
        [Lexicon Runtime Metadata]
        active_model_id: \(model)
        """

        if visiblePrompt.isEmpty {
            return hiddenPrompt
        }

        return "\(visiblePrompt)\n\n\(hiddenPrompt)"
    }

    private func mapAPIError(data: Data, statusCode: Int) -> OpenAIClientError {
        if let parsed = try? decoder.decode(OpenAIErrorEnvelope.self, from: data),
           let message = parsed.error.message {
            return .apiError("\(statusCode): \(message)")
        }

        if let body = String(data: data, encoding: .utf8) {
            let lines = body
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

            for line in lines where !line.isEmpty {
                let normalized = line.hasPrefix("data:") ? String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces) : line
                guard let lineData = normalized.data(using: .utf8) else { continue }
                if let parsed = try? decoder.decode(OpenAIErrorEnvelope.self, from: lineData),
                   let message = parsed.error.message {
                    return .apiError("\(statusCode): \(message)")
                }
            }
        }

        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return .apiError("\(statusCode): \(text)")
        }

        return .apiError(L10n.format("error.openai.request_failed_status", statusCode))
    }

    private func mapTransportError(_ error: Error, request: URLRequest) -> OpenAIClientError {
        if let endpointError = error as? EndpointError {
            return .apiError(endpointError.localizedDescription)
        }

        guard let urlError = error as? URLError else {
            return .apiError(error.localizedDescription)
        }

        let host = request.url?.host ?? request.url?.absoluteString ?? ""
        switch urlError.code {
        case .cannotFindHost, .dnsLookupFailed:
            return .cannotFindHost(host)
        case .cannotConnectToHost, .networkConnectionLost:
            return .cannotConnectToHost(host)
        case .timedOut:
            return .timeout
        case .notConnectedToInternet:
            return .offline
        default:
            return .apiError(urlError.localizedDescription)
        }
    }
}

private struct OpenAIErrorEnvelope: Decodable {
    struct ErrorBody: Decodable {
        let message: String?
    }

    let error: ErrorBody
}

private struct ChatCompletionsResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct ChatCompletionsStreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
        }

        let delta: Delta
    }

    let choices: [Choice]
}

private struct ResponsesResponse: Decodable {
    struct OutputItem: Decodable {
        struct ContentItem: Decodable {
            let type: String
            let text: String?
        }

        let content: [ContentItem]
    }

    let outputText: String?
    let output: [OutputItem]

    enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let directText = try? container.decodeIfPresent(String.self, forKey: .outputText) {
            outputText = directText
        } else if let textArray = try? container.decodeIfPresent([String].self, forKey: .outputText) {
            outputText = textArray.joined()
        } else {
            outputText = nil
        }
        output = try container.decodeIfPresent([OutputItem].self, forKey: .output) ?? []
    }
}

private struct ResponsesStreamChunk: Decodable {
    struct DeltaObject: Decodable {
        let outputText: [OutputTextDelta]?

        enum CodingKeys: String, CodingKey {
            case outputText = "output_text"
        }

        struct OutputTextDelta: Decodable {
            let text: String?
        }

        var outputTextDelta: String {
            outputText?.compactMap(\.text).joined() ?? ""
        }
    }

    let type: String
    let delta: String?
    let deltaObject: DeltaObject?

    enum CodingKeys: String, CodingKey {
        case type
        case delta
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)

        if let deltaText = try? container.decode(String.self, forKey: .delta) {
            delta = deltaText
            deltaObject = nil
        } else if let object = try? container.decode(DeltaObject.self, forKey: .delta) {
            delta = nil
            deltaObject = object
        } else {
            delta = nil
            deltaObject = nil
        }
    }
}
