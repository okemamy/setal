import Foundation

/// Garde-fou : Setal ne supprime jamais rien en dehors de `~/Library/…` ou d'un
/// dossier caché du home (`~/.gradle/…`, `~/.android/…`), et jamais un dossier
/// de premier niveau lui-même.
public enum PathGuard {
    public static var home: String {
        FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
    }

    public static func expand(_ path: String, home: String = PathGuard.home) -> String {
        if path == "~" { return home }
        if path.hasPrefix("~/") { return home + String(path.dropFirst(1)) }
        return path
    }

    public static func isSafeToDelete(_ path: String, home: String = PathGuard.home) -> Bool {
        let standardized = URL(fileURLWithPath: expand(path, home: home)).standardizedFileURL.path
        guard standardized.hasPrefix(home + "/") else { return false }

        let components = standardized.dropFirst(home.count + 1).split(separator: "/")
        // Au moins deux niveaux : ~/Library/Caches oui, ~/Library non.
        guard components.count >= 2, let top = components.first else { return false }
        guard top == "Library" || top.hasPrefix(".") else { return false }
        // Les dossiers « build » de pip ressemblent à des artefacts mais n'en sont pas.
        if standardized.contains("/site-packages/") { return false }
        return true
    }
}
