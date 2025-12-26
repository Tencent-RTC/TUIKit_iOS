# AtomicPopover

一个功能强大、高度可定制的 iOS 通用弹窗容器组件。支持多种弹出位置、灵活的高度配置、丰富的动画效果和自动主题适配。

---

## 特性

- ✅ **多位置支持**：底部、居中、顶部三种弹出位置
- ✅ **灵活高度**：支持自适应内容高度和屏幕比例高度
- ✅ **丰富动画**：滑入、淡入、缩放等多种动画效果
- ✅ **主题自适应**：自动跟随系统主题（深色/浅色模式）
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
    public var onBackdropTap: (() -> Void)?
    
    public init(
        position: PopoverPosition = .bottom,
        height: PopoverHeight = .wrapContent,
        animation: PopoverAnimation = .slideFromBottom,
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

| 位置 | 宽度 | 圆角位置 | 适用场景 |
|------|------|---------|---------|
| `.bottom` | 全屏宽度 | 仅顶部圆角 | 底部菜单、选择器、操作面板 |
| `.center` | 屏幕宽度 × 0.8 | 四角圆角 | 对话框、Alert、表单 |
| `.top` | 全屏宽度 | 仅底部圆角 | 顶部通知、下拉菜单 |

#### 视觉效果

```
┌─────────────────────┐
│                     │
│                     │
├─────────────────────┤  ← Top 位置（全宽）
│    Top Popover      │
╰─────────────────────╯

┌─────────────────────┐
│                     │
│   ╭─────────────╮   │  ← Center 位置（80% 宽）
│   │   Center    │   │     左右留白，视觉优雅
│   │   Popover   │   │
│   ╰─────────────╯   │
│                     │
└─────────────────────┘

╭─────────────────────╮
│  Bottom Popover     │  ← Bottom 位置（全宽）
├─────────────────────┤
│                     │
│                     │
└─────────────────────┘
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

| 动画类型 | 入场效果 | 出场效果 | 时长 | 推荐搭配位置 |
|---------|---------|---------|------|------------|
| `.slideFromBottom` | 从底部滑入 | 滑出到底部 | 0.3s | `.bottom` |
| `.slideFromTop` | 从顶部滑入 | 滑出到顶部 | 0.3s | `.top` |
| `.fade` | 淡入 (透明度 0→1) | 淡出 (透明度 1→0) | 0.3s | `.center` |
| `.scale` | 缩放 + 淡入 (0.8→1.0) | 缩放 + 淡出 (1.0→0.9) | 0.3s | `.center` |
| `.none` | 直接显示 | 直接消失 | 无 | 所有位置 |

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

### onBackdropTap - 背景点击回调

控制点击蒙层背景时的行为。

```swift
public var onBackdropTap: (() -> Void)?  // 默认 nil
```

#### 使用场景

**`nil` (默认)** - 点击背景时自动调用 `dismiss()`
- 常规菜单、选择器
- 非强制性的弹窗
- 用户可随时取消的场景

**自定义闭包** - 执行自定义逻辑
- 点击背景时需要特殊处理（如保存数据、显示确认对话框）
- 通过路由系统管理的弹窗（调用路由的 dismiss）
- 需要额外逻辑的场景

#### 示例

```swift
// 默认行为：点击背景自动关闭
let config = AtomicPopover.AtomicPopoverConfig(
    onBackdropTap: nil  // 或直接不设置
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

// 禁止点击背景关闭：不添加闭包且不设置手势
// （需要手动处理，当前实现会自动 dismiss，如需禁止需要修改组件）
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
- **`.center`**：屏幕宽度的 80%（居中显示，两侧留白 10%）

### 3. 背景蒙层

- **颜色**：`theme.tokens.color.bgColorMask`（自动跟随主题）
- **透明度**：入场动画时从 0 → 1

### 4. 主题适配

- 自动订阅 `ThemeStore`
- 主题切换时自动更新背景色、蒙层色、圆角
- 无需手动处理

### 5. 横屏行为

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
        animation: .slideFromBottom
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
        animation: .scale
    )
    
    let popover = AtomicPopover(contentView: dialogView, configuration: config)
    present(popover, animated: false)
}
```

**效果：**
- 居中显示
- 宽度为屏幕的 80%
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
            animation: .slideFromBottom
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
│   └── containerView (内容容器)
│       └── contentView (用户内容)
└── AtomicPopoverConfig
    ├── position (位置)
    ├── height (高度)
    ├── animation (动画)
    └── onBackdropTap (背景点击回调)
```

### 性能

- ✅ 轻量级：ViewController-based，符合 iOS 设计模式
- ✅ 主题响应：使用 Combine 订阅，自动更新
- ✅ 内存优化：dismiss 后自动释放
- ✅ 动画流畅：使用 Spring 动画，视觉自然

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

A: 点击背景时会自动调用 `dismiss()`，等同于：

```swift
let config = AtomicPopover.AtomicPopoverConfig(
    onBackdropTap: { [weak self] in
        self?.dismiss(animated: false)
    }
)
```

### Q: 如何禁止点击背景关闭？

A: 当前实现中，如果 `onBackdropTap` 为 `nil`，会自动 dismiss。如需完全禁止，需要在闭包中不调用任何关闭逻辑，或者修改组件源码。

---

## 许可证

本组件属于 AtomicX iOS UIKit 项目的一部分。

---

## 支持

如有问题或建议，请联系组件维护团队。
