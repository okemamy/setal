import Foundation

public typealias LogHandler = @Sendable (String) async -> Void

public enum ExecutorError: LocalizedError {
    case commandFailed(String, Int32, String)
    case dockerUnavailable
    case unsafePath(String)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let command, let status, let output):
            let tail = output.split(separator: "\n").suffix(3).joined(separator: " ")
            return String(localized: "« \(command) » a échoué (code \(status)). \(tail)")
        case .dockerUnavailable:
            return String(localized: "Aucun moteur Docker n'a démarré (Docker Desktop, OrbStack ou Colima).")
        case .unsafePath(let path):
            return String(localized: "Chemin refusé par le garde-fou : \(path)")
        }
    }
}

public enum Executor {
    // MARK: Analyse

    public static func isAvailable(_ item: CleanupItem) async -> Bool {
        if let check = item.availability {
            return await Shell.run(check).status == 0
        }
        switch item.probe {
        case .paths(let paths): return !existing(paths).isEmpty
        case .dynamic(let target): return !Finder.resolve(target).isEmpty
        default: return true
        }
    }

    /// Vrai si un dossier existe mais que macOS en refuse la lecture : il faut
    /// accorder l'« Accès complet au disque » à Setal.
    public static func needsFullDiskAccess(_ item: CleanupItem) -> Bool {
        guard case .paths(let paths) = item.probe else { return false }
        return existing(paths).contains { path in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
                  isDirectory.boolValue else { return false }
            return (try? FileManager.default.contentsOfDirectory(atPath: path)) == nil
        }
    }

    /// Taille en octets, ou `nil` si elle ne peut pas être estimée.
    public static func measure(_ item: CleanupItem) async -> Int64? {
        switch item.probe {
        case .none:
            return nil
        case .paths(let paths):
            return await diskUsage(paths)
        case .shellKB(let command):
            return kilobytes(await Shell.run(command).output)
        case .docker(let types, let fallback):
            if await dockerIsRunning() {
                let result = await Shell.run("docker system df --format '{{.Type}}|{{.Reclaimable}}'")
                return DockerSize.reclaimable(result.output, types: Set(types))
            }
            return fallback.isEmpty ? nil : await diskUsage(fallback)
        case .dynamic(let target):
            return await diskUsage(Finder.resolve(target))
        case .simRuntimes(let selectors):
            var dryRun = ""
            for selector in selectors {
                dryRun += await Shell.run("xcrun simctl runtime delete \(selector) --dry-run").output
            }
            let list = await Shell.run("xcrun simctl runtime list -j 2>/dev/null")
            return SimRuntimes.total(dryRun: dryRun, listJSON: list.output)
        }
    }

    static func existing(_ paths: [String]) -> [String] {
        paths.map { PathGuard.expand($0) }.filter { FileManager.default.fileExists(atPath: $0) }
    }

    public static func diskUsage(_ paths: [String]) async -> Int64 {
        let found = existing(paths)
        guard !found.isEmpty else { return 0 }
        let arguments = found.map(Shell.quote).joined(separator: " ")
        let result = await Shell.run("du -sk \(arguments) 2>/dev/null | awk '{s+=$1} END {print s+0}'")
        return kilobytes(result.output) ?? 0
    }

    /// Dernière ligne numérique de la sortie : certains outils (brew) écrivent
    /// parfois des avertissements avant le résultat.
    static func kilobytes(_ output: String) -> Int64? {
        let value = output.split(whereSeparator: \.isNewline)
            .compactMap { Int64($0.trimmingCharacters(in: .whitespaces)) }
            .last
        return value.map { $0 * 1024 }
    }

    // MARK: Nettoyage

    public static func perform(_ action: CleanupAction, log: LogHandler) async throws {
        switch action {
        case .removeContents(let directories):
            for directory in directories {
                try await removeContents(of: PathGuard.expand(directory), log: log)
            }
        case .removePaths(let paths):
            try await remove(paths.map { PathGuard.expand($0) }, log: log)
        case .removeDynamic(let target):
            try await remove(Finder.resolve(target), log: log)
        case .trashDynamic(let target):
            for path in Finder.resolve(target) {
                guard PathGuard.isSafeToTrash(path) else { throw ExecutorError.unsafePath(path) }
                do {
                    try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                    await log(String(localized: "Mis à la Corbeille : \(path)"))
                } catch {
                    await log(String(localized: "Impossible de supprimer \(path) : \(error.localizedDescription)"))
                }
            }
        case .shell(let command):
            await log("$ \(command)")
            let result = await Shell.run(command)
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !output.isEmpty {
                await log(output.split(separator: "\n").suffix(5).joined(separator: "\n"))
            }
            if result.status != 0 {
                throw ExecutorError.commandFailed(command, result.status, result.output)
            }
        case .docker(let commands):
            try await ensureDocker(log: log)
            for command in commands {
                try await perform(.shell(command), log: log)
            }
        case .sequence(let actions):
            for step in actions {
                try await perform(step, log: log)
            }
        }
    }

