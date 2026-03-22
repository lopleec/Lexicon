import Combine
import Foundation

enum APIType: String, CaseIterable, Identifiable, Codable {
    case chatCompletions = "Chat Completions"
    case responses = "Responses"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chatCompletions:
            return L10n.text("api.type.chat_completions")
        case .responses:
            return L10n.text("api.type.responses")
        }
    }

    var endpointPath: String {
        switch self {
        case .chatCompletions:
            return "/chat/completions"
        case .responses:
            return "/responses"
        }
    }
}

struct ProviderModel: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

struct ProviderConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var apiType: APIType
    var apiKey: String
    var baseURL: String
    var models: [ProviderModel]

    init(
        id: UUID = UUID(),
        name: String,
        apiType: APIType = .responses,
        apiKey: String = "",
        baseURL: String = "https://api.openai.com",
        models: [ProviderModel] = [ProviderModel(name: "gpt-4.1-mini")]
    ) {
        self.id = id
        self.name = name
        self.apiType = apiType
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.models = models.isEmpty ? [ProviderModel(name: "gpt-4.1-mini")] : models
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case apiType
        case apiKey
        case baseURL
        case models
        case model
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? L10n.text("provider.default_name")
        apiType = try container.decodeIfPresent(APIType.self, forKey: .apiType) ?? .responses
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? "https://api.openai.com"

        if let decodedModels = try container.decodeIfPresent([ProviderModel].self, forKey: .models),
           !decodedModels.isEmpty {
            models = decodedModels
        } else if let legacyModel = try container.decodeIfPresent(String.self, forKey: .model),
                  !legacyModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            models = [ProviderModel(name: legacyModel)]
        } else {
            models = [ProviderModel(name: "gpt-4.1-mini")]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(apiType, forKey: .apiType)
        try container.encode(apiKey, forKey: .apiKey)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(models, forKey: .models)
    }
}

struct ProviderModelOption: Identifiable, Hashable {
    let providerID: UUID
    let providerName: String
    let apiType: APIType
    let apiKey: String
    let baseURL: String
    let modelID: UUID
    let modelName: String

    var id: String {
        "\(providerID.uuidString)|\(modelID.uuidString)"
    }

    var displayName: String {
        "\(providerName) · \(modelName)"
    }
}

struct SettingsSnapshot {
    let providerName: String
    let apiType: APIType
    let apiKey: String
    let baseURL: String
    let model: String
    let systemPrompt: String
    let temperature: Double
    let topP: Double
    let stream: Bool
    let useContext: Bool
}

final class SettingsStore: ObservableObject {
    @Published var providers: [ProviderConfig]
    @Published var selectedProviderID: UUID?
    @Published var activeProviderID: UUID?
    @Published var activeModelID: UUID?

    @Published var systemPrompt: String
    @Published var username: String
    @Published var temperature: Double
    @Published var topP: Double
    @Published var stream: Bool
    @Published var useContext: Bool

    private var cancellables = Set<AnyCancellable>()
    private let defaults = UserDefaults.standard
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private var isEnsuringSelectionIntegrity = false

    init() {
        let loadedProviders = Self.loadProviders(decoder: decoder, defaults: defaults)
        let initialProviders = loadedProviders.isEmpty ? [Self.defaultProvider] : loadedProviders

        let initialSelectedProviderID: UUID?
        if let selected = defaults.string(forKey: Keys.selectedProviderID),
           let id = UUID(uuidString: selected),
           initialProviders.contains(where: { $0.id == id }) {
            initialSelectedProviderID = id
        } else {
            initialSelectedProviderID = initialProviders.first?.id
        }

        let initialActiveProviderID: UUID?
        if let active = defaults.string(forKey: Keys.activeProviderID),
           let id = UUID(uuidString: active) {
            initialActiveProviderID = id
        } else {
            initialActiveProviderID = initialSelectedProviderID
        }

        let initialActiveModelID: UUID?
        if let activeModel = defaults.string(forKey: Keys.activeModelID),
           let id = UUID(uuidString: activeModel) {
            initialActiveModelID = id
        } else {
            initialActiveModelID = nil
        }

        providers = initialProviders
        selectedProviderID = initialSelectedProviderID
        activeProviderID = initialActiveProviderID
        activeModelID = initialActiveModelID

        systemPrompt = defaults.string(forKey: Keys.systemPrompt) ?? ""
        username = defaults.string(forKey: Keys.username) ?? ""
        temperature = defaults.object(forKey: Keys.temperature) as? Double ?? 0.7
        topP = defaults.object(forKey: Keys.topP) as? Double ?? 1.0
        stream = defaults.object(forKey: Keys.stream) as? Bool ?? true
        useContext = defaults.object(forKey: Keys.useContext) as? Bool ?? true

        ensureSelectionIntegrity()
        wirePersistence()
    }

