import SwiftUI

struct SettingsPanelView: View {
    @ObservedObject var settings: SettingsStore
    @EnvironmentObject private var localization: LocalizationStore

    @State private var selectedPage: SettingsPage? = .general
    @State private var newProviderNameInput = ""
    @State private var newModelNameInput = ""

    @State private var providerDeleteTarget: ProviderConfig?
    @State private var modelDeleteTarget: ModelDeleteTarget?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .background(Theme.background)
        .alert(
            L10n.text("settings.alert.delete_provider.title"),
            isPresented: Binding(
                get: { providerDeleteTarget != nil },
                set: { isPresented in
                    if !isPresented {
                        providerDeleteTarget = nil
                    }
                }
            )
        ) {
            Button(L10n.text("common.cancel"), role: .cancel) {
                providerDeleteTarget = nil
            }
            Button(L10n.text("common.delete"), role: .destructive) {
                if let id = providerDeleteTarget?.id {
                    settings.removeProvider(id: id)
                }
                providerDeleteTarget = nil
            }
        } message: {
            Text(
                L10n.format(
                    "settings.alert.delete_provider.message",
                    providerDeleteTarget?.name ?? L10n.text("provider.default_name")
                )
            )
        }
        .alert(
            L10n.text("settings.alert.delete_model.title"),
            isPresented: Binding(
                get: { modelDeleteTarget != nil },
                set: { isPresented in
                    if !isPresented {
                        modelDeleteTarget = nil
                    }
                }
            )
        ) {
            Button(L10n.text("common.cancel"), role: .cancel) {
                modelDeleteTarget = nil
            }
            Button(L10n.text("common.delete"), role: .destructive) {
                if let target = modelDeleteTarget {
                    settings.removeModel(providerID: target.providerID, modelID: target.model.id)
                }
                modelDeleteTarget = nil
            }
        } message: {
            Text(
                L10n.format(
                    "settings.alert.delete_model.message",
                    modelDeleteTarget?.model.name ?? ""
                )
            )
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(SettingsMenuSection.allCases) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.text(section.titleKey))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 2)

                        VStack(spacing: 6) {
                            ForEach(section.pages) { page in
                                sidebarItem(page)
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Theme.surface)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Theme.border)
                .frame(width: 1)
                .allowsHitTesting(false)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
    }

    private func sidebarItem(_ page: SettingsPage) -> some View {
        let isSelected = (selectedPage ?? .general) == page

        return Button {
            selectedPage = page
        } label: {
            HStack(spacing: 8) {
                Image(systemName: page.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 14)
                Text(L10n.text(page.titleKey))
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(isSelected ? Theme.surfaceElevated : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Theme.accent.opacity(0.45) : Theme.border.opacity(0.45), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                titleBlock

                switch selectedPage ?? .general {
                case .general:
                    generalIdentityCard
                    systemPromptCard
                    generationCard
                case .language:
                    languageCard
                case .providers:
                    providerListCard
                    providerConfigCard
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(Theme.background)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text((selectedPage ?? .general).titleKey))
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(L10n.text((selectedPage ?? .general).subtitleKey))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.bottom, 4)
    }

    private var generalIdentityCard: some View {
        PanelCard(title: L10n.text("settings.card.general")) {
            VStack(alignment: .leading, spacing: 8) {
                field(title: L10n.text("settings.field.username")) {
                    TextField(
                        L10n.text("settings.username.placeholder"),
                        text: $settings.username
                    )
                }

                Text(L10n.text("settings.username.hint"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var languageCard: some View {
        PanelCard(title: L10n.text("settings.card.language")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("settings.field.app_language"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)

                Picker(L10n.text("settings.field.app_language"), selection: $localization.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)

                Text(L10n.text("settings.language.hint"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var providerListCard: some View {
        PanelCard(title: L10n.text("settings.card.provider_list")) {
            VStack(alignment: .leading, spacing: 10) {
                if settings.providers.isEmpty {
                    Text(L10n.text("settings.providers.empty"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ForEach(settings.providers) { provider in
                        let activeModelName: String? = {
                            guard settings.activeProviderID == provider.id else { return nil }
                            return provider.models.first(where: { $0.id == settings.activeModelID })?.name
                        }()

                        ProviderRowView(
                            provider: provider,
                            activeModelName: activeModelName,
                            isSelected: provider.id == settings.selectedProviderID,
                            onSelect: { settings.selectProvider(provider.id) },
                            onDelete: { providerDeleteTarget = provider }
                        )
                    }
                }

                Divider()
                    .overlay(Theme.border.allowsHitTesting(false))

                HStack(spacing: 8) {
                    TextField(L10n.text("settings.provider.add.placeholder"), text: $newProviderNameInput)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Theme.surfaceStrong)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Theme.border, lineWidth: 1)
                                .allowsHitTesting(false)
                        )

                    Button(L10n.text("settings.provider.add.button")) {
                        settings.addProvider(name: newProviderNameInput)
                        newProviderNameInput = ""
                    }
                    .buttonStyle(.plain)
                    .modifier(ActionButtonStyle(background: Theme.accent, foreground: .white))
                }

                HStack(spacing: 8) {
                    Button(L10n.text("settings.provider.remove_current")) {
                        providerDeleteTarget = settings.selectedProvider
                    }
                    .buttonStyle(.plain)
                    .modifier(ActionButtonStyle(background: Theme.surfaceStrong, foreground: Theme.textPrimary))

                    Spacer()
                }
            }
        }
    }

    private var providerConfigCard: some View {
        PanelCard(title: L10n.text("settings.card.provider_config")) {
            if let provider = settings.selectedProvider {
                VStack(alignment: .leading, spacing: 12) {
                    field(title: L10n.text("settings.field.provider_name")) {
                        TextField(
                            L10n.text("provider.default_name"),
                            text: Binding(
                                get: { settings.selectedProvider?.name ?? "" },
                                set: { settings.updateSelectedProviderName($0) }
                            )
                        )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.text("settings.field.api_type"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Picker(
                            L10n.text("settings.field.api_type"),
                            selection: Binding(
                                get: { settings.selectedProvider?.apiType ?? .responses },
                                set: { settings.updateSelectedProviderAPIType($0) }
                            )
                        ) {
                            ForEach(APIType.allCases) { item in
                                Text(item.displayName).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    field(title: L10n.text("settings.field.api_key")) {
                        SecureField(
                            "sk-...",
                            text: Binding(
                                get: { settings.selectedProvider?.apiKey ?? "" },
                                set: { settings.updateSelectedProviderAPIKey($0) }
                            )
                        )
                    }

                    field(title: L10n.text("settings.field.base_url")) {
                        TextField(
                            "https://api.openai.com",
                            text: Binding(
                                get: { settings.selectedProvider?.baseURL ?? "" },
                                set: { settings.updateSelectedProviderBaseURL($0) }
                            )
                        )
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .foregroundStyle(Theme.accent)
                        Text(endpointPreview)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.text("settings.field.models"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)

                        if provider.models.isEmpty {
                            Text(L10n.text("settings.models.empty"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            ForEach(provider.models) { model in
                                ProviderModelRowView(
                                    model: model,
                                    isActive: settings.activeProviderID == provider.id && settings.activeModelID == model.id,
                                    onUse: { settings.selectActiveModel(providerID: provider.id, modelID: model.id) },
                                    onDelete: {
                                        modelDeleteTarget = ModelDeleteTarget(providerID: provider.id, model: model)
                                    }
                                )
                            }
                        }

                        HStack(spacing: 8) {
                            TextField(L10n.text("settings.model.add.placeholder"), text: $newModelNameInput)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Theme.surfaceStrong)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Theme.border, lineWidth: 1)
                                        .allowsHitTesting(false)
                                )

                            Button(L10n.text("settings.model.add.button")) {
                                settings.addModelToSelectedProvider(name: newModelNameInput)
                                newModelNameInput = ""
                            }
                            .buttonStyle(.plain)
                            .modifier(ActionButtonStyle(background: Theme.accent, foreground: .white))
                        }
                    }
                }
            } else {
                Text(L10n.text("settings.providers.empty"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var generationCard: some View {
        PanelCard(title: L10n.text("settings.card.generation")) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $settings.stream) {
                    Text(L10n.text("settings.toggle.stream"))
                        .foregroundStyle(Theme.textPrimary)
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)

                Toggle(isOn: $settings.useContext) {
                    Text(L10n.text("settings.toggle.context"))
                        .foregroundStyle(Theme.textPrimary)
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)

                sliderRow(title: L10n.text("settings.slider.temperature"), value: $settings.temperature, range: 0 ... 2)
                sliderRow(title: L10n.text("settings.slider.top_p"), value: $settings.topP, range: 0 ... 1)
            }
        }
    }

    private var systemPromptCard: some View {
        PanelCard(title: L10n.text("settings.card.answer_preference")) {
            TextEditor(text: $settings.systemPrompt)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .frame(minHeight: 160)
                .padding(8)
                .background(Theme.surfaceStrong)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                        .allowsHitTesting(false)
                )
        }
    }

    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            content()
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Theme.surfaceStrong)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                        .allowsHitTesting(false)
                )
        }
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }
            Slider(value: value, in: range)
                .tint(Theme.accent)
        }
    }

    private var endpointPreview: String {
        guard let provider = settings.selectedProvider else {
            return L10n.text("settings.base_url.invalid")
        }

        do {
            return try EndpointBuilder.buildURL(baseURL: provider.baseURL, apiType: provider.apiType).absoluteString
        } catch {
            return L10n.text("settings.base_url.invalid")
        }
    }
}

private struct ModelDeleteTarget {
    let providerID: UUID
    let model: ProviderModel
}

private enum SettingsPage: String, CaseIterable, Identifiable {
    case general
    case language
    case providers

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .general:
            return "settings.page.general.title"
        case .language:
            return "settings.page.language.title"
        case .providers:
            return "settings.page.providers.title"
        }
    }

    var subtitleKey: String {
        switch self {
        case .general:
            return "settings.page.general.subtitle"
        case .language:
            return "settings.page.language.subtitle"
        case .providers:
            return "settings.page.providers.subtitle"
        }
    }

    var icon: String {
        switch self {
        case .general:
            return "slider.horizontal.3"
        case .language:
            return "globe"
        case .providers:
            return "network"
        }
    }
}

private enum SettingsMenuSection: String, CaseIterable, Identifiable {
    case workspace
    case model

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .workspace:
            return "settings.menu.workspace"
        case .model:
            return "settings.menu.model"
        }
    }

    var pages: [SettingsPage] {
        switch self {
        case .workspace:
            return [.general, .language]
        case .model:
            return [.providers]
        }
    }
}

private struct ProviderRowView: View {
    let provider: ProviderConfig
    let activeModelName: String?
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Text(modelSummary)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)

                Text(provider.apiType.displayName)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary.opacity(0.8))
            }

            Spacer()

            Button(L10n.text("common.apply"), action: onSelect)
                .buttonStyle(.plain)
                .modifier(ActionButtonStyle(background: Theme.surfaceStrong, foreground: Theme.textPrimary, compact: true))

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.plain)
            .modifier(ActionButtonStyle(background: Theme.surfaceStrong, foreground: Theme.textPrimary, compact: true))
        }
        .padding(8)
        .background(isSelected ? Theme.surfaceElevated : Theme.surfaceStrong.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: 1)
                .allowsHitTesting(false)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture(perform: onSelect)
    }

    private var modelSummary: String {
        if let activeModelName {
            return "\(activeModelName) • \(provider.models.count)"
        }

        if let first = provider.models.first?.name {
            return "\(first) • \(provider.models.count)"
        }

        return L10n.text("settings.models.empty")
    }
}

private struct ProviderModelRowView: View {
    let model: ProviderModel
    let isActive: Bool
    let onUse: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                if isActive {
                    Text(L10n.text("settings.model.active"))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                }
            }

            Spacer()

            Button(L10n.text("common.apply"), action: onUse)
                .buttonStyle(.plain)
                .modifier(ActionButtonStyle(background: Theme.surfaceStrong, foreground: Theme.textPrimary, compact: true))

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.plain)
            .modifier(ActionButtonStyle(background: Theme.surfaceStrong, foreground: Theme.textPrimary, compact: true))
        }
        .padding(8)
        .background(isActive ? Theme.surfaceElevated : Theme.surfaceStrong.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isActive ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: 1)
                .allowsHitTesting(false)
        )
    }
}

private struct ActionButtonStyle: ViewModifier {
    let background: Color
    let foreground: Color
    var compact = false

    func body(content: Content) -> some View {
        content
            .font(.system(size: compact ? 11 : 12, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, compact ? 8 : 10)
            .frame(height: compact ? 24 : 30)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
                    .allowsHitTesting(false)
            )
    }
}

private struct PanelCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.accent)
            content
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
                .allowsHitTesting(false)
        )
    }
}
