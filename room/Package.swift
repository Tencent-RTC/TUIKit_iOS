// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TUIRoomKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "TUIRoomKit", targets: ["TUIRoomKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/Tencent-RTC/AtomicXCore_SwiftPM.git", from: "5.3.0"),
        .package(url: "https://github.com/Tencent-RTC/Professional_SwiftPM.git", from: "13.3.20845"),
        .package(url: "https://github.com/Tencent-RTC/Chat_SDK_SwiftPM.git", from: "9.1.7824"),
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.7.1"),
    ],
    targets: [
        .target(
            name: "TUIRoomKit",
            dependencies: [
                .product(name: "AtomicXCore", package: "AtomicXCore_SwiftPM"),
                .product(name: "Professional_SwiftPM", package: "Professional_SwiftPM"),
                .product(name: "TXIMSDK_Plus_iOS_XCFramework", package: "Chat_SDK_SwiftPM"),
                .product(name: "SnapKit", package: "SnapKit"),
            ],
            path: ".",
            exclude: ["README.md", "Package.swift"],
            resources: [
                .process("Resources/TUIRoomKitIcons.xcassets"),
                .process("Resources/TUIRoomKitLocalized.xcstrings"),
            ],
            linkerSettings: [
                .linkedFramework("ReplayKit")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
