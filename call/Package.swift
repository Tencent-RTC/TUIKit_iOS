// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TUICallKit_Swift",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "TUICallKit_Swift", targets: ["TUICallKit_Swift"])
    ],
    dependencies: [
        .package(url: "https://github.com/Tencent-RTC/AtomicXCore_SwiftPM.git", from: "5.3.2"),
        .package(url: "https://github.com/Tencent-RTC/Professional_SwiftPM.git", from: "13.3.20845"),
        .package(url: "https://github.com/Tencent-RTC/Chat_SDK_SwiftPM.git", from: "9.1.7824"),
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.7.1"),
    ],
    targets: [
        .target(
            name: "TUICallKit_Swift",
            dependencies: [
                .product(name: "AtomicXCore", package: "AtomicXCore_SwiftPM"),
                .product(name: "Professional_SwiftPM", package: "Professional_SwiftPM"),
                .product(name: "TXIMSDK_Plus_iOS_XCFramework", package: "Chat_SDK_SwiftPM"),
                .product(name: "SnapKit", package: "SnapKit"),
            ],
            path: ".",
            exclude: ["TUICallKit_Swift.podspec", "Package.swift"],
            resources: [
                .process("Resources/Assets.xcassets"),
                .process("Resources/en.lproj"),
                .process("Resources/zh-Hans.lproj"),
                .copy("Resources/AudioFile"),
                .copy("Resources/BadgeIcons"),
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
