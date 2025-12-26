# AtomicToast 组件

轻量级 Toast 提示组件，支持多种语义样式、自定义图标和位置配置，通过 `UIView` 扩展方法直接调用，自动响应主题切换。

---

## 快速开始

```swift
// 基础用法（纯文本，无图标）
view.showAtomicToast(text: "操作成功")

// 语义样式（带预设图标）
view.showAtomicToast(text: "保存成功", style: .success)
view.showAtomicToast(text: "请注意此操作", style: .warning)
view.showAtomicToast(text: "网络错误", style: .error)

// 自定义图标（覆盖预设图标）
view.showAtomicToast(
    text: "上传完成",
    customIcon: UIImage(systemName: "cloud.fill"),
    style: .success
)

// 长时间显示
view.showAtomicToast(
    text: "这是一条重要提示",
    style: .info,
    duration: .long
)
```

---

## 核心特性

### 1. 语义样式（ToastStyle）

| 样式 | 说明 | 默认图标资源名称 | 应用场景 |
|------|------|----------------|---------|
| `.text` | 纯文本 | 无 | 普通提示信息 |
| `.info` | 信息提示 | `toast_info` | 中性通知消息 |
| `.help` | 帮助说明 | `toast_help` | 引导性提示 |
| `.loading` | 加载中 | `toast_load` | 异步操作进行中 |
| `.success` | 成功 | `toast_success` | 操作成功反馈 |
| `.warning` | 警告 | `toast_warn` | 警告性提示 |
| `.error` | 错误 | `toast_error` | 错误反馈 |

**注意**：所有样式使用统一的主题色（`toastColorDefault`），不会根据语义样式改变背景色或文字色。

```swift
// 纯文本（无图标）
view.showAtomicToast(text: "纯文本提示", style: .text)

// 纯文本 + 自定义图标
view.showAtomicToast(
    text: "自定义提示",
    customIcon: UIImage(named: "my_icon"),
    style: .text
)

// 预设样式（自带图标）
view.showAtomicToast(text: "操作成功", style: .success)

// customIcon 优先级高于预设图标
view.showAtomicToast(
    text: "使用自定义图标",
    customIcon: UIImage(systemName: "star.fill"),
    style: .info  // 预设的 toast_info 图标被覆盖
)
```

### 2. 显示位置（ToastPosition）

```swift
// 顶部（距离 safeAreaLayoutGuide 顶部 40pt）
view.showAtomicToast(text: "顶部提示", position: .top)

// 居中（默认）
view.showAtomicToast(text: "居中提示", position: .center)

// 底部（距离 safeAreaLayoutGuide 底部 40pt）
view.showAtomicToast(text: "底部提示", position: .bottom)
```

**注意**：位置相对于父视图的安全区域计算，确保不会被刘海屏或底部指示器遮挡。

### 3. 显示时长（ToastDuration）

**对齐安卓设计**：仅提供两种预设时长

| 时长类型 | 数值 | 说明 | 应用场景 |
|---------|------|------|---------|
| `.short` | 2.0秒 | 短时间（默认） | 普通提示、成功反馈 |
| `.long` | 3.5秒 | 长时间 | 重要提示、警告信息 |

```swift
// 短时间显示（默认，2秒）
view.showAtomicToast(text: "操作成功", duration: .short)

// 长时间显示（3.5秒）
view.showAtomicToast(
    text: "这是一条重要提示信息",
    style: .warning,
    duration: .long
)

// 不指定duration，默认使用 .short
view.showAtomicToast(text: "默认提示")
```

### 4. 交互配置

```swift
// 点击背景区域关闭（默认 dismissOnTap: true）
view.showAtomicToast(text: "点击背景关闭")

// 禁止点击关闭（不创建透明背景视图）
view.showAtomicToast(
    text: "处理中...",
    style: .loading,
    dismissOnTap: false
)
```

### 5. 自动主题适配

Toast 通过 `ThemeStore.shared.$currentTheme` 订阅主题变化，**无需手动更新**：

```swift
// Toast 会自动跟随主题切换
view.showAtomicToast(text: "成功", style: .success)
// 浅色主题 → 深色主题时，背景色、文字色、阴影自动更新

// 自定义图标会保留，其他样式属性跟随主题
view.showAtomicToast(
    text: "上传完成",
    customIcon: UIImage(named: "upload"),
    style: .success
)
```

**实现原理**：
```swift
// AtomicToast 内部通过 Combine 订阅主题变化
private func bindTheme() {
    ThemeStore.shared.$currentTheme
        .receive(on: DispatchQueue.main)
        .sink { [weak self] theme in
            guard let self = self else { return }
            // 重新生成配置并应用
            self.config = AtomicToastConfig.style(self.style, for: theme, customIcon: self.customIcon)
            self.apply(designConfig: self.config)
        }
        .store(in: &cancellables)
}
```

**配置内容**（从 `DesignTokenSet` 读取）：
- `backgroundColor`：`tokens.color.toastColorDefault`
- `textColor`：`tokens.color.textColorPrimary`
- `font`：`tokens.typography.Medium14`
- `cornerRadius`：`tokens.borderRadius.radius6`
- `shadow`：`tokens.shadows.smallShadow`

---

