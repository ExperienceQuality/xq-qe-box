import XCTest
@testable import Motest

final class TransportTests: XCTestCase {
    func testEncodeDecodeJSONRPC() throws {
        let request = try WSCodec.encodeRequest(method: "device.dump.ui", params: .object([:]))
        XCTAssertTrue(request.contains("device.dump.ui"))
        let response = try WSCodec.decodeResponse(
            #"{"jsonrpc":"2.0","result":{"ok":true},"id":1}"#
        )
        XCTAssertNil(response.error)
        XCTAssertEqual(response.result?.objectValue?["ok"], .bool(true))
    }

    func testMockTransportRPCError() async throws {
        let config = Config(ensureRuntime: false)
        let transport = MockTransport(
            responses: [
                "device.dump.ui": JSONRPCResponse(
                    result: nil,
                    error: JSONRPCError(code: -1, message: "rpc failed"),
                    id: 1
                ),
            ]
        )
        do {
            _ = try await KitCall.call(config: config, transport: transport, method: "device.dump.ui")
            XCTFail("expected rpc error")
        } catch let error as CLIError {
            XCTAssertEqual(error.exitCode, ExitCodes.rpc)
        }
    }
}
