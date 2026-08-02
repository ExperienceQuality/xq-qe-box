import Foundation

/// Ready-check and start for an already-installed DeviceKit runner.
/// Install/resign are owned by agent-host infra (ADR-0001).
enum DeviceKitRuntime {
    struct Status: Sendable {
        var installed: Bool
        var bundleID: String?
        var version: String?
        var serverReachable: Bool
        var baseURL: String
        var deviceID: String?
        var mode: String?
    }

    /// When `config.ensureRuntime` is true, ensure DeviceKit responds on `/health`.
    /// Starts an already-installed runner when the server is down.
    static func ensure(config: Config) async throws {
        guard config.ensureRuntime else { return }
        if await isReachable(config: config) { return }

        let snapshot = statusSnapshot(config: config, device: config.deviceID)
        let sim = snapshot.mode != "device"
        try await start(
            config: config,
            sim: sim,
            deviceID: config.deviceID ?? snapshot.deviceID
        )
        try await waitUntilHealthy(
            port: config.listenPort(),
            timeoutSec: config.timeoutSec
        )
    }

    static func start(config: Config, sim: Bool, deviceID: String?) async throws {
        let stored = (try? loadDeviceJSON(config: config)) ?? [:]
        let udid = deviceID
            ?? stored["deviceId"] as? String
            ?? config.deviceID
            ?? ProcessInfo.processInfo.environment["XQ_MOTEST_DEVICE"]
            ?? ""
        guard !udid.isEmpty else {
            throw MotestError.runtime(
                "DeviceKit start requires a device UDID",
                hint: infraHint(sim: sim)
            )
        }

        let modeSim = sim || (stored["mode"] as? String) == "sim"
        let bundleID: String
        if let existing = stored["bundleId"] as? String, !existing.isEmpty {
            bundleID = existing
        } else if modeSim {
            bundleID = try RunnerDiscover.findSimRunner(udid: udid)
        } else {
            bundleID = try RunnerDiscover.findDeviceRunner(udid: udid)
        }

        let port = stored["forwardPort"] as? Int ?? DeviceKitConstants.defaultListenPort
        if modeSim {
            try await DeviceKitStart.startSim(config: config, udid: udid, bundleID: bundleID, port: port)
        } else {
            try await DeviceKitStart.startDevice(config: config, udid: udid, bundleID: bundleID, port: port)
        }
    }

    static func status(config: Config, device: String? = nil) async -> Status {
        let snapshot = statusSnapshot(config: config, device: device)
        return Status(
            installed: snapshot.installed,
            bundleID: snapshot.bundleID,
            version: snapshot.version,
            serverReachable: await isReachable(config: config),
            baseURL: snapshot.baseURL,
            deviceID: snapshot.deviceID,
            mode: snapshot.mode
        )
    }

    static func isReachable(config: Config) async -> Bool {
        guard let url = config.healthURL() else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = min(2, max(config.timeoutSec, 0.5))
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(http.statusCode)
        } catch {
            return false
        }
    }

    static func waitUntilHealthy(
        port: Int,
        timeoutSec: TimeInterval,
        logHint: String? = nil
    ) async throws {
        guard let url = URL(string: "http://127.0.0.1:\(port)/health") else {
            throw MotestError.runtime("invalid health URL", hint: "")
        }
        let deadline = ContinuousClock.now + .seconds(max(Int(timeoutSec), 1))
        var lastError = ""
        while ContinuousClock.now < deadline {
            if Task.isCancelled {
                throw MotestError.timeout("health wait cancelled")
            }
            var request = URLRequest(url: url)
            request.timeoutInterval = 2
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                    return
                }
                if let http = response as? HTTPURLResponse {
                    lastError = "HTTP \(http.statusCode)"
                }
            } catch {
                lastError = error.localizedDescription
            }
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        var message = "DeviceKit health check timed out"
        if let logHint { message += ". See \(logHint)" }
        if !lastError.isEmpty { message += " (last error: \(lastError))" }
        throw MotestError.timeout(
            message,
            hint: "ensure DeviceKit runner is installed by infra, then: xq-motest devicekit start [--sim] --device <UDID>"
        )
    }

    static func infraHint(sim: Bool) -> String {
        if sim {
            return "install DeviceKit runner (.app) on the simulator via agent-host infra, then: xq-motest devicekit start --sim --device <UDID>"
        }
        return "install DeviceKit runner (.ipa) on the device via agent-host infra, then: xq-motest devicekit start --device <UDID>"
    }

    private struct Snapshot {
        var installed: Bool
        var bundleID: String?
        var version: String?
        var baseURL: String
        var deviceID: String?
        var mode: String?
    }

    private static func statusSnapshot(config: Config, device: String?) -> Snapshot {
        let stored = (try? loadDeviceJSON(config: config)) ?? [:]
        let bundleID = stored["bundleId"] as? String
        return Snapshot(
            installed: bundleID != nil,
            bundleID: bundleID,
            version: stored["version"] as? String,
            baseURL: config.baseURL,
            deviceID: device ?? stored["deviceId"] as? String,
            mode: stored["mode"] as? String
        )
    }

    private static func loadDeviceJSON(config: Config) throws -> [String: Any] {
        let path = config.stateDir.appendingPathComponent("device.json")
        let data = try Data(contentsOf: path)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}
