import Foundation

struct HealthResult: Sendable {
    let ok: Bool
    let statusCode: Int
    let durationMs: Int
}

struct JSONRPCError: Sendable {
    let code: Int
    let message: String
}

struct JSONRPCResponse: Sendable {
    let result: JSONValue?
    let error: JSONRPCError?
    let id: Int
}

protocol KitTransport: Sendable {
    func fetchHealth() async throws -> HealthResult
    func call(method: String, params: JSONValue?, rpcID: Int) async throws -> JSONRPCResponse
    func callAction(method: String, params: JSONValue?, rpcID: Int) async throws
}

enum WSCodec {
    static func encodeRequest(method: String, params: JSONValue?, rpcID: Int = 1) throws -> String {
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

    static func decodeResponse(_ raw: String, rpcID: Int = 1) throws -> JSONRPCResponse {
        let data = Data(raw.utf8)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MotestError.internal("JSON-RPC response must be an object")
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

final class MockTransport: KitTransport, @unchecked Sendable {
    var healthOK: Bool
    var healthStatus: Int
    var healthDurationMs: Int
    var responses: [String: JSONRPCResponse]
    var raiseOnConnect: MotestError?
    private(set) var calls: [(String, JSONValue?)] = []

    init(
        healthOK: Bool = false,
        healthStatus: Int = 503,
        healthDurationMs: Int = 1,
        responses: [String: JSONRPCResponse] = [:],
        raiseOnConnect: MotestError? = nil
    ) {
        self.healthOK = healthOK
        self.healthStatus = healthStatus
        self.healthDurationMs = healthDurationMs
        self.responses = responses
        self.raiseOnConnect = raiseOnConnect
    }

    func fetchHealth() async throws -> HealthResult {
        if let raiseOnConnect { throw raiseOnConnect }
        return HealthResult(ok: healthOK, statusCode: healthStatus, durationMs: healthDurationMs)
    }

    func call(method: String, params: JSONValue?, rpcID: Int = 1) async throws -> JSONRPCResponse {
        calls.append((method, params))
        if let raiseOnConnect { throw raiseOnConnect }
        if let response = responses[method] { return response }
        return JSONRPCResponse(
            result: nil,
            error: JSONRPCError(code: -1, message: "no mock for \(method)"),
            id: rpcID
        )
    }

    func callAction(method: String, params: JSONValue?, rpcID: Int = 1) async throws {
        let response = try await call(method: method, params: params, rpcID: rpcID)
        if let error = response.error {
            throw MotestError.rpc(error.message, command: method)
        }
    }
}

final class HTTPHealthTransport: KitTransport, @unchecked Sendable {
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func fetchHealth() async throws -> HealthResult {
        guard let url = config.healthURL() else {
            throw MotestError.transport("invalid base URL")
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
            throw MotestError.transport("Connection refused: \(error.localizedDescription)")
        }
    }

    func call(method: String, params: JSONValue?, rpcID: Int = 1) async throws -> JSONRPCResponse {
        try await WSJSONRPCTransport(config: config).call(method: method, params: params, rpcID: rpcID)
    }

    func callAction(method: String, params: JSONValue?, rpcID: Int = 1) async throws {
        try await WSJSONRPCTransport(config: config).callAction(method: method, params: params, rpcID: rpcID)
    }
}

final class WSJSONRPCTransport: KitTransport, @unchecked Sendable {
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func fetchHealth() async throws -> HealthResult {
        try await HTTPHealthTransport(config: config).fetchHealth()
    }

    func call(method: String, params: JSONValue?, rpcID: Int = 1) async throws -> JSONRPCResponse {
        try await Timeout.run(seconds: config.timeoutSec) {
            try await self.callUnbounded(method: method, params: params, rpcID: rpcID)
        }
    }

    private func callUnbounded(method: String, params: JSONValue?, rpcID: Int) async throws -> JSONRPCResponse {
        guard let url = config.wsURL() else {
            throw MotestError.transport("invalid base URL")
        }
        let requestText = try WSCodec.encodeRequest(method: method, params: params, rpcID: rpcID)
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeoutSec
        sessionConfig.timeoutIntervalForResource = config.timeoutSec
        let session = URLSession(configuration: sessionConfig)
        let task = session.webSocketTask(with: url)
        task.resume()
        defer {
            task.cancel(with: .goingAway, reason: nil)
            session.invalidateAndCancel()
        }
        try await task.send(.string(requestText))
        let message = try await task.receive()
        let raw: String
        switch message {
        case .string(let text):
            raw = text
        case .data(let data):
            raw = String(decoding: data, as: UTF8.self)
        @unknown default:
            throw MotestError.internal("unexpected websocket frame")
        }
        return try WSCodec.decodeResponse(raw, rpcID: rpcID)
    }

    func callAction(method: String, params: JSONValue?, rpcID: Int = 1) async throws {
        let response = try await call(method: method, params: params, rpcID: rpcID)
        if let error = response.error {
            throw MotestError.rpc(error.message, command: method)
        }
    }
}
