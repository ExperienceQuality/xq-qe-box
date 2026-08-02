import Foundation

public struct AgentStatus: Sendable {
    public var installed: Bool
    public var bundleID: String?
    public var version: String?
    public var serverReachable: Bool
    public var baseURL: String
    public var deviceID: String?
    public var mode: String?
}

public enum AgentLifecycle {
    public static func status(config: Config, device: String? = nil) -> AgentStatus {
        let deviceJSON = config.stateDir.appendingPathComponent("device.json")
        var stored: [String: Any] = [:]
        if let data = try? Data(contentsOf: deviceJSON),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            stored = object
        }
        let bundleID = stored["bundleId"] as? String
        let version = stored["version"] as? String
        let reachable = isServerReachable(config: config)
        return AgentStatus(
            installed: bundleID != nil,
            bundleID: bundleID,
            version: version,
            serverReachable: reachable,
            baseURL: config.baseURL,
            deviceID: device ?? stored["deviceId"] as? String,
            mode: stored["mode"] as? String
        )
    }

    public static func isServerReachable(config: Config) -> Bool {
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

    public static func installSim(config: Config, udid: String, version: String = "0.0.20", force: Bool = false) throws {
        _ = force
        let arch = ProcessInfo.processInfo.machineArchitecture
        let artifact = arch == "arm64" ? "devicekit-ios-Sim-arm64.zip" : "devicekit-ios-Sim-x86_64.zip"
        let cacheDir = config.stateDir.appendingPathComponent("cache", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let destination = cacheDir.appendingPathComponent("\(version)-\(artifact)")
        let artifactPath = try ShellScripts.run(
            "fetch-release.sh",
            arguments: ["--version", version, "--artifact", artifact, "--out", destination.path]
        )
        _ = try ShellScripts.run("install-sim.sh", arguments: [artifactPath, udid])
        let bundleID = try BundleIDDetect.findSimRunner(udid: udid)
        try writeDeviceJSON(
            config: config,
            deviceID: udid,
            bundleID: bundleID,
            version: version,
            mode: "sim"
        )
    }

    public static func installDevice(
        config: Config,
        udid: String,
        provisioningProfile: String,
        signingIdentity: String? = nil,
        version: String = "0.0.20",
        ipaPath: String? = nil
    ) throws {
        let cacheDir = config.stateDir.appendingPathComponent("cache", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let unsigned: URL
        if let ipaPath {
            unsigned = URL(fileURLWithPath: ipaPath)
        } else {
            let destination = cacheDir.appendingPathComponent("\(version)-devicekit-ios-runner.ipa")
            let fetched = try ShellScripts.run(
                "fetch-release.sh",
                arguments: [
                    "--version", version,
                    "--artifact", "devicekit-ios-runner.ipa",
                    "--out", destination.path,
                ]
            )
            unsigned = URL(fileURLWithPath: fetched)
        }

        let signedIPA = try ResignIPA.resign(
            ipaPath: unsigned,
            provisioningProfile: URL(fileURLWithPath: provisioningProfile),
            signingIdentity: signingIdentity
        )
        defer { try? FileManager.default.removeItem(at: signedIPA) }

        _ = try ShellScripts.run("install-device.sh", arguments: [signedIPA.path, udid])
        let bundleID = try BundleIDDetect.findDeviceRunner(udid: udid)
        try writeDeviceJSON(
            config: config,
            deviceID: udid,
            bundleID: bundleID,
            version: version,
            mode: "device"
        )
    }

    public static func start(config: Config, sim: Bool, deviceID: String?) throws {
        let status = self.status(config: config, device: deviceID)
        guard status.installed, let bundleID = status.bundleID else {
            throw CLIError.runtime(
                "DeviceKit runner not installed",
                hint: "xq-motest devicekit install --sim"
            )
        }
        let stored = try loadDeviceJSON(config: config)
        let udid = deviceID ?? stored["deviceId"] as? String ?? ""
        let port = stored["forwardPort"] as? Int ?? DeviceKitConstants.defaultListenPort
        if sim || status.mode == "sim" {
            try DeviceKitStart.startSim(config: config, udid: udid, bundleID: bundleID, port: port)
        } else {
            try DeviceKitStart.startDevice(config: config, udid: udid, bundleID: bundleID, port: port)
        }
    }

    private static func writeDeviceJSON(
        config: Config,
        deviceID: String,
        bundleID: String,
        version: String,
        mode: String
    ) throws {
        try FileManager.default.createDirectory(at: config.stateDir, withIntermediateDirectories: true)
        let payload: [String: Any] = [
            "deviceId": deviceID,
            "forwardPort": DeviceKitConstants.defaultListenPort,
            "bundleId": bundleID,
            "baseUrl": config.baseURL,
            "version": version,
            "mode": mode,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        try data.write(to: config.stateDir.appendingPathComponent("device.json"))
    }

    private static func loadDeviceJSON(config: Config) throws -> [String: Any] {
        let path = config.stateDir.appendingPathComponent("device.json")
        let data = try Data(contentsOf: path)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

private extension ProcessInfo {
    var machineArchitecture: String {
        var sysinfo = utsname()
        uname(&sysinfo)
        return withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "arm64"
            }
        }
    }
}
