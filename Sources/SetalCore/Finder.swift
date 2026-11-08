import Foundation

/// Cibles dont la liste de chemins n'est connue qu'à l'exécution.
public enum DynamicTarget: Sendable {
    /// Dossiers portant l'un de ces noms sous `root`, jusqu'à `maxDepth` niveaux.
    /// Les dossiers de premier niveau listés dans `excluding` ne sont pas parcourus.
    case directoriesNamed(Set<String>, under: String, maxDepth: Int, excluding: Set<String>)
    /// Fichiers d'un dossier (sans récursion) ayant l'une de ces extensions.
    case files(extensions: Set<String>, in: String)
    /// Réglages des versions d'IDE remplacées par une version plus récente
    /// (`PyCharm2025.2` quand `PyCharm2026.2` existe).
    case outdatedIDEVersions(roots: [String])
    /// Contenu direct d'un dossier.
    case contents(of: String)
}

public enum Finder {
    public static func resolve(_ target: DynamicTarget) -> [String] {
        switch target {
        case let .directoriesNamed(names, root, maxDepth, excluding):
            return directories(named: names, under: PathGuard.expand(root),
                               maxDepth: maxDepth, excluding: excluding)
        case let .files(extensions, directory):
            let path = PathGuard.expand(directory)
            let children = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
            return children
                .filter { extensions.contains(($0 as NSString).pathExtension.lowercased()) }
                .map { (path as NSString).appendingPathComponent($0) }
                .sorted()
        case let .contents(directory):
            let path = PathGuard.expand(directory)
            let children = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
            return children.filter { $0 != ".DS_Store" }
                .map { (path as NSString).appendingPathComponent($0) }.sorted()
        case let .outdatedIDEVersions(roots):
            return roots.flatMap { root -> [String] in
                let path = PathGuard.expand(root)
                let children = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
                return outdatedVersions(children).map { (path as NSString).appendingPathComponent($0) }
            }
        }
    }

    static func directories(named names: Set<String>, under root: String,
                            maxDepth: Int, excluding: Set<String>) -> [String] {
        var found: [String] = []
        var queue: [(URL, Int)] = [(URL(fileURLWithPath: root), 0)]
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        while !queue.isEmpty {
            let (directory, depth) = queue.removeFirst()
            guard let children = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: keys) else { continue }
            for child in children {
                let values = try? child.resourceValues(forKeys: Set(keys))
                guard values?.isDirectory == true, values?.isSymbolicLink != true else { continue }
                let name = child.lastPathComponent
                if depth == 0, excluding.contains(name) || name.hasPrefix("com.apple.") { continue }
                if names.contains(name) {
                    found.append(child.path)
                } else if depth + 1 < maxDepth {
                    queue.append((child, depth + 1))
                }
            }
        }
        return found.sorted()
    }

    /// Parmi des noms de dossiers « ProduitAAAA.N[.N] », ceux qui ne sont pas la
    /// version la plus récente de leur produit.
    public static func outdatedVersions(_ names: [String]) -> [String] {
        let pattern = #/^([A-Za-z]+)(\d{4}(?:\.\d+)+)$/#
        var byProduct: [String: [(name: String, version: [Int])]] = [:]
        for name in names {
            guard let match = name.wholeMatch(of: pattern) else { continue }
            let version = match.2.split(separator: ".").compactMap { Int($0) }
            byProduct[match.1.lowercased(), default: []].append((name, version))
        }
        return byProduct.values.flatMap { versions -> [String] in
            guard let newest = versions.max(by: { isOlder($0.version, $1.version) }) else { return [] }
            return versions.filter { $0.name != newest.name }.map(\.name)
        }.sorted()
    }

    static func isOlder(_ lhs: [Int], _ rhs: [Int]) -> Bool {
        for index in 0..<max(lhs.count, rhs.count) {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0
            if a != b { return a < b }
        }
        return false
    }
}

/// Lecture des runtimes de simulateur via `simctl`.
public enum SimRuntimes {
    /// Somme des tailles des runtimes cités dans une sortie `--dry-run`.
    public static func total(dryRun: String, listJSON: String) -> Int64 {
        let ids = Set(dryRun.matches(of: #/[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}/#)
            .map { String($0.output) })
        guard !ids.isEmpty,
              let data = listJSON.data(using: .utf8),
              let list = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]]
        else { return 0 }
        return list.reduce(0) { total, entry in
            guard ids.contains(entry.key), let size = entry.value["sizeBytes"] as? NSNumber else { return total }
            return total + size.int64Value
        }
    }
}
