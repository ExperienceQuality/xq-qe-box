import XCTest
@testable import Motest

final class RuntimeEnsureTests: XCTestCase {
    func testDisabledIsNoOp() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("xq-motest-runtime-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let config = Config(ensureRuntime: false, stateDir: dir)
        XCTAssertNoThrow(try RuntimeEnsure.ensure(config: config))
    }

    func testMissingInstallFailsWithHint() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("xq-motest-runtime-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let config = Config(ensureRuntime: true, stateDir: dir)
        do {
            try RuntimeEnsure.ensure(config: config)
            XCTFail("expected runtime error")
        } catch let error as CLIError {
            XCTAssertEqual(error.exitCode, ExitCodes.runtime)
            XCTAssertTrue(error.hint.contains("devicekit install"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testListenPortFromBaseURL() {
        let config = Config(baseURL: "http://127.0.0.1:12004")
        XCTAssertEqual(config.listenPort(), 12_004)
    }
}
