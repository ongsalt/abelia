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
        .package(url: "https://github.com/ongsalt/swinit", branch: "main"),
        .package(
            url: "https://github.com/ongsalt/swift-vulkan",
            revision: "03b43f505c73e3e710e567e27f38b6f2540ad90c"),
        .package(url: "https://github.com/LuizZak/swift-blend2d", branch: "master"),

    ],
    targets: [
        // bruh, how do i do this on windows
        // .systemLibrary(name: "CPango", pkgConfig: "pangoft2"),
        .target(name: "Reactivity"),
        .target(name: "Pointer"),

        .target(
            name: "CShim",
            // dependencies: [
            //     .product(name: "Vulkan", package: "swift-vulkan"),
            // ]
            cSettings: vulkanIncludePath
        ),

        .target(name: "CEmaPlatforms"),

        .target(
            name: "EmaCore",
            dependencies: [
                "Reactivity",
                "Pointer",
                "DSLMacro",
                "CShim",
                "CEmaPlatforms",
                .product(name: "SwiftBlend2D", package: "swift-blend2d"),
            ],
            exclude: [
                "Resources/Shaders/"
            ],
            resources: [
                .copy("Generated/Resources")
                // .ignore("Resources/Shaders"),
            ],
        ),

        .target(
            name: "Ema",
            dependencies: [
                "EmaCore",
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

        .testTarget(
            name: "ReactivityTests",
            dependencies: [
                "Reactivity"
            ]
        ),

        .testTarget(
            name: "EmaTests",
            dependencies: [
                "Ema",
                "EmaCore",
            ]
        ),

        .target(
            name: "AbeliaGraphics",
            dependencies: [
                "CShim",
                .product(name: "Vulkan", package: "swift-vulkan"),
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
    ],
    swiftLanguageModes: [.v6],
    cLanguageStandard: .c2x,
)
