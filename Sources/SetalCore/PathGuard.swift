import Foundation

/// Garde-fou : Setal ne supprime jamais rien en dehors de `~/Library/…` ou d'un
/// dossier caché du home (`~/.gradle/…`, `~/.android/…`), et jamais un dossier
/// de premier niveau lui-même. Deux exceptions étroites :
/// - vider `~/.Trash` et `~/.cache` (le contenu, pas le dossier) ;
/// - mettre à la Corbeille (récupérable) un installeur posé dans `~/Downloads`.
public enum PathGuard {
    public static var home: String {
        FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
    }

    public static let installerExtensions: Set<String> = ["dmg", "pkg", "xip", "ipsw", "iso"]

    public static func expand(_ path: String, home: String = PathGuard.home) -> String {
        if path == "~" { return home }
        if path.hasPrefix("~/") { return home + String(path.dropFirst(1)) }
        return path
    }

    static func standardize(_ path: String, home: String) -> String {
        URL(fileURLWithPath: expand(path, home: home)).standardizedFileURL.path
    }

    /// Composants du chemin relatifs au home, ou `nil` s'il est en dehors.
    static func relativeComponents(_ path: String, home: String) -> [Substring]? {
        let standardized = standardize(path, home: home)
        guard standardized.hasPrefix(home + "/") else { return nil }
        return standardized.dropFirst(home.count + 1).split(separator: "/")
    }

    public static func isSafeToDelete(_ path: String, home: String = PathGuard.home) -> Bool {
        guard let components = relativeComponents(path, home: home) else { return false }
        // Au moins deux niveaux : ~/Library/Caches oui, ~/Library non.
        guard components.count >= 2, let top = components.first else { return false }
        guard top == "Library" || top.hasPrefix(".") else { return false }
        // Les dossiers « build » de pip ressemblent à des artefacts mais n'en sont pas.
        if components.contains("site-packages") { return false }
        return true
    }

    /// Dossier dont on peut supprimer le contenu (chaque enfant reste vérifié).
    public static func isSafeContainer(_ path: String, home: String = PathGuard.home) -> Bool {
        let standardized = standardize(path, home: home)
        if standardized == home + "/.Trash" || standardized == home + "/.cache" { return true }
        return isSafeToDelete(path, home: home)
    }

    /// Mise à la Corbeille : récupérable, donc on autorise aussi les installeurs
    /// rangés directement dans ~/Downloads.
    public static func isSafeToTrash(_ path: String, home: String = PathGuard.home) -> Bool {
        if isSafeToDelete(path, home: home) { return true }
        let url = URL(fileURLWithPath: standardize(path, home: home))
        return url.deletingLastPathComponent().path == home + "/Downloads"
            && installerExtensions.contains(url.pathExtension.lowercased())
    }
}
