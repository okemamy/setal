import AppKit
import SwiftUI

/// Langues disponibles. Chaque nom est écrit dans sa propre langue.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, fr, en, es, pt

    var id: String { rawValue }

    var name: String {
        switch self {
        case .system: String(localized: "Langue du système")
        case .fr: "Français"
        case .en: "English"
        case .es: "Español"
        case .pt: "Português"
        }
    }

    static var current: AppLanguage {
        guard let override = UserDefaults.standard.persistentDomain(
            forName: Bundle.main.bundleIdentifier ?? "")?["AppleLanguages"] as? [String],
              let code = override.first?.prefix(2)
        else { return .system }
        return AppLanguage(rawValue: String(code)) ?? .system
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
