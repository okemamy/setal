import Foundation

/// Ce que macOS range dans « Données système » sur un Mac de développeur.
///
/// Le premier jeu d'éléments vient d'un vrai nettoyage (Docker 47 Go, simulateurs
/// iOS 25 Go, Gradle 18 Go, émulateurs Android 21 Go) ; les suivants couvrent les
/// autres gisements courants. Règles :
/// - un élément « Perte de données » n'est jamais coché par défaut ;
/// - ce qui appartient vraiment à l'utilisateur (sauvegardes, installeurs) part
///   à la Corbeille plutôt que d'être supprimé.
public enum Catalog {
    static let dockerFallback = [
        "~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw",
        "~/Library/Group Containers/HUAQ24HBR6.dev.orbstack/data",
        "~/.colima/_lima",
    ]

    static let deviceSupport = [
        "~/Library/Developer/Xcode/iOS DeviceSupport",
        "~/Library/Developer/Xcode/watchOS DeviceSupport",
        "~/Library/Developer/Xcode/tvOS DeviceSupport",
        "~/Library/Developer/Xcode/visionOS DeviceSupport",
    ]

    static let vscodeCaches = [
        "~/Library/Application Support/Code/Cache",
        "~/Library/Application Support/Code/CachedData",
        "~/Library/Application Support/Code/CachedExtensionVSIXs",
        "~/Library/Application Support/Code/Code Cache",
    ]

    static let iosBackups = "~/Library/Application Support/MobileSync/Backup"

    static let chromiumCaches = DynamicTarget.directoriesNamed(
        ["Cache", "Code Cache", "GPUCache", "DawnCache", "DawnGraphiteCache", "DawnWebGPUCache",
         "GrShaderCache", "ShaderCache", "CacheStorage", "ScriptCache"],
        under: "~/Library/Application Support", maxDepth: 5,
        excluding: ["MobileSync", "Code", "CloudDocs", "FileProvider", "Knowledge", "AddressBook"])

    static let outdatedIDEs = DynamicTarget.outdatedIDEVersions(roots: [
        "~/Library/Application Support/JetBrains",
        "~/Library/Application Support/Google",
    ])

    static let installers = DynamicTarget.files(extensions: PathGuard.installerExtensions, in: "~/Downloads")

