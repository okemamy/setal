import AppKit
import SetalCore
import SwiftUI

struct ProjectsView: View {
    @ObservedObject var projects: ProjectsModel
    @Binding var showLog: Bool
    @State private var confirm = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
            Divider()
            footer
        }
        .confirmationDialog(
            "Supprimer les artefacts de build sélectionnés ?",
            isPresented: $confirm,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) { Task { await projects.clean() } }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text(restoreSummary)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder").foregroundStyle(.secondary)
            Text(verbatim: abbreviate(projects.root))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(projects.root)
            Button("Choisir…", action: chooseFolder)
                .disabled(projects.isBusy)
            Spacer()
            Picker("Présélectionner les projets inactifs depuis", selection: $projects.inactiveDays) {
                ForEach(ProjectsModel.inactivityChoices, id: \.self) { days in
                    Text("\(days) jours").tag(days)
                }
            }
            .fixedSize()
            .disabled(projects.isBusy)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if projects.phase == .scanning {
            placeholder {
                ProgressView()
                Text("Recherche des artefacts de build…").foregroundStyle(.secondary)
            }
        } else if !projects.hasScanned {
            placeholder {
                Image(systemName: "shippingbox.and.arrow.backward")
                    .font(.system(size: 40)).foregroundStyle(.secondary)
                Text("node_modules, build, Pods, .dart_tool, target…").font(.headline)
                Text("Setal cherche les dossiers régénérables de tes projets. Un dossier n'est retenu que si le fichier de son écosystème est à côté (package.json, pubspec.yaml, build.gradle, Podfile, Cargo.toml…).")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 460)
                Button("Analyser ce dossier") { Task { await projects.scan() } }
                    .buttonStyle(.borderedProminent)
                    .tint(.setalGreen)
            }
        } else if projects.rows.isEmpty {
            placeholder {
                Image(systemName: "checkmark.seal").font(.system(size: 40)).foregroundStyle(Color.setalGreen)
                Text("Aucun artefact de build trouvé.").foregroundStyle(.secondary)
            }
        } else {
            List {
                ForEach(projects.groups) { group in
                    Section {
                        ForEach(group.rows) { row in ArtifactRowView(projects: projects, row: row) }
                    } header: {
                        ProjectHeader(projects: projects, group: group)
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
        }
    }

    private func placeholder<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 12, content: content)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Menu("Sélection") {
                Button("Projets inactifs") { projects.selectInactive() }
                Button("Tout") { projects.selectAll(true) }
                Divider()
                Button("Aucun") { projects.selectAll(false) }
            }
            .fixedSize()
            .disabled(projects.isBusy || projects.rows.isEmpty)

            Button {
                Task { await projects.scan() }
            } label: {
                Label("Analyser", systemImage: "arrow.clockwise")
            }
            .disabled(projects.isBusy)

            Button {
                showLog = true
            } label: {
                Label("Journal", systemImage: "text.alignleft")
            }

            Spacer()

            if projects.isBusy {
                ProgressView().controlSize(.small)
            }
            Text(summary).foregroundStyle(.secondary)

            Button {
                confirm = true
            } label: {
                Label("Supprimer", systemImage: "trash")
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.setalGreen)
            .controlSize(.large)
            .disabled(projects.isBusy || projects.selectedRows.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var summary: String {
        guard projects.hasScanned, !projects.rows.isEmpty else { return "" }
        let count = projects.selectedRows.count
        if count == 0 {
            return String(localized: "\(projects.rows.count) artefact(s) · \(Format.bytes(projects.grandTotal)) au total")
        }
        return String(localized: "\(count) élément(s) · environ \(Format.bytes(projects.selectedTotal))")
    }

    private var restoreSummary: String {
        let commands = Set(projects.selectedRows.map(\.artifact.restore)).sorted()
        return String(localized: "Ces dossiers se recréent avec : \(commands.joined(separator: ", ")).")
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: projects.root)
        panel.prompt = String(localized: "Choisir")
        if panel.runModal() == .OK, let url = panel.url {
            projects.root = url.path
            Task { await projects.scan() }
        }
    }
}

func abbreviate(_ path: String) -> String {
    let home = PathGuard.home
    return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
}

struct ProjectHeader: View {
    @ObservedObject var projects: ProjectsModel
    let group: ProjectGroup

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Toggle("", isOn: Binding(
                get: { group.rows.allSatisfy(\.selected) },
                set: { projects.setSelected(project: group.path, $0) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .disabled(projects.isBusy)

            Text(verbatim: group.name).font(.headline)
            Text(verbatim: abbreviate((group.path as NSString).deletingLastPathComponent))
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
            Spacer()
            Text(activityText)
                .font(.caption)
                .foregroundStyle(projects.isInactive(group.lastActivity) ? Color.orange : .secondary)
            Text(Format.bytes(group.total))
                .font(.callout.weight(.semibold).monospacedDigit())
                .frame(minWidth: 80, alignment: .trailing)
        }
    }

    private var activityText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: group.lastActivity, relativeTo: Date())
        return String(localized: "modifié \(relative)")
    }
}

struct ArtifactRowView: View {
    @ObservedObject var projects: ProjectsModel
    let row: ArtifactRow

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { row.selected },
                set: { projects.setSelected(row.id, $0) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .disabled(projects.isBusy || row.state != .ready)

            Text(verbatim: relativePath)
                .font(.system(.body, design: .monospaced))
            Text(verbatim: row.artifact.ecosystem)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(.secondary)
            Text(verbatim: row.artifact.restore)
                .font(.caption).foregroundStyle(.tertiary)

            Spacer()

            status.frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.leading, 20)
    }

    private var relativePath: String {
        String(row.artifact.path.dropFirst(row.artifact.projectPath.count + 1))
    }

    @ViewBuilder
    private var status: some View {
        switch row.state {
        case .measuring, .pending, .cleaning:
            ProgressView().controlSize(.small)
        case .done(let freed):
            Label("+\(Format.bytes(freed))", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Color.setalGreen)
                .font(.callout.weight(.semibold).monospacedDigit())
        case .failed(let message):
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .help(message)
        case .ready:
            Text(Format.bytes(row.size ?? 0))
                .font(.callout.monospacedDigit())
                .foregroundStyle((row.size ?? 0) >= 1_000_000_000 ? .primary : .secondary)
        }
    }
}
