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
    }

    func testDeviceKitTestIdentifier() {
        XCTAssertEqual(
            DeviceKitConstants.testIdentifier(),
            "devicekit-iosUITests/DeviceKitUITests/testRunAutomation"
        )
    }
}
