// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport

import Foundation

import PackageDescription

var vulkanIncludePath: [CSetting] = [
    .define("VK_USE_PLATFORM_WAYLAND_KHR", .when(platforms: [.linux])),
    .define("VK_USE_PLATFORM_WIN32_KHR", .when(platforms: [.windows])),
]
if let vulkanSDK = ProcessInfo.processInfo.environment["VULKAN_SDK"] {
    vulkanIncludePath.append(.unsafeFlags(["-I\(vulkanSDK)/Include"]))
}
let package = Package(
    name: "graphics-101",
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
        .package(url: "https://github.com/ongsalt/swinit", branch: "main", traits: ["WaylandCSD"]),
        .package(
            url: "https://github.com/ongsalt/swift-vulkan",
            revision: "ad4cffdd4e159479b1ebcbd06a8c68a122bf9520"),
        .package(url: "https://github.com/tomasf/Apus.git", branch: "master"),
        // .package(url: "https://github.com/LuizZak/swift-blend2d", branch: "master"),

    ],
    targets: [
        .target(name: "Reactivity"),
        .target(name: "ReactivityGraph"),

        .target(
            name: "CShim",
            cSettings: vulkanIncludePath
        ),

        .target(name: "CSTBImage"),

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
                "CShim",
                "CSTBImage",
                "ReactivityGraph",
                .product(name: "Vulkan", package: "swift-vulkan"),
                .product(name: "Apus", package: "Apus"),
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
)
