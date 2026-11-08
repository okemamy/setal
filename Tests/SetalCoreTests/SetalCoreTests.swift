import XCTest
@testable import SetalCore

final class PathGuardTests: XCTestCase {
    let home = "/Users/test"

    func testAllowsLibraryAndHiddenFolders() {
        XCTAssertTrue(PathGuard.isSafeToDelete("~/Library/Caches", home: home))
        XCTAssertTrue(PathGuard.isSafeToDelete("~/Library/Caches/com.example", home: home))
        XCTAssertTrue(PathGuard.isSafeToDelete("~/.gradle/caches", home: home))
    }

    func testRefusesTopLevelAndUserFolders() {
        XCTAssertFalse(PathGuard.isSafeToDelete("~", home: home))
        XCTAssertFalse(PathGuard.isSafeToDelete("~/Library", home: home))
        XCTAssertFalse(PathGuard.isSafeToDelete("~/.gradle", home: home))
        XCTAssertFalse(PathGuard.isSafeToDelete("~/Documents/old", home: home))
        XCTAssertFalse(PathGuard.isSafeToDelete("~/Codes/app/build", home: home))
        XCTAssertFalse(PathGuard.isSafeToDelete("/Library/Caches", home: home))
        XCTAssertFalse(PathGuard.isSafeToDelete("/Users/testother/Library/Caches", home: home))
    }

    func testRefusesTraversalAndPipBuildFolders() {
        XCTAssertFalse(PathGuard.isSafeToDelete("~/Library/../Documents/x", home: home))
        XCTAssertFalse(PathGuard.isSafeToDelete(
            "~/.venv/lib/python3.12/site-packages/pip/_internal/operations/build", home: home))
    }
}

final class DockerSizeTests: XCTestCase {
    func testParse() {
        XCTAssertEqual(DockerSize.parse("804.2MB (72%)"), 804_200_000)
        XCTAssertEqual(DockerSize.parse("21.58GB"), 21_580_000_000)
        XCTAssertEqual(DockerSize.parse("0B"), 0)
        XCTAssertEqual(DockerSize.parse("12kB"), 12_000)
        XCTAssertNil(DockerSize.parse("n/a"))
    }

    func testReclaimableFiltersTypes() {
        let output = """
        Images|804.2MB (72%)
        Containers|0B (0%)
        Local Volumes|614.3MB (7%)
        Build Cache|20.96GB
        """
        XCTAssertEqual(
            DockerSize.reclaimable(output, types: ["Images", "Containers", "Build Cache"]),
            804_200_000 + 20_960_000_000)
        XCTAssertEqual(DockerSize.reclaimable(output, types: ["Local Volumes"]), 614_300_000)
    }
}

final class CatalogTests: XCTestCase {
    func testIdsAreUnique() {
        let ids = Catalog.items.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testDataLossItemsAreNeverPreselected() {
        for item in Catalog.items where item.risk == .data {
            XCTAssertFalse(item.defaultSelected, item.id)
        }
    }

    func testEveryDeletablePathPassesTheGuard() {
        for item in Catalog.items {
            for path in item.deletablePaths {
                XCTAssertTrue(PathGuard.isSafeToDelete(path), "\(item.id): \(path)")
            }
            for path in item.containerPaths {
                XCTAssertTrue(PathGuard.isSafeContainer(path), "\(item.id): \(path)")
            }
        }
    }
}

final class PathGuardExceptionsTests: XCTestCase {
    let home = "/Users/test"

    func testTrashContentsCanBeEmptiedButNotOtherTopLevelFolders() {
        XCTAssertTrue(PathGuard.isSafeContainer("~/.Trash", home: home))
        XCTAssertTrue(PathGuard.isSafeToDelete("~/.Trash/old.zip", home: home))
        XCTAssertFalse(PathGuard.isSafeContainer("~/Library", home: home))
        XCTAssertFalse(PathGuard.isSafeContainer("~/Documents", home: home))
    }

