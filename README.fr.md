<p align="center">
  <img src="docs/icon.png" width="128" alt="Icône de Setal">
</p>

<h1 align="center">Setal</h1>

<p align="center">
  <b>Réduire les « Données système » de ton Mac, sans risque.</b><br>
  Petite app macOS open source pour développeurs.<br>
  14 langues : English · Français · Español · Português · Deutsch · Italiano · Nederlands · Русский · Türkçe · العربية · 日本語 · 한국어 · 简体中文 · 繁體中文
</p>

> *Setal* — « nettoyer, rendre propre » en wolof. Clin d'œil au mouvement
> **Set Setal** qui a vu la jeunesse de Dakar nettoyer la ville en 1990.
> Une app [OKEMAMY](http://okemamy.com/) · [Read in English](README.md).

## Pourquoi

Sur un Mac de développeur, **Réglages › Stockage › Données système** dépasse
vite 200 Go. Ce n'est pas le système : c'est le disque virtuel de Docker, les
simulateurs iOS, les caches Gradle, les émulateurs Android, de vieux runtimes
Xcode, des `node_modules`…

Setal vient d'un vrai nettoyage : 203 Go de Données système, 34 Go libres.
Docker (47 Go), simulateurs iOS (25 Go), Gradle (18 Go) et émulateurs Android
(21 Go) en tête. Après : **139 Go libres**.

## Ce qu'elle nettoie

- **Onglet Données système** : Docker (Docker Desktop, OrbStack, Colima),
  Xcode et simulateurs (DerivedData, DeviceSupport, aperçus, runtimes
  obsolètes…), Android et Flutter, gestionnaires de paquets (npm, Yarn, pnpm,
  bun, Homebrew, uv, Cargo, Go, Maven, `~/.cache`), anciennes versions d'IDE,
  caches des apps Electron et Chrome, mises à jour iOS, sauvegardes iPhone,
  installeurs dans Téléchargements, caches, journaux, instantanés Time
  Machine, Corbeille.
- **Onglet Projets** : `node_modules`, `build`, `.dart_tool`, `Pods`,
  `.gradle`, `target`, `.build`, `.next`… dans ton dossier de code. Les
  projets inactifs depuis 30 jours (réglable) sont présélectionnés.

## Sécurité

- **Analyse d'abord**, rien n'est supprimé avant « Nettoyer ».
- **Trois niveaux de risque** : Sûr · À reconstruire · Perte de données
  (jamais coché par défaut, toujours confirmé).
- **Garde-fou** : suppression uniquement dans `~/Library/…` ou un dossier
  caché du home, jamais un dossier de premier niveau.
- **Tes fichiers vont à la Corbeille** : sauvegardes iPhone et installeurs
  sont mis à la Corbeille, pas supprimés.
- **Un artefact de projet doit être prouvé** : un dossier `build` n'est
  retenu que si le fichier de son écosystème est à côté, revérifié juste
  avant la suppression.
- **Journal** de chaque commande et chemin.

## Soutenir Setal

Setal est gratuite et open source. Si elle t'a fait gagner des gigaoctets,
tu peux soutenir son développement :

<p align="center">
  <a href="https://paypal.me/sybirante"><img src="https://img.shields.io/badge/Faire%20un%20don-PayPal-00457C?logo=paypal&logoColor=white" alt="Faire un don avec PayPal"></a>
</p>

Une étoile sur GitHub, un bug signalé ou un nouveau cas de nettoyage
proposé aident tout autant.

## Installer

Télécharger le `.zip` dans les [Releases](../../releases), ou :

```bash
./build-app.sh --install
```

Les versions publiées sont signées (Developer ID) et notarisées par Apple :
elles s'ouvrent sans alerte. App universelle Apple Silicon et Intel, macOS 14
ou plus récent.

## Langues

14 langues : français, anglais, espagnol, portugais, allemand, italien,
néerlandais, russe, turc, arabe, japonais, coréen, chinois simplifié et
traditionnel. L'app suit la langue du système ; on peut la changer dans
**Setal › Réglages… (⌘,)**. Textes dans `Resources/Localizable.xcstrings` ; après avoir
ajouté un texte : `./Scripts/sync-strings.sh`, puis traduire dans Xcode.

## Contribuer

Voir [CONTRIBUTING.md](CONTRIBUTING.md). Licence [MIT](LICENSE) © 2026 [OKEMAMY](http://okemamy.com/).
