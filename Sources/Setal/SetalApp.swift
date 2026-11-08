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

    var body: some Scene {
        WindowGroup("Setal") {
            ContentView()
                .environmentObject(model)
                .onAppear { NSApplication.shared.activate(ignoringOtherApps: true) }
        }
        .defaultSize(width: 880, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Nettoyage") {
                Button("Analyser") { Task { await model.scan() } }
                    .keyboardShortcut("r")
                    .disabled(model.isBusy)
            }
        }
    }
}