    func testOnlyInstallersDirectlyInDownloadsMayBeTrashed() {
        XCTAssertTrue(PathGuard.isSafeToTrash("~/Downloads/Xcode_27.xip", home: home))
        XCTAssertTrue(PathGuard.isSafeToTrash("~/Downloads/Setup.DMG", home: home))
        XCTAssertFalse(PathGuard.isSafeToTrash("~/Downloads/thesis.pdf", home: home))
        XCTAssertFalse(PathGuard.isSafeToTrash("~/Downloads/sub/app.dmg", home: home))
        XCTAssertFalse(PathGuard.isSafeToTrash("~/Desktop/app.dmg", home: home))
        XCTAssertFalse(PathGuard.isSafeToDelete("~/Downloads/app.dmg", home: home))
    }
}

final class FinderTests: XCTestCase {
    func testOutdatedIDEVersionsKeepsNewestPerProduct() {
        let names = ["AndroidStudio2026.1.1", "AndroidStudio2026.1.4", "AndroidStudio2026.2.1",
                     "PyCharm2025.2", "PyCharm2026.2", "WebStorm2026.1", "Chrome", "consentOptions"]
        XCTAssertEqual(Finder.outdatedVersions(names),
                       ["AndroidStudio2026.1.1", "AndroidStudio2026.1.4", "PyCharm2025.2"])
    }

    func testVersionComparisonIsNumeric() {
        XCTAssertEqual(Finder.outdatedVersions(["Rider2026.10", "Rider2026.9"]), ["Rider2026.9"])
    }

    func testSimRuntimeTotal() {
        let dryRun = "Would delete: 4FC67E96-CD4F-4884-8AC2-960B6F04DB9A iOS 26.0"
        let json = """
        {"4FC67E96-CD4F-4884-8AC2-960B6F04DB9A": {"sizeBytes": 8067000161},
         "11111111-2222-3333-4444-555555555555": {"sizeBytes": 999}}
        """
        XCTAssertEqual(SimRuntimes.total(dryRun: dryRun, listJSON: json), 8_067_000_161)
        XCTAssertEqual(SimRuntimes.total(dryRun: "No matching images found to delete", listJSON: json), 0)
    }
}

final class ProjectScannerTests: XCTestCase {
    var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("setal-tests-\(UUID().uuidString)").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func make(_ path: String, file: Bool = false) throws {
        let url = root.appendingPathComponent(path)
        if file {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: url.path, contents: Data())
        } else {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    func testFindsArtifactsOnlyNextToTheirMarker() throws {
        try make("web/package.json", file: true)
        try make("web/node_modules/left-pad/node_modules")   // imbriqué : non compté deux fois
        try make("app/pubspec.yaml", file: true)
        try make("app/build")
        try make("app/.dart_tool")
        try make("app/android/settings.gradle", file: true)
        try make("app/android/.gradle")
        try make("app/ios/Podfile", file: true)
        try make("app/ios/Pods")
        try make("notes/build")                              // pas de marqueur : ignoré
        try make("py/.venv/lib/site-packages/pip/build")     // pip : ignoré

        let marker = root.lastPathComponent + "/"
        let found = ProjectScanner.scan(root: root.path).compactMap { artifact in
            artifact.path.range(of: marker).map { String(artifact.path[$0.upperBound...]) }
        }.sorted()
        XCTAssertEqual(found, ["app/.dart_tool", "app/android/.gradle", "app/build",
                               "app/ios/Pods", "web/node_modules"])
    }

    func testRevalidationBeforeDeletion() throws {
        try make("web/package.json", file: true)
        try make("web/node_modules")
        try make("notes/build")
        let home = root.path
        XCTAssertTrue(ProjectScanner.isStillArtifact(root.appendingPathComponent("web/node_modules").path, home: home))
        XCTAssertFalse(ProjectScanner.isStillArtifact(root.appendingPathComponent("notes/build").path, home: home))
        XCTAssertFalse(ProjectScanner.isStillArtifact("/etc/node_modules", home: home))
    }
}

final class ExecutorParsingTests: XCTestCase {
    func testKilobytesTakesLastNumericLine() {
        XCTAssertEqual(Executor.kilobytes("42\n"), 42 * 1024)
        XCTAssertEqual(Executor.kilobytes("==> Auto-updating Homebrew...\n39400\n"), 39400 * 1024)
        XCTAssertNil(Executor.kilobytes("du: no such file"))
    }
}
