# AtomicPopover

一个功能强大、高度可定制的 iOS 通用弹窗容器组件。支持多种弹出位置、灵活的高度配置、丰富的动画效果和自动主题适配。

---

## 特性

- ✅ **多位置支持**：底部、居中、顶部三种弹出位置
- ✅ **灵活高度**：支持自适应内容高度和屏幕比例高度
- ✅ **丰富动画**：滑入、淡入、缩放等多种动画效果
- ✅ **主题自适应**：自动跟随系统主题（深色/浅色模式）
- ✅ **安全区域填充**：自动填充顶部/底部安全区域，无缝贴合屏幕边缘
- ✅ **交互友好**：支持自定义背景点击行为、横屏自动关闭
- ✅ **易于使用**：一行代码即可弹出，配置简单直观

---

## 快速开始

### 最简单的用法

```swift
let contentView = MyCustomView()
let popover = AtomicPopover(contentView: contentView)
present(popover, animated: false)
```

### 自定义配置

```swift
let config = AtomicPopover.AtomicPopoverConfig(
    position: .bottom,
    height: .ratio(0.6),
    animation: .slideFromBottom,
    onBackdropTap: { [weak self] in
        self?.dismiss(animated: false)
    }
)
let popover = AtomicPopover(contentView: contentView, configuration: config)
present(popover, animated: false)
```

---

## API 文档

### 初始化

```swift
public init(
    contentView: UIView,
    configuration: AtomicPopoverConfig = AtomicPopoverConfig()
)
```

**参数说明：**
- `contentView`: 要显示的内容视图
- `configuration`: 弹窗配置（可选，有默认值）

### 公开方法

#### `dismiss(animated:completion:)`

关闭弹窗。

```swift
public override func dismiss(
    animated: Bool,
    completion: (() -> Void)? = nil
)
```

---

## 配置项详解

### AtomicPopoverConfig

```swift
public struct AtomicPopoverConfig {
    public var position: PopoverPosition
    public var height: PopoverHeight
    public var animation: PopoverAnimation
    public var backgroundColor: PopoverColor
    public var onBackdropTap: (() -> Void)?
    
    public init(
        position: PopoverPosition = .bottom,
        height: PopoverHeight = .wrapContent,
        animation: PopoverAnimation = .slideFromBottom,
        backgroundColor: PopoverColor = .defaultThemeColor,
        onBackdropTap: (() -> Void)? = nil
    )
}
```

---

### PopoverPosition - 弹出位置

控制弹窗在屏幕中的位置。

```swift
public enum PopoverPosition {
    case bottom   // 底部弹出（默认）
    case center   // 居中弹出
    case top      // 顶部弹出
}
```

#### 位置特性

| 位置 | 宽度 | 圆角位置 | 安全区域处理 | 适用场景 |
|------|------|---------|------------|---------|
| `.bottom` | 全屏宽度 | 仅顶部圆角 | 自动填充底部安全区域 | 底部菜单、选择器、操作面板 |
| `.center` | 屏幕宽度 × 0.9 | 四角圆角 | 不填充（悬浮显示） | 对话框、Alert、表单 |
| `.top` | 全屏宽度 | 仅底部圆角 | 自动填充顶部安全区域 | 顶部通知、下拉菜单 |

#### 视觉效果

```
█████████████████████  ← 顶部安全区域自动填充
├─────────────────────┤  ← Top 位置（全宽）
│    Top Popover      │
╰─────────────────────╯

┌─────────────────────┐
│                     │
│  ╭──────────────╮   │  ← Center 位置（90% 宽）
│  │   Center     │   │     左右留白，视觉优雅
│  │   Popover    │   │     不填充安全区域
│  ╰──────────────╯   │
│                     │
└─────────────────────┘

╭─────────────────────╮
│  Bottom Popover     │  ← Bottom 位置（全宽）
├─────────────────────┤
█████████████████████  ← 底部安全区域自动填充
```

#### 使用示例

