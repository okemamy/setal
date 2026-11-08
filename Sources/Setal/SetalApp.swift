import AppKit
import SwiftUI

@main
struct SetalApp: App {
    @StateObject private var model = CleanerModel()

    init() {
        // Lancée via `swift run`, l'app doit se déclarer comme app normale
        // pour avoir une fenêtre au premier plan et une icône dans le Dock.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    /// Sens de lecture de la langue réellement chargée (arabe : droite à gauche).
    static let layoutDirection: LayoutDirection = {
        let language = Bundle.main.preferredLocalizations.first ?? "en"
        return Locale.characterDirection(forLanguage: language) == .rightToLeft ? .rightToLeft : .leftToRight
    }()

    var body: some Scene {
        WindowGroup("Setal") {
            ContentView()
                .environmentObject(model)
                .environment(\.layoutDirection, Self.layoutDirection)
                .onAppear { NSApplication.shared.activate(ignoringOtherApps: true) }
        }
        .defaultSize(width: 880, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                if Links.donate != nil {
                    Button("Soutenir Setal…") { Links.openDonate() }
                }
            }
            CommandMenu("Nettoyage") {
                Button("Analyser") { Task { await model.scan() } }
                    .keyboardShortcut("r")
                    .disabled(model.isBusy)
            }
        }

        Settings {
            SettingsView()
                .environment(\.layoutDirection, Self.layoutDirection)
        }
    }
}
