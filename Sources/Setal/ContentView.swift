import SetalCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: CleanerModel
    @State private var showLog = false
    @State private var confirmDataLoss = false
    @State private var tab: Tab = .system

    enum Tab: Hashable { case system, projects }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
            Picker("", selection: $tab) {
                Text("Données système").tag(Tab.system)
                Text("Projets").tag(Tab.projects)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 340)
            .padding(.bottom, 12)
            Divider()
            if tab == .system {
                systemList
                Divider()
                footer
            } else {
                ProjectsView(projects: model.projects, showLog: $showLog)
            }
        }
        .frame(minWidth: 760, minHeight: 600)
        .task { await model.scan() }
        .sheet(isPresented: $showLog) { LogView() }
        .confirmationDialog(
            "Certains éléments sélectionnés suppriment des données",
            isPresented: $confirmDataLoss,
            titleVisibility: .visible
        ) {
            Button("Nettoyer quand même", role: .destructive) { startCleaning() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text(model.selectedDataLossRows
                .map { String(localized: "• \($0.item.title) : \($0.item.consequence)") }
                .joined(separator: "\n"))
        }
    }

    private var systemList: some View {
            List {
                ForEach(Category.allCases, id: \.self) { category in
                    let rows = model.rows.filter { $0.item.category == category }
                    if !rows.isEmpty {
                        Section {
                            ForEach(rows) { row in RowView(row: row) }
                        } header: {
                            Label(category.title, systemImage: category.symbol)
                                .font(.headline)
                        }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Menu("Sélection") {
                Button("Sûrs uniquement") { model.selectAll(risk: .safe) }
                Button("Sûrs + à reconstruire") { model.selectAll(risk: .rebuild) }
                Button("Tout") { model.selectAll(risk: .data) }
                Divider()
                Button("Aucun") { model.selectAll(risk: nil) }
            }
            .fixedSize()
            .disabled(model.isBusy)

            Button {
                Task { await model.scan() }
            } label: {
                Label("Analyser", systemImage: "arrow.clockwise")
            }
            .disabled(model.isBusy)

            Button {
                showLog = true
            } label: {
                Label("Journal", systemImage: "text.alignleft")
            }

            Spacer()

            if model.isBusy {
                ProgressView().controlSize(.small)
                Group {
                    if model.phase == .scanning { Text("Analyse…") } else { Text("Nettoyage…") }
                }
                .foregroundStyle(.secondary)
            } else {
                Text(selectionSummary).foregroundStyle(.secondary)
            }

            Button {
                if model.selectedDataLossRows.isEmpty { startCleaning() } else { confirmDataLoss = true }
            } label: {
                Label("Nettoyer", systemImage: "sparkles")
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.setalGreen)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(model.isBusy || model.selectedRows.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var selectionSummary: String {
        let count = model.selectedRows.count
        guard count > 0 else { return String(localized: "Rien de sélectionné") }
        return String(localized: "\(count) élément(s) · environ \(Format.bytes(model.selectedTotal))")
    }

    private func startCleaning() {
        showLog = false
        Task { await model.clean() }
    }
}

// MARK: - En-tête

struct HeaderView: View {
    @EnvironmentObject private var model: CleanerModel
    @State private var showInfo = false

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [.setalGreen, .setalGold],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(verbatim: "Setal").font(.title.bold())
                    Button { showInfo.toggle() } label: { Image(systemName: "info.circle") }
                        .buttonStyle(.borderless)
                        .popover(isPresented: $showInfo, arrowEdge: .bottom) { InfoView() }
                }
                Text("Rendre propre les « Données système » de ton Mac")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("\(Format.bytes(model.freeBytes)) libres sur \(Format.bytes(model.totalBytes))")
                    .font(.headline.monospacedDigit())
                ProgressView(value: usedFraction)
                    .tint(usedFraction > 0.9 ? .red : .setalGreen)
                    .frame(width: 240)
                if model.lastRunFreed != nil, model.recoveredSinceLaunch > 0 {
                    HStack(spacing: 10) {
                        if Links.donate != nil {
                        Button {
                            Links.openDonate()
                        } label: {
                            Label("Soutenir Setal", systemImage: "heart.fill")
                        }
                        .buttonStyle(.link)
                        .font(.callout)
                        }
                        Text("+\(Format.bytes(model.recoveredSinceLaunch)) récupérés")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(Color.setalGreen)
                    }
                }
            }
        }
        .padding(16)
    }

    private var usedFraction: Double {
        guard model.totalBytes > 0 else { return 0 }
        return Double(model.totalBytes - model.freeBytes) / Double(model.totalBytes)
    }
}

