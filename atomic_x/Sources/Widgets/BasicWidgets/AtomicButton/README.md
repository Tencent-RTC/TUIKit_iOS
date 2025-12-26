# AtomicButton 按钮组件

AtomicX iOS UIKit 通用按钮组件，支持多种语义变体、尺寸档位和灵活的图文布局，并与主题系统深度集成。

## 文件结构

```
AtomicButton/
├── AtomicButton.swift        # 按钮组件核心实现
├── AtomicButtonConfig.swift  # 配置与主题工厂
├── README.md                 # 使用指南（本文件）
└── MIGRATION_GUIDE.md        # 迁移指南
```

---

## 快速开始

### 基础用法

```swift
// 主操作按钮
let primaryButton = AtomicButton(
    variant: .filled,
    colorType: .primary,
    size: .medium,
    content: .textOnly(text: "提交")
)

// 次级按钮
let secondaryButton = AtomicButton(
    variant: .outlined,
    colorType: .secondary,
    size: .medium,
    content: .textOnly(text: "取消")
)

// 危险操作按钮（带图标）
let dangerButton = AtomicButton(
    variant: .filled,
    colorType: .danger,
    size: .small,
    content: .iconLeading(text: "删除", icon: UIImage(systemName: "trash.fill"))
)

// 设置点击回调
primaryButton.setClickAction { button in
    print("按钮被点击")
}
```

### 自定义配置模式

```swift
let customButton = AtomicButton(
    content: .textOnly(text: "自定义"),
    contentInsets: NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16),
    buttonConfigProvider: { theme in
        AtomicButtonConfig(
            normalButtonColor: ButtonColors(
                backgroundColor: theme.tokens.color.buttonColorPrimaryDefault,
                textColor: theme.tokens.color.textColorButton,
                borderColor: .clear
            ),
            cornerRadius: 12,
            borderWidth: 0,
            font: theme.tokens.typography.Medium16
        )
    }
)
```

---

## API 参考

### AtomicButton

#### 初始化方法

**预设模式**（推荐）
```swift
public init(
    variant: ButtonVariant = .filled,
    colorType: ButtonColorType = .primary,
    size: ButtonSize = .small,
    content: ButtonContent = .textOnly(text: "")
)
```

**自定义模式**
```swift
public init(
    content: ButtonContent = .textOnly(text: ""),
    contentInsets: NSDirectionalEdgeInsets = Defaults.contentInsets,
    buttonConfigProvider: @escaping ButtonConfigProvider
)
```

#### 公开属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `fixedSize` | `ButtonSize?` | 固定尺寸（预设模式时有值） |
| `content` | `ButtonContent` | 当前按钮内容（只读） |
| `contentInsets` | `NSDirectionalEdgeInsets` | 内容边距 |
| `currentTitle` | `String?` | 当前文本（兼容 UIButton） |
| `currentImage` | `UIImage?` | 当前图标（兼容 UIButton） |

#### 公开方法

```swift
// 设置按钮内容
func setButtonContent(_ content: ButtonContent)

// 设置按钮样式变体
func setVariant(_ variant: ButtonVariant)

// 设置按钮颜色类型
func setColorType(_ colorType: ButtonColorType)

// 设置点击回调
func setClickAction(_ action: @escaping (AtomicButton) -> Void)
```
---

## 核心枚举与配置

### ButtonContent

按钮内容布局枚举：

| 类型 | 说明 |
|------|------|
| `.textOnly(text:)` | 仅文本 |
| `.iconOnly(icon:)` | 仅图标 |
| `.iconLeading(text:icon:)` | 左图标 + 右文本 |
| `.iconTrailing(text:icon:)` | 左文本 + 右图标 |

### ButtonVariant

按钮样式变体：

| 值 | 说明 |
|------|------|
| `.filled` | 实心填充，适合主要操作 |
| `.outlined` | 边框描边，适合次级操作 |
| `.text` | 纯文本，无背景无边框 |

