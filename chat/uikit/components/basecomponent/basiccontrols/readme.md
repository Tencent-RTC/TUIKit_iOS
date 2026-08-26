# BaseComponent SwiftUI 组件使用说明

## 目录

- [Avatar](#avatar)
- [Button](#button)
- [Toast](#toast)
- [AlertDialog](#alertdialog)
- [Label](#label)
- [Badge](#badge)
- [Switch](#switch)
- [Bubble](#bubble)
- [PopMenu](#popmenu)
- [主题语义化样式枚举](#主题语义化样式枚举)

---

## Avatar

### 用法

#### 便捷用法
```swift
Avatar(url: "https://example.com/avatar.jpg", name: "张三")
```

#### 完整用法
```swift
Avatar(
    content: .image(url: "https://example.com/avatar.jpg", name: "张三"),
    size: .m,    // .xs / .s / .m / .l / .xl / .xxl
    shape: .round, // .round / .roundedRectangle / .rectangle
    status: .online, // .none / .online / .offline
    badge: .count(5), // .none / .dot / .text("VIP") / .count(5)
    onClick: { /* ... */ }
)
```

### 参数说明
- `content`: 头像内容（.image/.text/.symbol/.local）
- `size`: 头像尺寸
- `shape`: 头像形状
- `status`: 在线状态点
- `badge`: 角标
- `onClick`: 点击回调（可选）

### 字体适配
头像内文字的字体会根据 `size` 自动适配，无需手动指定。

---

## Button

### 用法

#### 便捷用法
```swift
FilledButton(text: "主按钮") { /* ... */ }
OutlinedButton(text: "次按钮") { /* ... */ }
IconButton(text: "带图标", icon: Image(systemName: "star")) { /* ... */ }
```

#### 完整用法
```swift
ButtonView(
    content: .iconWithText(text: "收藏", icon: Image(systemName: "star")),
    enabled: true,
    type: .filled, // .filled / .outlined / .noBorder
    colorType: .primary, // .primary / .secondary / .danger
    size: .m, // .xs / .s / .m / .l
    onClick: { /* ... */ }
)
```

### 参数说明
- `content`: 按钮内容（.textOnly/.iconOnly/.iconWithText）
- `enabled`: 是否可用（默认 true）
- `type`: 按钮类型（填充、描边、无边框）
- `colorType`: 语义色类型（主色、次色、危险）
- `size`: 按钮尺寸（xs/s/m/l）
- `onClick`: 点击回调

### 字体适配
按钮字体会根据 `size` 自动适配，无需手动指定。

### 主题环境
需要 `.environmentObject(themeState)` 注入主题。

---

## Toast

### 用法

#### 页面集成
```swift
@StateObject private var toast = Toast()

var body: some View {
    VStack {
        // ... 你的页面内容 ...
        Button("显示 Toast") {
            toast.success("操作成功！")
        }
    }
    .toast(toast) // 必须加在页面最外层
}
```

#### 便捷用法
```swift
toast.loading("加载中...")
toast.info("信息提示")
toast.success("操作成功")
toast.warning("警告信息")
toast.error("错误信息")
toast.simple("纯文字提示")
```

#### 完整用法
```swift
toast.show("自定义内容", type: .info, icon: "iconName", duration: 2.0)
```

### 主题环境
Toast 组件自动适配深色/浅色主题，无需额外配置。

---

## AlertDialog

### 用法

#### 便捷用法
```swift
@State private var showAlert = false
Button("弹窗") { showAlert = true }
    .alertDialog(isPresented: $showAlert, message: "操作成功！")
```

#### 完整用法
```swift
.alertDialog(
    isPresented: $showAlert,
    title: "确认操作",
    message: "是否确认执行此操作？",
    confirmText: "确认",
    onConfirm: { /* 确认回调 */ },
    secondaryText: "取消",
    onSecondary: { /* 取消回调 */ }
)
```

### 参数说明
- `isPresented`: 显示绑定
- `title`: 标题（可选）
- `message`: 内容（可选）
- `confirmText`: 确认按钮文字（默认"我知道了"）
- `onConfirm`: 确认回调
- `secondaryText`: 次要按钮文字（可选）
- `onSecondary`: 次要按钮回调（可选）

---

## Label

### 用法

#### 便捷用法
```swift
TitleLabel(size: .s, text: "主标题-小")
SubTitleLabel(size: .s, text: "副标题-小")
ItemLabel(size: .s, text: "条目-小")
DangerLabel(size: .s, text: "警告-小")
TagLabel(size: .m, text: "标签", colorType: .blue)
```

#### 完整用法
```swift
CustomLabel(
    text: "自定义Label",
    font: .system(size: 16),
    textColor: .red,
    backgroundColor: .yellow,
    lineLimit: 2,
    icon: "iconName", // 可选，assets图片名
    iconPosition: .start // .start/.end
)
```

### 参数说明
- `size`: .s / .m / .l（小/中/大）
- `text`: 文本内容
- `font`: 字体（仅 CustomLabel 支持）
- `textColor`: 文字颜色（CustomLabel 支持自定义，其它自动适配主题）
- `backgroundColor`: 背景色（CustomLabel 支持自定义，其它自动适配主题）
- `lineLimit`: 行数限制（默认1，CustomLabel可自定义）
- `icon`: 图标（assets图片名，CustomLabel/TagLabel 支持）
- `iconPosition`: 图标位置（.start/.end，CustomLabel/TagLabel 支持）
- `colorType`: TagLabel 颜色类型（.white/.blue/.green/.gray/.orange/.red）

### 字体适配
Label 字体会根据 `size` 和类型自动适配，无需手动指定。

### 主题环境
Label 组件自动适配主题色，无需手动设置。

---

## Badge

### 用法
```swift
Badge(text: "99+")
Badge(type: .dot)
Badge(text: "新消息", type: .text)
```

### 参数说明
- `text`: 显示文本（可选）
- `type`: .text / .dot

---

## Switch

### 用法
```swift
BasicSwitch(checked: isOn, onCheckedChange: { isOn = $0 })
```

#### 完整用法
```swift
SwitchView(
    checked: isOn,
    onCheckedChange: { isOn = $0 },
    enabled: true,
    loading: false,
    size: .l, // .s / .m / .l
    type: .basic // .basic / .withText / .withIcon
)
```

### 参数说明
- `checked`: 当前开关状态（Bool）
- `onCheckedChange`: 状态变更回调 ((Bool) -> Void)?
- `enabled`: 是否可用（默认 true）
- `loading`: 是否显示加载动画（默认 false）
- `size`: 尺寸（.s / .m / .l）
- `type`: 展示类型（.basic / .withText / .withIcon）

---

## Bubble

### 用法
```swift
LeftBottomSquareBubble(backgroundColor: .green) {
    Text("左下直角气泡")
}
RightBottomSquareBubble(backgroundColor: .blue) {
    Text("右下直角气泡")
}
AllRoundBubble(backgroundColor: .orange) {
    Text("全圆角气泡")
}
LeftTopSquareBubble(backgroundColor: .purple) {
    Text("左上直角气泡")
}
RightTopSquareBubble(backgroundColor: .pink) {
    Text("右上直角气泡")
}
```

#### 通用用法
```swift
Bubble(
    bubbleColorType: .filled, // .filled / .outlined / .both
    backgroundColor: .gray,
    highlightColors: [.gray, .white], // 可选，渐变色
    radii: [18, 18, 0, 18], // 四角圆角
    borderColor: .red, // 可选，描边色
    borderWidth: 2 // 可选，描边宽度
) {
    Text("自定义内容")
}
```

### 参数说明
- `bubbleColorType`: 气泡类型（.filled 填充，.outlined 描边，.both 填充+描边）
- `backgroundColor`: 背景色
- `highlightColors`: 渐变色数组（可选）
- `radii`: 四角圆角半径 [左上, 右上, 右下, 左下]
- `borderColor`: 边框颜色（可选）
- `borderWidth`: 边框宽度（可选）
- `content`: 气泡内容（ViewBuilder）

---

## PopMenu

### 用法
```swift
PopMenu(items: menuItems, onSelect: { selected in
    // 处理选中项
})
```

### 参数说明
- `items`: 菜单项数组
- `onSelect`: 选中回调

---

## 主题语义化样式枚举

### 1. 颜色

#### SemanticColorScheme 全量属性
- textColorPrimary
- textColorSecondary
- textColorTertiary
- textColorDisable
- textColorButton
- textColorButtonDisabled
- textColorLink
- textColorLinkHover
- textColorLinkActive
- textColorLinkDisabled
- textColorAntiPrimary
- textColorAntiSecondary
- textColorWarning
- textColorSuccess
- textColorError
- bgColorTopBar
- bgColorOperate
- bgColorDialog
- bgColorDialogModule
- bgColorEntryCard
- bgColorFunction
- bgColorBottomBar
- bgColorInput
- bgColorBubbleReciprocal
- bgColorBubbleOwn
- bgColorDefault
- bgColorTagMask
- bgColorElementMask
- bgColorMask
- bgColorMaskDisappeared
- bgColorMaskBegin
- strokeColorPrimary
- strokeColorSecondary
- strokeColorModule
- shadowColor
- listColorDefault
- listColorHover
- listColorFocused
- buttonColorPrimaryDefault
- buttonColorPrimaryHover
- buttonColorPrimaryActive
- buttonColorPrimaryDisabled
- buttonColorSecondaryDefault
- buttonColorSecondaryHover
- buttonColorSecondaryActive
- buttonColorSecondaryDisabled
- buttonColorAccept
- buttonColorHangupDefault
- buttonColorHangupDisabled
- buttonColorHangupHover
- buttonColorHangupActive
- buttonColorOn
- buttonColorOff
- dropdownColorDefault
- dropdownColorHover
- dropdownColorActive
- scrollbarColorDefault
- scrollbarColorHover
- floatingColorDefault
- floatingColorOperate
- checkboxColorSelected
- toastColorWarning
- toastColorSuccess
- toastColorError
- toastColorDefault
- tagColorLevel1
- tagColorLevel2
- tagColorLevel3
- tagColorLevel4
- switchColorOff
- switchColorOn
- switchColorButton
- sliderColorFilled
- sliderColorEmpty
- sliderColorButton
- tabColorSelected
- tabColorUnselected
- tabColorOption
- clearColor

### 2. 字体

#### SemanticFontScheme 全量属性
- title1Bold
- title2Bold
- title3Bold
- title4Bold
- body1Bold
- body2Bold
- body3Bold
- body4Bold
- caption1Bold
- caption2Bold
- caption3Bold
- caption4Bold
- title1Medium
- title2Medium
- title3Medium
- title4Medium
- body1Medium
- body2Medium
- body3Medium
- body4Medium
- caption1Medium
- caption2Medium
- caption3Medium
- caption4Medium
- title1Regular
- title2Regular
- title3Regular
- title4Regular
- body1Regular
- body2Regular
- body3Regular
- body4Regular
- caption1Regular
- caption2Regular
- caption3Regular
- caption4Regular

### 3. 圆角

#### RadiusScheme 全量 case
- tipsRadius
- smallRadius
- alertRadius
- largeRadius
- superLargeRadius
- roundRadius

### 4. 间距

#### SpacingScheme 全量 case
- iconTextSpacing
- smallSpacing
- iconIconSpacing
- bubbleSpacing
- contentSpacing
- normalSpacing
- titleSpacing
- cardSpacing
- largeSpacing
- maxSpacing

---