```swift
// 底部菜单
let config = AtomicPopover.AtomicPopoverConfig(position: .bottom)

// 居中对话框
let config = AtomicPopover.AtomicPopoverConfig(position: .center)

// 顶部通知
let config = AtomicPopover.AtomicPopoverConfig(position: .top)
```

---

### PopoverHeight - 高度配置

控制弹窗的高度。

```swift
public enum PopoverHeight {
    case wrapContent        // 自适应内容高度（默认）
    case ratio(CGFloat)     // 屏幕比例高度（0.0 ~ 1.0）
}
```

#### 高度说明

**`.wrapContent`** - 自适应内容
- 根据 `contentView` 的 `intrinsicContentSize` 或约束自动计算高度
- 适用于高度固定或可预测的内容
- 不会超过屏幕可用高度（自动限制）

**`.ratio(CGFloat)`** - 比例高度
- 按屏幕高度的比例设置（0.0 ~ 1.0）
- `0.5` = 半屏，`0.8` = 80% 屏高
- 不会超过屏幕可用高度（自动限制）

#### 比例参考

| 比例值 | 说明 | 适用场景 |
|--------|------|---------|
| `0.3` | 30% 屏高 | 简单选择器、快捷操作 |
| `0.5` | 半屏 | 常规内容面板 |
| `0.6` | 60% 屏高 | 内容较多的面板 |
| `0.8` | 80% 屏高 | 接近全屏的内容 |
| `1.0` | 全屏高度 | 全屏展示 |

#### 使用示例

```swift
// 自适应内容高度
let config = AtomicPopover.AtomicPopoverConfig(
    height: .wrapContent
)

// 半屏高度
let config = AtomicPopover.AtomicPopoverConfig(
    height: .ratio(0.5)
)

// 60% 屏幕高度
let config = AtomicPopover.AtomicPopoverConfig(
    height: .ratio(0.6)
)
```

---

### PopoverAnimation - 动画效果

控制弹窗的进出场动画。

```swift
public enum PopoverAnimation {
    case slideFromBottom    // 从底部滑入（默认）
    case slideFromTop       // 从顶部滑入
    case fade              // 淡入淡出
    case scale             // 缩放动画
    case none              // 无动画
}
```

#### 动画详情

| 动画类型 | 入场效果 | 出场效果 | 时长 | 动画曲线 | 推荐搭配位置 |
|---------|---------|---------|------|----------|------------|
| `.slideFromBottom` | 从底部滑入 + 淡入 | 滑出到底部 + 淡出 | 0.35s / 0.28s | Spring (damping: 0.85) | `.bottom` |
| `.slideFromTop` | 从顶部滑入 + 淡入 | 滑出到顶部 + 淡出 | 0.35s / 0.28s | Spring (damping: 0.85) | `.top` |
| `.fade` | 淡入 (透明度 0→1) | 淡出 (透明度 1→0) | 0.35s / 0.28s | Spring (damping: 0.85) | `.center` |
| `.scale` | 缩放 + 淡入 (0.8→1.0) | 缩放 + 淡出 (1.0→0.9) | 0.35s / 0.28s | Spring (damping: 0.85) | `.center` |
| `.none` | 直接显示 | 直接消失 | 无 | - | 所有位置 |

**动画特性：**
- ✅ **弹簧动画**：使用 Spring 动画替代线性动画，视觉更自然
- ✅ **入场时长**：0.35s，更从容的展示效果
- ✅ **出场时长**：0.28s，快速响应用户操作
- ✅ **安全区域同步**：safeAreaFillView 与 containerView 同步淡入淡出，无突兀感
- ✅ **允许交互**：动画过程中允许用户继续交互（`.allowUserInteraction`）

#### 最佳实践

