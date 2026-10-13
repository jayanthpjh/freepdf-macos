// swift-tools-version: 5.10
import PackageDescription
import Foundation
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let package = Package(
    name: "FreePDF",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "FreePDF", targets: ["FreePDF"]), .library(name: "FreePDFCore", targets: ["FreePDFCore"])],
    targets: [
        .target(name: "CPDFium", linkerSettings: [.linkedLibrary("pdfium"), .unsafeFlags(["-L", root + "/Vendor/pdfium/lib", "-Xlinker", "-rpath", "-Xlinker", root + "/Vendor/pdfium/lib", "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .target(name: "FreePDFCore", dependencies: ["CPDFium"]),
        .executableTarget(name: "FreePDF", dependencies: ["FreePDFCore"]),
        .testTarget(name: "FreePDFCoreTests", dependencies: ["FreePDFCore"])
    ]
)