    public static let items: [CleanupItem] = [
        // MARK: Docker
        CleanupItem(
            id: "docker.prune",
            title: String(localized: "Images, conteneurs arrêtés et cache de build"),
            detail: String(localized: "Le disque virtuel Docker.raw grossit sans jamais rendre l'espace tout seul."),
            consequence: String(localized: "Les volumes (données des bases) sont gardés. Le prochain build Docker est plus long. Le moteur Docker (Docker Desktop, OrbStack ou Colima) est démarré si besoin."),
            category: .docker, risk: .rebuild, defaultSelected: false,
            availability: "command -v docker",
            probe: .docker(types: ["Images", "Containers", "Build Cache"], fallback: dockerFallback),
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
            id: "xcode.deviceSupport",
            title: String(localized: "Symboles des appareils (DeviceSupport)"),
            detail: String(localized: "Copiés depuis chaque iPhone, iPad ou Apple Watch branché pour le débogage : plusieurs Go par version d'iOS."),
            consequence: String(localized: "Recopiés automatiquement au prochain branchement de l'appareil (quelques minutes)."),
            category: .xcode, risk: .rebuild, defaultSelected: true,
            probe: .paths(deviceSupport),
            action: .removeContents(deviceSupport)
        ),
        CleanupItem(
            id: "xcode.previews",
            title: String(localized: "Aperçus SwiftUI"),
            detail: String(localized: "Simulateurs et builds créés pour les Previews."),
            consequence: String(localized: "Le premier aperçu sera plus lent."),
            category: .xcode, risk: .safe, defaultSelected: true,
            probe: .paths(["~/Library/Developer/Xcode/UserData/Previews"]),
            action: .removeContents(["~/Library/Developer/Xcode/UserData/Previews"])
        ),
        CleanupItem(
            id: "xcode.simCaches",
            title: String(localized: "Caches des simulateurs"),
            detail: String(localized: "Caches dyld et de démarrage de CoreSimulator."),
            consequence: String(localized: "Aucune."),
            category: .xcode, risk: .safe, defaultSelected: true,
            probe: .paths(["~/Library/Developer/CoreSimulator/Caches"]),
            action: .removeContents(["~/Library/Developer/CoreSimulator/Caches"])
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
            id: "xcode.runtimesOutdated",
            title: String(localized: "Runtimes de simulateur obsolètes"),
            detail: String(localized: "Versions d'iOS remplacées par une plus récente ou marquées inutilisables. Plusieurs Go chacune, stockées hors de ton dossier personnel."),
            consequence: String(localized: "Aucune : une version plus récente est installée."),
            category: .xcode, risk: .safe, defaultSelected: true,
            availability: "xcrun simctl runtime list >/dev/null 2>&1",
            probe: .simRuntimes(["--outdated", "--unusable"]),
            action: .sequence([
                .shell(runtimeDelete("--outdated")),
                .shell(runtimeDelete("--unusable")),
            ])
        ),
        CleanupItem(
            id: "xcode.runtimesUnused",
            title: String(localized: "Runtimes non utilisés depuis 60 jours"),
            detail: String(localized: "Versions d'iOS, watchOS ou visionOS qu'aucun simulateur n'a lancées récemment."),
            consequence: String(localized: "Xcode les retélécharge (Réglages › Components) si un projet en a besoin."),
            category: .xcode, risk: .rebuild, defaultSelected: false,
            availability: "xcrun simctl runtime list >/dev/null 2>&1",
            probe: .simRuntimes(["--notUsedSinceDays 60"]),
            action: .shell(runtimeDelete("--notUsedSinceDays 60"))
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
            id: "android.gradleWrapper",
            title: String(localized: "Distributions Gradle (wrapper)"),
            detail: String(localized: "Une copie complète de Gradle par version utilisée dans tes projets."),
            consequence: String(localized: "Chaque projet retélécharge sa version de Gradle (~150 Mo) au prochain build."),
            category: .android, risk: .rebuild, defaultSelected: false,
            probe: .paths(["~/.gradle/wrapper/dists"]),
            action: .removePaths(["~/.gradle/wrapper/dists"])
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
            id: "packages.yarn",
            title: String(localized: "Cache Yarn (Berry)"),
            detail: String(localized: "Archives de paquets de Yarn 2 et plus."),
            consequence: String(localized: "Les prochains « yarn install » retéléchargent."),
            category: .packages, risk: .safe, defaultSelected: true,
            probe: .paths(["~/.yarn/berry/cache"]),
            action: .removeContents(["~/.yarn/berry/cache"])
        ),
        CleanupItem(
            id: "packages.pnpm",
            title: String(localized: "Store pnpm"),
            detail: String(localized: "Paquets que plus aucun projet ne référence."),
            consequence: String(localized: "Aucune."),
            category: .packages, risk: .safe, defaultSelected: true,
            availability: "command -v pnpm",
            // Seuls les paquets non référencés partent : la taille du store
            // surestimerait le gain.
            probe: .none,
            action: .shell("pnpm store prune")
        ),
        CleanupItem(
            id: "packages.bun",
            title: String(localized: "Cache bun"),
            detail: String(localized: "Paquets téléchargés par bun."),
            consequence: String(localized: "Les prochains « bun install » retéléchargent."),
            category: .packages, risk: .safe, defaultSelected: true,
            probe: .paths(["~/.bun/install/cache"]),
            action: .removeContents(["~/.bun/install/cache"])
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
            id: "packages.uv",
            title: String(localized: "Cache uv (Python)"),
            detail: String(localized: "Paquets Python téléchargés par uv."),
            consequence: String(localized: "Les environnements se recréent en retéléchargeant."),
            category: .packages, risk: .safe, defaultSelected: true,
            availability: "command -v uv",
            probe: .shellKB("du -sk \"$(uv cache dir 2>/dev/null)\" 2>/dev/null | cut -f1"),
            action: .shell("uv cache clean")
        ),
        CleanupItem(
            id: "packages.cargo",
            title: String(localized: "Registre Cargo (Rust)"),
            detail: String(localized: "Sources et archives des crates téléchargées."),
            consequence: String(localized: "Le prochain « cargo build » retélécharge les crates."),
            category: .packages, risk: .rebuild, defaultSelected: true,
            probe: .paths(["~/.cargo/registry/cache", "~/.cargo/registry/src", "~/.cargo/git/checkouts"]),
            action: .removePaths(["~/.cargo/registry/cache", "~/.cargo/registry/src", "~/.cargo/git/checkouts"])
        ),
        CleanupItem(
            id: "packages.go",
            title: String(localized: "Modules Go"),
            detail: String(localized: "Cache des modules Go (GOMODCACHE)."),
            consequence: String(localized: "Le prochain « go build » retélécharge les modules."),
            category: .packages, risk: .rebuild, defaultSelected: false,
            availability: "command -v go",
            probe: .shellKB("du -sk \"$(go env GOMODCACHE)\" 2>/dev/null | cut -f1"),
            action: .shell("go clean -modcache")
        ),
        CleanupItem(
            id: "packages.maven",
            title: String(localized: "Dépôt Maven local"),
            detail: String(localized: "~/.m2/repository, partagé par Maven et certains builds Gradle."),
            consequence: String(localized: "Maven et Gradle retéléchargent les dépendances."),
            category: .packages, risk: .rebuild, defaultSelected: false,
            probe: .paths(["~/.m2/repository"]),
            action: .removePaths(["~/.m2/repository"])
        ),
        CleanupItem(
            id: "packages.cliCache",
            title: String(localized: "Outils téléchargés (~/.cache)"),
            detail: String(localized: "Navigateurs de Puppeteer et Selenium, binaires Prisma ou MongoDB, modèles Hugging Face…"),
            consequence: String(localized: "Chaque outil retélécharge ce dont il a besoin, parfois plusieurs Go (modèles d'IA)."),
            category: .packages, risk: .rebuild, defaultSelected: false,
            probe: .paths(["~/.cache"]),
            action: .removeContents(["~/.cache"])
        ),

        // MARK: Éditeurs & IDE
        CleanupItem(
            id: "ide.outdated",
            title: String(localized: "Anciennes versions d'IDE"),
            detail: String(localized: "Réglages, plugins et index JetBrains et Android Studio de versions remplacées par une plus récente."),
            consequence: String(localized: "La version actuelle a déjà importé ses réglages ; seules les anciennes disparaissent."),
            category: .ide, risk: .rebuild, defaultSelected: false,
            probe: .dynamic(outdatedIDEs),
            action: .removeDynamic(outdatedIDEs)
        ),
        CleanupItem(
            id: "caches.vscode",
            title: String(localized: "Caches VS Code"),
            detail: String(localized: "Cache, CachedData et extensions déjà installées."),
            consequence: String(localized: "Aucune."),
            category: .ide, risk: .safe, defaultSelected: true,
            probe: .paths(vscodeCaches),
            action: .removePaths(vscodeCaches)
        ),

        // MARK: Apps & appareils
        CleanupItem(
            id: "apps.chromium",
            title: String(localized: "Caches des apps Electron et Chrome"),
            detail: String(localized: "Cache, Code Cache, GPUCache… de Slack, Discord, Teams, Chrome, Figma, etc."),
            consequence: String(localized: "Ferme ces apps avant : elles reconstruisent leurs caches au prochain lancement."),
            category: .apps, risk: .safe, defaultSelected: false,
            probe: .dynamic(chromiumCaches),
            action: .removeDynamic(chromiumCaches)
        ),
        CleanupItem(
            id: "apps.iosUpdates",
            title: String(localized: "Mises à jour iOS téléchargées"),
            detail: String(localized: "Fichiers .ipsw gardés par le Finder après une mise à jour par câble."),
            consequence: String(localized: "Aucune : le Finder les retélécharge si besoin."),
            category: .apps, risk: .safe, defaultSelected: true,
            probe: .paths(["~/Library/iTunes/iPhone Software Updates", "~/Library/iTunes/iPad Software Updates"]),
            action: .removeContents(["~/Library/iTunes/iPhone Software Updates", "~/Library/iTunes/iPad Software Updates"])
        ),
        CleanupItem(
            id: "apps.iosBackups",
            title: String(localized: "Sauvegardes iPhone et iPad"),
            detail: String(localized: "Sauvegardes locales faites par le Finder. Souvent des dizaines de Go."),
            consequence: String(localized: "Mises à la Corbeille. Vérifie que tes appareils sont sauvegardés ailleurs (iCloud) avant de la vider."),
            category: .apps, risk: .data, defaultSelected: false,
            probe: .paths([iosBackups]),
            action: .trashDynamic(.contents(of: iosBackups))
        ),
        CleanupItem(
            id: "apps.installers",
            title: String(localized: "Installeurs dans Téléchargements"),
            detail: String(localized: "Fichiers .dmg, .pkg, .xip, .ipsw et .iso de ~/Downloads."),
            consequence: String(localized: "Mis à la Corbeille, donc récupérables. Un Xcode.xip pèse à lui seul plus de 10 Go."),
            category: .apps, risk: .data, defaultSelected: false,
            probe: .dynamic(installers),
            action: .trashDynamic(installers)
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
        // En dernier : les éléments « mis à la Corbeille » passent avant.
        CleanupItem(
            id: "system.trash",
            title: String(localized: "Vider la Corbeille"),
            detail: String(localized: "~/.Trash, y compris ce que Setal vient d'y mettre."),
            consequence: String(localized: "Définitif : les fichiers de la Corbeille ne sont plus récupérables."),
            category: .system, risk: .data, defaultSelected: false,
            probe: .paths(["~/.Trash"]),
            action: .removeContents(["~/.Trash"])
        ),
    ]

    /// `simctl` échoue quand rien ne correspond : ce n'est pas une erreur ici.
    static func runtimeDelete(_ selector: String) -> String {
        "xcrun simctl runtime delete \(selector) || "
            + "xcrun simctl runtime delete \(selector) --dry-run 2>&1 | grep -q 'No matching'"
    }
}