```swift
// ✅ 推荐：位置和动画匹配
let bottomConfig = AtomicPopover.AtomicPopoverConfig(
    position: .bottom,
    animation: .slideFromBottom  // 底部 + 滑入，符合直觉
)

let centerConfig = AtomicPopover.AtomicPopoverConfig(
    position: .center,
    animation: .scale  // 居中 + 缩放，类似系统 Alert
)

// ❌ 不推荐：位置和动画不匹配
let badConfig = AtomicPopover.AtomicPopoverConfig(
    position: .bottom,
    animation: .slideFromTop  // 视觉上不连贯
)
```

---

### PopoverColor - 背景颜色

控制弹窗容器的背景颜色。

```swift
public enum PopoverColor {
    case defaultThemeColor  // 默认主题色（默认）
    case custom(UIColor)    // 自定义颜色
}
```

#### 颜色说明

**`.defaultThemeColor`** - 默认主题色
- 使用 `theme.tokens.color.bgColorDialog`
- 自动跟随系统主题切换（深色/浅色模式）
- 推荐用于大部分场景

**`.custom(UIColor)`** - 自定义颜色
- 使用指定的 UIColor
- 不会随主题切换而变化
- 适用于需要特定颜色的场景（如透明、半透明、品牌色）

#### 使用示例

```swift
// 默认主题色
let config = AtomicPopover.AtomicPopoverConfig(
    backgroundColor: .defaultThemeColor
)

// 自定义颜色
let config = AtomicPopover.AtomicPopoverConfig(
    backgroundColor: .custom(.bgOperateColor)
)

// 半透明效果
let config = AtomicPopover.AtomicPopoverConfig(
    backgroundColor: .custom(UIColor.black.withAlphaComponent(0.8))
)
```

**注意**：`backgroundColor` 会同时应用于：
- `containerView`（内容容器）
- `safeAreaFillView`（安全区域填充视图）

这样可以确保整个弹窗视觉一致，无缝贴合屏幕边缘。

---

### onBackdropTap - 背景点击回调

控制点击蒙层背景时的行为。

```swift
public var onBackdropTap: (() -> Void)?  // 默认 nil
```

#### 使用场景

**`nil` (默认)** - 点击背景时无操作
- 需要用户必须通过特定操作关闭的弹窗（如填写表单后点击确认）
- 不允许随意关闭的场景

**自定义闭包** - 执行自定义逻辑
- 点击背景时关闭弹窗（最常见的用法）
- 点击背景时需要特殊处理（如保存数据、显示确认对话框）
- 通过路由系统管理的弹窗（调用路由的 dismiss）
- 需要额外逻辑的场景

#### 示例

```swift
// 禁止点击背景关闭
let config = AtomicPopover.AtomicPopoverConfig(
    onBackdropTap: nil  // 或直接不设置
)

// 点击背景直接关闭（最常见用法）
let config = AtomicPopover.AtomicPopoverConfig(
    onBackdropTap: { [weak self] in
        self?.dismiss(animated: false)
    }
)

// 自定义行为：通过路由系统关闭
let config = AtomicPopover.AtomicPopoverConfig(
    onBackdropTap: { [weak self] in
        self?.routerManager.router(action: .dismiss())
    }
)

// 自定义行为：显示确认对话框
let config = AtomicPopover.AtomicPopoverConfig(
    onBackdropTap: { [weak self] in
        self?.showConfirmDialog {
            // 用户确认后才关闭
            self?.dismiss(animated: false)
        }
    }
)
```

---

## 固定特性

以下特性是组件内置的，无需配置：

### 1. 圆角

- **圆角半径**：固定 20pt（`theme.tokens.borderRadius.radius20`）
- **圆角类型**：连续曲线（`.continuous`），视觉更自然
- **圆角策略**：
  - `.bottom`：仅顶部两个圆角（底部贴边）
  - `.top`：仅底部两个圆角（顶部贴边）
  - `.center`：四个圆角（完全悬浮）

### 2. 宽度

- **`.bottom` / `.top`**：屏幕全宽（左右贴边）
- **`.center`**：屏幕宽度的 90%（居中显示，两侧留白 5%）

### 3. 安全区域处理

