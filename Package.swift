// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ArtifactKeeper",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ArtifactKeeper", targets: ["ArtifactKeeper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.0.0"),
        .package(url: "https://github.com/artifact-keeper/artifact-keeper-swift-sdk.git", from: "1.1.0-dev.1"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.7.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "ArtifactKeeper",
            dependencies: [
                "Alamofire",
                "Kingfisher",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "ArtifactKeeperClient", package: "artifact-keeper-swift-sdk"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            path: "ArtifactKeeper/Sources",
            exclude: ["App/ArtifactKeeperApp.swift"]
        ),
        .testTarget(
            name: "ArtifactKeeperTests",
            dependencies: ["ArtifactKeeper"],
            path: "ArtifactKeeper/Tests"
        ),
    ]
)
