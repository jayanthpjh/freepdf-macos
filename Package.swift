// swift-tools-version: 5.10
import PackageDescription
let package = Package(
    name: "FreePDF",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "FreePDF", targets: ["FreePDF"]), .library(name: "FreePDFCore", targets: ["FreePDFCore"])],
    targets: [
        .target(name: "FreePDFCore"),
        .executableTarget(name: "FreePDF", dependencies: ["FreePDFCore"]),
        .testTarget(name: "FreePDFCoreTests", dependencies: ["FreePDFCore"])
    ]
)
