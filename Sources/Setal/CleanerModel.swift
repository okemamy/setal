import Foundation
import SetalCore

enum RowState: Equatable {
    case pending
    case measuring
    case ready
    case cleaning
    case done(freed: Int64)
    case failed(String)
}

struct Row: Identifiable {
    let item: CleanupItem
    var selected: Bool
    var available = true
    var size: Int64?
    var state: RowState = .pending

    var id: String { item.id }
    var isActionable: Bool { available }
}

struct LogLine: Identifiable {
    let id = UUID()
    let date = Date()
    let text: String
}

@MainActor
final class CleanerModel: ObservableObject {
    enum Phase { case idle, scanning, cleaning }

    @Published var rows: [Row]
    @Published var phase: Phase = .idle
    @Published var freeBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var freeAtLaunch: Int64 = 0
    @Published var log: [LogLine] = []
    @Published var lastRunFreed: Int64?

    init() {
        rows = Catalog.items.map { Row(item: $0, selected: $0.defaultSelected) }
        refreshDisk()
        freeAtLaunch = freeBytes
    }

    var isBusy: Bool { phase != .idle }

    var selectedRows: [Row] { rows.filter { $0.selected && $0.isActionable } }

    var selectedTotal: Int64 { selectedRows.compactMap(\.size).reduce(0, +) }

    var selectedDataLossRows: [Row] { selectedRows.filter { $0.item.risk == .data } }

    var recoveredSinceLaunch: Int64 { max(0, freeBytes - freeAtLaunch) }

    func refreshDisk() {
        freeBytes = DiskSpace.free()
        totalBytes = DiskSpace.total()
    }

    func setSelected(_ id: String, _ value: Bool) {
        guard let index = index(of: id) else { return }
        rows[index].selected = value
    }

    func selectAll(risk: Risk?) {
        for index in rows.indices where rows[index].isActionable {
            rows[index].selected = risk.map { rows[index].item.risk <= $0 } ?? false
        }
    }

    func scan() async {
        guard !isBusy else { return }
        phase = .scanning
        for index in rows.indices { rows[index].state = .measuring }

        await withTaskGroup(of: (String, Bool, Int64?).self) { group in
            for row in rows {
                let item = row.item
                group.addTask {
                    let available = await Executor.isAvailable(item)
                    let size = available ? await Executor.measure(item) : nil
                    return (item.id, available, size)
                }
            }
            for await (id, available, size) in group {
                guard let index = index(of: id) else { continue }
                rows[index].available = available
                rows[index].size = size
                rows[index].state = .ready
                if !available { rows[index].selected = false }
            }
        }

        refreshDisk()
        phase = .idle
    }

    func clean() async {
        guard !isBusy else { return }
        let targets = selectedRows
        guard !targets.isEmpty else { return }
        phase = .cleaning
        refreshDisk()
        let startFree = freeBytes
        append(String(localized: "Nettoyage de \(targets.count) élément(s) — libre : \(Format.bytes(startFree))"))

        for target in targets {
            guard let index = index(of: target.id) else { continue }
            rows[index].state = .cleaning
            append("▸ \(target.item.title)")
            let diskBefore = DiskSpace.free()

            do {
                try await Executor.perform(target.item.action) { [weak self] line in
                    await self?.append("   " + line)
                }
                let sizeAfter = await Executor.measure(target.item)
                let freed: Int64
                if let before = target.size, let after = sizeAfter {
                    freed = max(0, before - after)
                } else {
                    freed = max(0, DiskSpace.free() - diskBefore)
                }
                rows[index].size = sizeAfter
                rows[index].state = .done(freed: freed)
                rows[index].selected = false
            } catch {
                rows[index].state = .failed(error.localizedDescription)
                append("   ✗ \(error.localizedDescription)")
            }
        }

        refreshDisk()
        lastRunFreed = max(0, freeBytes - startFree)
        append(String(localized: "Terminé — libre : \(Format.bytes(freeBytes)) (+\(Format.bytes(lastRunFreed ?? 0)))"))
        phase = .idle
    }

    func append(_ text: String) {
        log.append(LogLine(text: text))
    }

    private func index(of id: String) -> Int? {
        rows.firstIndex { $0.id == id }
    }
}

enum Format {
    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }
}
