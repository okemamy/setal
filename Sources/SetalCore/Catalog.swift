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
            title: String(localized: "Images, conteneurs arrêtés et cache de build"),
            detail: String(localized: "Le disque virtuel Docker.raw grossit sans jamais rendre l'espace tout seul."),
            consequence: String(localized: "Les volumes (données des bases) sont gardés. Le prochain build Docker est plus long. Docker Desktop est démarré si besoin."),
            category: .docker, risk: .rebuild, defaultSelected: false,
            availability: "command -v docker",
            probe: .docker(types: ["Images", "Containers", "Build Cache"], fallback: [dockerDisk]),
            action: .docker(["docker system prune -af", "docker builder prune -af"])
        ),
        CleanupItem(
            id: "docker.volumes",
            title: String(localized: "Volumes Docker inutilisés"),
            detail: String(localized: "Volumes qu'aucun conteneur n'utilise."),
            consequence: String(localized: "Les données des bases locales qu'ils contiennent sont perdues."),
            category: .docker, risk: .data, defaultSelected: false,
            availability: "command -v docker",
            probe: .docker(types: ["Local Volumes"], fallback: []),
            action: .docker(["docker volume prune -af"])
        ),

        // MARK: Xcode & iOS
        CleanupItem(
            id: "xcode.derived",
            title: String(localized: "DerivedData Xcode"),
            detail: String(localized: "Produits intermédiaires de compilation."),
            consequence: String(localized: "Le prochain build Xcode ou Flutter iOS est plus long."),
            category: .xcode, risk: .rebuild, defaultSelected: true,
            probe: .paths(["~/Library/Developer/Xcode/DerivedData"]),
            action: .removeContents(["~/Library/Developer/Xcode/DerivedData"])
        ),
        CleanupItem(
            id: "xcode.unavailable",
            title: String(localized: "Simulateurs indisponibles"),
            detail: String(localized: "Appareils liés à une version d'iOS qui n'est plus installée."),
            consequence: String(localized: "Aucune : ils ne peuvent plus démarrer."),
            category: .xcode, risk: .safe, defaultSelected: true,
            availability: "xcrun simctl list devices unavailable 2>/dev/null | grep -q '('",
            probe: .none,
            action: .shell("xcrun simctl delete unavailable")
        ),
        CleanupItem(
            id: "xcode.simErase",
            title: String(localized: "Contenu des simulateurs iOS"),
            detail: String(localized: "Apps installées et données accumulées sur chaque simulateur."),
            consequence: String(localized: "Les appareils restent, mais il faudra réinstaller les apps dessus."),
            category: .xcode, risk: .data, defaultSelected: false,
            probe: .paths(["~/Library/Developer/CoreSimulator/Devices"]),
            action: .shell("xcrun simctl shutdown all; xcrun simctl erase all")
        ),
        CleanupItem(
            id: "xcode.archives",
            title: String(localized: "Archives Xcode"),
            detail: String(localized: "Builds archivés pour l'App Store, avec leurs dSYM."),
            consequence: String(localized: "Sans les dSYM, les crashs des versions publiées ne sont plus symbolisables."),
            category: .xcode, risk: .data, defaultSelected: false,
            probe: .paths(["~/Library/Developer/Xcode/Archives"]),
            action: .removeContents(["~/Library/Developer/Xcode/Archives"])
        ),

        // MARK: Android & Flutter
        CleanupItem(
            id: "android.gradle",
            title: String(localized: "Caches Gradle"),
            detail: String(localized: "Dépendances et transformations téléchargées par Gradle."),
            consequence: String(localized: "Le premier build Android ou Flutter retélécharge les dépendances."),
            category: .android, risk: .rebuild, defaultSelected: true,
            probe: .paths(["~/.gradle/caches", "~/.gradle/daemon"]),
            action: .sequence([
                .shell("pkill -f GradleDaemon || true"),
                .removePaths(["~/.gradle/caches", "~/.gradle/daemon"]),
            ])
        ),
        CleanupItem(
            id: "android.cache",
            title: String(localized: "Cache Android"),
            detail: String(localized: "Cache du SDK Android."),
            consequence: String(localized: "Aucune."),
            category: .android, risk: .safe, defaultSelected: true,
            probe: .paths(["~/.android/cache"]),
            action: .removeContents(["~/.android/cache"])
        ),
        CleanupItem(
            id: "android.avd",
            title: String(localized: "Émulateurs Android (AVD)"),
            detail: String(localized: "Disques des appareils virtuels."),
            consequence: String(localized: "Il faudra recréer les émulateurs dans Android Studio (Device Manager)."),
            category: .android, risk: .data, defaultSelected: false,
            probe: .paths(["~/.android/avd"]),
            action: .sequence([
                .shell("pkill -f qemu-system || true"),
                .removeContents(["~/.android/avd"]),
            ])
        ),
        CleanupItem(
            id: "android.systemImages",
            title: String(localized: "Images système Android"),
            detail: String(localized: "Images utilisées pour créer les émulateurs."),
            consequence: String(localized: "Le SDK Manager les retélécharge à la création d'un émulateur."),
            category: .android, risk: .rebuild, defaultSelected: false,
            probe: .paths(["~/Library/Android/sdk/system-images"]),
            action: .removePaths(["~/Library/Android/sdk/system-images"])
        ),
        CleanupItem(
            id: "packages.pub",
            title: String(localized: "Cache pub (Flutter / Dart)"),
            detail: String(localized: "Paquets Dart téléchargés."),
            consequence: String(localized: "Chaque projet Flutter devra refaire « flutter pub get »."),
            category: .android, risk: .rebuild, defaultSelected: false,
            availability: "command -v flutter",
            probe: .paths(["~/.pub-cache"]),
            action: .shell("flutter pub cache clean --force")
        ),

        // MARK: Gestionnaires de paquets
        CleanupItem(
            id: "packages.npm",
            title: String(localized: "Cache npm"),
            detail: String(localized: "Archives de paquets téléchargées par npm."),
            consequence: String(localized: "Les prochains « npm install » retéléchargent."),
            category: .packages, risk: .safe, defaultSelected: true,
            availability: "command -v npm",
            probe: .paths(["~/.npm/_cacache"]),
            action: .shell("npm cache clean --force")
        ),
        CleanupItem(
            id: "packages.brew",
            title: String(localized: "Homebrew"),
            detail: String(localized: "Anciennes versions et téléchargements de Homebrew."),
            consequence: String(localized: "Aucune."),
            category: .packages, risk: .safe, defaultSelected: true,
            availability: "command -v brew",
            probe: .shellKB("du -sk \"$(brew --cache)\" 2>/dev/null | cut -f1"),
            action: .shell("brew cleanup -s --prune=all")
        ),
        CleanupItem(
            id: "packages.pnpm",
            title: String(localized: "Store pnpm"),
            detail: String(localized: "Paquets que plus aucun projet ne référence."),
            consequence: String(localized: "Aucune."),
            category: .packages, risk: .safe, defaultSelected: true,
            availability: "command -v pnpm",
            probe: .shellKB("du -sk \"$(pnpm store path 2>/dev/null)\" 2>/dev/null | cut -f1"),
            action: .shell("pnpm store prune")
        ),

        // MARK: Caches
        CleanupItem(
            id: "caches.user",
            title: String(localized: "Caches des applications"),
            detail: String(localized: "~/Library/Caches (CocoaPods, Yarn, navigateurs, etc.)."),
            consequence: String(localized: "Les apps reconstruisent leurs caches au besoin."),
            category: .caches, risk: .safe, defaultSelected: true,
            probe: .paths(["~/Library/Caches"]),
            action: .removeContents(["~/Library/Caches"])
        ),
        CleanupItem(
            id: "caches.vscode",
            title: String(localized: "Caches VS Code"),
            detail: String(localized: "Cache, CachedData et extensions déjà installées."),
            consequence: String(localized: "Aucune."),
            category: .caches, risk: .safe, defaultSelected: true,
            probe: .paths(vscodeCaches),
            action: .removePaths(vscodeCaches)
        ),
        CleanupItem(
            id: "caches.logs",
            title: String(localized: "Journaux"),
            detail: String(localized: "~/Library/Logs."),
            consequence: String(localized: "Les anciens journaux de diagnostic disparaissent."),
            category: .caches, risk: .safe, defaultSelected: true,
            probe: .paths(["~/Library/Logs"]),
            action: .removeContents(["~/Library/Logs"])
        ),

        // MARK: Système
        CleanupItem(
            id: "system.snapshots",
            title: String(localized: "Instantanés locaux Time Machine"),
            detail: String(localized: "Copies que macOS garde sur le disque interne entre deux sauvegardes."),
            consequence: String(localized: "Les sauvegardes sur le disque externe ne sont pas touchées."),
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
