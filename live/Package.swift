// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TUILiveKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [.library(name: "TUILiveKit", targets: ["TUILiveKit"])],
    dependencies: [
        .package(url: "https://github.com/Tencent-RTC/AtomicXCore_SwiftPM.git", from: "5.3.0"),
        .package(url: "https://github.com/Tencent-RTC/TUICore_SwiftPM.git", from: "9.0.7652"),
        .package(url: "https://github.com/Tencent-RTC/Chat_SDK_SwiftPM.git", from: "9.1.7824"),
        .package(url: "https://github.com/Tencent-RTC/Professional_SwiftPM.git", from: "13.5.21355"),
        .package(url: "https://github.com/Tencent-RTC/TCGiftPlayerKit_SwiftPM.git", from: "1.0.0"),
        .package(url: "https://github.com/SnapKit/SnapKit.git", exact: "5.7.1"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", exact: "8.14.0"),
    ],
    targets: [
        .target(name: "TUILiveKit", dependencies: [
            .product(name: "AtomicXCore", package: "AtomicXCore_SwiftPM"),
            .product(name: "TXIMSDK_Plus_iOS_XCFramework", package: "Chat_SDK_SwiftPM"),
            .product(name: "TUICore_SwiftPM", package: "TUICore_SwiftPM"),
            .product(name: "Professional_SwiftPM", package: "Professional_SwiftPM"),
            .product(name: "TCGiftPlayerKit", package: "TCGiftPlayerKit_SwiftPM"),
            .product(name: "SnapKit", package: "SnapKit"),
            .product(name: "Kingfisher", package: "Kingfisher"),
        ], path: ".", exclude: ["TUILiveKit.podspec", "README.md", "Package.swift"], resources: [
            .process("Resources/Assets.xcassets"), .process("Resources/en.lproj"),
            .process("Resources/zh-Hans.lproj"), .process("Resources/livekit_coguest_wave.gif"),
            .process("Resources/VoiceBackgroundGif"),
        ])
    ],
    swiftLanguageModes: [.v5]
)
