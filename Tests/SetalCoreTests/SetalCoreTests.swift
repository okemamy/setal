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
        }
    }
}
