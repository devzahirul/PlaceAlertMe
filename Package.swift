// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "PlaceAlertMe",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "PlaceAlertMe",
            targets: ["PlaceAlertMe", "GeoEngineCore"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PlaceAlertMe",
            dependencies: ["GeoEngineCore"],
            path: "ios/PlaceAlertMe",
            exclude: [
                "SampleViewController.swift"  // UIKit demo, not part of library
            ],
            publicHeadersPath: "."
        ),
        .target(
            name: "GeoEngineCore",
            dependencies: [],
            path: "cpp",
            exclude: [
                "geo_engine/include/geo_engine.h"
            ],
            sources: [
                "geo_engine/geo_engine.cpp"
            ],
            publicHeadersPath: "geo_engine/include",
            cxxSettings: [
                .headerSearchPath("geo_engine/include"),
                .unsafeFlags([
                    "-fmodules",
                    "-fcxx-modules"
                ])
            ]
        ),
        .testTarget(
            name: "PlaceAlertMeTests",
            dependencies: ["PlaceAlertMe"],
            path: "ios/PlaceAlertMeTests"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
