import Foundation

/// Bounded async execution for CLI I/O (WebSocket RPC, health waits).
public enum Timeout {
    /// Runs `operation` and cancels it if it does not finish within `seconds`.
    public static func run<T: Sendable>(
        seconds: TimeInterval,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        let limit = max(seconds, 0.001)
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(limit * 1_000_000_000))
                throw CLIError.timeout(
                    "timed out after \(formatSeconds(limit))s",
                    hint: "raise --timeout / XQ_MOTEST_TIMEOUT, or check DeviceKit is responding"
                )
            }
            guard let value = try await group.next() else {
                throw CLIError.internal("timeout race produced no result")
            }
            group.cancelAll()
            return value
        }
    }

    private static func formatSeconds(_ seconds: TimeInterval) -> String {
        if seconds == floor(seconds) {
            return String(Int(seconds))
        }
        return String(format: "%.1f", seconds)
    }
}
