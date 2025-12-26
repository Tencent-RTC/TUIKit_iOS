# AtomicLabel

AtomicX 基础 Label 组件，支持纯文本展示和图文混排，通过 Theme/Design Tokens 实现主题化。

## 特性

- ✅ 支持标准 `label.text = ""` 方式设置文本
- ✅ 图文混排（NSTextAttachment 实现）
- ✅ 自定义内边距（padding）
- ✅ 主题化外观（Theme/Design Tokens）
- ✅ 圆角支持

## 基础用法

### 纯文本

```swift
let label = AtomicLabel("Hello World")
```

### 设置文本

```swift
let label = AtomicLabel()
label.text = "新文本内容"
```

### 带图标

```swift
let label = AtomicLabel("带图标的文本")
label.iconConfiguration = IconConfiguration(
    icon: UIImage(named: "icon_star"),
    position: .left,
    spacing: 4,
    size: CGSize(width: 16, height: 16)
)
```

### 图标在右侧

```swift
label.iconConfiguration = IconConfiguration(
    icon: UIImage(systemName: "chevron.right"),
    position: .right,
    spacing: 8
)
```

### 自定义内边距

```swift
label.padding = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
```

## API 参考

### AtomicLabel

| 属性 | 类型 | 说明 |
|------|------|------|
| `text` | `String?` | 文本内容，支持标准赋值方式 |
| `iconConfiguration` | `IconConfiguration?` | 图标配置，nil 时为纯文本模式 |
| `padding` | `UIEdgeInsets` | 内边距，默认 `.zero` |

#### 初始化

```swift
init(_ text: String = "", appearanceProvider: AppearanceProvider)
```

- `text`: 初始文本内容
- `appearanceProvider`: 外观提供者闭包，根据 Theme 返回 LabelAppearance

### LabelAppearance

外观配置结构体，定义文本显示的视觉样式。

| 属性 | 类型 | 说明 |
|------|------|------|
| `textColor` | `UIColor` | 文本颜色 |
| `backgroundColor` | `UIColor` | 背景颜色 |
| `font` | `UIFont` | 字体 |
| `cornerRadius` | `BorderRadiusToken.RadiusType` | 圆角类型 |

#### 默认外观

```swift
LabelAppearance.defaultAppearance(for: theme)
```

### IconConfiguration

图标配置结构体。

| 属性 | 类型 | 说明 |
|------|------|------|
| `image` | `UIImage?` | 图标图片 |
| `position` | `Position` | 图标位置（`.left` / `.right`） |
| `spacing` | `CGFloat` | 图文间距，默认 4pt |
| `size` | `CGSize?` | 图标尺寸，nil 时使用图片原始尺寸 |

## 自定义外观

```swift
let label = AtomicLabel("自定义样式") { theme in
    LabelAppearance(
        textColor: theme.tokens.color.textColorSecondary,
        backgroundColor: theme.tokens.color.backgroundColorSecondary,
        font: theme.tokens.typography.Bold16,
        cornerRadius: .medium
    )
}
```

## 图文混排原理

AtomicLabel 使用 `NSTextAttachment` 实现图文混排：

1. 图标作为 `NSTextAttachment` 嵌入 `attributedText`
2. 垂直对齐：`attachment.bounds.origin.y = (font.capHeight - iconSize.height) / 2`
3. 间距通过空白 `NSTextAttachment` 实现

## 注意事项

- 设置 `text` 属性会自动触发 `attributedText` 重建
- 图标尺寸建议不超过字体行高的 1.5 倍
- 不支持图标动画
