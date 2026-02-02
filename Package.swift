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
    ],
    targets: [
        .target(
            name: "ArtifactKeeper",
            dependencies: [
                "Alamofire",
                "Kingfisher",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            path: "ArtifactKeeper/Sources"
        ),
        .testTarget(
            name: "ArtifactKeeperTests",
            dependencies: ["ArtifactKeeper"],
            path: "ArtifactKeeper/Tests"
        ),
    ]
)
