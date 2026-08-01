import Foundation

public struct HealthResult: Sendable {
    public let ok: Bool
    public let statusCode: Int
    public let durationMs: Int
}

public struct JSONRPCError: Sendable {
    public let code: Int
    public let message: String
}

public struct JSONRPCResponse: Sendable {
    public let result: JSONValue?
    public let error: JSONRPCError?
    public let id: Int
}

public protocol KitTransport: Sendable {
    func fetchHealth() async throws -> HealthResult
    func call(method: String, params: JSONValue?, rpcID: Int) async throws -> JSONRPCResponse
    func callAction(method: String, params: JSONValue?, rpcID: Int) async throws
}

public enum WSCodec {
    public static func encodeRequest(method: String, params: JSONValue?, rpcID: Int = 1) throws -> String {
        var payload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method,
            "id": rpcID,
        ]
        if let params {
            payload["params"] = params.foundationValue
        }
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        return String(decoding: data, as: UTF8.self)
    }

    public static func decodeResponse(_ raw: String, rpcID: Int = 1) throws -> JSONRPCResponse {
        let data = Data(raw.utf8)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CLIError.internal("JSON-RPC response must be an object")
        }
        var error: JSONRPCError?
        if let err = object["error"] as? [String: Any] {
            error = JSONRPCError(
                code: err["code"] as? Int ?? -1,
                message: err["message"] as? String ?? "unknown error"
            )
        }
        let result = object["result"].map { JSONValue(any: $0) }
        let id = object["id"] as? Int ?? rpcID
        return JSONRPCResponse(result: result, error: error, id: id)
    }
}

public final class MockTransport: KitTransport, @unchecked Sendable {
    public var healthOK: Bool
    public var healthStatus: Int
    public var healthDurationMs: Int
    public var responses: [String: JSONRPCResponse]
    public var raiseOnConnect: CLIError?
    public private(set) var calls: [(String, JSONValue?)] = []

    public init(
        healthOK: Bool = false,
        healthStatus: Int = 503,
        healthDurationMs: Int = 1,
        responses: [String: JSONRPCResponse] = [:],
        raiseOnConnect: CLIError? = nil
    ) {
        self.healthOK = healthOK
        self.healthStatus = healthStatus
        self.healthDurationMs = healthDurationMs
        self.responses = responses
        self.raiseOnConnect = raiseOnConnect
    }

    public func fetchHealth() async throws -> HealthResult {
        if let raiseOnConnect { throw raiseOnConnect }
        return HealthResult(ok: healthOK, statusCode: healthStatus, durationMs: healthDurationMs)
    }

    public func call(method: String, params: JSONValue?, rpcID: Int = 1) async throws -> JSONRPCResponse {
        calls.append((method, params))
        if let raiseOnConnect { throw raiseOnConnect }
        if let response = responses[method] { return response }
        return JSONRPCResponse(
            result: nil,
            error: JSONRPCError(code: -1, message: "no mock for \(method)"),
            id: rpcID
        )
    }

    public func callAction(method: String, params: JSONValue?, rpcID: Int = 1) async throws {
        let response = try await call(method: method, params: params, rpcID: rpcID)
        if let error = response.error {
            throw CLIError.rpc(error.message, command: method)
        }
    }
}

public final class HTTPHealthTransport: KitTransport, @unchecked Sendable {
    private let config: Config

    public init(config: Config) {
        self.config = config
    }

    public func fetchHealth() async throws -> HealthResult {
        guard let url = config.healthURL() else {
            throw CLIError.transport("invalid base URL")
        }
        let started = Date()
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = config.timeoutSec
            let (_, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let duration = Int(Date().timeIntervalSince(started) * 1000)
            return HealthResult(ok: (200..<300).contains(statusCode), statusCode: statusCode, durationMs: duration)
        } catch {
            throw CLIError.transport("Connection refused: \(error.localizedDescription)")
        }
    }

    public func call(method: String, params: JSONValue?, rpcID: Int = 1) async throws -> JSONRPCResponse {
        try await WSJSONRPCTransport(config: config).call(method: method, params: params, rpcID: rpcID)
    }

    public func callAction(method: String, params: JSONValue?, rpcID: Int = 1) async throws {
        try await WSJSONRPCTransport(config: config).callAction(method: method, params: params, rpcID: rpcID)
    }
}

public final class WSJSONRPCTransport: KitTransport, @unchecked Sendable {
    private let config: Config

    public init(config: Config) {
        self.config = config
    }

    public func fetchHealth() async throws -> HealthResult {
        try await HTTPHealthTransport(config: config).fetchHealth()
    }

    public func call(method: String, params: JSONValue?, rpcID: Int = 1) async throws -> JSONRPCResponse {
        guard let url = config.wsURL() else {
            throw CLIError.transport("invalid base URL")
        }
        let requestText = try WSCodec.encodeRequest(method: method, params: params, rpcID: rpcID)
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        task.resume()
        defer { task.cancel(with: .goingAway, reason: nil) }
        try await task.send(.string(requestText))
        let message = try await task.receive()
        let raw: String
        switch message {
        case .string(let text):
            raw = text
        case .data(let data):
            raw = String(decoding: data, as: UTF8.self)
        @unknown default:
            throw CLIError.internal("unexpected websocket frame")
        }
        return try WSCodec.decodeResponse(raw, rpcID: rpcID)
    }

    public func callAction(method: String, params: JSONValue?, rpcID: Int = 1) async throws {
        let response = try await call(method: method, params: params, rpcID: rpcID)
        if let error = response.error {
            throw CLIError.rpc(error.message, command: method)
        }
    }
}
