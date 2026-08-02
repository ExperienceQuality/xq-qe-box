import Foundation

enum DeviceKitStart {
    static func startSim(
        config: Config,
        udid: String,
        bundleID: String,
        port: Int
    ) async throws {
        let state = try simulatorState(udid: udid)
        guard state == "Booted" else {
            throw CLIError.runtime(
                "simulator is offline (state: \(state)); boot it first: xcrun simctl boot \(udid)",
                hint: "xcrun simctl boot \(udid)"
            )
        }

        // Modern simctl has no --env; child env vars use SIMCTL_CHILD_<NAME>.
        var env = ProcessInfo.processInfo.environment
        env["SIMCTL_CHILD_DEVICEKIT_LISTEN_PORT"] = String(port)
        env["SIMCTL_CHILD_DEVICEKIT_LISTEN_HOST"] = "127.0.0.1"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [
            "simctl", "launch",
            "--terminate-running-process",
            udid, bundleID,
        ]
        process.environment = env
        let stderr = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw CLIError.runtime(message.trimmingCharacters(in: .whitespacesAndNewlines), hint: "")
        }

        try await DeviceKitRuntime.waitUntilHealthy(
            config: config,
            timeoutSec: min(30, config.timeoutSec)
        )
        try writeStartedJSON(config: config, udid: udid, bundleID: bundleID, port: port, mode: "sim")
    }

    /// Apple-only real-device start: `xcodebuild test-without-building` against a
    /// same-build products sidecar (`.xctestrun` + `Release-iphoneos`), not go-ios.
    /// IPA install remains infra-owned (ADR-0001). Caller must set `config.baseURL`
    /// to a reachable DeviceKit URL (device Wi‑Fi IP) when not using localhost forward.
    static func startDevice(
        config: Config,
        udid: String,
        bundleID: String,
        port: Int
    ) async throws {
        guard FileManager.default.fileExists(atPath: "/usr/bin/xcrun") else {
            throw CLIError.runtime(
                "real-device start requires Xcode (xcodebuild)",
                hint: "install Xcode and run xcode-select --install"
            )
        }

        guard let productsDir = config.productsDir else {
            throw CLIError.runtime(
                "real-device start requires DeviceKit products directory",
                hint: "pass --products-dir /path/to/Products (or XQ_MOTEST_DEVICEKIT_PRODUCTS) containing .xctestrun + Release-iphoneos from the same build as the IPA"
            )
        }

        let xctestrun = try XCTestRun.prepareProductsRunner(productsDir: productsDir, port: port)

        let logFile = config.stateDir.appendingPathComponent("xcodebuild-start.log")
        try FileManager.default.createDirectory(at: config.stateDir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: logFile.path, contents: nil)
        let logHandle = try FileHandle(forWritingTo: logFile)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [
            "xcodebuild",
            "test-without-building",
            "-xctestrun", xctestrun.path,
            "-destination", "platform=iOS,id=\(udid)",
            "-only-testing:\(DeviceKitConstants.testIdentifier())",
        ]
        process.standardOutput = logHandle
        process.standardError = logHandle
        try process.run()

        do {
            try await DeviceKitRuntime.waitUntilHealthy(
                config: config,
                timeoutSec: max(90, config.timeoutSec),
                logHint: logFile.path
            )
        } catch {
            process.terminate()
            throw error
        }

        try writeStartedJSON(config: config, udid: udid, bundleID: bundleID, port: port, mode: "device")
    }

    private static func simulatorState(udid: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", udid]
        let stdout = Pipe()
        process.standardOutput = stdout
        try process.run()
        process.waitUntilExit()
        let output = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        if output.contains(udid), output.contains("(Booted)") {
            return "Booted"
        }
        if let match = output.range(of: #"\(([^)]+)\)\s*$"#, options: .regularExpression) {
            let state = output[match].dropFirst().dropLast()
            return String(state)
        }
        return "unknown"
    }

    private static func writeStartedJSON(
        config: Config,
        udid: String,
        bundleID: String,
        port: Int,
        mode: String
    ) throws {
        try FileManager.default.createDirectory(at: config.stateDir, withIntermediateDirectories: true)
        var payload: [String: Any] = [
            "deviceId": udid,
            "bundleId": bundleID,
            "forwardPort": port,
            "baseUrl": config.baseURL,
            "started": true,
            "mode": mode,
        ]
        if let productsDir = config.productsDir {
            payload["productsDir"] = productsDir.path
        }
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        try data.write(to: config.stateDir.appendingPathComponent("device.json"))
    }
}
