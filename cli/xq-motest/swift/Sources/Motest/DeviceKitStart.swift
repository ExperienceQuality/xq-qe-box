import Foundation

enum DeviceKitStart {
    static func startSim(
        config: Config,
        udid: String,
        bundleID: String,
        port: Int
    ) throws {
        let state = try simulatorState(udid: udid)
        guard state == "Booted" else {
            throw CLIError.runtime(
                "simulator is offline (state: \(state)); boot it first: xcrun simctl boot \(udid)",
                hint: "xcrun simctl boot \(udid)"
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [
            "simctl", "launch",
            "--env", "DEVICEKIT_LISTEN_PORT=\(port)",
            udid, bundleID,
        ]
        let stderr = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw CLIError.runtime(message.trimmingCharacters(in: .whitespacesAndNewlines), hint: "")
        }

        try HealthWait.poll(port: port, timeoutSec: 30)
        try writeStartedJSON(config: config, udid: udid, bundleID: bundleID, port: port, mode: "sim")
    }

    static func startDevice(
        config: Config,
        udid: String,
        bundleID: String,
        port: Int
    ) throws {
        guard FileManager.default.fileExists(atPath: "/usr/bin/xcrun") else {
            throw CLIError.runtime(
                "real-device start requires Xcode (xcodebuild)",
                hint: "install Xcode and run xcode-select --install"
            )
        }

        let xctestrun = config.stateDir.appendingPathComponent("devicekit.xctestrun")
        try XCTestRun.writeDeviceRunner(at: xctestrun, bundleID: bundleID, port: port)

        let logFile = config.stateDir.appendingPathComponent("xcodebuild-start.log")
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
            try HealthWait.poll(
                port: port,
                timeoutSec: 90,
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
        let payload: [String: Any] = [
            "deviceId": udid,
            "bundleId": bundleID,
            "forwardPort": port,
            "baseUrl": "http://127.0.0.1:\(port)",
            "started": true,
            "mode": mode,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        try data.write(to: config.stateDir.appendingPathComponent("device.json"))
    }
}