    var selectedProvider: ProviderConfig? {
        guard let id = selectedProviderID else { return nil }
        return providers.first(where: { $0.id == id })
    }

    var availableModelOptions: [ProviderModelOption] {
        modelOptions(from: providers)
    }

    var activeModelOption: ProviderModelOption? {
        guard let providerID = activeProviderID, let modelID = activeModelID else {
            return availableModelOptions.first
        }
        return availableModelOptions.first {
            $0.providerID == providerID && $0.modelID == modelID
        } ?? availableModelOptions.first
    }

    func selectProvider(_ id: UUID) {
        guard providers.contains(where: { $0.id == id }) else { return }
        selectedProviderID = id
    }

    func selectActiveModel(providerID: UUID, modelID: UUID) {
        guard availableModelOptions.contains(where: { $0.providerID == providerID && $0.modelID == modelID }) else {
            return
        }
        activeProviderID = providerID
        activeModelID = modelID
    }

    func addProvider(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = L10n.format("provider.default_name_indexed", providers.count + 1)
        let finalName = trimmed.isEmpty ? fallbackName : trimmed

        let provider = ProviderConfig(
            name: finalName,
            apiType: .responses,
            apiKey: "",
            baseURL: "https://api.openai.com",
            models: [ProviderModel(name: "gpt-4.1-mini")]
        )

        providers.append(provider)
        selectedProviderID = provider.id
        if activeProviderID == nil || activeModelID == nil {
            activeProviderID = provider.id
            activeModelID = provider.models.first?.id
        }
    }

    func removeProvider(id: UUID) {
        providers.removeAll { $0.id == id }

        if providers.isEmpty {
            let provider = Self.defaultProvider
            providers = [provider]
            selectedProviderID = provider.id
            activeProviderID = provider.id
            activeModelID = provider.models.first?.id
            return
        }

        if selectedProviderID == id {
            selectedProviderID = providers.first?.id
        }

        if activeProviderID == id {
            activeProviderID = providers.first?.id
            activeModelID = providers.first?.models.first?.id
        }
    }

    func removeSelectedProvider() {
        guard let id = selectedProviderID else { return }
        removeProvider(id: id)
    }

    func updateSelectedProviderName(_ value: String) {
        updateSelectedProvider { provider in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            provider.name = trimmed.isEmpty ? L10n.text("provider.default_name") : trimmed
        }
    }

    func updateSelectedProviderAPIType(_ value: APIType) {
        updateSelectedProvider { provider in
            provider.apiType = value
        }
    }

    func updateSelectedProviderAPIKey(_ value: String) {
        updateSelectedProvider { provider in
            provider.apiKey = value
        }
    }

    func updateSelectedProviderBaseURL(_ value: String) {
        updateSelectedProvider { provider in
            provider.baseURL = value
        }
    }

    func addModelToSelectedProvider(name: String) {
        guard let providerID = selectedProviderID else { return }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        updateProvider(id: providerID) { provider in
            let exists = provider.models.contains {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(trimmed) == .orderedSame
            }
            guard !exists else { return }
            provider.models.append(ProviderModel(name: trimmed))
        }

        if activeProviderID == providerID,
           activeModelID == nil,
           let selected = providers.first(where: { $0.id == providerID }),
           let first = selected.models.first {
            activeModelID = first.id
        }
    }

