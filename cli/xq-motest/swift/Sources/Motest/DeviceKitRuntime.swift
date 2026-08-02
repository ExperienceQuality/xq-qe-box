import Foundation

/// Ready-check and start for an already-installed DeviceKit runner.
/// Install/resign are owned by agent-host infra (ADR-0001).
public enum DeviceKitRuntime {
    public struct Status: Sendable {
        public var installed: Bool
        public var bundleID: String?
        public var version: String?
        public var serverReachable: Bool
        public var baseURL: String
        public var deviceID: String?
        public var mode: String?
    }

    /// When `config.ensureRuntime` is true, ensure DeviceKit responds on `/health`.
    /// Starts an already-installed runner when the server is down.
    public static func ensure(config: Config) throws {
        guard config.ensureRuntime else { return }
        if isReachable(config: config) { return }

        let status = status(config: config, device: config.deviceID)
        let sim = status.mode != "device"
        try start(
            config: config,
            sim: sim,
            deviceID: config.deviceID ?? status.deviceID
        )
        try waitUntilHealthy(port: config.listenPort(), timeoutSec: config.timeoutSec)
    }

    public static func start(config: Config, sim: Bool, deviceID: String?) throws {
        let stored = (try? loadDeviceJSON(config: config)) ?? [:]
        let udid = deviceID
            ?? stored["deviceId"] as? String
            ?? config.deviceID
            ?? ProcessInfo.processInfo.environment["XQ_MOTEST_DEVICE"]
            ?? ""
        guard !udid.isEmpty else {
            throw CLIError.runtime(
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
            try DeviceKitStart.startSim(config: config, udid: udid, bundleID: bundleID, port: port)
        } else {
            try DeviceKitStart.startDevice(config: config, udid: udid, bundleID: bundleID, port: port)
        }
    }

    public static func status(config: Config, device: String? = nil) -> Status {
        let stored = (try? loadDeviceJSON(config: config)) ?? [:]
        let bundleID = stored["bundleId"] as? String
        return Status(
            installed: bundleID != nil,
            bundleID: bundleID,
            version: stored["version"] as? String,
            serverReachable: isReachable(config: config),
            baseURL: config.baseURL,
            deviceID: device ?? stored["deviceId"] as? String,
            mode: stored["mode"] as? String
        )
    }

    public static func isReachable(config: Config) -> Bool {
        guard let url = config.healthURL() else { return false }
        let semaphore = DispatchSemaphore(value: 0)
        var ok = false
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse {
                ok = (200..<300).contains(http.statusCode)
            }
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + 3)
        return ok
    }

    public static func waitUntilHealthy(
        port: Int,
        timeoutSec: TimeInterval,
        logHint: String? = nil
    ) throws {
        guard let url = URL(string: "http://127.0.0.1:\(port)/health") else {
            throw CLIError.runtime("invalid health URL", hint: "")
        }
        let deadline = Date().addingTimeInterval(timeoutSec)
        var lastError = ""
        while Date() < deadline {
            var request = URLRequest(url: url)
            request.timeoutInterval = 2
            let semaphore = DispatchSemaphore(value: 0)
            var ok = false
            URLSession.shared.dataTask(with: request) { _, response, error in
                if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                    ok = true
                } else if let error {
                    lastError = error.localizedDescription
                } else if let http = response as? HTTPURLResponse {
                    lastError = "HTTP \(http.statusCode)"
                }
                semaphore.signal()
            }.resume()
            _ = semaphore.wait(timeout: .now() + 3)
            if ok { return }
            Thread.sleep(forTimeInterval: 1)
        }
        var message = "DeviceKit health check timed out"
        if let logHint { message += ". See \(logHint)" }
        if !lastError.isEmpty { message += " (last error: \(lastError))" }
        throw CLIError.runtime(
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

    private static func loadDeviceJSON(config: Config) throws -> [String: Any] {
        let path = config.stateDir.appendingPathComponent("device.json")
        let data = try Data(contentsOf: path)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}