### ButtonColorType

按钮颜色语义：

| 值 | 说明 |
|------|------|
| `.primary` | 主色调，强调操作 |
| `.secondary` | 次级/默认操作 |
| `.danger` | 危险/警示操作 |

### ButtonSize

尺寸档位：

| 尺寸 | 高度 | 最小宽度 | 水平内边距 | 图标尺寸 |
|------|------|----------|------------|----------|
| `.xsmall` | 24pt | 48pt | 8pt | 14pt |
| `.small` | 32pt | 64pt | 12pt | 16pt |
| `.medium` | 40pt | 80pt | 16pt | 20pt |
| `.large` | 48pt | 96pt | 20pt | 20pt |

### AtomicButtonConfig

按钮配置结构体：

| 属性 | 类型 | 说明 |
|------|------|------|
| `normalButtonColor` | `ButtonColors` | 正常态颜色 |
| `highlightedButtonColor` | `ButtonColors` | 高亮态颜色（自动生成） |
| `disabledButtonColor` | `ButtonColors` | 禁用态颜色（自动生成） |
| `cornerRadius` | `CGFloat` | 圆角半径 |
| `borderWidth` | `CGFloat` | 边框宽度 |
| `font` | `UIFont` | 文本字体 |

**预设工厂方法**
```swift
static func preset(
    colorType: ButtonColorType,
    variant: ButtonVariant,
    ButtonSize: ButtonSize,
    for theme: Theme
) -> AtomicButtonConfig
```

### ButtonColors

颜色配置结构体：

| 属性 | 类型 | 说明 |
|------|------|------|
| `backgroundColor` | `UIColor` | 背景色 |
| `textColor` | `UIColor` | 文本/图标颜色 |
| `borderColor` | `UIColor` | 边框颜色 |

---

## 使用示例

### 图标按钮

```swift
// 仅图标
let iconButton = AtomicButton(
    variant: .filled,
    colorType: .primary,
    size: .medium,
    content: .iconOnly(icon: UIImage(systemName: "plus"))
)

// 图标在前
let leadingIcon = AtomicButton(
    variant: .outlined,
    colorType: .secondary,
    size: .small,
    content: .iconLeading(text: "添加", icon: UIImage(systemName: "plus"))
)

// 图标在后
let trailingIcon = AtomicButton(
    variant: .text,
    colorType: .primary,
    size: .small,
    content: .iconTrailing(text: "更多", icon: UIImage(systemName: "chevron.right"))
)
```

### 动态更新内容

```swift
let button = AtomicButton(
    variant: .filled,
    colorType: .primary,
    size: .medium,
    content: .textOnly(text: "加载中...")
)

// 更新文本
button.setButtonContent(.textOnly(text: "完成"))

// 切换为带图标
button.setButtonContent(.iconLeading(text: "成功", icon: UIImage(systemName: "checkmark")))
```

### 动态更新样式

```swift
let button = AtomicButton(
    variant: .filled,
    colorType: .primary,
    size: .medium,
    content: .textOnly(text: "按钮")
)

// 切换样式
button.setVariant(.outlined)

// 切换颜色
button.setColorType(.danger)

// 一次性更新多个属性
func updateStyle(isActive: Bool) {
    button.setButtonContent(.textOnly(text: isActive ? "激活" : "未激活"))
    button.setVariant(isActive ? .filled : .outlined)
    button.setColorType(isActive ? .primary : .secondary)
}
```

### 禁用状态

```swift
let button = AtomicButton(
    variant: .filled,
    colorType: .primary,
    size: .medium,
    content: .textOnly(text: "提交")
)

button.isEnabled = false  // 自动应用禁用样式
```

### 状态切换（使用原生 UIButton API）

AtomicButton 移除了复杂的状态管理，推荐使用原生 UIButton API 配合 `isSelected` 实现状态切换：

