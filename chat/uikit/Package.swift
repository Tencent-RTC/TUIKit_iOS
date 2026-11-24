// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TUIChatKit", defaultLocalization: "en", platforms: [.iOS(.v15)],
    products: [.library(name: "TUIChatKit", targets: ["TUIChatKit"])],
    dependencies: [
        .package(url: "https://github.com/Tencent-RTC/AtomicXCore_SwiftPM.git", "3.0.0"..<"5.0.0"),
        .package(url: "https://github.com/Tencent-RTC/Chat_SDK_SwiftPM.git", from: "9.1.7834"),
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.7.1"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", exact: "7.12.0"),
    ],
    targets: [
        .target(
            name: "TUIChatKit",
            dependencies: [
                .product(name: "AtomicXCore", package: "AtomicXCore_SwiftPM"),
                .product(name: "TXIMSDK_Plus_iOS_XCFramework", package: "Chat_SDK_SwiftPM"),
                .product(name: "SnapKit", package: "SnapKit"), .product(name: "Kingfisher", package: "Kingfisher"),
                "AlbumPicker", "AlbumPickerCore", "tui_cmark_gfm", "TXLiteAVSDK_VoiceAI_iOS",
            ], path: ".",
            exclude: [
                "TUIChatKit.podspec", "Package.swift", "README.md", "components/basecomponent/basiccontrols/readme.md",
            ], sources: ["components", "page"],
            resources: [
                .process("resources/assets/chat/chat.xcassets"), .copy("resources/strings/ChatLocalizable.bundle"),
                .copy("resources/strings/EmojiFace.bundle"),
            ], linkerSettings: [.linkedLibrary("c++")]),
        // These are the same published artifacts used by the CocoaPods dependencies.
        // AlbumPicker's dynamic frameworks include their own resource bundles.
        .binaryTarget(
            name: "AlbumPicker",
            url: "https://sdk-im-1252463788.cos.ap-hongkong.myqcloud.com/album-picker/1.0.8/AlbumPicker_1.0.8.zip",
            checksum: "826c89c2329dd2ec886ee7a8614a1b8099ea834117a973531b4fdfb7aeab54de"),
        .binaryTarget(
            name: "AlbumPickerCore",
            url: "https://sdk-im-1252463788.cos.ap-hongkong.myqcloud.com/album-picker/1.0.8/AlbumPickerCore_1.0.8.zip",
            checksum: "efc6df223819804e128d7bb3483e9e7560331ab9fddbe7e7307776af780b9c96"),
        .binaryTarget(
            name: "tui_cmark_gfm",
            url:
                "https://im.sdk.cloud.tencent.cn/download/tuichatkit/tui-cmark-gfm/0.29.17/tui_cmark_gfm.xcframework.zip",
            checksum: "152a813b99b7ac8923444ecfd282490835f99ae938318f3512f3624252f9ff85"),
        .binaryTarget(
            name: "TXLiteAVSDK_VoiceAI_iOS", url: "https://dl.gmertc.com/voiceai/13.6.0/VoiceAI_iOS_sdk_13.6.0.255.zip",
            checksum: "4d1d0c49b3b1213d50bbb8ed3840802bce5f391f7e3a0d99135f9560fcc18dff"),
    ], swiftLanguageModes: [.v5])
