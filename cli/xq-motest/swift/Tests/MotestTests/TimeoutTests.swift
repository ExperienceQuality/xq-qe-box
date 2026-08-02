import XCTest
@testable import Motest

final class TimeoutTests: XCTestCase {
    func testCompletesBeforeDeadline() async throws {
        let value = try await Timeout.run(seconds: 2) {
            "ok"
        }
        XCTAssertEqual(value, "ok")
    }

    func testThrowsTimeoutError() async {
        do {
            _ = try await Timeout.run(seconds: 0.05) {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                return "late"
            }
            XCTFail("expected timeout")
        } catch let error as CLIError {
            XCTAssertEqual(error.kind, .timeout)
            XCTAssertEqual(error.exitCode, ExitCodes.timeout)
            XCTAssertTrue(error.message.contains("timed out"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testWrappingPreservesCLIError() {
        let original = CLIError.timeout("boom")
        let wrapped = CLIError.wrapping(original)
        XCTAssertEqual(wrapped.kind, .timeout)
        XCTAssertEqual(wrapped.message, "boom")
    }

    func testWrappingMapsUnknownErrors() {
        struct Weird: Error {}
        let wrapped = CLIError.wrapping(Weird(), command: "tap")
        XCTAssertEqual(wrapped.kind, .internal)
        XCTAssertEqual(wrapped.exitCode, ExitCodes.internal)
        XCTAssertEqual(wrapped.command, "tap")
    }
}
