# Contributing to Setal

Thanks for helping! Setal deletes files, so the bar for safety is high, but
adding a new cleanup target is usually small.

## Adding a cleanup target

1. Add a `CleanupItem` to [`Sources/SetalCore/Catalog.swift`](Sources/SetalCore/Catalog.swift):
   - `probe`: how to measure it (`.paths`, `.shellKB`, `.dynamic`, …);
   - `action`: how to clean it. Prefer the tool's own command
     (`npm cache clean --force`) over deleting its folder;
   - `risk`: be honest.
     - `.safe`: a pure cache, rebuilt silently;
     - `.rebuild`: downloaded or compiled again, the next build is slower;
     - `.data`: the user might want it back. **Never** `defaultSelected: true`.
   - `consequence`: one sentence telling the user what happens afterwards.
2. Paths must pass [`PathGuard`](Sources/SetalCore/PathGuard.swift):
   inside `~/Library/…` or a hidden folder of the home, at least two levels
   deep. `CatalogTests` checks this for every item. Please do not loosen the
   guard in the same PR as a new target.
3. Anything that is really the user's (backups, downloads) should go to the
   Trash (`.trashDynamic`), not be deleted.
4. Run `./Scripts/sync-strings.sh` and translate the new strings in
   `Resources/Localizable.xcstrings` (Xcode's String Catalog editor works
   well) for every language listed in `.github/workflows/ci.yml`. CI fails
   on untranslated strings. Not fluent in all of them? Open the PR anyway
   and say so: maintainers will complete the rest.
5. `swift test` and `./build-app.sh`, then try the item on your Mac.

## Adding a language

Add it to the String Catalog, to `CFBundleLocalizations` in
`Resources/Info.plist`, to `AppLanguage` in `Sources/Setal/SettingsView.swift`
and to the language list checked in `.github/workflows/ci.yml`.

The current translations beyond French and English were machine-assisted:
corrections from native speakers are very welcome. A Wolof translation would
be especially welcome.

## Code style

- Core logic goes in `SetalCore` with tests; `Setal` is only UI.
- Source language is French (strings and comments); identifiers are English.

## Reporting a dangerous bug

If Setal deleted or could delete something it should not, please follow
[SECURITY.md](SECURITY.md).