    func removeModelFromSelectedProvider(id: UUID) {
        guard let providerID = selectedProviderID else { return }
        removeModel(providerID: providerID, modelID: id)
    }

    func removeModel(providerID: UUID, modelID: UUID) {
        updateProvider(id: providerID) { provider in
            provider.models.removeAll { $0.id == modelID }
            if provider.models.isEmpty {
                provider.models = [ProviderModel(name: "gpt-4.1-mini")]
            }
        }
    }

    func snapshot() -> SettingsSnapshot {
        let option = activeModelOption ?? availableModelOptions.first ?? Self.defaultOption

        return SettingsSnapshot(
            providerName: option.providerName,
            apiType: option.apiType,
            apiKey: option.apiKey,
            baseURL: option.baseURL,
            model: option.modelName,
            systemPrompt: systemPrompt,
            temperature: temperature,
            topP: topP,
            stream: stream,
            useContext: useContext
        )
    }

    private func wirePersistence() {
        $providers
            .sink { [weak self] providers in
                self?.persistProviders(providers)
                self?.ensureSelectionIntegrity()
            }
            .store(in: &cancellables)

        $selectedProviderID
            .sink { [weak self, defaults] id in
                defaults.set(id?.uuidString, forKey: Keys.selectedProviderID)
                self?.ensureSelectionIntegrity()
            }
            .store(in: &cancellables)

        $activeProviderID
            .sink { [weak self, defaults] id in
                defaults.set(id?.uuidString, forKey: Keys.activeProviderID)
                self?.ensureSelectionIntegrity()
            }
            .store(in: &cancellables)

        $activeModelID
            .sink { [weak self, defaults] id in
                defaults.set(id?.uuidString, forKey: Keys.activeModelID)
                self?.ensureSelectionIntegrity()
            }
            .store(in: &cancellables)

        $systemPrompt
            .sink { [defaults] in defaults.set($0, forKey: Keys.systemPrompt) }
            .store(in: &cancellables)

        $username
            .sink { [defaults] in defaults.set($0, forKey: Keys.username) }
            .store(in: &cancellables)

        $temperature
            .sink { [defaults] in defaults.set($0, forKey: Keys.temperature) }
            .store(in: &cancellables)

        $topP
            .sink { [defaults] in defaults.set($0, forKey: Keys.topP) }
            .store(in: &cancellables)

        $stream
            .sink { [defaults] in defaults.set($0, forKey: Keys.stream) }
            .store(in: &cancellables)

        $useContext
            .sink { [defaults] in defaults.set($0, forKey: Keys.useContext) }
            .store(in: &cancellables)
    }

    private func updateSelectedProvider(_ update: (inout ProviderConfig) -> Void) {
        guard let id = selectedProviderID else { return }
        updateProvider(id: id, update)
    }

    private func updateProvider(id: UUID, _ update: (inout ProviderConfig) -> Void) {
        guard let index = providers.firstIndex(where: { $0.id == id }) else { return }
        var provider = providers[index]
        update(&provider)
        providers[index] = provider
    }

