import Foundation

enum L10n {
    static func text(_ key: String) -> String {
        LocalizationStore.shared.localizedString(forKey: key)
    }

    static func format(_ key: String, _ args: CVarArg...) -> String {
        let format = text(key)
        return String(format: format, locale: LocalizationStore.shared.locale, arguments: args)
    }
}
