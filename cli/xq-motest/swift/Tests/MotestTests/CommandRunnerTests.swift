import XCTest
@testable import Motest

final class CommandRunnerTests: XCTestCase {
    func testTapTargetParsesRefAndCoordinates() throws {
        let byRef = try CommandRunner.TapTarget.parse(
            first: "@e3",
            second: nil,
            ref: nil,
            x: nil,
            y: nil
        )
        XCTAssertEqual(byRef.ref, "@e3")

        let byXY = try CommandRunner.TapTarget.parse(
            first: "10",
            second: "20",
            ref: nil,
            x: nil,
            y: nil
        )
        XCTAssertEqual(byXY.x, 10)
        XCTAssertEqual(byXY.y, 20)

        XCTAssertThrowsError(
            try CommandRunner.TapTarget.parse(first: "nope", second: nil, ref: nil, x: nil, y: nil)
        ) { error in
            let cli = error as? CLIError
            XCTAssertEqual(cli?.kind, .usage)
        }
    }

    func testTypeInputParsesRefPrefix() {
        let parsed = CommandRunner.TypeInput.parse(first: "@e2", rest: ["hello", "world"], ref: nil)
        XCTAssertEqual(parsed.ref, "@e2")
        XCTAssertEqual(parsed.text, "hello world")
    }

    func testForegroundViaMockTransport() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("xq-motest-cr-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let config = Config(ensureRuntime: false, stateDir: dir)
        let transport = MockTransport(
            responses: [
                "device.apps.foreground": JSONRPCResponse(result: .object([:]), error: nil, id: 1),
            ]
        )
        try await CommandRunner.foreground(config: config, transport: transport)
        XCTAssertEqual(transport.calls.map(\.0), ["device.apps.foreground"])
    }

    func testScreenshotWritesDecodedBytes() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("xq-motest-cr-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let config = Config(ensureRuntime: false, stateDir: dir)
        let transport = MockTransport(
            responses: [
                "device.screenshot": JSONRPCResponse(
                    result: .string(png.base64EncodedString()),
                    error: nil,
                    id: 1
                ),
            ]
        )
        let out = dir.appendingPathComponent("shot.png")
        try await CommandRunner.screenshot(config: config, transport: transport, path: out.path)
        XCTAssertEqual(try Data(contentsOf: out), png)
    }

    func testDevicekitStatusEnvelope() async {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("xq-motest-cr-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let config = Config(ensureRuntime: false, stateDir: dir)
        let envelope = await CommandRunner.devicekitStatus(config: config, device: "UDID-1")
        XCTAssertEqual(envelope["ok"], .bool(true))
        XCTAssertEqual(envelope["command"], .string("devicekit.status"))
        XCTAssertEqual(envelope["result"]?.objectValue?["device_id"], .string("UDID-1"))
    }

    func testRpcMissingMethod() async {
        let config = Config(ensureRuntime: false)
        let transport = MockTransport()
        do {
            _ = try await CommandRunner.rpc(
                config: config,
                transport: transport,
                method: nil,
                paramsJSON: nil
            )
            XCTFail("expected usage error")
        } catch let error as CLIError {
            XCTAssertEqual(error.kind, .usage)
            XCTAssertTrue(error.hint.contains("xq-motest rpc "))
            XCTAssertFalse(error.hint.contains("--method"))
        } catch {
            XCTFail("unexpected \(error)")
        }
    }
}
