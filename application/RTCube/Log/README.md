# Log

统一日志与日志上传模块。

## 文件列表

| 文件 | 职责 |
|------|------|
| `AppLogger.swift` | 基于 AtomicX `Loggable` 协议的统一日志工具，定义 App 模块日志类型 |
| `LogUploadManager.swift` | 日志文件上传管理器，收集 TRTC SDK 的 `.clog` / `.xlog` 日志文件并通过系统分享上传 |
| `LogUploadView.swift` | 日志上传的 Picker 选择视图 |

## 使用示例

```swift
// info / warn / error 通过 Loggable 协议走 TRTC 日志通道
AppLogger.App.info("用户允许了推送权限")
AppLogger.App.warn("日志目录读取失败")

// debug 仅在 DEBUG 构建通过 debugPrint 输出
AppLogger.App.debug("调试信息")
```
