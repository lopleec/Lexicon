import SwiftUI

@main
struct LexiconApp: App {
    @StateObject private var settings: SettingsStore
    @StateObject private var viewModel: ChatViewModel
    @StateObject private var localization: LocalizationStore

    init() {
        let localizationStore = LocalizationStore.shared
        _localization = StateObject(wrappedValue: localizationStore)

        let settingsStore = SettingsStore()
        _settings = StateObject(wrappedValue: settingsStore)
        _viewModel = StateObject(wrappedValue: ChatViewModel(settings: settingsStore))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .id(localization.appLanguage)
                .environmentObject(localization)
                .environment(\.locale, localization.locale)
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            SidebarCommands()
        }

        Settings {
            SettingsPanelView(settings: settings)
                .id(localization.appLanguage)
                .environmentObject(localization)
                .environment(\.locale, localization.locale)
                .frame(minWidth: 860, minHeight: 680)
        }
        .defaultSize(width: 980, height: 760)
    }
}
