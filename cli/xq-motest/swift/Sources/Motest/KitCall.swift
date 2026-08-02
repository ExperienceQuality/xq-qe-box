import Foundation

public enum KitCall {
    public static func call(
        config: Config,
        transport: any KitTransport,
        method: String,
        params: JSONValue? = nil
    ) async throws -> (JSONValue, Int) {
        try DeviceKitRuntime.ensure(config: config)
        let started = Date()
        let response = try await transport.call(method: method, params: params, rpcID: 1)
        if let error = response.error {
            throw CLIError.rpc(error.message, command: method)
        }
        let duration = Int(Date().timeIntervalSince(started) * 1000)
        return (response.result ?? .null, duration)
    }

    public static func action(
        config: Config,
        transport: any KitTransport,
        method: String,
        params: JSONValue? = nil
    ) async throws {
        try DeviceKitRuntime.ensure(config: config)
        try await transport.callAction(method: method, params: params, rpcID: 1)
    }
}
