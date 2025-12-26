# AtomicAlertView

一个支持主题切换的自定义弹窗组件，从 Kotlin `AtomicAlertDialog` 重构而来。

## 功能特性

- 支持标题、内容、图标配置
- 支持标准双按钮模式（取消/确定）
- 支持垂直列表模式（多选项 ActionSheet 风格）
- 支持倒计时自动关闭
- 自动响应 `ThemeStore` 主题变化
- 按钮颜色预设（primary/grey/blue/red）

## 使用方式

### 1. 通过 `AtomicPopover` 弹出（推荐）

```swift
// 创建 AlertView
let alertView = AtomicAlertView(config: AlertViewConfig(
    title: "提示",
    content: "确定要执行此操作吗？",
    cancelButton: AlertButtonConfig(text: "取消"),
    confirmButton: AlertButtonConfig(text: "确定", type: .blue, isBold: true) { alertView in
        print("点击了确定")
    }
))

// 使用 AtomicPopover 弹出（居中显示）
let popover = AtomicPopover(
    contentView: alertView,
    configuration: AtomicPopover.AtomicPopoverConfig.centerDefault()
)
alertView.onDismissRequested = { [weak popover] in
    popover?.dismiss(animated: false)
}
viewController.present(popover, animated: false)
```

```swift
// 底部弹出样式
let popover = AtomicPopover(
    contentView: alertView,
    configuration: AtomicPopover.AtomicPopoverConfig()
)
alertView.onDismissRequested = { [weak popover] in
    popover?.dismiss(animated: false)
}
viewController.present(popover, animated: false)
```

### 2. 通过 `show()` 方法弹出

```swift
// 标准双按钮对话框
let alertView = AtomicAlertView(config: AlertViewConfig(
    title: "提示",
    content: "确定要执行此操作吗？",
    cancelButton: AlertButtonConfig(text: "取消"),
    confirmButton: AlertButtonConfig(text: "确定", type: .blue, isBold: true) { alertView in
        print("点击了确定")
    }
))
alertView.show()
```

### 2. 带倒计时的对话框

```swift
let alertView = AtomicAlertView(config: AlertViewConfig(
    title: "删除确认",
    content: "此操作不可恢复，确定要删除吗？",
    countdownDuration: 5, // 5秒后自动关闭
    cancelButton: AlertButtonConfig(text: "取消", type: .grey),
    confirmButton: AlertButtonConfig(text: "删除", type: .red, isBold: true) { _ in
        // 执行删除
    }
))
alertView.show()
```

### 3. 垂直列表模式（ActionSheet 风格）

```swift
let alertView = AtomicAlertView(config: AlertViewConfig(
    title: "选择操作",
    items: [
        AlertButtonConfig(text: "拍照", type: .blue) { _ in print("拍照") },
        AlertButtonConfig(text: "从相册选择") { _ in print("相册") },
        AlertButtonConfig(text: "取消", type: .red)
    ]
))
alertView.show()
```

### 4. 带图标的对话框

```swift
let alertView = AtomicAlertView(config: AlertViewConfig(
    title: "上传成功",
    content: "文件已成功上传到服务器",
    iconUrl: "https://example.com/success.png",
    confirmButton: AlertButtonConfig(text: "知道了", type: .blue)
))
alertView.show()
```

### 5. 手动控制关闭

```swift
let alertView = AtomicAlertView(config: AlertViewConfig(
    title: "处理中",
    content: "请稍候...",
    dismissOnButtonTap: false, // 禁用点击按钮自动关闭
    confirmButton: AlertButtonConfig(text: "取消") { alertView in
        // 手动关闭
        alertView.dismiss()
    }
))
alertView.show()
```

## API 参考

### AlertViewConfig

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `title` | `String?` | `nil` | 弹窗标题 |
| `content` | `String?` | `nil` | 弹窗内容 |
| `iconUrl` | `String?` | `nil` | 标题图标 URL |
| `dismissOnButtonTap` | `Bool` | `true` | 点击按钮后是否自动关闭 |
| `countdownDuration` | `TimeInterval?` | `nil` | 倒计时时长（秒），倒计时结束后自动关闭 |
| `cancelButton` | `AlertButtonConfig?` | `nil` | 取消按钮配置 |
| `confirmButton` | `AlertButtonConfig?` | `nil` | 确定按钮配置 |
| `items` | `[AlertButtonConfig]` | `[]` | 垂直列表按钮（与双按钮模式互斥） |

### AlertButtonConfig

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `text` | `String` | 必填 | 按钮文字 |
| `type` | `TextColorPreset` | `.grey` | 文字颜色预设 |
| `isBold` | `Bool` | `false` | 是否加粗 |
| `onClick` | `((AtomicAlertView) -> Void)?` | `nil` | 点击回调 |

### TextColorPreset

| 枚举值 | 说明 |
|--------|------|
| `.primary` | 主要文字颜色 |
| `.grey` | 次要文字颜色（默认） |
| `.blue` | 链接/确认颜色 |
| `.red` | 错误/危险操作颜色 |

### AtomicAlertView 实例方法

| 方法 | 说明 |
|------|------|
| `show(animated:completion:)` | 在当前最顶层 VC 显示弹窗 |
| `dismiss()` | 关闭弹窗 |

### AtomicAlertView 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `config` | `AlertViewConfig` | 弹窗配置（只读） |
| `onDismissRequested` | `(() -> Void)?` | 关闭回调 |

## 注意事项

- `items` 与 `cancelButton`/`confirmButton` 互斥，优先使用 `items`
- 倒计时会显示在 `cancelButton` 上，格式为 "按钮文字 (剩余秒数)"
- 组件会自动监听 `ThemeStore` 主题变化并更新 UI
- 弹窗动画：显示时缩放+淡入，关闭时缩放+淡出
