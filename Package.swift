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
            targets: ["PlaceAlertMe"]
        ),
    ],
    dependencies: [],
    targets: [
        // C++ engine — internal, compiles geo_engine.cpp.
        // Public headers live in `include/`. The legacy header at
        // cpp/geo_engine/geo_engine.h is intentionally excluded; it's an
        // older flat-namespace draft superseded by include/geo_engine.h.
        .target(
            name: "GeoEngineCore",
            dependencies: [],
            path: "cpp/geo_engine",
            exclude: [
                "geo_engine.h",
                "CMakeLists.txt",
                "tests",
                "build"
            ],
            sources: ["geo_engine.cpp"],
            publicHeadersPath: "include",
            cxxSettings: [
                .define("_USE_MATH_DEFINES")
            ]
        ),
        // C wrapper — exposes ios_geo_engine_* functions to Swift via
        // extern "C". Depends on GeoEngineCore for the C++ implementation
        // and is the only header that the Swift target sees.
        .target(
            name: "GeoEngineWrapper",
            dependencies: ["GeoEngineCore"],
            path: "ios/CppInterop",
            sources: ["GeoEngineWrapper.cpp"],
            publicHeadersPath: ".",
            cxxSettings: [
                .define("_USE_MATH_DEFINES")
            ]
        ),
        // Swift API. Sample UIKit demo file is excluded so the library
        // builds on macOS host (UIKit isn't available there).
        .target(
            name: "PlaceAlertMe",
            dependencies: ["GeoEngineWrapper"],
            path: "ios/PlaceAlertMe",
            exclude: [
                "SampleViewController.swift"
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
