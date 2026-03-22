import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var selectedSessionID: UUID?
    @Published var messages: [ChatMessage] = [] {
        didSet {
            syncMessagesToCurrentSession()
        }
    }
    @Published var draftText = ""
    @Published var draftImages: [ImageAttachment] = []
    @Published var isSending = false
    @Published var errorMessage: String?

    let settings: SettingsStore

    private let client = OpenAIClient()
    private var sendTasksBySessionID: [UUID: Task<Void, Never>] = [:]
    private var sendingSessionIDs = Set<UUID>()
    private var sessionErrors: [UUID: String] = [:]

    private var persistTask: Task<Void, Never>?
    private var isApplyingSessionMessages = false

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(settings: SettingsStore) {
        self.settings = settings
        loadSessions()
    }

    deinit {
        sendTasksBySessionID.values.forEach { $0.cancel() }
        persistTask?.cancel()
    }

    var currentSessionTitle: String {
        currentSession()?.title ?? defaultSessionTitle
    }

    func sendCurrentMessage() {
        guard let sessionID = selectedSessionID else { return }
        guard !sendingSessionIDs.contains(sessionID) else { return }

        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        let images = draftImages
        guard !text.isEmpty || !images.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text, images: images)
        appendMessage(userMessage, to: sessionID)
        updateSessionTitleIfNeeded(using: userMessage, in: sessionID)

        draftText = ""
        draftImages.removeAll()
        sessionErrors[sessionID] = nil
        refreshDerivedStateForSelection()

        let requestMessages = outboundMessages(for: userMessage, in: sessionID)
        let assistantID = UUID()
        appendMessage(ChatMessage(id: assistantID, role: .assistant, content: "", isStreaming: true), to: sessionID)

        let snapshot = settings.snapshot()
        sendingSessionIDs.insert(sessionID)
        refreshDerivedStateForSelection()

        let task = Task { [weak self] in
            guard let self else { return }
            defer {
                self.markSessionSendFinished(sessionID: sessionID)
            }

            do {
                try await self.client.streamReply(settings: snapshot, messages: requestMessages) { [weak self] delta in
                    self?.appendAssistantDelta(delta, to: assistantID, in: sessionID)
                }
                self.finishAssistant(assistantID: assistantID, in: sessionID)
            } catch is CancellationError {
                self.finishAssistant(assistantID: assistantID, in: sessionID)
            } catch {
                self.failAssistant(error: error, assistantID: assistantID, in: sessionID)
            }
        }

        sendTasksBySessionID[sessionID] = task
    }

    func cancelCurrentRequest() {
        guard let sessionID = selectedSessionID else { return }
        sendTasksBySessionID[sessionID]?.cancel()
        markSessionSendFinished(sessionID: sessionID)
        finalizeStreamingState(in: sessionID)
    }

    func clearConversation() {
        guard let sessionID = selectedSessionID else { return }
        cancelCurrentRequest()
        mutateSession(id: sessionID) { session in
            session.messages.removeAll()
        }
        sessionErrors[sessionID] = nil
        refreshDerivedStateForSelection()
    }

    func createSession() {
        let session = ChatSession(title: defaultSessionTitle)
        sessions.insert(session, at: 0)
        selectedSessionID = session.id
        applySessionMessages([])
        draftText = ""
        draftImages.removeAll()
        refreshDerivedStateForSelection()

        persistSessionsDebounced()
    }

    func selectSession(_ id: UUID) {
        guard selectedSessionID != id else { return }
        guard let session = sessions.first(where: { $0.id == id }) else { return }

        selectedSessionID = id
        applySessionMessages(session.messages)
        draftText = ""
        draftImages.removeAll()
        refreshDerivedStateForSelection()

        persistSessionsDebounced()
    }

    func renameCurrentSession(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmed.isEmpty ? defaultSessionTitle : trimmed
        guard let index = currentSessionIndex() else { return }
        sessions[index].title = finalTitle
        sessions[index].updatedAt = Date()
        persistSessionsDebounced()
    }

    func deleteSession(_ id: UUID) {
        sendTasksBySessionID[id]?.cancel()
        sendTasksBySessionID[id] = nil
        sendingSessionIDs.remove(id)
        sessionErrors.removeValue(forKey: id)

        sessions.removeAll { $0.id == id }

        if sessions.isEmpty {
            let session = ChatSession(title: defaultSessionTitle)
            sessions = [session]
            selectedSessionID = session.id
            applySessionMessages([])
        } else if selectedSessionID == id {
            selectedSessionID = sessions[0].id
            applySessionMessages(sessions[0].messages)
        }

        refreshDerivedStateForSelection()
        persistSessionsDebounced()
    }

    func deleteCurrentSession() {
        guard let id = selectedSessionID else { return }
        deleteSession(id)
    }

    func openImagePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif, .heic, .bmp, .tiff, .webP]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            let selected = panel.urls.compactMap(ImageAttachment.fromURL)
            draftImages.append(contentsOf: selected)
        }
    }

    func removeDraftImage(_ image: ImageAttachment) {
        draftImages.removeAll { $0.id == image.id }
    }

    private func outboundMessages(for latestUserMessage: ChatMessage, in sessionID: UUID) -> [OutboundMessage] {
        let source: [ChatMessage]
        if settings.useContext, let session = sessions.first(where: { $0.id == sessionID }) {
            source = session.messages.filter {
                ($0.role == .user || $0.role == .assistant) && !$0.isStreaming
            }
        } else {
            source = [latestUserMessage]
        }

        return source.map {
            OutboundMessage(role: $0.role, text: $0.content, images: $0.images)
        }
    }

    private func appendAssistantDelta(_ delta: String, to assistantID: UUID, in sessionID: UUID) {
        mutateSession(id: sessionID, markUpdatedAt: false, persist: false) { session in
            guard let index = session.messages.firstIndex(where: { $0.id == assistantID }) else { return }
            session.messages[index].content += delta
        }
    }

    private func finishAssistant(assistantID: UUID, in sessionID: UUID) {
        mutateSession(id: sessionID) { session in
            guard let index = session.messages.firstIndex(where: { $0.id == assistantID }) else { return }
            session.messages[index].isStreaming = false
            if session.messages[index].content.isEmpty {
                session.messages[index].content = ""
            }
        }
    }

    private func failAssistant(error: Error, assistantID: UUID, in sessionID: UUID) {
        let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        sessionErrors[sessionID] = description
        refreshDerivedStateForSelection()

        mutateSession(id: sessionID) { session in
            guard let index = session.messages.firstIndex(where: { $0.id == assistantID }) else { return }
            session.messages[index].isStreaming = false
            if session.messages[index].content.isEmpty {
                session.messages[index].content = L10n.format("error.message_prefix", description)
            }
        }
    }

    private func markSessionSendFinished(sessionID: UUID) {
        sendTasksBySessionID[sessionID] = nil
        sendingSessionIDs.remove(sessionID)
        refreshDerivedStateForSelection()
    }

    private func finalizeStreamingState(in sessionID: UUID) {
        mutateSession(id: sessionID) { session in
            for index in session.messages.indices where session.messages[index].isStreaming {
                session.messages[index].isStreaming = false
            }
        }
    }

    private func appendMessage(_ message: ChatMessage, to sessionID: UUID) {
        mutateSession(id: sessionID) { session in
            session.messages.append(message)
        }
    }

    private func updateSessionTitleIfNeeded(using message: ChatMessage, in sessionID: UUID) {
        guard message.role == .user else { return }
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }

        let existing = sessions[index].title.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldAutoName = existing.isEmpty || legacyDefaultSessionTitles.contains(existing)
        guard shouldAutoName else { return }

        let candidate: String
        if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            candidate = message.content
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            candidate = imageSessionTitle
        }

        sessions[index].title = String(candidate.prefix(36))
        sessions[index].updatedAt = Date()
        persistSessionsDebounced()
    }

    private func mutateSession(
        id sessionID: UUID,
        markUpdatedAt: Bool = true,
        persist: Bool = true,
        _ mutate: (inout ChatSession) -> Void
    ) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        mutate(&sessions[index])
        if markUpdatedAt {
            sessions[index].updatedAt = Date()
        }

        if selectedSessionID == sessionID {
            applySessionMessages(sessions[index].messages)
        }

        if persist {
            persistSessionsDebounced()
        }
    }

    private func refreshDerivedStateForSelection() {
        guard let selected = selectedSessionID else {
            isSending = false
            errorMessage = nil
            return
        }

        isSending = sendingSessionIDs.contains(selected)
        errorMessage = sessionErrors[selected]
    }

    private func currentSession() -> ChatSession? {
        guard let id = selectedSessionID else { return nil }
        return sessions.first(where: { $0.id == id })
    }

    private func currentSessionIndex() -> Int? {
        guard let id = selectedSessionID else { return nil }
        return sessions.firstIndex(where: { $0.id == id })
    }

    private func applySessionMessages(_ newMessages: [ChatMessage]) {
        isApplyingSessionMessages = true
        messages = newMessages
        isApplyingSessionMessages = false
    }

    private func syncMessagesToCurrentSession() {
        guard !isApplyingSessionMessages else { return }
        guard let index = currentSessionIndex() else { return }
        sessions[index].messages = messages
        sessions[index].updatedAt = Date()
        persistSessionsDebounced()
    }

    private func loadSessions() {
        if let data = defaults.data(forKey: "chatSessions"),
           let decoded = try? decoder.decode([ChatSession].self, from: data),
           !decoded.isEmpty {
            sessions = decoded.map { session in
                var normalized = session
                normalized.messages = normalized.messages.map { message in
                    var copy = message
                    copy.isStreaming = false
                    return copy
                }
                return normalized
            }
        } else {
            sessions = [ChatSession(title: defaultSessionTitle)]
        }

        if let selected = defaults.string(forKey: "selectedSessionID"),
           let id = UUID(uuidString: selected),
           sessions.contains(where: { $0.id == id }) {
            selectedSessionID = id
        } else {
            selectedSessionID = sessions.first?.id
        }

        applySessionMessages(currentSession()?.messages ?? [])
        refreshDerivedStateForSelection()
    }

    private func persistSessionsDebounced() {
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self else { return }
            self.persistSessionsNow()
        }
    }

    private func persistSessionsNow() {
        guard let data = try? encoder.encode(sessions) else { return }
        defaults.set(data, forKey: "chatSessions")
        defaults.set(selectedSessionID?.uuidString, forKey: "selectedSessionID")
    }

    private var defaultSessionTitle: String {
        L10n.text("session.default_title")
    }

    private var imageSessionTitle: String {
        L10n.text("session.image_title")
    }

    private var legacyDefaultSessionTitles: Set<String> {
        [
            defaultSessionTitle,
            "新会话",
            "New Chat",
        ]
    }
}