#### 方案 1: 使用原生 API（推荐）

```swift
let button = AtomicButton(
    variant: .filled,
    colorType: .primary,
    size: .medium
)

// 为不同状态设置不同文本
button.setTitle("关注", for: .normal)
button.setTitle("已关注", for: .selected)

// 为不同状态设置不同图标
button.setImage(nil, for: .normal)
button.setImage(UIImage(systemName: "checkmark"), for: .selected)

// 切换状态
button.setClickAction { btn in
    btn.isSelected.toggle()  // 自动切换文本和图标
}
```

#### 方案 2: 动态更新样式

```swift
let followButton = AtomicButton(
    variant: .filled,
    colorType: .primary,
    size: .medium,
    content: .textOnly(text: "关注")
)

func updateFollowState(isFollowing: Bool) {
    if isFollowing {
        followButton.setButtonContent(.iconOnly(icon: UIImage(systemName: "checkmark")))
        followButton.setVariant(.outlined)
        followButton.setColorType(.secondary)
    } else {
        followButton.setButtonContent(.textOnly(text: "关注"))
        followButton.setVariant(.filled)
        followButton.setColorType(.primary)
    }
}

followButton.setClickAction { [weak self] _ in
    self?.isFollowing.toggle()
    self?.updateFollowState(isFollowing: self?.isFollowing ?? false)
}
```

#### 方案 3: 双按钮方案（适合复杂场景）

```swift
// 创建两个不同状态的按钮
let normalButton = AtomicButton(
    variant: .filled,
    colorType: .primary,
    size: .medium,
    content: .textOnly(text: "邀请")
)

let selectedButton = AtomicButton(
    variant: .outlined,
    colorType: .secondary,
    size: .medium,
    content: .textOnly(text: "取消邀请")
)

// 通过隐藏/显示控制
func updateState(isSelected: Bool) {
    normalButton.isHidden = isSelected
    selectedButton.isHidden = !isSelected
}

normalButton.setClickAction { [weak self] _ in
    self?.updateState(isSelected: true)
}

selectedButton.setClickAction { [weak self] _ in
    self?.updateState(isSelected: false)
}
```

---

## 主要特性

### 1. 主题系统集成
- 通过 `ThemeStore.shared.$currentTheme` 自动监听主题变化
- 使用 Combine 订阅，主题切换时自动刷新样式
- 无需手动调用更新方法

### 2. 自动状态管理
组件根据 `isEnabled` 和 `isHighlighted` 自动切换样式：
- **normal**: 使用 `normalButtonColor`
- **highlighted**: 使用 `highlightedButtonColor`（自动生成 0.8 透明度）
- **disabled**: 使用 `disabledButtonColor`（自动生成 0.3 透明度）

### 3. 智能内容更新
- 相同结构的内容更新（如仅改文本）不会重建视图
- 结构变化时自动重建内部 StackView
- 性能优化，适合在列表中大量使用

### 4. 默认值常量

```swift
public enum Defaults {
    public static let spacing: CGFloat = 6.0
    public static let fallbackIconSize: CGFloat = 20.0
    public static let contentInsets = NSDirectionalEdgeInsets(
        top: 4, leading: 4, bottom: 4, trailing: 4
    )
}
```

---

## 注意事项

1. **点击区域**: 按钮的可点击区域与可见尺寸一致
2. **图标尺寸**: 图标大小由 `ButtonSize.iconSize` 自动控制
3. **主题切换**: 使用 Combine 自动响应 `ThemeStore` 主题变化
4. **性能优化**: 相同结构内容更新不重建视图，可在列表中大量使用
5. **圆角**: 预设模式固定使用 26pt 圆角
6. **状态切换**: 推荐使用原生 UIButton API（`setTitle(_:for:)`、`setImage(_:for:)`）配合 `isSelected`

---

## 许可证

本组件属于 AtomicX iOS UIKit 项目的一部分。
