// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport

import Foundation

import PackageDescription

var linkerSettings: [LinkerSetting] = []
#if os(Windows)
// dxgi shit
linkerSettings.append(.linkedLibrary("dcomp"))
linkerSettings.append(.linkedLibrary("dxgi"))
linkerSettings.append(.linkedLibrary("d3d12"))
#endif



let package = Package(
    name: "graphics-101",
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
        .package(url: "https://github.com/ongsalt/SwiftWayland", branch: "master"),
        // .package(url: "https://github.com/tomasf/Apus.git", branch: "master"),
        // .package(url: "https://github.com/LuizZak/swift-blend2d", branch: "master"),

    ],
    targets: [
        .target(name: "Cnanosvg"),
        .target(name: "CSTBImage"),
        
        .target(
            name: "CVulkan",
        ),
        .target(
            name: "CPlatform",
            linkerSettings: linkerSettings,
        ),
        .target(
            name: "CHarfbuzz",
            cxxSettings: [
                .headerSearchPath("../../Vendors/harfbuzz/src"),
                .define("HB_HAS_GPU")
            ]
        ),
        
        .target(name: "Reactivity"),
        .target(name: "ReactivityGraph"),


        .macro(
            name: "DSLMacro",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            ]
        ),

        .executableTarget(
            name: "AbeliaGraphics",
            dependencies: [
                // "Cnanosvg",
                "CPlatform",
                // "CSTBImage",
                "CVulkan",
                // "ReactivityGraph",
                .product(name: "WaylandClient", package: "SwiftWayland"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes")
            ],
            // exclude: [
            //     "Resources/"
            // ],
            // resources: [
            //     .copy("Generated/Resources")
            // ],
        ),

        // .executableTarget(
        //     name: "Playground",
        //     dependencies: [
        //         "AbeliaGraphics",
        //         .product(name: "WaylandClient", package: "SwiftWayland"),
        //     ],
        // ),

        .testTarget(
            name: "ReactivityTests",
            dependencies: [
                "Reactivity"
            ]
        ),

        .testTarget(
            name: "AbeliaGraphicsTests",
            dependencies: [
                "AbeliaGraphics"
            ]
        ),
    ],
    swiftLanguageModes: [.v6],
    cLanguageStandard: .c2x,
    cxxLanguageStandard: .cxx17,
)
