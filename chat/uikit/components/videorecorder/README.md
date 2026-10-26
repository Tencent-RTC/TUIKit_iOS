中文版本
# 开启纵横比设置

纵横比设置是 VideoRecorder 的高级功能，需依赖 TXLiteAVSDK_Professional。

在项目或任一模块的 Podfile 中添加依赖：

```ruby
pod 'TXLiteAVSDK_Professional'
```

- 如果工程任一模块已依赖 TXLiteAVSDK_TRTC，可将其替换为 TXLiteAVSDK_Professional（不会影响其他模块的正常使用）。
- 依赖 TXLiteAVSDK_Professional 后，可使用纵横比设置；同时在兼容性与画质方面会有更好的表现。
- 未依赖 TXLiteAVSDK_Professional 时，将使用系统录制能力，纵横比按钮自动隐藏。


English Version
# Enable Aspect Ratio Settings

Aspect ratio is an advanced feature of VideoRecorder and requires TXLiteAVSDK_Professional.

Add the dependency in your project or any module’s Podfile:

```ruby
pod 'TXLiteAVSDK_Professional'
```

- If any module already depends on TXLiteAVSDK_TRTC, replace it with TXLiteAVSDK_Professional (this change will not affect other modules).
- After switching to TXLiteAVSDK_Professional, you can enable aspect ratio settings, with improved compatibility and image quality.
- Without TXLiteAVSDK_Professional, the system recorder is used and the aspect ratio button is hidden automatically.
