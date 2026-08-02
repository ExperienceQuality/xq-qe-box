import Foundation

public enum ErrorKind: String, Sendable {
    case usage
    case transport
    case rpc
    case `internal`
    case runtime
    case timeout
}

public enum ResponseTier: Sendable {
    case action
    case data
}

public struct MotestError: Error, Sendable {
    public let kind: ErrorKind
    public let message: String
    public let hint: String
    public let exitCode: Int32
    public let command: String?

    public init(
        kind: ErrorKind,
        message: String,
        hint: String,
        exitCode: Int32,
        command: String? = nil
    ) {
        self.kind = kind
        self.message = message
        self.hint = hint
        self.exitCode = exitCode
        self.command = command
    }

    public static func usage(_ message: String, hint: String, command: String? = nil) -> MotestError {
        MotestError(kind: .usage, message: message, hint: hint, exitCode: ExitCodes.usage, command: command)
    }

    public static func transport(
        _ message: String,
        hint: String = "xq-motest devicekit start --sim && xq-motest health",
        command: String? = nil
    ) -> MotestError {
        MotestError(kind: .transport, message: message, hint: hint, exitCode: ExitCodes.transport, command: command)
    }

    public static func rpc(_ message: String, command: String? = nil) -> MotestError {
        MotestError(kind: .rpc, message: message, hint: message, exitCode: ExitCodes.rpc, command: command)
    }

    public static func `internal`(_ message: String, command: String? = nil) -> MotestError {
        MotestError(kind: .internal, message: message, hint: message, exitCode: ExitCodes.internal, command: command)
    }

    public static func runtime(_ message: String, hint: String, command: String? = nil) -> MotestError {
        MotestError(kind: .runtime, message: message, hint: hint, exitCode: ExitCodes.runtime, command: command)
    }

    public static func timeout(
        _ message: String,
        hint: String = "raise --timeout / XQ_MOTEST_TIMEOUT, or check DeviceKit is responding",
        command: String? = nil
    ) -> MotestError {
        MotestError(kind: .timeout, message: message, hint: hint, exitCode: ExitCodes.timeout, command: command)
    }

    /// Map any thrown error into MotestError for the executable edge.
    public static func wrapping(_ error: Error, command: String? = nil) -> MotestError {
        if let err = error as? MotestError { return err }
        return .internal(String(describing: error), command: command)
    }
}

public enum Envelope {
    public static let actionOK = "{\"ok\":true}"

    public static func failure(
        command: String?,
        kind: ErrorKind,
        message: String,
        hint: String,
        exitCode: Int32
    ) -> [String: JSONValue] {
        var envelope: [String: JSONValue] = [
            "ok": .bool(false),
            "error": .object([
                "kind": .string(kind.rawValue),
                "message": .string(message),
                "hint": .string(hint),
            ]),
            "exitCode": .int(Int(exitCode)),
        ]
        if let command {
            envelope["command"] = .string(command)
        }
        return envelope
    }

    public static func success(
        command: String,
        result: JSONValue,
        baseURL: String,
        method: String? = nil,
        durationMs: Int? = nil,
        extraMeta: [String: JSONValue] = [:]
    ) -> [String: JSONValue] {
        var meta: [String: JSONValue] = ["baseUrl": .string(baseURL)]
        if let method { meta["method"] = .string(method) }
        if let durationMs { meta["durationMs"] = .int(durationMs) }
        for (key, value) in extraMeta { meta[key] = value }
        return [
            "ok": .bool(true),
            "command": .string(command),
            "result": result,
            "meta": .object(meta),
        ]
    }

    public static func compactJSON(_ object: [String: JSONValue]) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: object.mapValues(\.foundationValue),
            options: []
        )
        return String(decoding: data, as: UTF8.self)
    }

    public static func prettyJSON(_ object: [String: JSONValue]) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: object.mapValues(\.foundationValue),
            options: [.prettyPrinted, .sortedKeys]
        )
        return String(decoding: data, as: UTF8.self)
    }
}
