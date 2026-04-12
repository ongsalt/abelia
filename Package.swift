// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "graphics-101",
    // products: [
    //     .executable(name: "Signal", targets: ["Signal"]),
    //     .executable(name: "App", targets: ["graphics-101"]),
    // ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0")
    ],
    targets: [
        .target(name: "CWayland"),
        .target(
            name: "Wayland",
            dependencies: ["CWayland"],
            swiftSettings: [
                .interoperabilityMode(.C)
            ]
        ),

        .systemLibrary(name: "CPango", pkgConfig: "pangoft2"),

        // Everything vulkan is in here
        .target(
            name: "CVMA",
            cSettings: [
                .define("VK_USE_PLATFORM_WAYLAND_KHR", .when(platforms: [.linux]))  // i should fucking put these 2 together
            ],
        ),

        .target(name: "Signal"),
        .target(name: "UI", dependencies: ["graphics-101"]),
        // .executableTarget(name: "Signal"),

        // .plugin(
        //     name: "ShaderCompilation",
        //     capability: .buildTool(),
        // ),

        .executableTarget(
            name: "graphics-101",
            dependencies: [
                .product(name: "Numerics", package: "swift-numerics"),
                .target(name: "Wayland", condition: .when(platforms: [.linux])),
                "CVMA",
                // "FreeType",
                "CPango",
            ],
            resources: [
                .copy("Resources/Compiled")
            ],
            cSettings: [
                .define("VK_USE_PLATFORM_WAYLAND_KHR", .when(platforms: [.linux]))
            ],
        ),
    ]
)
