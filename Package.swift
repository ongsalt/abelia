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
        .package(url: "https://github.com/ongsalt/swinit", branch: "main", traits: ["WaylandCSD"]),
        .package(
            url: "https://github.com/ongsalt/swift-vulkan",
            revision: "7545f1c64236fe2c13dfdbaeda1810aaf96274db"),
        // .package(url: "https://github.com/tomasf/Apus.git", branch: "master"),
        // .package(url: "https://github.com/LuizZak/swift-blend2d", branch: "master"),

    ],
    targets: [
        .target(name: "Cnanosvg"),
        .target(name: "CSTBImage"),
        .target(
            name: "CShim",
            dependencies: [
                .product(name: "Vulkan", package: "swift-vulkan"),
            ],
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

        .target(
            name: "AbeliaUI",
            dependencies: [
                "AbeliaGraphics",
                "DSLMacro",
                .product(name: "Swinit", package: "swinit"),
            ],
        ),

        .macro(
            name: "DSLMacro",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            ]
        ),

        .target(
            name: "AbeliaGraphics",
            dependencies: [
                "Cnanosvg",
                "CShim",
                "CPlatform",
                "CSTBImage",
                "ReactivityGraph",
                .product(name: "Vulkan", package: "swift-vulkan"),
                // .product(name: "SwiftBlend2D", package: "swift-blend2d"),
                .product(name: "Swinit", package: "swinit"),
            ],
            exclude: [
                "Resources/"
            ],
            resources: [
                .copy("Generated/Resources")
            ],
        ),

        .executableTarget(
            name: "Playground",
            dependencies: [
                "AbeliaGraphics",
                .product(name: "Swinit", package: "swinit"),
            ],
        ),

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
