import Foundation

enum XCTestRun {
    /// Legacy synthetic xctestrun (destination artifacts). Kept for unit tests;
    /// real-device start uses `prepareProductsRunner` instead.
    static func writeDeviceRunner(
        at path: URL,
        bundleID: String,
        port: Int = DeviceKitConstants.defaultListenPort
    ) throws {
        let payload: [String: Any] = [
            "__xctestrun_metadata__": ["FormatVersion": 2],
            "TestConfigurations": [
                [
                    "Name": "DeviceKit",
                    "IsEnabled": true,
                    "TestTargets": [
                        [
                            "BlueprintName": DeviceKitConstants.testTarget,
                            "UseDestinationArtifacts": true,
                            "TestHostBundleIdentifier": bundleID,
                            "TestBundleDestinationRelativePath": DeviceKitConstants.testBundleRelativePath,
                            "UITargetAppBundleIdentifier": bundleID,
                            "EnvironmentVariables": [
                                "DEVICEKIT_LISTEN_PORT": String(port),
                                "DEVICEKIT_LISTEN_HOST": "0.0.0.0",
                            ],
                            "TestingEnvironmentVariables": [:] as [String: String],
                        ],
                    ],
                ],
            ],
        ]
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: payload, format: .xml, options: 0)
        try data.write(to: path)
    }

    /// Prepare an Apple products-based `.xctestrun` for `xcodebuild test-without-building`.
    ///
    /// `productsDir` must contain a build-for-testing layout, e.g.:
    /// `Release-iphoneos/*.app` and a sibling `*.xctestrun` whose `__TESTROOT__`
    /// paths resolve next to that folder. Writes `devicekit-motest.xctestrun`
    /// into `productsDir` with DeviceKit listen env set (all-interfaces).
    static func prepareProductsRunner(
        productsDir: URL,
        port: Int = DeviceKitConstants.defaultListenPort
    ) throws -> URL {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: productsDir.path, isDirectory: &isDir), isDir.boolValue else {
            throw CLIError.runtime(
                "DeviceKit products directory not found: \(productsDir.path)",
                hint: "pass --products-dir to the build-for-testing Products folder (contains .xctestrun + Release-iphoneos)"
            )
        }

        let source = try findXCTestRun(in: productsDir)
        let data = try Data(contentsOf: source)
        guard var plist = try PropertyListSerialization.propertyList(from: data, options: [.mutableContainers], format: nil)
            as? [String: Any]
        else {
            throw CLIError.runtime("failed to parse xctestrun at \(source.path)", hint: "")
        }

        applyListenEnvironment(to: &plist, port: port)

        let dest = productsDir.appendingPathComponent("devicekit-motest.xctestrun")
        let out = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try out.write(to: dest)
        return dest
    }

    private static func findXCTestRun(in productsDir: URL) throws -> URL {
        let fm = FileManager.default
        let preferred = [
            "devicekit-motest.xctestrun",
            "devicekit-blackbox.xctestrun",
        ]
        for name in preferred {
            let url = productsDir.appendingPathComponent(name)
            if fm.fileExists(atPath: url.path) { return url }
        }

        let entries = try fm.contentsOfDirectory(at: productsDir, includingPropertiesForKeys: nil)
        let matches = entries
            .filter { $0.pathExtension == "xctestrun" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        if let first = matches.first { return first }

        throw CLIError.runtime(
            "no .xctestrun found in \(productsDir.path)",
            hint: "provide the Products folder from the same build-for-testing that produced the DeviceKit IPA"
        )
    }

    private static func applyListenEnvironment(to plist: inout [String: Any], port: Int) {
        let listen: [String: String] = [
            "DEVICEKIT_LISTEN_PORT": String(port),
            "DEVICEKIT_LISTEN_HOST": "0.0.0.0",
        ]

        if var configs = plist["TestConfigurations"] as? [[String: Any]] {
            for i in configs.indices {
                guard var targets = configs[i]["TestTargets"] as? [[String: Any]] else { continue }
                for j in targets.indices {
                    mergeEnv(into: &targets[j], key: "EnvironmentVariables", values: listen)
                    mergeEnv(into: &targets[j], key: "TestingEnvironmentVariables", values: listen)
                }
                configs[i]["TestTargets"] = targets
            }
            plist["TestConfigurations"] = configs
            return
        }

        // FormatVersion 1: top-level target dictionaries.
        for key in plist.keys where key != "__xctestrun_metadata__" {
            guard var target = plist[key] as? [String: Any] else { continue }
            mergeEnv(into: &target, key: "EnvironmentVariables", values: listen)
            mergeEnv(into: &target, key: "TestingEnvironmentVariables", values: listen)
            plist[key] = target
        }
    }

    private static func mergeEnv(into target: inout [String: Any], key: String, values: [String: String]) {
        var env = target[key] as? [String: String] ?? [:]
        for (k, v) in values { env[k] = v }
        target[key] = env
    }
}
