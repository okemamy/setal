import Foundation

public enum Risk: Int, Sendable, Comparable, CaseIterable {
    /// Cache pur, reconstruit sans qu'on s'en aperçoive.
    case safe
    /// Sera retéléchargé ou recompilé : le prochain build est plus long.
    case rebuild
    /// Supprime des données que l'utilisateur pourrait vouloir garder.
    case data

    public static func < (lhs: Risk, rhs: Risk) -> Bool { lhs.rawValue < rhs.rawValue }

    public var label: String {
        switch self {
        case .safe: String(localized: "Sûr")
        case .rebuild: String(localized: "À reconstruire")
        case .data: String(localized: "Perte de données")
        }
    }
}

public enum Category: String, CaseIterable, Sendable {
    case docker = "Docker"
    case xcode = "Xcode & iOS"
    case android = "Android & Flutter"
    case packages = "Gestionnaires de paquets"
    case ide = "Éditeurs & IDE"
    case apps = "Apps & appareils"
    case caches = "Caches"
    case system = "Système"

    public var title: String {
        switch self {
        case .docker: String(localized: "Docker")
        case .xcode: String(localized: "Xcode & iOS")
        case .android: String(localized: "Android & Flutter")
        case .packages: String(localized: "Gestionnaires de paquets")
        case .ide: String(localized: "Éditeurs & IDE")
        case .apps: String(localized: "Apps & appareils")
        case .caches: String(localized: "Caches")
        case .system: String(localized: "Système")
        }
    }

    public var symbol: String {
        switch self {
        case .docker: "shippingbox"
        case .xcode: "hammer"
        case .android: "iphone.gen1"
        case .packages: "archivebox"
        case .ide: "chevron.left.forwardslash.chevron.right"
        case .apps: "ipad.and.iphone"
        case .caches: "tray.full"
        case .system: "clock.arrow.circlepath"
        }
    }
}

public enum SizeProbe: Sendable {
    case none
    /// Taille cumulée (`du`) des chemins existants.
    case paths([String])
    /// Commande shell qui affiche une taille en kilo-octets.
    case shellKB(String)
    /// Espace récupérable selon `docker system df` pour ces types ; si Docker
    /// est arrêté, taille des chemins de repli.
    case docker(types: [String], fallback: [String])
    /// Taille cumulée des chemins trouvés à l'exécution.
    case dynamic(DynamicTarget)
    /// Taille des runtimes de simulateur que `simctl runtime delete <sélecteur>` supprimerait.
    case simRuntimes([String])
}

public indirect enum CleanupAction: Sendable {
    /// Supprime le contenu de chaque dossier, en gardant le dossier.
    case removeContents([String])
    /// Supprime les chemins eux-mêmes.
    case removePaths([String])
    case shell(String)
    /// Commandes docker ; démarre Docker Desktop si nécessaire.
    case docker([String])
    /// Supprime les chemins trouvés à l'exécution.
    case removeDynamic(DynamicTarget)
    /// Met à la Corbeille (récupérable) les chemins trouvés à l'exécution.
    case trashDynamic(DynamicTarget)
    case sequence([CleanupAction])
}

public struct CleanupItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let consequence: String
    public let category: Category
    public let risk: Risk
    public let defaultSelected: Bool
    /// Commande shell : code de sortie 0 = élément présent sur ce Mac.
    public let availability: String?
    public let probe: SizeProbe
    public let action: CleanupAction

    public init(
        id: String, title: String, detail: String, consequence: String,
        category: Category, risk: Risk, defaultSelected: Bool,
        availability: String? = nil, probe: SizeProbe, action: CleanupAction
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.consequence = consequence
        self.category = category
        self.risk = risk
        self.defaultSelected = defaultSelected
        self.availability = availability
        self.probe = probe
        self.action = action
    }

    /// Chemins que l'action supprime, pour vérification par le garde-fou.
    public var deletablePaths: [String] { Self.paths(in: action, contents: false) }

    /// Dossiers dont l'action vide le contenu.
    public var containerPaths: [String] { Self.paths(in: action, contents: true) }

    private static func paths(in action: CleanupAction, contents: Bool) -> [String] {
        switch action {
        case .removeContents(let paths): contents ? paths : []
        case .removePaths(let paths): contents ? [] : paths
        case .shell, .docker, .removeDynamic, .trashDynamic: []
        case .sequence(let actions): actions.flatMap { Self.paths(in: $0, contents: contents) }
        }
    }
}