    static func remove(_ paths: [String], log: LogHandler) async throws {
        for path in paths {
            guard PathGuard.isSafeToDelete(path) else { throw ExecutorError.unsafePath(path) }
            guard FileManager.default.fileExists(atPath: path) else { continue }
            do {
                try FileManager.default.removeItem(atPath: path)
                await log(String(localized: "Supprimé : \(path)"))
            } catch {
                await log(String(localized: "Impossible de supprimer \(path) : \(error.localizedDescription)"))
            }
        }
    }

    static func removeContents(of directory: String, log: LogHandler) async throws {
        guard PathGuard.isSafeContainer(directory) else { throw ExecutorError.unsafePath(directory) }
        let fileManager = FileManager.default
        guard let children = try? fileManager.contentsOfDirectory(atPath: directory) else { return }
        var removed = 0
        var skipped = 0
        for child in children {
            let path = (directory as NSString).appendingPathComponent(child)
            guard PathGuard.isSafeToDelete(path) else { skipped += 1; continue }
            do {
                try fileManager.removeItem(atPath: path)
                removed += 1
            } catch {
                skipped += 1
            }
        }
        if skipped > 0 {
            await log(String(localized: "\(directory) : \(removed) élément(s) supprimé(s), \(skipped) protégé(s) par macOS laissé(s) en place"))
        } else {
            await log(String(localized: "\(directory) : \(removed) élément(s) supprimé(s)"))
        }
    }

    // MARK: Docker

    static func dockerIsRunning() async -> Bool {
        await Shell.run("docker info >/dev/null 2>&1").status == 0
    }

    /// Démarre le moteur Docker installé : Docker Desktop, OrbStack ou Colima.
    static func ensureDocker(log: LogHandler) async throws {
        if await dockerIsRunning() { return }
        if await Shell.run("open -Ra Docker").status == 0 {
            await log(String(localized: "Démarrage de Docker Desktop…"))
            await Shell.run("open -a Docker")
        } else if await Shell.run("command -v orb").status == 0 {
            await log(String(localized: "Démarrage d'OrbStack…"))
            await Shell.run("orb start")
        } else if await Shell.run("command -v colima").status == 0 {
            await log(String(localized: "Démarrage de Colima…"))
            await Shell.run("colima start")
        } else {
            throw ExecutorError.dockerUnavailable
        }
        for _ in 0..<60 {
            if await dockerIsRunning() {
                await log(String(localized: "Docker est prêt."))
                return
            }
            try await Task.sleep(nanoseconds: 3_000_000_000)
        }
        throw ExecutorError.dockerUnavailable
    }
}

public enum DockerSize {
    /// Convertit une taille Docker (« 804.2MB (72%) », « 21.58GB », « 0B ») en octets.
    /// Docker utilise des unités décimales.
    public static func parse(_ text: String) -> Int64? {
        guard let token = text.split(separator: " ").first else { return nil }
        let number = token.prefix { $0.isNumber || $0 == "." }
        let unit = token.dropFirst(number.count).uppercased()
        guard let value = Double(number) else { return nil }
        let multipliers: [String: Double] = ["B": 1, "KB": 1e3, "MB": 1e6, "GB": 1e9, "TB": 1e12]
        guard let multiplier = multipliers[unit] else { return nil }
        return Int64(value * multiplier)
    }

    /// Additionne la colonne « récupérable » des lignes `Type|Reclaimable` retenues.
    public static func reclaimable(_ output: String, types: Set<String>) -> Int64 {
        output.split(separator: "\n").reduce(0) { total, line in
            let parts = line.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2, types.contains(parts[0]) else { return total }
            return total + (parse(parts[1]) ?? 0)
        }
    }
}

public enum DiskSpace {
    /// Espace libre réel du volume de données (ce qu'affiche `df`).
    public static func free() -> Int64 {
        let attributes = try? FileManager.default.attributesOfFileSystem(forPath: PathGuard.home)
        return (attributes?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
    }

    public static func total() -> Int64 {
        let attributes = try? FileManager.default.attributesOfFileSystem(forPath: PathGuard.home)
        return (attributes?[.systemSize] as? NSNumber)?.int64Value ?? 0
    }
}
