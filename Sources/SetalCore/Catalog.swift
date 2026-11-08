import Foundation

/// Ce que macOS range dans « Données système » sur un Mac de développeur.
/// L'ordre et les choix par défaut viennent d'un vrai nettoyage (novembre 2026) :
/// Docker 47 Go, simulateurs iOS 25 Go, Gradle 18 Go, émulateurs Android 21 Go.
public enum Catalog {
    static let dockerDisk = "~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw"

    public static let items: [CleanupItem] = [
        // MARK: Docker
        CleanupItem(
            id: "docker.prune",
            title: "Images, conteneurs arrêtés et cache de build",
            detail: "Le disque virtuel Docker.raw grossit sans jamais rendre l'espace tout seul.",
            consequence: "Les volumes (données des bases) sont gardés. Le prochain build Docker est plus long. Docker Desktop est démarré si besoin.",
            category: .docker, risk: .rebuild, defaultSelected: false,
            availability: "command -v docker",
            probe: .docker(types: ["Images", "Containers", "Build Cache"], fallback: [dockerDisk]),
            action: .docker(["docker system prune -af", "docker builder prune -af"])
        ),
        CleanupItem(
            id: "docker.volumes",
            title: "Volumes Docker inutilisés",
            detail: "Volumes qu'aucun conteneur n'utilise.",
            consequence: "Les données des bases locales qu'ils contiennent sont perdues.",
            category: .docker, risk: .data, defaultSelected: false,
            availability: "command -v docker",
            probe: .docker(types: ["Local Volumes"], fallback: []),
            action: .docker(["docker volume prune -af"])
        ),

        // MARK: Xcode & iOS
        CleanupItem(
            id: "xcode.derived",
            title: "DerivedData Xcode",
            detail: "Produits intermédiaires de compilation.",
            consequence: "Le prochain build Xcode ou Flutter iOS est plus long.",
            category: .xcode, risk: .rebuild, defaultSelected: true,
            probe: .paths(["~/Library/Developer/Xcode/DerivedData"]),
            action: .removeContents(["~/Library/Developer/Xcode/DerivedData"])
        ),
        CleanupItem(
            id: "xcode.unavailable",
            title: "Simulateurs indisponibles",
            detail: "Appareils liés à une version d'iOS qui n'est plus installée.",
            consequence: "Aucune : ils ne peuvent plus démarrer.",
            category: .xcode, risk: .safe, defaultSelected: true,
            availability: "xcrun simctl list devices unavailable 2>/dev/null | grep -q '('",
            probe: .none,
            action: .shell("xcrun simctl delete unavailable")
        ),
        CleanupItem(
            id: "xcode.simErase",
            title: "Contenu des simulateurs iOS",
            detail: "Apps installées et données accumulées sur chaque simulateur.",
            consequence: "Les appareils restent, mais il faudra réinstaller les apps dessus.",
            category: .xcode, risk: .data, defaultSelected: false,
            probe: .paths(["~/Library/Developer/CoreSimulator/Devices"]),
            action: .shell("xcrun simctl shutdown all; xcrun simctl erase all")
        ),
        CleanupItem(
            id: "xcode.archives",
            title: "Archives Xcode",
            detail: "Builds archivés pour l'App Store, avec leurs dSYM.",
            consequence: "Sans les dSYM, les crashs des versions publiées ne sont plus symbolisables.",
            category: .xcode, risk: .data, defaultSelected: false,
            probe: .paths(["~/Library/Developer/Xcode/Archives"]),
            action: .removeContents(["~/Library/Developer/Xcode/Archives"])
        ),

        // MARK: Android & Flutter
        CleanupItem(
            id: "android.gradle",
            title: "Caches Gradle",
            detail: "Dépendances et transformations téléchargées par Gradle.",
            consequence: "Le premier build Android ou Flutter retélécharge les dépendances.",
            category: .android, risk: .rebuild, defaultSelected: true,
            probe: .paths(["~/.gradle/caches", "~/.gradle/daemon"]),
            action: .sequence([
                .shell("pkill -f GradleDaemon || true"),
                .removePaths(["~/.gradle/caches", "~/.gradle/daemon"]),
            ])
        ),
        CleanupItem(
            id: "android.cache",
            title: "Cache Android",
            detail: "Cache du SDK Android.",
            consequence: "Aucune.",
            category: .android, risk: .safe, defaultSelected: true,
            probe: .paths(["~/.android/cache"]),
            action: .removeContents(["~/.android/cache"])
        ),
        CleanupItem(
            id: "android.avd",
            title: "Émulateurs Android (AVD)",
            detail: "Disques des appareils virtuels.",
            consequence: "Il faudra recréer les émulateurs dans Android Studio (Device Manager).",
            category: .android, risk: .data, defaultSelected: false,
            probe: .paths(["~/.android/avd"]),
            action: .sequence([
                .shell("pkill -f qemu-system || true"),
                .removeContents(["~/.android/avd"]),
            ])
        ),
        CleanupItem(
            id: "android.systemImages",
            title: "Images système Android",
            detail: "Images utilisées pour créer les émulateurs.",
            consequence: "Le SDK Manager les retélécharge à la création d'un émulateur.",
            category: .android, risk: .rebuild, defaultSelected: false,
            probe: .paths(["~/Library/Android/sdk/system-images"]),
            action: .removePaths(["~/Library/Android/sdk/system-images"])
        ),
        CleanupItem(
            id: "packages.pub",
            title: "Cache pub (Flutter / Dart)",
            detail: "Paquets Dart téléchargés.",
            consequence: "Chaque projet Flutter devra refaire « flutter pub get ».",
            category: .android, risk: .rebuild, defaultSelected: false,
            availability: "command -v flutter",
            probe: .paths(["~/.pub-cache"]),
            action: .shell("flutter pub cache clean --force")
        ),

        // MARK: Gestionnaires de paquets
        CleanupItem(
            id: "packages.npm",
            title: "Cache npm",
            detail: "Archives de paquets téléchargées par npm.",
            consequence: "Les prochains « npm install » retéléchargent.",
            category: .packages, risk: .safe, defaultSelected: true,
            availability: "command -v npm",
            probe: .paths(["~/.npm/_cacache"]),
            action: .shell("npm cache clean --force")
        ),
        CleanupItem(
            id: "packages.brew",
            title: "Homebrew",
            detail: "Anciennes versions et téléchargements de Homebrew.",
            consequence: "Aucune.",
            category: .packages, risk: .safe, defaultSelected: true,
            availability: "command -v brew",
            probe: .shellKB("du -sk \"$(brew --cache)\" 2>/dev/null | cut -f1"),
            action: .shell("brew cleanup -s --prune=all")
        ),
        CleanupItem(
            id: "packages.pnpm",
            title: "Store pnpm",
            detail: "Paquets que plus aucun projet ne référence.",
            consequence: "Aucune.",
            category: .packages, risk: .safe, defaultSelected: true,
            availability: "command -v pnpm",
            probe: .shellKB("du -sk \"$(pnpm store path 2>/dev/null)\" 2>/dev/null | cut -f1"),
            action: .shell("pnpm store prune")
        ),

        // MARK: Caches
        CleanupItem(
            id: "caches.user",
            title: "Caches des applications",
            detail: "~/Library/Caches (CocoaPods, Yarn, navigateurs, etc.).",
            consequence: "Les apps reconstruisent leurs caches au besoin.",
            category: .caches, risk: .safe, defaultSelected: true,
            probe: .paths(["~/Library/Caches"]),
            action: .removeContents(["~/Library/Caches"])
        ),
        CleanupItem(
            id: "caches.vscode",
            title: "Caches VS Code",
            detail: "Cache, CachedData et extensions déjà installées.",
            consequence: "Aucune.",
            category: .caches, risk: .safe, defaultSelected: true,
            probe: .paths(vscodeCaches),
            action: .removePaths(vscodeCaches)
        ),
        CleanupItem(
            id: "caches.logs",
            title: "Journaux",
            detail: "~/Library/Logs.",
            consequence: "Les anciens journaux de diagnostic disparaissent.",
            category: .caches, risk: .safe, defaultSelected: true,
            probe: .paths(["~/Library/Logs"]),
            action: .removeContents(["~/Library/Logs"])
        ),

        // MARK: Système
        CleanupItem(
            id: "system.snapshots",
            title: "Instantanés locaux Time Machine",
            detail: "Copies que macOS garde sur le disque interne entre deux sauvegardes.",
            consequence: "Les sauvegardes sur le disque externe ne sont pas touchées.",
            category: .system, risk: .safe, defaultSelected: true,
            availability: "tmutil listlocalsnapshots / 2>/dev/null | grep -q com.apple",
            probe: .none,
            action: .shell("tmutil thinlocalsnapshots / 999999999999 4")
        ),
    ]

    static let vscodeCaches = [
        "~/Library/Application Support/Code/Cache",
        "~/Library/Application Support/Code/CachedData",
        "~/Library/Application Support/Code/CachedExtensionVSIXs",
        "~/Library/Application Support/Code/Code Cache",
    ]
}
