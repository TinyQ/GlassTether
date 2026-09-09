// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "LiveMateBluetoothLab",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "LiveMateBluetoothLab", targets: ["BluetoothLab"])],
  targets: [
    .target(name: "PhoneControlCore"),
    .executableTarget(name: "BluetoothLab", dependencies: ["PhoneControlCore"]),
    .testTarget(name: "PhoneControlCoreTests", dependencies: ["PhoneControlCore"]),
  ]
)
