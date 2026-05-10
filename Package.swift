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
    // vulkanSearchPath.append
    // let includePath = "\(vulkanSDK)/Include"
    vulkanIncludePath.append(.unsafeFlags(["-I\(vulkanSDK)/Include"]))
}
let package = Package(
    name: "graphics-101",
    dependencies: [
        .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
        .package(url: "https://github.com/ongsalt/swinit", branch: "main"),
    ],
    targets: [
        // bruh, how do i do this on windows
        .systemLibrary(name: "CPango", pkgConfig: "pangoft2"),
        .target(
            name: "CVulkan",
            cSettings: vulkanIncludePath,
        ),

        // .target(name: "Signal"),
        .target(name: "Reactivity"),
        .target(name: "Pointer"),
        .target(name: "UI", dependencies: ["Composition", "DSLMacro"]),
        // .executableTarget(name: "Signal"),

        .target(
            name: "EmaCore",
            dependencies: [
                "Reactivity"
            ]
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
            ]),
        // .plugin(
        //     name: "ShaderCompilation",
        //     capability: .buildTool(),
        // ),

        .target(
            name: "Composition",
            dependencies: [
                .product(name: "Numerics", package: "swift-numerics"),
                "CVulkan",
                // "FreeType",
                .target(name: "CPango", condition: .when(platforms: [.linux])),
                "Pointer",
            ],
            resources: [
                .copy("Resources/Compiled")
            ],
            cSettings: vulkanIncludePath,
        ),

        .executableTarget(
            name: "Playground",
            dependencies: [
                "UI",
                "Composition",
                "Reactivity",
                .product(name: "Swinit", package: "swinit"),
            ],
        ),

    ]
)
