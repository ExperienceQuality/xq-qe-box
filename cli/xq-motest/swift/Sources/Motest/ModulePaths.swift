import Foundation

/// Paths into the source package for offline contract fixtures (tests).
public enum ModulePaths {
    public static func moduleRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    public static func contractFile(_ name: String) -> URL {
        moduleRoot().appendingPathComponent("contract/\(name)")
    }
}
