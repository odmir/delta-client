// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "DeltaCore",
  platforms: [.macOS(.v11)],
  products: [
    .library(name: "DeltaCore", type: .dynamic, targets: ["DeltaCore", "DeltaCoreC"]),
    .library(name: "StaticDeltaCore", type: .static, targets: ["DeltaCore", "DeltaCoreC"]),
  ],
  dependencies: [
    .package(name: "ZIPFoundation", url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
    .package(name: "IDZSwiftCommonCrypto", url: "https://github.com/iosdevzone/IDZSwiftCommonCrypto", from: "0.13.1"),
    .package(name: "DeltaLogger", url: "https://github.com/stackotter/delta-logger", .branch("main")),
    .package(name: "NioDNS", url: "https://github.com/OpenKitten/NioDNS", from: "1.0.2"),
    .package(name: "SwiftProtobuf", url: "https://github.com/apple/swift-protobuf.git", from: "1.6.0"),
    .package(name: "swift-collections", url: "https://github.com/apple/swift-collections.git", from: "0.0.7"),
    .package(name: "Concurrency", url: "https://github.com/uber/swift-concurrency.git", from: "0.7.1"),
    .package(name: "FirebladeECS", url: "https://github.com/fireblade-engine/ecs.git", from: "0.17.5"),
  ],
  targets: [
    .target(
      name: "DeltaCore",
      dependencies: [
        "DeltaCoreC",
        "DeltaLogger",
        "ZIPFoundation",
        "IDZSwiftCommonCrypto",
        "NioDNS",
        "SwiftProtobuf",
        "Concurrency",
        "FirebladeECS",
        .product(name: "Collections", package: "swift-collections")],
      path: "Sources",
      exclude: [
        "Resources/Cache/BlockModelPalette.proto",
        "Resources/Cache/Compile.sh",
        "C"],
      resources: [.process("Render/Renderer/Shader/ChunkShaders.metal")]),
    .target(
      name: "DeltaCoreC",
      path: "Sources/C",
      publicHeadersPath: "."),
  ]
)