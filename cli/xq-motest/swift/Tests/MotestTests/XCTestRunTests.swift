import Foundation
import XCTest
@testable import Motest

final class XCTestRunTests: XCTestCase {
    func testWriteDeviceRunnerUsesDestinationArtifacts() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("devicekit-\(UUID().uuidString).xctestrun")
        defer { try? FileManager.default.removeItem(at: path) }

        try XCTestRun.writeDeviceRunner(
            at: path,
            bundleID: "TEAM.com.mobilenext.devicekit-iosUITests.xctrunner",
            port: 12004
        )

        let data = try Data(contentsOf: path)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        let metadata = plist?["__xctestrun_metadata__"] as? [String: Any]
        XCTAssertEqual(metadata?["FormatVersion"] as? Int, 2)

        let configs = plist?["TestConfigurations"] as? [[String: Any]]
        let targets = configs?.first?["TestTargets"] as? [[String: Any]]
        let target = targets?.first
        XCTAssertEqual(target?["UseDestinationArtifacts"] as? Bool, true)
        XCTAssertEqual(
            target?["TestHostBundleIdentifier"] as? String,
            "TEAM.com.mobilenext.devicekit-iosUITests.xctrunner"
        )
        let env = target?["EnvironmentVariables"] as? [String: String]
        XCTAssertEqual(env?["DEVICEKIT_LISTEN_PORT"], "12004")
        XCTAssertEqual(env?["DEVICEKIT_LISTEN_HOST"], "0.0.0.0")
    }

    func testPrepareProductsRunnerPatchesFormatVersion1() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("products-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("sample.xctestrun")
        let original: [String: Any] = [
            "__xctestrun_metadata__": ["FormatVersion": 1],
            "devicekit-iosUITests": [
                "BlueprintName": "devicekit-iosUITests",
                "TestHostPath": "__TESTROOT__/Release-iphoneos/devicekit-iosUITests-Runner.app",
                "EnvironmentVariables": ["TERM": "dumb"] as [String: String],
                "TestingEnvironmentVariables": [:] as [String: String],
            ] as [String: Any],
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: original, format: .xml, options: 0)
        try data.write(to: source)

        let prepared = try XCTestRun.prepareProductsRunner(productsDir: root, port: 12004)
        XCTAssertEqual(prepared.lastPathComponent, "devicekit-motest.xctestrun")

        let outData = try Data(contentsOf: prepared)
        let plist = try PropertyListSerialization.propertyList(from: outData, format: nil) as? [String: Any]
        let target = plist?["devicekit-iosUITests"] as? [String: Any]
        let env = target?["EnvironmentVariables"] as? [String: String]
        XCTAssertEqual(env?["DEVICEKIT_LISTEN_HOST"], "0.0.0.0")
        XCTAssertEqual(env?["DEVICEKIT_LISTEN_PORT"], "12004")
        XCTAssertEqual(env?["TERM"], "dumb")
        let tenv = target?["TestingEnvironmentVariables"] as? [String: String]
        XCTAssertEqual(tenv?["DEVICEKIT_LISTEN_HOST"], "0.0.0.0")
    }

    func testDeviceKitTestIdentifier() {
        XCTAssertEqual(
            DeviceKitConstants.testIdentifier(),
            "devicekit-iosUITests/DeviceKitUITests/testRunAutomation"
        )
    }
}