    private func ensureSelectionIntegrity() {
        guard !isEnsuringSelectionIntegrity else { return }
        isEnsuringSelectionIntegrity = true
        defer { isEnsuringSelectionIntegrity = false }

        if providers.isEmpty {
            providers = [Self.defaultProvider]
        }

        providers = providers.map { provider in
            var normalized = provider
            let trimmedName = normalized.name.trimmingCharacters(in: .whitespacesAndNewlines)
            normalized.name = trimmedName.isEmpty ? L10n.text("provider.default_name") : trimmedName

            normalized.models = normalized.models
                .map { model in
                    let trimmedModel = model.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    return ProviderModel(id: model.id, name: trimmedModel.isEmpty ? "gpt-4.1-mini" : trimmedModel)
                }

            if normalized.models.isEmpty {
                normalized.models = [ProviderModel(name: "gpt-4.1-mini")]
            }
            return normalized
        }

        if let selected = selectedProviderID,
           !providers.contains(where: { $0.id == selected }) {
            selectedProviderID = providers.first?.id
        } else if selectedProviderID == nil {
            selectedProviderID = providers.first?.id
        }

        let options = modelOptions(from: providers)
        let isActiveValid = {
            guard let activeProviderID, let activeModelID else { return false }
            return options.contains(where: { $0.providerID == activeProviderID && $0.modelID == activeModelID })
        }()

        if !isActiveValid {
            if let activeProviderID,
               let activeProvider = providers.first(where: { $0.id == activeProviderID }),
               let firstModel = activeProvider.models.first {
                self.activeProviderID = activeProvider.id
                activeModelID = firstModel.id
            } else if let selectedProviderID,
               let provider = providers.first(where: { $0.id == selectedProviderID }),
               let firstModel = provider.models.first {
                activeProviderID = provider.id
                activeModelID = firstModel.id
            } else if let first = options.first {
                activeProviderID = first.providerID
                activeModelID = first.modelID
            }
        }
    }

    private func modelOptions(from providers: [ProviderConfig]) -> [ProviderModelOption] {
        providers.flatMap { provider in
            provider.models.map { model in
                ProviderModelOption(
                    providerID: provider.id,
                    providerName: provider.name,
                    apiType: provider.apiType,
                    apiKey: provider.apiKey,
                    baseURL: provider.baseURL,
                    modelID: model.id,
                    modelName: model.name
                )
            }
        }
    }

    private func persistProviders(_ providers: [ProviderConfig]) {
        guard let data = try? encoder.encode(providers) else { return }
        defaults.set(data, forKey: Keys.providers)
    }

    private static func loadProviders(decoder: JSONDecoder, defaults: UserDefaults) -> [ProviderConfig] {
        if let data = defaults.data(forKey: Keys.providers),
           let decoded = try? decoder.decode([ProviderConfig].self, from: data),
           !decoded.isEmpty {
            return decoded
        }

        let legacyAPIType = APIType(rawValue: defaults.string(forKey: Keys.apiType) ?? "") ?? .responses
        let legacyAPIKey = defaults.string(forKey: Keys.apiKey) ?? ""
        let legacyBaseURL = defaults.string(forKey: Keys.baseURL) ?? "https://api.openai.com"
        let legacyModel = defaults.string(forKey: Keys.model) ?? "gpt-4.1-mini"
        let legacyName = defaults.string(forKey: Keys.providerName) ?? L10n.text("provider.default_name")

        return [
            ProviderConfig(
                name: legacyName,
                apiType: legacyAPIType,
                apiKey: legacyAPIKey,
                baseURL: legacyBaseURL,
                models: [ProviderModel(name: legacyModel)]
            ),
        ]
    }

    private static var defaultProvider: ProviderConfig {
        ProviderConfig(
            name: L10n.text("provider.default_name"),
            apiType: .responses,
            apiKey: "",
            baseURL: "https://api.openai.com",
            models: [ProviderModel(name: "gpt-4.1-mini")]
        )
    }

    private static var defaultOption: ProviderModelOption {
        ProviderModelOption(
            providerID: UUID(),
            providerName: L10n.text("provider.default_name"),
            apiType: .responses,
            apiKey: "",
            baseURL: "https://api.openai.com",
            modelID: UUID(),
            modelName: "gpt-4.1-mini"
        )
    }

    private enum Keys {
        static let providers = "providers"
        static let selectedProviderID = "selectedProviderID"
        static let activeProviderID = "activeProviderID"
        static let activeModelID = "activeModelID"

        // Legacy migration keys
        static let providerName = "providerName"
        static let apiType = "apiType"
        static let apiKey = "apiKey"
        static let baseURL = "baseURL"
        static let model = "model"

        static let systemPrompt = "systemPrompt"
        static let username = "username"
        static let temperature = "temperature"
        static let topP = "topP"
        static let stream = "stream"
        static let useContext = "useContext"
    }
}
