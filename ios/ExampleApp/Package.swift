// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PlaceAlertMeExample",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "PlaceAlertMeExample", targets: ["PlaceAlertMeExample"])
    ],
    dependencies: [
        .package(path: "../PlaceAlertMe")
    ],
    targets: [
        .target(
            name: "PlaceAlertMeExample",
            dependencies: [
                .product(name: "PlaceAlertMe", package: "PlaceAlertMe")
            ],
            path: "Sources"
        )
    ]
)