- **`.bottom`**：
  - 底部约束到屏幕底部（`view.snp.bottom`）
  - 顶部限制不超出顶部安全区域（`>= safeAreaLayoutGuide.top`）
  - 使用 `clipsToBounds = true` 裁剪内容
  - 圆角区域内的内容会被自然裁剪
  
- **`.top`**：
  - 顶部约束到屏幕顶部（`view.snp.top`）
  - 底部限制不超出底部安全区域（`<= safeAreaLayoutGuide.bottom`）
  - 使用 `clipsToBounds = true` 裁剪内容
  - 圆角区域内的内容会被自然裁剪
  
- **`.center`**：
  - 居中在安全区域内（`centerY = safeAreaLayoutGuide.centerY`）
  - 不会被安全区域遮挡

**效果示例：**

```
iPhone X 及以上机型：

底部弹出 (.bottom)：
╭─────────────────────╮  ← 顶部圆角
│  Content (内容区域)   │  ← containerView
│                     │     内容被 clipsToBounds 裁剪
├─────────────────────┤  ← containerView 底部 = 屏幕底部
                          底部内容被圆角自然裁剪

顶部弹出 (.top)：
├─────────────────────┤  ← containerView 顶部 = 屏幕顶部
│  Content (内容区域)   │  ← containerView
│                     │     内容被 clipsToBounds 裁剪
╰─────────────────────╯  ← 底部圆角
                          顶部内容被圆角自然裁剪
```

### 4. 背景蒙层

- **颜色**：`theme.tokens.color.bgColorMask`（自动跟随主题）
- **透明度**：入场动画时从 0 → 1

### 5. 主题适配

- 自动订阅 `ThemeStore`
- 主题切换时自动更新背景色、蒙层色、圆角、安全区域填充色
- 无需手动处理

### 6. 横屏行为

- 检测到设备旋转至横屏时，自动调用 `dismiss(animated: true)`
- 适用场景：视频播放、游戏等需要全屏的场景
- 从横屏切回竖屏不会自动重新显示

---

## 使用场景

### 场景 1：底部选择器

```swift
func showCityPicker() {
    let pickerView = CityPickerView()
    
    let config = AtomicPopover.AtomicPopoverConfig(
        position: .bottom,
        height: .ratio(0.5),
        animation: .slideFromBottom,
        onBackdropTap: { [weak self] in
            self?.dismiss(animated: false)
        }
    )
    
    let popover = AtomicPopover(contentView: pickerView, configuration: config)
    present(popover, animated: false)
}
```

**效果：**
- 从底部滑入
- 占据半屏高度
- 宽度占满屏幕
- 点击背景可关闭

---

### 场景 2：居中对话框

```swift
func showConfirmDialog() {
    let dialogView = ConfirmDialogView()
    
    let config = AtomicPopover.AtomicPopoverConfig(
        position: .center,
        height: .wrapContent,
        animation: .scale,
        onBackdropTap: { [weak self] in
            self?.dismiss(animated: false)
        }
    )
    
    let popover = AtomicPopover(contentView: dialogView, configuration: config)
    present(popover, animated: false)
}
```

**效果：**
- 居中显示
- 宽度为屏幕的 90%
- 缩放动画进场
- 高度自适应内容

---

### 场景 3：通过路由系统管理的弹窗

```swift
// 在 RouterControlCenter 中
private func presentPopover(view: UIView, viewPosition: ViewPosition) -> UIViewController {
    var popover: AtomicPopover
    if viewPosition == .bottom {
        let config = AtomicPopover.AtomicPopoverConfig(
            onBackdropTap: { [weak self] in
                self?.routerManager.router(action: .dismiss())
            }
        )
        popover = AtomicPopover(contentView: view, configuration: config)
    } else {
        var config = AtomicPopover.AtomicPopoverConfig.centerDefault()
        config.onBackdropTap = { [weak self] in
            self?.routerManager.router(action: .dismiss())
        }
        popover = AtomicPopover(contentView: view, configuration: config)
    }
    
    guard let rootViewController = rootViewController else { return UIViewController() }
    let presentingViewController = getPresentingViewController(rootViewController)
    presentingViewController.present(popover, animated: false)
    
    return popover
}
```

