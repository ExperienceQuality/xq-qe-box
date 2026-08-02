import Foundation

/// Locate an already-installed DeviceKit runner on sim/device (infra installs it).
enum RunnerDiscover {
    static func findSimRunner(udid: String) throws -> String {
        let output = try runCommand("/usr/bin/xcrun", arguments: ["simctl", "listapps", udid])
        guard let data = output.data(using: .utf8),
              let apps = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MotestError.runtime("failed to parse simctl listapps output", hint: "")
        }
        let suffix = DeviceKitConstants.runnerBundleSuffix
        if let bundleID = apps.keys.first(where: { $0.hasSuffix(suffix) }) {
            return bundleID
        }
        throw MotestError.runtime(
            "DeviceKit runner not found on simulator",
            hint: DeviceKitRuntime.infraHint(sim: true)
        )
    }

    static func findDeviceRunner(udid: String) throws -> String {
        let suffix = DeviceKitConstants.runnerBundleSuffix
        let devicectl = try runCommand(
            "/usr/bin/xcrun",
            arguments: ["devicectl", "device", "info", "apps", "--device", udid, "--json-output", "-"]
        )
        if let data = devicectl.data(using: .utf8),
           let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let result = payload["result"] as? [String: Any],
           let apps = result["apps"] as? [[String: Any]] {
            for app in apps {
                if let bundleID = app["bundleIdentifier"] as? String, bundleID.hasSuffix(suffix) {
                    return bundleID
                }
            }
        }

        if let iosPath = which("ios") {
            let fallback = try runCommand(iosPath, arguments: ["apps", "--udid", udid], allowFailure: true)
            for line in fallback.split(separator: "\n") {
                let text = String(line)
                if text.contains(suffix), let bundleID = text.split(separator: " ").first {
                    return String(bundleID)
                }
            }
        }

        throw MotestError.runtime(
            "DeviceKit runner not found on device",
            hint: DeviceKitRuntime.infraHint(sim: false)
        )
    }

    private static func which(_ name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        let stdout = Pipe()
        process.standardOutput = stdout
        try? process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let path = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    private static func runCommand(
        _ executable: String,
        arguments: [String],
        allowFailure: Bool = false
    ) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        let out = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard process.terminationStatus == 0 || allowFailure else {
            let err = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw MotestError.runtime(err.trimmingCharacters(in: .whitespacesAndNewlines), hint: "")
        }
        return out
    }
}
