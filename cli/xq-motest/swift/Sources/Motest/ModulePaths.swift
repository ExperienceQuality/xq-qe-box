import Foundation

/// Paths into the source package for offline contract fixtures (tests).
enum ModulePaths {
    static func moduleRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func contractFile(_ name: String) -> URL {
        moduleRoot().appendingPathComponent("contract/\(name)")
    }
}
