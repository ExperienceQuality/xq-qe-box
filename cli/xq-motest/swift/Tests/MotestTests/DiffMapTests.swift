import XCTest
@testable import Motest

final class DiffMapTests: XCTestCase {
    func testAddedRemoved() {
        let previous = MapDocument(
            version: 1,
            createdAt: "t",
            baseURL: "http://x",
            bundleID: nil,
            raw: .null,
            refs: [
                "@e1": .object(["role": .string("button"), "label": .string("Sign In")]),
                "@e2": .object(["role": .string("textfield"), "label": .string("Email")]),
            ],
            summary: [:]
        )
        let current = MapDocument(
            version: 1,
            createdAt: "t",
            baseURL: "http://x",
            bundleID: nil,
            raw: .null,
            refs: [
                "@e1": .object(["role": .string("button"), "label": .string("OK")]),
            ],
            summary: [:]
        )
        let result = DiffMap.diff(previous: previous, current: current)
        XCTAssertEqual(result["unchanged"], .int(0))
        let added = result["added"]?.arrayValue?.compactMap(\.stringValue) ?? []
        XCTAssertTrue(added.contains { $0.contains("OK") })
    }
}
