import Foundation
import Motest

/// Process edge only: print agent envelopes and exit. Motest library must not call this.
enum CLIEmit {
    static func emit(
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
            if let json = try? Envelope.prettyJSON(envelope) {
                print(json)
            }
        } else if let json = try? Envelope.compactJSON(envelope) {
            print(json)
        }
        exit(ExitCodes.success)
    }

    static func emitActionOK(pretty: Bool) -> Never {
        if pretty {
            print("ok")
        } else {
            print(Envelope.actionOK)
        }
        exit(ExitCodes.success)
    }

    static func emitFailure(_ error: MotestError, pretty: Bool) -> Never {
        if pretty {
            fputs("error: \(error.message)\n", stderr)
            fputs("hint: \(error.hint)\n", stderr)
        } else {
            let envelope = Envelope.failure(
                command: error.command,
                kind: error.kind,
                message: error.message,
                hint: error.hint,
                exitCode: error.exitCode
            )
            if let json = try? Envelope.compactJSON(envelope) {
                print(json)
            }
        }
        exit(error.exitCode)
    }

    static func emitFailure(_ error: Error, pretty: Bool, command: String? = nil) -> Never {
        emitFailure(MotestError.wrapping(error, command: command), pretty: pretty)
    }
}
