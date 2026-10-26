// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TUIChatKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "TUIChatKit", targets: ["TUIChatKit"]),
        .library(name: "AlbumPicker", targets: ["AlbumPicker"]),
    ],
    dependencies: [
        // 与 chat/uikit/TUIChatKit.podspec 的 '>= 3.0.0', '< 5.0' 保持一致：3.0.0 <= v < 5.0.0
        .package(url: "https://github.com/Tencent-RTC/AtomicXCore_SwiftPM.git", "3.0.0"..<"5.0.0"),
        // 9.x 内最新版本：9.0.7652 <= v < 10.0.0
        .package(url: "https://github.com/Tencent-RTC/Chat_SDK_SwiftPM.git", .upToNextMajor(from: "9.0.7652")),
        // Kingfisher 8.12+ 要求 swift-tools-version 6.2；Xcode 16 / Swift 6.0 只能用 8.11.x
        .package(url: "https://github.com/onevcat/Kingfisher.git", .upToNextMinor(from: "8.11.0")),
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.7.1"),
    ],
    targets: [
        .binaryTarget(
            name: "AlbumPickerCore",
            url: "https://liteav.sdk.qcloud.com/app/tuikit/download/release/1.0/AlbumPickerCore_1.0.8.zip",
            checksum: "efc6df223819804e128d7bb3483e9e7560331ab9fddbe7e7307776af780b9c96"
        ),
        .target(
            name: "AlbumPicker",
            dependencies: ["AlbumPickerCore"],
            path: "atomic_x/Sources/AlbumPicker",
            exclude: ["AlbumPicker.podspec", "build_landun.py", "build_landun.sh"],
            resources: [
                .process("Resources/AlbumPicker.xcassets"),
                .process("Resources/AlbumPickerLocalized.xcstrings")
            ]
        ),
        .target(
            name: "TUIChatKit",
            dependencies: [
                "AlbumPicker",
                "AlbumPickerCore",
                .product(name: "AtomicXCore", package: "AtomicXCore_SwiftPM"),
                .product(name: "Chat_SDK_SwiftPM", package: "Chat_SDK_SwiftPM"),
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "SnapKit", package: "SnapKit"),
            ],
            path: "chat/uikit",
            exclude: ["TUIChatKit.podspec"],
            // xcassets 必须 .process 才会编译成 Assets.car；strings/assets 内 bundle 用 .copy 保留目录结构避免重名冲突
            resources: [
                .process("resources/assets/chat/chat.xcassets"),
                .process("resources/assets/chat/videorecorder.xcassets"),
                .copy("resources/strings"),
                .copy("resources/assets/chat/VideoRecorder.bundle")
            ]
        )
    ]
)
