// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Align",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Align", targets: ["Align"])],
    targets: [
        .executableTarget(name: "Align"),
        .testTarget(name: "AlignTests", dependencies: ["Align"])
    ]
)
