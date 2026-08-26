以下为转为 Markdown 的两份文档：中文版本与英文版本。

中文版本
# 开启美颜/纵横比设置

美颜和纵横比设置是 VideoRecorder 的高级功能。启用需满足以下条件：

## 1. 依赖 TXLiteAVSDK_Professional

在项目或任一模块的 Podfile 中添加依赖：

```ruby
pod 'TXLiteAVSDK_Professional'
```

- 如果工程任一模块已依赖 TXLiteAVSDK_TRTC，可将其替换为 TXLiteAVSDK_Professional（不会影响其他模块的正常使用）。
- 依赖 TXLiteAVSDK_Professional 后，可使用纵横比设置；同时在兼容性与画质方面会有更好的表现。

## 2. 开通“多媒体高级功能”权限

当前仍需通过内测申请开通“多媒体插件高级功能”使用权限（包含视频录制、音频录制、图片/视频编辑等能力）。

- 申请入口：多媒体插件高级功能内测申请地址（https://cloud.tencent.com/apply/p/wlav0nzz7dp）。

### 注意事项
1. 提交后通常在 1 个工作日内完成审核。建议使用企业认证的腾讯云账号申请，以提升通过率。
2. 内测使用日期截至 2026 年 7 月 1 日，届时所有内测使用权限将失效。
3. 内测截止日期之前，将上线高级功能的付费购买方案（购买方式与插件市场其他插件一致，详见“插件市场概述及开通指引”）。若到期未购买，美颜功能将被屏蔽（不显示美颜按钮）；购买后将自动恢复显示（除非在配置中被强制屏蔽）。

## 3. 不同构建配置下的行为说明

- Release：
  - 若不满足启用条件，即使在配置中开启，高级功能也不会生效（相关按钮将自动隐藏）。
- Debug：
  - 点击不支持的功能时，会在 UI 中弹窗提示。
  - 如需在 Debug 版本中也屏蔽这些功能，可在 Config 或配置文件中关闭对应开关（详见配置描述）。


English Version
# Enable Beauty/Aspect Ratio Settings

Beauty and aspect ratio are advanced features of VideoRecorder. To enable them, the following conditions must be met:

## 1. Depend on TXLiteAVSDK_Professional

Add the dependency in your project or any module’s Podfile:

```ruby
pod 'TXLiteAVSDK_Professional'
```

- If any module already depends on TXLiteAVSDK_TRTC, replace it with TXLiteAVSDK_Professional (this change will not affect other modules).
- After switching to TXLiteAVSDK_Professional, you can enable aspect ratio settings, with improved compatibility and image quality.

## 2. Enable “Advanced Multimedia Features” Permission

You currently need to apply for internal testing access to the “Advanced Multimedia Plugin Features” (including video recording, audio recording, and photo/video editing).

- Application entry: Advanced Multimedia Plugin Features Early Access (https://cloud.tencent.com/apply/p/wlav0nzz7dp).

### Notes
1. Reviews are typically completed within one business day. We recommend applying with a Tencent Cloud enterprise-verified account to increase the approval rate.
2. The internal testing access is valid until July 1, 2026. After that date, all early-access permissions will expire.
3. Before the end of the early-access period, a paid plan for advanced features will be available (purchasing follows the same process as other plugins; see “Plugin Marketplace Overview and Activation Guide”). If not purchased upon expiration, the beauty feature will be disabled (the beauty button will be hidden). It will automatically be re-enabled after purchase (unless explicitly disabled via configuration).

## 3. Behavior in Different Build Configurations

- Release:
  - If prerequisites are not met, advanced features will not work even if enabled in the configuration (related buttons will be automatically hidden).
- Debug:
  - Tapping unsupported features will trigger a UI dialog/toast message.
  - If you also want to hide these features in Debug, disable the corresponding switches in the Config or configuration file (see configuration documentation).