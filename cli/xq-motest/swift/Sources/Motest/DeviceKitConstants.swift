import Foundation

enum DeviceKitConstants {
    static let defaultListenPort = 12004
    static let testTarget = "devicekit-iosUITests"
    static let testClass = "DeviceKitUITests"
    static let testBundleRelativePath = "PlugIns/devicekit-iosUITests.xctest"
    static let runnerBundleSuffix = "devicekit-iosUITests.xctrunner"

    static func testIdentifier() -> String {
        "\(testTarget)/\(testClass)/testRunAutomation"
    }
}
