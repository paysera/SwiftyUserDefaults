// swift-tools-version:6.2
// swiftlint:disable prefixed_toplevel_constant
// The swift-tools-version declares the minimum version of Swift required to build this package.

import class Foundation.ProcessInfo
import PackageDescription

let shouldTest = ProcessInfo.processInfo.environment["TEST"] == "1"

func resolveDependencies() -> [Package.Dependency] {
    guard shouldTest else { return [] }

    return [
        .package(url: "https://github.com/Quick/Quick.git", .upToNextMajor(from: "2.0.0")),
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "8.0.0")),
    ]
}

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InferSendableFromCaptures"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("ExistentialAny"),
]

func resolveTargets() -> [Target] {
    let baseTarget = Target.target(
        name: "SwiftyUserDefaults",
        dependencies: [],
        path: "Sources",
        exclude: ["Info.plist"],
        swiftSettings: swiftSettings
    )
    let testTarget = Target.testTarget(
        name: "SwiftyUserDefaultsTests",
        dependencies: ["SwiftyUserDefaults", "Quick", "Nimble"],
        swiftSettings: swiftSettings
    )

    return shouldTest ? [baseTarget, testTarget] : [baseTarget]
}

let package = Package(
    name: "SwiftyUserDefaults",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6),
    ],
    products: [
        .library(name: "SwiftyUserDefaults", targets: ["SwiftyUserDefaults"]),
    ],
    dependencies: resolveDependencies(),
    targets: resolveTargets(),
    swiftLanguageModes: [.v6]
)
