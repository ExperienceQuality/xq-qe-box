// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "xq-motest",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "xq-motest", targets: ["xq-motest"]),
        .library(name: "Motest", targets: ["Motest"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(name: "Motest"),
        .executableTarget(
            name: "xq-motest",
            dependencies: [
                "Motest",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "MotestTests",
            dependencies: ["Motest"]
        ),
    ]
)