**效果：**
- 点击背景通过路由系统关闭
- 路由栈状态正确管理
- 统一的关闭逻辑

---

### 场景 4：AtomicAlertView 弹窗

```swift
// 在 RouterControlCenter 中
private func presentAtomicAlert(alert: AtomicAlertView, viewPosition: ViewPosition) -> UIViewController {
    var popover: AtomicPopover
    if viewPosition == .bottom {
        let config = AtomicPopover.AtomicPopoverConfig(
            onBackdropTap: { [weak self] in
                self?.routerManager.router(action: .dismiss())
            }
        )
        popover = AtomicPopover(contentView: alert, configuration: config)
    } else {
        var config = AtomicPopover.AtomicPopoverConfig.centerDefault()
        config.onBackdropTap = { [weak self] in
            self?.routerManager.router(action: .dismiss())
        }
        popover = AtomicPopover(contentView: alert, configuration: config)
    }
    
    alert.onDismissRequested = { [weak popover] in
        popover?.dismiss(animated: false)
    }
    
    guard let rootViewController = rootViewController else { return UIViewController() }
    let presentingViewController = getPresentingViewController(rootViewController)
    presentingViewController.present(popover, animated: false)
    
    return popover
}
```

**效果：**
- 使用 AtomicAlertView 作为内容
- 点击背景或按钮都通过路由系统关闭
- 双向绑定：AlertView 的 onDismissRequested 和 Popover 的 onBackdropTap

---

### 场景 5：直播间礼物面板

```swift
class LiveRoomViewController: UIViewController {
    private var giftPopover: AtomicPopover?
    
    func showGiftPanel() {
        let giftView = GiftPanelView()
        
        let config = AtomicPopover.AtomicPopoverConfig(
            position: .bottom,
            height: .ratio(0.6),
            animation: .slideFromBottom,
            onBackdropTap: { [weak self] in
                self?.giftPopover?.dismiss(animated: false)
                self?.giftPopover = nil
            }
        )
        
        giftPopover = AtomicPopover(contentView: giftView, configuration: config)
        present(giftPopover!, animated: false)
    }
}
```

**效果：**
- 底部弹出礼物面板
- 直播画面上半部分仍可见
- 横屏时自动关闭，进入全屏观看

---

## 最佳实践

### ✅ 推荐做法

#### 1. 根据场景选择合适的位置和动画

```swift
// 底部操作菜单
let menuConfig = AtomicPopover.AtomicPopoverConfig(
    position: .bottom,
    animation: .slideFromBottom  // 匹配位置
)

// 居中确认对话框
let dialogConfig = AtomicPopover.AtomicPopoverConfig(
    position: .center,
    animation: .scale  // 更有吸引力
)
```

#### 2. 使用 ratio 设置常见高度

```swift
// ✅ 推荐
let config = AtomicPopover.AtomicPopoverConfig(height: .ratio(0.5))  // 清晰明确

// ❌ 不要写魔法数字的注释
// let config = AtomicPopover.AtomicPopoverConfig(height: .ratio(0.5))  // 300pt
```

#### 3. 对于固定高度的内容，使用 wrapContent

```swift
class MyContentView: UIView {
    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: 300)
    }
}

let config = AtomicPopover.AtomicPopoverConfig(height: .wrapContent)
```

#### 4. 使用闭包自定义背景点击行为

```swift
// ✅ 推荐：使用 weak self 避免循环引用
let config = AtomicPopover.AtomicPopoverConfig(
    onBackdropTap: { [weak self] in
        self?.handleBackdropTap()
    }
)
```

#### 5. 在路由系统中统一管理弹窗关闭

```swift
// ✅ 推荐：通过路由系统关闭
let config = AtomicPopover.AtomicPopoverConfig(
    onBackdropTap: { [weak self] in
        self?.routerManager.router(action: .dismiss())
    }
)
```

