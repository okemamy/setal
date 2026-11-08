import Foundation
import SetalCore

struct ArtifactRow: Identifiable {
    let artifact: ProjectArtifact
    var size: Int64?
    var selected: Bool
    var state: RowState = .ready

    var id: String { artifact.id }
}

struct ProjectGroup: Identifiable {
    let path: String
    let rows: [ArtifactRow]

    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }
    var total: Int64 { rows.compactMap(\.size).reduce(0, +) }
    var lastActivity: Date { rows.map(\.artifact.lastActivity).max() ?? .distantPast }
}

@MainActor
final class ProjectsModel: ObservableObject {
    enum Phase { case idle, scanning, measuring, cleaning }

    static let inactivityChoices = [7, 30, 90, 180, 365]

    @Published var root: String {
        didSet { UserDefaults.standard.set(root, forKey: "projectsRoot") }
    }
    @Published var inactiveDays: Int {
        didSet {
            UserDefaults.standard.set(inactiveDays, forKey: "projectsInactiveDays")
            selectInactive()
        }
    }
    @Published var rows: [ArtifactRow] = []
    @Published var phase: Phase = .idle
    @Published var hasScanned = false

    var onLog: ((String) -> Void)?
    var onCleaned: ((Int64) -> Void)?

    init() {
        let defaults = UserDefaults.standard
        root = defaults.string(forKey: "projectsRoot") ?? ProjectScanner.suggestedRoot()
        let days = defaults.integer(forKey: "projectsInactiveDays")
        inactiveDays = days > 0 ? days : 30
    }

    var isBusy: Bool { phase != .idle }

    var groups: [ProjectGroup] {
        Dictionary(grouping: rows, by: \.artifact.projectPath)
            .map { ProjectGroup(path: $0.key, rows: $0.value.sorted { ($0.size ?? 0) > ($1.size ?? 0) }) }
            .sorted { $0.total > $1.total }
    }

    var selectedRows: [ArtifactRow] { rows.filter(\.selected) }
    var selectedTotal: Int64 { selectedRows.compactMap(\.size).reduce(0, +) }
    var grandTotal: Int64 { rows.compactMap(\.size).reduce(0, +) }

    func isInactive(_ date: Date) -> Bool {
        date < Date().addingTimeInterval(-Double(inactiveDays) * 86_400)
    }

    func selectInactive() {
        for index in rows.indices where rows[index].state == .ready {
            rows[index].selected = isInactive(rows[index].artifact.lastActivity)
        }
    }

    func selectAll(_ value: Bool) {
        for index in rows.indices where rows[index].state == .ready { rows[index].selected = value }
    }

    func setSelected(_ id: String, _ value: Bool) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[index].selected = value
    }

    func setSelected(project: String, _ value: Bool) {
        for index in rows.indices where rows[index].artifact.projectPath == project && rows[index].state == .ready {
            rows[index].selected = value
        }
    }

    func scan() async {
        guard !isBusy else { return }
        phase = .scanning
        let root = self.root
        let found = await Task.detached(priority: .userInitiated) { ProjectScanner.scan(root: root) }.value
        rows = found.map { ArtifactRow(artifact: $0, selected: false, state: .measuring) }
        hasScanned = true
        phase = .measuring

        // `du` en parallèle, 6 à la fois : un dossier de projets peut contenir
        // des centaines de node_modules.
        await withTaskGroup(of: (String, Int64).self) { group in
            var pending = found.makeIterator()
            for _ in 0..<6 {
                guard let next = pending.next() else { break }
                group.addTask { (next.path, await Executor.diskUsage([next.path])) }
            }
            for await (path, size) in group {
                if let index = rows.firstIndex(where: { $0.id == path }) {
                    rows[index].size = size
                    rows[index].state = .ready
                }
                if let next = pending.next() {
                    group.addTask { (next.path, await Executor.diskUsage([next.path])) }
                }
            }
        }
        selectInactive()
        phase = .idle
    }

    func clean() async {
        guard !isBusy else { return }
        let targets = selectedRows
        guard !targets.isEmpty else { return }
        phase = .cleaning
        let startFree = DiskSpace.free()
        onLog?(String(localized: "Suppression de \(targets.count) artefact(s) de projets"))

        for target in targets {
            guard let index = rows.firstIndex(where: { $0.id == target.id }) else { continue }
            let path = target.artifact.path
            guard ProjectScanner.isStillArtifact(path) else {
                rows[index].state = .failed(String(localized: "Chemin refusé par le garde-fou : \(path)"))
                continue
            }
            rows[index].state = .cleaning
            let removal = await Task.detached { () -> String? in
                do {
                    try FileManager.default.removeItem(atPath: path)
                    return nil
                } catch {
                    return error.localizedDescription
                }
            }.value
            if let message = removal {
                rows[index].state = .failed(message)
                onLog?(String(localized: "Impossible de supprimer \(path) : \(message)"))
            } else {
                rows[index].state = .done(freed: target.size ?? 0)
                rows[index].selected = false
                onLog?(String(localized: "Supprimé : \(path)"))
            }
        }

        let freed = max(0, DiskSpace.free() - startFree)
        onLog?(String(localized: "Terminé — libre : \(Format.bytes(DiskSpace.free())) (+\(Format.bytes(freed)))"))
        onCleaned?(freed)
        phase = .idle
    }
}
