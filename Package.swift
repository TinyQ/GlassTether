// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "GlassTether", platforms: [.macOS(.v14)],
  products: [.executable(name: "GlassTether", targets: ["GlassTether"])],
  targets: [
    .target(name: "PhoneControlCore"),
    .executableTarget(name: "GlassTether", dependencies: ["PhoneControlCore"]),
    .testTarget(name: "PhoneControlCoreTests", dependencies: ["PhoneControlCore"]),
  ]
)