struct InfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Setal — « nettoyer » en wolof").font(.headline)
            Text("macOS range dans « Données système » tout ce qui n'est ni une app, ni un document : caches, disque Docker, simulateurs, caches Gradle, instantanés Time Machine… Sur un Mac de développeur, cela dépasse vite 200 Go.")
            Text("Setal ne touche qu'à ~/Library et aux dossiers cachés de ton dossier personnel. Les éléments « Perte de données » ne sont jamais cochés par défaut et demandent une confirmation.")
            Text("Le swap et les fichiers temporaires du système ne disparaissent qu'au redémarrage du Mac.")
            Text("Réglages › Stockage peut mettre quelques minutes à afficher le nouveau chiffre.")
                .foregroundStyle(.secondary)
            if Links.donate != nil {
                Divider()
                Text("Setal est gratuite et open source. Si elle t'a fait gagner de la place, tu peux soutenir son développement.")
                Button {
                    Links.openDonate()
                } label: {
                    Label("Faire un don", systemImage: "heart.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
            }
        }
        .font(.callout)
        .frame(width: 360)
        .padding(16)
    }
}

// MARK: - Ligne

struct RowView: View {
    @EnvironmentObject private var model: CleanerModel
    let row: Row

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: Binding(
                get: { row.selected },
                set: { model.setSelected(row.id, $0) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .disabled(!row.isActionable || model.isBusy)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(row.item.title).font(.body.weight(.medium))
                    RiskBadge(risk: row.item.risk)
                }
                Text(row.item.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(row.item.consequence)
                    .font(.caption)
                    .foregroundStyle(row.item.risk == .data ? Color.red.opacity(0.85) : .secondary)
                if case .failed(let message) = row.state {
                    Text(message).font(.caption).foregroundStyle(.red)
                }
            }

            Spacer(minLength: 12)

            status.frame(minWidth: 90, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .opacity(row.isActionable ? 1 : 0.45)
    }

    @ViewBuilder
    private var status: some View {
        switch row.state {
        case .pending, .measuring:
            ProgressView().controlSize(.small)
        case .cleaning:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("en cours").font(.caption).foregroundStyle(.secondary)
            }
        case .done(let freed):
            VStack(alignment: .trailing, spacing: 2) {
                Label(freed > 0 ? "+\(Format.bytes(freed))" : String(localized: "Fait"),
                      systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.setalGreen)
                    .font(.callout.weight(.semibold).monospacedDigit())
                if let size = row.size, size > 0 {
                    Text("reste \(Format.bytes(size))").font(.caption).foregroundStyle(.secondary)
                }
            }
        case .ready, .failed:
            if row.blocked {
                VStack(alignment: .trailing, spacing: 2) {
                    Button("Autoriser…") { FullDiskAccess.openSettings() }
                        .controlSize(.small)
                    Text("Accès complet au disque requis")
                        .font(.caption2).foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            } else if !row.available {
                Text("absent").font(.callout).foregroundStyle(.secondary)
            } else if let size = row.size {
                Text(Format.bytes(size))
                    .font(.callout.weight(size >= 1_000_000_000 ? .semibold : .regular).monospacedDigit())
                    .foregroundStyle(size >= 5_000_000_000 ? .primary : .secondary)
            } else {
                Text(verbatim: "—").foregroundStyle(.secondary)
                    .help("Taille inconnue avant nettoyage")
            }
        }
    }
}

struct RiskBadge: View {
    let risk: Risk

    var body: some View {
        Text(risk.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch risk {
        case .safe: .setalGreen
        case .rebuild: .orange
        case .data: .red
        }
    }
}

// MARK: - Journal

struct LogView: View {
    @EnvironmentObject private var model: CleanerModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Journal").font(.headline)
                Spacer()
                Button("Copier") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.log.map(\.text).joined(separator: "\n"), forType: .string)
                }
                Button("Fermer") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(12)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if model.log.isEmpty {
                        Text("Aucune action pour l'instant.").foregroundStyle(.secondary)
                    }
                    ForEach(model.log) { line in
                        Text(line.text)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 640, height: 420)
    }
}

extension Color {
    /// Vert et or : couleurs du drapeau sénégalais.
    static let setalGreen = Color(red: 0.0, green: 0.52, blue: 0.25)
    static let setalGold = Color(red: 0.99, green: 0.76, blue: 0.0)
}

enum FullDiskAccess {
    static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}