---

### ❌ 避免的做法

#### 1. 位置和动画不匹配

```swift
// ❌ 避免
let config = AtomicPopover.AtomicPopoverConfig(
    position: .bottom,
    animation: .slideFromTop  // 不连贯
)
```

#### 2. wrapContent 但内容没有高度

```swift
// ❌ 避免
let contentView = UIView()  // 没有 intrinsicContentSize 或约束
let config = AtomicPopover.AtomicPopoverConfig(height: .wrapContent)
// 结果：高度为 0，什么都看不到
```

#### 3. 闭包中使用强引用

```swift
// ❌ 避免循环引用
let config = AtomicPopover.AtomicPopoverConfig(
    onBackdropTap: {
        self.handleBackdropTap()  // 可能造成循环引用
    }
)

// ✅ 使用 weak self
let config = AtomicPopover.AtomicPopoverConfig(
    onBackdropTap: { [weak self] in
        self?.handleBackdropTap()
    }
)
```

---

## 内存管理

### 自动释放

```swift
func showPopover() {
    let popover = AtomicPopover(contentView: contentView)
    present(popover, animated: false)
    // popover 不需要保存为属性
    // 系统的 presentedViewController 会持有它
    // dismiss 后自动释放
}
```

### 手动管理（需要主动关闭的场景）

```swift
class MyViewController: UIViewController {
    private var popover: AtomicPopover?  // 强引用
    
    func showPopover() {
        let config = AtomicPopover.AtomicPopoverConfig(
            onBackdropTap: { [weak self] in
                self?.hidePopover()
            }
        )
        popover = AtomicPopover(contentView: contentView, configuration: config)
        present(popover!, animated: false)
    }
    
    func hidePopover() {
        popover?.dismiss(animated: false) { [weak self] in
            self?.popover = nil  // 释放引用
        }
    }
    
    deinit {
        popover?.dismiss(animated: false)
    }
}
```

### 避免循环引用

```swift
class MyViewController: UIViewController {
    func showPopover() {
        let contentView = MyContentView()
        
        // ✅ 使用 weak self
        contentView.onButtonTap = { [weak self] in
            self?.handleAction()
        }
        
        let config = AtomicPopover.AtomicPopoverConfig(
            onBackdropTap: { [weak self] in
                self?.dismiss(animated: false)
            }
        )
        
        let popover = AtomicPopover(contentView: contentView, configuration: config)
        present(popover, animated: false)
    }
}
```

---

## 注意事项

### 1. 内容视图高度

使用 `.wrapContent` 时，确保内容视图有明确的高度：

```swift
// 方式 1：实现 intrinsicContentSize
class MyContentView: UIView {
    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: 300)
    }
}

// 方式 2：使用约束
class MyContentView: UIView {
    private func setupConstraints() {
        someView.snp.makeConstraints { make in
            make.height.equalTo(300)
        }
    }
}
```

**重要**：内容视图的约束应该直接约束到 `superview`，不要使用 `safeAreaLayoutGuide`。安全区域的填充由 `AtomicPopover` 自动处理。

```swift
// ✅ 推荐
class MyPanelView: UIView {
    private func setupConstraints() {
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()  // 直接约束到 superview
        }
    }
}

// ❌ 避免
class MyPanelView: UIView {
    private func setupConstraints() {
        backgroundView.snp.makeConstraints { make in
            make.edges.equalTo(safeAreaLayoutGuide)  // 会造成底部空隙
        }
    }
}
```

### 2. 横屏自动关闭

组件默认在横屏时自动关闭。如果你的应用不支持横屏，无需担心此特性。

### 3. 多层模态

避免在已有模态 ViewController 上再弹出 Popover。如果确实需要，建议先关闭当前模态。

### 4. 线程安全

所有 UI 操作必须在主线程：

```swift
DispatchQueue.main.async {
    self.present(popover, animated: false)
}
```

### 5. 动画参数

