import Foundation

/// Un dossier régénérable dans un projet : `node_modules`, `build`, `Pods`…
public struct ProjectArtifact: Identifiable, Hashable, Sendable {
    public let path: String
    public let name: String
    public let ecosystem: String
    /// Commande qui le recrée, affichée à l'utilisateur.
    public let restore: String
    public let projectPath: String
    public let lastActivity: Date

    public var id: String { path }
}

/// Trouve les artefacts de build dans un dossier de projets.
///
/// Un dossier n'est retenu que si son nom correspond à une règle ET que le
/// dossier parent contient le fichier qui prouve le type de projet
/// (`node_modules` à côté d'un `package.json`, `build` à côté d'un
/// `pubspec.yaml` ou d'un `build.gradle`…). Un dossier `build` quelconque
/// n'est jamais touché.
public enum ProjectScanner {
    struct Rule {
        let name: String
        let markers: [String]
        let ecosystem: String
        let restore: String
    }

    static let gradle = ["build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts"]

    static let rules: [Rule] = [
        Rule(name: "node_modules", markers: ["package.json"], ecosystem: "Node", restore: "npm install"),
        Rule(name: ".next", markers: ["package.json"], ecosystem: "Next.js", restore: "next build"),
        Rule(name: ".nuxt", markers: ["package.json"], ecosystem: "Nuxt", restore: "nuxt build"),
        Rule(name: ".turbo", markers: ["package.json"], ecosystem: "Turborepo", restore: "turbo run build"),
        Rule(name: ".svelte-kit", markers: ["package.json"], ecosystem: "SvelteKit", restore: "vite build"),
        Rule(name: ".parcel-cache", markers: ["package.json"], ecosystem: "Parcel", restore: "parcel build"),
        Rule(name: ".angular", markers: ["angular.json"], ecosystem: "Angular", restore: "ng build"),
        Rule(name: ".dart_tool", markers: ["pubspec.yaml"], ecosystem: "Flutter", restore: "flutter pub get"),
        Rule(name: "build", markers: ["pubspec.yaml"], ecosystem: "Flutter", restore: "flutter build"),
        Rule(name: "build", markers: gradle, ecosystem: "Gradle", restore: "./gradlew build"),
        Rule(name: ".gradle", markers: gradle, ecosystem: "Gradle", restore: "./gradlew build"),
        Rule(name: ".cxx", markers: gradle, ecosystem: "Android NDK", restore: "./gradlew build"),
        Rule(name: "Pods", markers: ["Podfile"], ecosystem: "CocoaPods", restore: "pod install"),
        Rule(name: ".build", markers: ["Package.swift"], ecosystem: "SwiftPM", restore: "swift build"),
        Rule(name: "target", markers: ["Cargo.toml"], ecosystem: "Rust", restore: "cargo build"),
        Rule(name: "target", markers: ["pom.xml"], ecosystem: "Maven", restore: "mvn package"),
    ]

    static let artifactNames = Set(rules.map(\.name))

    /// Dossiers jamais parcourus.
    static let skipped: Set<String> = ["Library", "Applications", "Pictures", "Movies", "Music",
                                       "site-packages", "vendor", "venv"]

    public static func scan(root: String, maxDepth: Int = 8) -> [ProjectArtifact] {
        var found: [ProjectArtifact] = []
        visit(URL(fileURLWithPath: PathGuard.expand(root)).standardizedFileURL, depth: 0,
              maxDepth: maxDepth, into: &found)
        return found
    }

    private static func visit(_ directory: URL, depth: Int, maxDepth: Int, into found: inout [ProjectArtifact]) {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys) else { return }
        let siblings = Set(children.map(\.lastPathComponent))

        for child in children {
            let values = try? child.resourceValues(forKeys: Set(keys))
            guard values?.isDirectory == true, values?.isSymbolicLink != true else { continue }
            let name = child.lastPathComponent

            if let rule = matchingRule(name: name, siblings: siblings) {
                found.append(ProjectArtifact(
                    path: child.path, name: name, ecosystem: rule.ecosystem, restore: rule.restore,
                    projectPath: directory.path,
                    lastActivity: lastActivity(of: directory, markers: rule.markers)))
                continue
            }
            if name.hasPrefix(".") || skipped.contains(name) || artifactNames.contains(name) { continue }
            if depth + 1 < maxDepth {
                visit(child, depth: depth + 1, maxDepth: maxDepth, into: &found)
            }
        }
    }

    static func matchingRule(name: String, siblings: Set<String>) -> Rule? {
        rules.first { $0.name == name && $0.markers.contains(where: siblings.contains) }
    }

    /// Date la plus récente entre le dossier du projet et ses fichiers marqueurs.
    static func lastActivity(of project: URL, markers: [String]) -> Date {
        let candidates = [project] + markers.map { project.appendingPathComponent($0) }
        return candidates.compactMap {
            try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        }.max() ?? .distantPast
    }

    /// Revérifie juste avant suppression que le dossier est toujours un artefact
    /// reconnu, dans le home, hors de ~/Library, et pas un lien symbolique.
    public static func isStillArtifact(_ path: String, home: String = PathGuard.home) -> Bool {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard url.path.hasPrefix(home + "/"),
              !url.path.hasPrefix(home + "/Library/"),
              !url.pathComponents.contains("site-packages"),
              (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true
        else { return false }
        let parent = url.deletingLastPathComponent()
        let siblings = Set((try? FileManager.default.contentsOfDirectory(atPath: parent.path)) ?? [])
        return matchingRule(name: url.lastPathComponent, siblings: siblings) != nil
    }

    /// Dossier de projets par défaut : le premier qui existe.
    public static func suggestedRoot(home: String = PathGuard.home) -> String {
        let candidates = ["Codes", "Code", "Developer", "Projects", "projects", "dev", "src",
                          "workspace", "StudioProjects", "Documents/GitHub"]
        return candidates.map { home + "/" + $0 }
            .first { FileManager.default.fileExists(atPath: $0) } ?? home
    }
}
