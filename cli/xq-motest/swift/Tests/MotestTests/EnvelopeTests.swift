import XCTest
@testable import Motest

final class EnvelopeTests: XCTestCase {
    func testActionOKConstant() {
        XCTAssertEqual(Envelope.actionOK, #"{"ok":true}"#)
    }

    func testFailureEnvelope() throws {
        let envelope = Envelope.failure(
            command: "tap",
            kind: .usage,
            message: "bad",
            hint: "xq-motest tap @e3",
            exitCode: ExitCodes.usage
        )
        XCTAssertEqual(envelope["ok"], .bool(false))
        XCTAssertEqual(envelope["exitCode"], .int(2))
    }

    func testContractActionOK() throws {
        let contractURL = ModulePaths.contractFile("action.ok.json")
        let data = try Data(contentsOf: contractURL)
        let expected = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(Envelope.actionOK, expected)
    }
}