组件统一使用 `animated: false` 来控制是否使用过渡动画。实际的动画效果由 `configuration.animation` 控制。

---

## 完整示例

### 选择城市的底部选择器

```swift
import UIKit
import AtomicX

class CityPickerView: UIView {
    // 城市列表
    private let cities = ["北京", "上海", "深圳", "广州"]
    
    // 选中回调
    var onCitySelected: ((String) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: 300)
    }
    
    private func setupUI() {
        // 实现城市选择 UI
    }
}

// 使用
class MyViewController: UIViewController {
    private var pickerPopover: AtomicPopover?
    
    func showCityPicker() {
        let pickerView = CityPickerView()
        
        pickerView.onCitySelected = { [weak self] city in
            print("选中城市：\(city)")
            // 关闭弹窗
            self?.pickerPopover?.dismiss(animated: false)
        }
        
        let config = AtomicPopover.AtomicPopoverConfig(
            position: .bottom,
            height: .wrapContent,
            animation: .slideFromBottom,
            onBackdropTap: { [weak self] in
                self?.pickerPopover?.dismiss(animated: false)
            }
        )
        
        let popover = AtomicPopover(contentView: pickerView, configuration: config)
        present(popover, animated: false)
        self.pickerPopover = popover
    }
}
```

---

## 技术细节

### 依赖

- **UIKit**: 基础 UI 框架
- **Combine**: 主题订阅
- **SnapKit**: 自动布局
- **ThemeStore**: 主题管理（内部组件）

### 架构

```
AtomicPopover (UIViewController)
├── modalPresentationStyle = .overFullScreen
├── view
│   ├── backdropView (背景蒙层)
│   └── containerView (内容容器，带圆角，clipsToBounds = true)
│       └── contentView (用户内容)
└── AtomicPopoverConfig
    ├── position (位置)
    ├── height (高度)
    ├── animation (动画)
    ├── backgroundColor (背景色)
    └── onBackdropTap (背景点击回调)
```

**布局层级说明：**

- `backdropView`: 全屏蒙层，透明黑色，接收背景点击手势
- `containerView`: 内容容器，带圆角和背景色
  - `clipsToBounds = true`：内容会被圆角裁剪
  - 底部/顶部弹窗约束到屏幕边缘
  - 内容通过圆角自然裁剪
- `contentView`: 用户提供的自定义内容视图

### 性能

- ✅ 轻量级：ViewController-based，符合 iOS 设计模式
- ✅ 主题响应：使用 Combine 订阅，自动更新
- ✅ 内存优化：dismiss 后自动释放
- ✅ 动画流畅：使用 Spring 动画，入场 0.35s（damping: 0.85），出场 0.28s（damping: 1.0）
- ✅ 交互优化：动画过程中允许用户交互，响应更快
- ✅ 视觉简洁：使用 clipsToBounds 裁剪内容，无需额外的 layer 管理

---

## FAQ

### Q: 如何实现自定义动画？

A: 当前版本提供了 5 种内置动画。如需自定义，可以使用 `.none` 然后手动添加动画。

### Q: 支持拖拽手势关闭吗？

A: 当前版本不支持，未来版本可能会添加此功能。

### Q: 可以嵌套使用吗？

A: 不推荐。如需在 Popover 中再弹出 Popover，建议先关闭当前的。

### Q: 横屏自动关闭可以禁用吗？

A: 当前版本不支持禁用。这是为了在横屏场景（如视频播放）提供更好的用户体验。

### Q: 如何监听 Popover 的关闭？

A: 使用 `dismiss(completion:)` 的回调：

```swift
popover.dismiss(animated: false) { 
    print("已关闭")
}
```

### Q: onBackdropTap 为 nil 时会发生什么？

A: 点击背景时**不会有任何操作**，弹窗保持显示状态。用户必须通过其他方式关闭弹窗（如点击内部的按钮）。

如果需要点击背景关闭，需要显式设置：

```swift
let config = AtomicPopover.AtomicPopoverConfig(
    onBackdropTap: { [weak self] in
        self?.dismiss(animated: false)
    }
)
```

