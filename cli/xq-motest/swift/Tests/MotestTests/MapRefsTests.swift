import XCTest
@testable import Motest

final class MapRefsTests: XCTestCase {
    func testAssignRefsDepthFirst() {
        let tree: JSONValue = .object([
            "tree": .object([
                "role": .string("application"),
                "children": .array([
                    .object([
                        "role": .string("button"),
                        "label": .string("Sign In"),
                        "frame": .object([
                            "x": .int(10), "y": .int(20), "width": .int(100), "height": .int(44),
                        ]),
                    ]),
                    .object([
                        "role": .string("textfield"),
                        "placeholder": .string("Email"),
                        "frame": .object([
                            "x": .int(10), "y": .int(80), "width": .int(200), "height": .int(44),
                        ]),
                    ]),
                    .object([
                        "role": .string("text"),
                        "label": .string("Hidden"),
                        "frame": .object([
                            "x": .int(0), "y": .int(0), "width": .int(0), "height": .int(0),
                        ]),
                    ]),
                ]),
            ]),
        ])
        let assigned = MapRefs.assign(tree)
        XCTAssertEqual(assigned.summary["count"], .int(2))
        XCTAssertNotNil(assigned.refs["@e1"])
        XCTAssertEqual(assigned.refs["@e1"]?.objectValue?["label"], .string("Sign In"))
    }
}
