# Setal

> *Setal* — « nettoyer, rendre propre » en wolof. Clin d'œil au mouvement
> **Set Setal** qui a vu la jeunesse de Dakar nettoyer la ville en 1990.

Petite app macOS (SwiftUI) qui réduit la catégorie **« Données système »** de
Réglages › Stockage sur un Mac de développeur.

## Le cas d'origine

Le 8 novembre 2026, « Données système » occupait **203 Go** et il ne restait
que 34 Go libres. Ce qui la remplissait :

| Gisement | Taille | Action |
|---|---|---|
| Docker (`Docker.raw`, dont 21 Go de cache de build) | 47 Go | `docker system prune -af` + `docker builder prune -af`, volumes gardés |
| Simulateurs iOS | 25 Go | `xcrun simctl erase all` |
| Caches Gradle | 18 Go | suppression de `~/.gradle/caches` |
| Émulateurs Android + images système | 21 Go | suppression des AVD et de `sdk/system-images` |
| DerivedData, npm, Homebrew, caches divers | ~9 Go | suppression |

Résultat : **139 Go libres**. Setal refait ce nettoyage en quelques clics.

## Fonctionnement

1. Au lancement, Setal **analyse** (sans rien supprimer) et affiche la taille de chaque élément.
2. Chaque élément porte un niveau de risque :
   - **Sûr** : cache pur, coché par défaut ;
   - **À reconstruire** : retéléchargé ou recompilé au prochain build ;
   - **Perte de données** : jamais coché par défaut, confirmation obligatoire.
3. **Nettoyer** exécute les éléments cochés, affiche l'espace récupéré par
   élément et tient un journal des commandes lancées.

### Garde-fou

Setal ne supprime que dans `~/Library/…` ou un dossier caché du dossier
personnel (`~/.gradle/…`), jamais un dossier de premier niveau et jamais un
chemin `site-packages` (faux positifs `build` de pip). Voir
`Sources/SetalCore/PathGuard.swift` et ses tests.

### Ce que Setal ne fait pas (volontairement)

- les `node_modules`, `build`, `.dart_tool` des projets (à auditer à la main) ;
- les runtimes de simulateur dans `/Library/Developer/CoreSimulator/Volumes` (droits admin) ;
- `~/Library/Application Support/JetBrains` (anciennes versions d'IDE à trier).

## Langues

Français (langue source), anglais, espagnol et portugais. L'app suit la langue
du système ; on peut aussi la changer dans **Setal › Réglages… (⌘,)**.

Les textes sont dans `Resources/Localizable.xcstrings` (String Catalog, à
ouvrir dans Xcode). Après avoir ajouté ou modifié un texte dans le code :

```bash
./Scripts/sync-strings.sh   # ajoute les nouvelles chaînes au catalogue
```

puis traduire les nouvelles entrées dans Xcode. Pour ajouter une langue :
l'ajouter dans le catalogue, dans `CFBundleLocalizations` (`Resources/Info.plist`),
dans `AppLanguage` (`SettingsView.swift`) et dans la boucle `lproj` de `build-app.sh`.

## Construire

```bash
swift test                 # tests du cœur (garde-fou, parsing Docker, catalogue)
swift run Setal            # lancer en développement
./build-app.sh             # → build/Setal.app
./build-app.sh --install   # → aussi dans ~/Applications
```

Prérequis : macOS 14+, Xcode (Swift 5.10+).

## Structure

```
Sources/SetalCore/   logique testable : catalogue, exécution, garde-fou, shell
Sources/Setal/       interface SwiftUI
Tests/               tests XCTest
Scripts/make-icon.swift  génère l'icône (vert et or du drapeau sénégalais)
```

Pour ajouter un élément à nettoyer : une entrée dans `Catalog.swift`.