### Q: 如何禁止点击背景关闭？

A: 将 `onBackdropTap` 设置为 `nil`（或不设置），这样点击背景时不会有任何操作。

```swift
let config = AtomicPopover.AtomicPopoverConfig(
    onBackdropTap: nil  // 禁止点击背景关闭
)
```

### Q: 底部弹窗的内容会被安全区域遮挡吗？

A: 不会。`AtomicPopover` 会自动限制 containerView 不超出顶部安全区域（`top >= safeAreaLayoutGuide.top`），同时底部约束到屏幕底部（`bottom = view.bottom`），内容通过 `clipsToBounds = true` 被圆角自然裁剪。

### Q: 内容视图需要处理安全区域吗？

A: **不需要**。内容视图的约束应该直接约束到 `superview`（即 containerView）。`AtomicPopover` 已经处理好了安全区域的限制和裁剪。

### Q: 如何让头像等元素溢出容器边界？

A: 内容视图可以自由布局，包括让元素溢出边界。只需在内容视图中将元素约束到负的 offset：

```swift
class RoomInfoPanelView: UIView {
    private func setupConstraints() {
        // 头像溢出顶部 29pt
        avatarView.snp.makeConstraints { make in
            make.top.equalToSuperview()  // 从容器顶部开始
            make.centerX.equalToSuperview()
        }
        
        // 背景视图从头像中部开始
        backgroundView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(29)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
```

### Q: 动画参数可以自定义吗？

A: 当前版本的动画参数已经过优化：
- **入场动画**：0.35s，Spring damping 0.85，初速度 0.6
- **出场动画**：0.28s，Spring damping 1.0，初速度 0.3
- 这些参数经过调试，提供了最佳的视觉体验

如需完全自定义动画，可使用 `.none` 动画类型，然后手动实现动画。

### Q: clipsToBounds 会影响性能吗？

A: 不会。`clipsToBounds = true` 是 iOS 系统层面的优化，对性能影响可以忽略不计。相比之前使用额外的 layer 填充方案，当前方案更简洁高效。

---

## 更新日志

### Version 3.0 (2026-01-20)

#### 🎨 架构优化
- ✅ **移除 safeAreaFillLayer**：不再使用额外的 CALayer 填充安全区域
- ✅ **改用 clipsToBounds**：使用 `containerView.clipsToBounds = true` 实现内容裁剪
- ✅ **简化实现**：减少代码复杂度，移除 `updateSafeAreaFillLayer()` 方法
- ✅ **约束优化**：底部/顶部弹窗约束到屏幕边缘（`view.snp.bottom`/`view.snp.top`）

#### 🔧 布局改进
- ✅ 底部弹窗：`containerView.bottom = view.bottom`，内容被圆角自然裁剪
- ✅ 顶部弹窗：`containerView.top = view.top`，内容被圆角自然裁剪
- ✅ 居中弹窗：保持原有逻辑，居中在安全区域内

#### 📚 文档更新
- ✅ 更新架构说明，反映最新实现
- ✅ 更新安全区域处理说明
- ✅ 更新 FAQ，移除 safeAreaFillView 相关问题
- ✅ 添加 clipsToBounds 性能说明

### Version 2.0 (2026-01-13)

#### 🎨 动画优化
- ✅ 优化入场动画时长：从 0.3s 提升到 0.35s，展示更从容
- ✅ 优化出场动画时长：从 0.25s 提升到 0.28s，响应更自然
- ✅ 改进弹簧动画参数：
  - 入场：damping 0.85（更稳定），初速度 0.6（更有冲力）
  - 出场：damping 1.0（无弹跳），初速度 0.3（轻微初速度）
- ✅ 添加 `.allowUserInteraction` 选项：动画过程中允许用户交互

---

## 许可证

本组件属于 AtomicX iOS UIKit 项目的一部分。

---

## 支持

如有问题或建议，请联系组件维护团队。
