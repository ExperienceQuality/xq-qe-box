import Foundation

public enum ModulePaths {
    public static func moduleRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    public static func devicekitScript(_ name: String) -> URL {
        moduleRoot().appendingPathComponent("scripts/devicekit/\(name)")
    }

    public static func contractFile(_ name: String) -> URL {
        moduleRoot().appendingPathComponent("contract/\(name)")
    }
}

public enum ShellScripts {
    public static func run(_ name: String, arguments: [String] = []) throws -> String {
        let script = ModulePaths.devicekitScript(name)
        guard FileManager.default.fileExists(atPath: script.path) else {
            throw CLIError.runtime("Missing devicekit script: \(name)", hint: "reinstall xq-motest from source")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path] + arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: errData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw CLIError.runtime(message.isEmpty ? "script failed" : message, hint: hint(for: name))
        }
        return String(decoding: outData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func hint(for name: String) -> String {
        switch name {
        case "install-device.sh":
            return "xq-motest devicekit install --device UDID --provisioning-profile PATH"
        default:
            return "xq-motest devicekit install --sim"
        }
    }
}
