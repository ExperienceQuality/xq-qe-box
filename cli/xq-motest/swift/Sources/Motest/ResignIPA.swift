import Foundation

enum ResignIPA {
    static func resign(
        ipaPath: URL,
        provisioningProfile: URL,
        signingIdentity: String? = nil
    ) throws -> URL {
        guard FileManager.default.fileExists(atPath: ipaPath.path) else {
            throw CLIError.runtime("IPA not found: \(ipaPath.path)", hint: "")
        }
        guard FileManager.default.fileExists(atPath: provisioningProfile.path) else {
            throw CLIError.runtime(
                "Provisioning profile not found: \(provisioningProfile.path)",
                hint: ""
            )
        }

        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("xq-resign-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }

        try unzip(ipaPath, to: workDir)
        let appPath = try findAppBundle(in: workDir)
        let profile = try decodeProfile(at: provisioningProfile)
        let identity = try signingIdentity ?? findSigningIdentity(teamID: profile.teamID)
        let entitlementsPath = try writeEntitlements(profile: profile, workDir: workDir)

        try FileManager.default.copyItem(
            at: provisioningProfile,
            to: appPath.appendingPathComponent("embedded.mobileprovision")
        )
        try signEmbeddedBinaries(appPath: appPath, identity: identity, entitlementsPath: entitlementsPath)
        try codesign(target: appPath, identity: identity, entitlementsPath: entitlementsPath)

        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("xq-resigned-\(UUID().uuidString).ipa")
        try zipPayload(workDir.appendingPathComponent("Payload"), to: output)
        return output
    }

    private struct ProfileInfo {
        let teamID: String
        let entitlements: [String: Any]
    }

    private static func unzip(_ ipaPath: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", ipaPath.path, "-d", destination.path]
        let stderr = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw CLIError.runtime(message.trimmingCharacters(in: .whitespacesAndNewlines), hint: "")
        }
    }

    private static func findAppBundle(in workDir: URL) throws -> URL {
        let payload = workDir.appendingPathComponent("Payload")
        let entries = try FileManager.default.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil)
        guard let app = entries.first(where: { $0.pathExtension == "app" }) else {
            throw CLIError.runtime("no .app bundle found in IPA payload", hint: "")
        }
        return app
    }

    private static func decodeProfile(at path: URL) throws -> ProfileInfo {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        process.arguments = ["smime", "-inform", "DER", "-verify", "-noverify", "-in", path.path]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw CLIError.runtime(
                "failed to decode provisioning profile: \(message.trimmingCharacters(in: .whitespacesAndNewlines))",
                hint: ""
            )
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let teamIDs = plist["TeamIdentifier"] as? [String],
              let teamID = teamIDs.first else {
            throw CLIError.runtime("no TeamIdentifier in provisioning profile", hint: "")
        }
        let entitlements = plist["Entitlements"] as? [String: Any] ?? [:]
        return ProfileInfo(teamID: teamID, entitlements: entitlements)
    }

    private static func findSigningIdentity(teamID: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-identity", "-v", "-p", "codesigning"]
        let stdout = Pipe()
        process.standardOutput = stdout
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CLIError.runtime("failed to list codesigning identities", hint: "")
        }
        let output = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        for line in output.split(separator: "\n") {
            let text = String(line)
            guard text.contains(teamID) else { continue }
            guard text.contains("Apple Development") || text.contains("iPhone Developer") else { continue }
            let parts = text.split(separator: "\"")
            if parts.count >= 2 {
                let hashParts = text.split(separator: " ")
                if hashParts.count >= 2 {
                    return String(hashParts[1])
                }
                return String(parts[1])
            }
        }
        throw CLIError.runtime(
            "no Apple Development signing identity found for team \(teamID)",
            hint: "xq-motest devicekit install --device UDID --provisioning-profile PATH"
        )
    }

    private static func writeEntitlements(profile: ProfileInfo, workDir: URL) throws -> URL {
        var entitlements = profile.entitlements
        if entitlements["com.apple.developer.team-identifier"] == nil {
            entitlements["com.apple.developer.team-identifier"] = profile.teamID
        }
        let path = workDir.appendingPathComponent("entitlements.plist")
        let data = try PropertyListSerialization.data(fromPropertyList: entitlements, format: .xml, options: 0)
        try data.write(to: path)
        return path
    }

    private static func signEmbeddedBinaries(
        appPath: URL,
        identity: String,
        entitlementsPath: URL
    ) throws {
        let frameworks = appPath.appendingPathComponent("Frameworks")
        if FileManager.default.fileExists(atPath: frameworks.path) {
            let entries = try FileManager.default.contentsOfDirectory(at: frameworks, includingPropertiesForKeys: nil)
            for entry in entries where ["framework", "dylib"].contains(entry.pathExtension) {
                try codesign(target: entry, identity: identity, entitlementsPath: nil)
            }
        }
        let plugins = appPath.appendingPathComponent("PlugIns")
        if FileManager.default.fileExists(atPath: plugins.path) {
            let entries = try FileManager.default.contentsOfDirectory(at: plugins, includingPropertiesForKeys: nil)
            for entry in entries where ["appex", "xctest"].contains(entry.pathExtension) {
                try codesign(target: entry, identity: identity, entitlementsPath: entitlementsPath)
            }
        }
    }

    private static func codesign(target: URL, identity: String, entitlementsPath: URL?) throws {
        var args = [
            "--force", "--sign", identity,
            "--timestamp=none", "--generate-entitlement-der",
        ]
        if let entitlementsPath {
            args.append(contentsOf: ["--entitlements", entitlementsPath.path])
        }
        args.append(target.path)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = args
        let stderr = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw CLIError.runtime(message.trimmingCharacters(in: .whitespacesAndNewlines), hint: "")
        }
    }

    private static func zipPayload(_ payloadDir: URL, to output: URL) throws {
        if FileManager.default.fileExists(atPath: output.path) {
            try FileManager.default.removeItem(at: output)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-qr", output.path, "Payload"]
        process.currentDirectoryURL = payloadDir.deletingLastPathComponent()
        let stderr = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw CLIError.runtime(message.trimmingCharacters(in: .whitespacesAndNewlines), hint: "")
        }
    }
}
