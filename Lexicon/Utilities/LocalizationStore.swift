import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        L10n.text(displayNameKey)
    }

    fileprivate var displayNameKey: String {
        switch self {
        case .system:
            return "language.option.system"
        case .simplifiedChinese:
            return "language.option.zh_hans"
        case .english:
            return "language.option.en"
        }
    }

    fileprivate var lprojName: String? {
        switch self {
        case .system:
            return nil
        case .simplifiedChinese:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }

    fileprivate var locale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        case .english:
            return Locale(identifier: "en")
        }
    }
}

final class LocalizationStore: ObservableObject {
    static let shared = LocalizationStore()

    @Published var appLanguage: AppLanguage {
        didSet {
            guard oldValue != appLanguage else { return }
            defaults.set(appLanguage.rawValue, forKey: Keys.appLanguage)
        }
    }

    var locale: Locale {
        appLanguage.locale
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let appLanguage = "appLanguage"
    }

    private init() {
        if let raw = defaults.string(forKey: Keys.appLanguage),
           let language = AppLanguage(rawValue: raw) {
            appLanguage = language
        } else {
            appLanguage = .system
        }
    }

    func localizedString(forKey key: String, tableName: String = "Localizable") -> String {
        let bundle = activeBundle
        let localized = NSLocalizedString(key, tableName: tableName, bundle: bundle, value: key, comment: "")

        if localized == key, bundle != .main {
            return NSLocalizedString(key, tableName: tableName, bundle: .main, value: key, comment: "")
        }
        return localized
    }

    private var activeBundle: Bundle {
        guard let lprojName = appLanguage.lprojName else { return .main }
        guard let path = Bundle.main.path(forResource: lprojName, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}
