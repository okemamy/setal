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
        case .safe: "Sûr"
        case .rebuild: "À reconstruire"
        case .data: "Perte de données"
        }
    }
}

public enum Category: String, CaseIterable, Sendable {
    case docker = "Docker"
    case xcode = "Xcode & iOS"
    case android = "Android & Flutter"
    case packages = "Gestionnaires de paquets"
    case caches = "Caches"
    case system = "Système"

    public var symbol: String {
        switch self {
        case .docker: "shippingbox"
        case .xcode: "hammer"
        case .android: "iphone.gen1"
        case .packages: "archivebox"
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
}

public indirect enum CleanupAction: Sendable {
    /// Supprime le contenu de chaque dossier, en gardant le dossier.
    case removeContents([String])
    /// Supprime les chemins eux-mêmes.
    case removePaths([String])
    case shell(String)
    /// Commandes docker ; démarre Docker Desktop si nécessaire.
    case docker([String])
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

    /// Chemins que l'action peut supprimer, pour vérification par le garde-fou.
    public var deletablePaths: [String] { Self.paths(in: action) }

    private static func paths(in action: CleanupAction) -> [String] {
        switch action {
        case .removeContents(let paths), .removePaths(let paths): paths
        case .shell, .docker: []
        case .sequence(let actions): actions.flatMap(paths(in:))
        }
    }
}
