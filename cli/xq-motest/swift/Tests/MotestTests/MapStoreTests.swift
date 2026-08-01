import XCTest
@testable import Motest

final class MapStoreTests: XCTestCase {
    func testSaveLoadResolveTap() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = MapStore(stateDir: dir)
        let refs: [String: JSONValue] = [
            "@e1": .object([
                "label": .string("Sign In"),
                "role": .string("button"),
                "center": .object(["x": .int(60), "y": .int(42)]),
            ]),
        ]
        let document = MapDocumentFactory.newDocument(
            baseURL: "http://127.0.0.1:12004",
            bundleID: nil,
            raw: .object([:]),
            refs: refs,
            summary: ["count": .int(1), "refRange": .array([.string("@e1"), .string("@e1")])]
        )
        _ = try store.save(document)
        let tap = try store.resolveTap(ref: "@e1", x: nil, y: nil)
        XCTAssertEqual(tap["x"], .int(60))
        XCTAssertEqual(tap["y"], .int(42))
    }
}
