# Extension/

Login 模块的扩展与基础设施，提供 App 生命周期分发机制和模块级公共工具。

## 文件列表

| 文件 | 职责 |
|------|------|
| `AppLifecycleRegistry.swift` | App 生命周期回调分发中心 — 定义 `AppLifecycleHandler` 协议和 `AppLifecycleRegistry` 单例，将 AppDelegate 的系统回调（URL 打开、前后台切换、deviceToken 等）广播给所有已注册的 handler |
| `Bundle+Login.swift` | Login 模块的 Bundle 扩展，用于加载模块内资源 |
| `LayoutDefine.swift` | 布局常量定义（屏幕尺寸、安全区域等） |
| `PrivacyConfig.swift` | 隐私协议配置（链接类型定义） |
| `TUIGlobalization+Extension.swift` | TUIGlobalization 语言工具扩展 |
| `UIView+ToastSwiftExtension.swift` | UIView Toast 便捷扩展 |
