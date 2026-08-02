import Foundation

public enum ErrorKind: String, Sendable {
    case usage
    case transport
    case rpc
    case `internal`
    case runtime
}

public enum ResponseTier: Sendable {
    case action
    case data
}

public struct CLIError: Error, Sendable {
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

    public static func usage(_ message: String, hint: String, command: String? = nil) -> CLIError {
        CLIError(kind: .usage, message: message, hint: hint, exitCode: ExitCodes.usage, command: command)
    }

    public static func transport(
        _ message: String,
        hint: String = "xq-motest devicekit start --sim && xq-motest health",
        command: String? = nil
    ) -> CLIError {
        CLIError(kind: .transport, message: message, hint: hint, exitCode: ExitCodes.transport, command: command)
    }

    public static func rpc(_ message: String, command: String? = nil) -> CLIError {
        CLIError(kind: .rpc, message: message, hint: message, exitCode: ExitCodes.rpc, command: command)
    }

    public static func `internal`(_ message: String, command: String? = nil) -> CLIError {
        CLIError(kind: .internal, message: message, hint: message, exitCode: ExitCodes.internal, command: command)
    }

    public static func runtime(_ message: String, hint: String, command: String? = nil) -> CLIError {
        CLIError(kind: .runtime, message: message, hint: hint, exitCode: ExitCodes.runtime, command: command)
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

    public static func emitActionOK(pretty: Bool) -> Never {
        if pretty {
            print("ok")
        } else {
            print(actionOK)
        }
        exit(ExitCodes.success)
    }

    public static func emitFailure(_ error: CLIError, pretty: Bool) -> Never {
        if pretty {
            fputs("error: \(error.message)\n", stderr)
            fputs("hint: \(error.hint)\n", stderr)
        } else {
            let envelope = failure(
                command: error.command,
                kind: error.kind,
                message: error.message,
                hint: error.hint,
                exitCode: error.exitCode
            )
            if let json = try? compactJSON(envelope) {
                print(json)
            }
        }
        exit(error.exitCode)
    }

    public static func emit(
        _ envelope: [String: JSONValue]?,
        pretty: Bool,
        tier: ResponseTier
    ) -> Never {
        if tier == .action, envelope == nil {
            emitActionOK(pretty: pretty)
        }
        guard let envelope else {
            emitFailure(.internal("data tier requires an envelope"), pretty: pretty)
        }
        if pretty {
            let data = try! JSONSerialization.data(
                withJSONObject: envelope.mapValues(\.foundationValue),
                options: [.prettyPrinted, .sortedKeys]
            )
            print(String(decoding: data, as: UTF8.self))
        } else if let json = try? compactJSON(envelope) {
            print(json)
        }
        exit(ExitCodes.success)
    }
}