## API 参数

```swift
extension UIView {
    public func showAtomicToast(
        text: String,
        customIcon: UIImage? = nil,
        style: ToastStyle = .text,
        position: ToastPosition = .center,
        duration: ToastDuration = .short,
        dismissOnTap: Bool = true
    )
}
```

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `text` | `String` | 必填 | 显示文本（最多 2 行，超出截断） |
| `customIcon` | `UIImage?` | `nil` | 自定义图标（优先级高于预设图标） |
| `style` | `ToastStyle` | `.text` | 语义样式（决定预设图标） |
| `position` | `ToastPosition` | `.center` | 显示位置（相对于安全区域） |
| `duration` | `ToastDuration` | `.short` | 显示时长（`.short`: 2秒，`.long`: 3.5秒） |
| `dismissOnTap` | `Bool` | `true` | 点击背景是否关闭 |

**返回值**：无（`Void`）

---

## 设计规范

### 尺寸（ToastSize）

| 属性 | 值 | 说明 |
|------|-----|------|
| 高度 | `40pt` | 固定高度 |
| 最大宽度 | `340pt` | 自适应，不超过最大值 |
| 图标尺寸 | `16pt × 16pt` | `SpaceTokens.space16` |
| 元素间距 | `4pt` | `SpaceTokens.space4` |
| 水平内边距 | `16pt` | `SpaceTokens.space16` |
| 顶部/底部偏移 | `40pt` | 距离安全区域顶部/底部 |

### 动画

- **入场动画**：淡入 + 缩放（0.8 → 1.0），弹性效果
- **出场动画**：淡出 + 缩放（1.0 → 0.9）
- **时长**：入场 `0.3s`，出场 `0.2s`

### 显示时长（对齐安卓）

| 类型 | 时长 | 应用场景 |
|------|------|---------|
| `.short` | 2.0秒 | 普通提示、成功/失败反馈 |
| `.long` | 3.5秒 | 重要提示、警告/错误信息 |

---

## 注意事项

### 1. 视图层级

Toast 添加到调用视图（`self`）上，而非 Window：
- ✅ 生命周期自动管理（视图销毁时 Toast 自动移除）
- ⚠️ 可能被后续添加的子视图遮挡
- ⚠️ 位置计算相对于父视图边界

```swift
// ✅ 全局提示
view.showAtomicToast(text: "全局消息")

// ✅ 局部提示
tableView.showAtomicToast(text: "删除成功", position: .bottom)

// ⚠️ 视图太小可能被裁剪
smallButton.superview?.showAtomicToast(text: "操作成功")
```

### 2. 主线程调用

Toast 涉及 UI 操作，必须在主线程调用：

```swift
// ✅ 正确
DispatchQueue.main.async {
    self.view.showAtomicToast(text: "完成")
}

// ❌ 错误（可能崩溃）
DispatchQueue.global().async {
    self.view.showAtomicToast(text: "完成") // 崩溃风险
}
```

### 3. 多 Toast 管理

当前设计允许同时显示多个 Toast，如需排队显示，请自行实现：

```swift
// 多个 Toast 可能重叠
view.showAtomicToast(text: "消息1")
view.showAtomicToast(text: "消息2") // 可能覆盖消息1
```

---

## 最佳实践

### ✅ 推荐

```swift
// 1. 使用语义样式
view.showAtomicToast(text: "操作成功", style: .success)

// 2. 重要信息使用长时间显示
view.showAtomicToast(
    text: "重要提示信息",
    style: .warning,
    duration: .long
)

// 3. 自定义图标 + 语义样式
view.showAtomicToast(
    text: "上传完成",
    customIcon: UIImage(named: "upload"),
    style: .success
)

// 4. 不同位置区分场景
view.showAtomicToast(text: "表单错误", style: .warning, position: .top)
view.showAtomicToast(text: "已添加", style: .success, position: .bottom)

// 5. 短时间提示使用默认值
view.showAtomicToast(text: "复制成功") // 自动使用 .short (2秒)
```

### ❌ 避免

```swift
// ❌ 文本过长导致显示不全
view.showAtomicToast(text: "这是一段非常非常非常非常长的提示文本...")

// ❌ 在即将销毁的视图上显示 Toast
temporaryView.showAtomicToast(text: "提示")

// ❌ 不要在后台线程调用
DispatchQueue.global().async {
    view.showAtomicToast(text: "错误") // 崩溃风险
}
```

---

## 与安卓平台对齐

本组件在显示时长设计上完全对齐安卓平台：

| 特性 | iOS (AtomicToast) | Android | 说明 |
|------|------------------|---------|------|
| 短时间 | `.short` (2.0s) | `LENGTH_SHORT` (2s) | ✅ 对齐 |
| 长时间 | `.long` (3.5s) | `LENGTH_LONG` (3.5s) | ✅ 对齐 |
| 默认时长 | `.short` | `LENGTH_SHORT` | ✅ 对齐 |

---

## 文件结构

```
Toast/
├── AtomicToast.swift          # Toast 组件核心实现
├── AtomicToastConfig.swift    # 配置与主题工厂
└── README.md                  # 本文件
```

---

## 许可证

本组件属于 AtomicX iOS UIKit 项目的一部分。
