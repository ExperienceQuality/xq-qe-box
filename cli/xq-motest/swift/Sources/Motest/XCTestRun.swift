import Foundation

enum XCTestRun {
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
}
