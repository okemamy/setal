import AppKit
import SwiftUI

/// Langues disponibles. Chaque nom est écrit dans sa propre langue.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en, fr, es, pt, de, it, nl, ru, tr, ar, ja, ko
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .system: String(localized: "Langue du système")
        case .en: "English"
        case .fr: "Français"
        case .es: "Español"
        case .pt: "Português"
        case .de: "Deutsch"
        case .it: "Italiano"
        case .nl: "Nederlands"
        case .ru: "Русский"
        case .tr: "Türkçe"
        case .ar: "العربية"
        case .ja: "日本語"
        case .ko: "한국어"
        case .zhHans: "简体中文"
        case .zhHant: "繁體中文"
        }
    }

    static var current: AppLanguage {
        guard let override = UserDefaults.standard.persistentDomain(
            forName: Bundle.main.bundleIdentifier ?? "")?["AppleLanguages"] as? [String],
              let code = override.first
        else { return .system }
        return AppLanguage(rawValue: code) ?? AppLanguage(rawValue: String(code.prefix(2))) ?? .system
    }

    func apply() {
        if self == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        }
    }
}

struct SettingsView: View {
    @State private var language = AppLanguage.current
    private let launchLanguage = AppLanguage.current

    var body: some View {
        Form {
            Picker("Langue", selection: $language) {
                ForEach(AppLanguage.allCases) { Text(verbatim: $0.name).tag($0) }
            }
            .onChange(of: language) { _, newValue in newValue.apply() }

            if language != launchLanguage {
                HStack {
                    Text("La nouvelle langue s'applique au redémarrage.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Redémarrer Setal", action: relaunch)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize()
    }

    private func relaunch() {
        let path = Bundle.main.bundlePath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", path]
        try? process.run()
        NSApplication.shared.terminate(nil)
    }
}
