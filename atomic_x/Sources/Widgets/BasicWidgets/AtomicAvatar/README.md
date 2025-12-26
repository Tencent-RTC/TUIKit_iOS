# AtomicAvatar 头像组件

轻量级头像组件，支持多种内容类型、尺寸档位、形状和徽章配置，自动响应主题切换，采用延迟初始化模式确保性能和稳定性。

---

## 快速开始

```swift
// 基础用法 - 网络图片头像
let avatar = AtomicAvatar(
    content: .url("https://example.com/avatar.jpg", placeholder: UIImage(named: "default_avatar")),
    size: .m,
    shape: .round
)

// 文本头像（用户名首字母）
let textAvatar = AtomicAvatar(
    content: .text(name: "张三"),
    size: .l,
    shape: .round
)

// 图标头像
let iconAvatar = AtomicAvatar(
    content: .icon(image: UIImage(systemName: "person.fill")!),
    size: .m,
    shape: .roundRectangle
)

// 带徽章的头像（在线状态）
let onlineAvatar = AtomicAvatar(
    content: .url("https://example.com/avatar.jpg", placeholder: nil),
    size: .l,
    shape: .round,
    badge: .dot
)

// 带未读数徽章
let unreadAvatar = AtomicAvatar(
    content: .url("https://example.com/avatar.jpg", placeholder: nil),
    size: .m,
    shape: .round,
    badge: .text("99+")
)

// 可点击的头像
let clickableAvatar = AtomicAvatar(
    content: .url("https://example.com/avatar.jpg", placeholder: nil),
    size: .m,
    shape: .round,
    onTap: { [weak self] in
        self?.showUserProfile()
    }
)
```

---

## 核心特性

### 1. 三种内容类型（AtomicAvatarContent）

| 内容类型 | 说明 | 适用场景 |
|---------|------|----------|
| `.url(_:placeholder:)` | 网络图片头像 | 用户头像、个人照片 |
| `.text(name:)` | 文本头像（姓名缩写） | 无头像时的占位 |
| `.icon(image:)` | 本地图标 | 系统账号、品牌 Logo |

```swift
// 网络图片（推荐提供占位图）
avatar.setContent(.url(
    "https://example.com/avatar.jpg",
    placeholder: UIImage(named: "default_avatar")
))

// 文本头像（1-2 个字符最佳）
avatar.setContent(.text(name: "张三"))

// 本地图标
if let icon = UIImage(systemName: "person.circle.fill") {
    avatar.setContent(.icon(image: icon))
}
```

**图片加载特性**（基于 Kingfisher）：
- ✅ 自动缓存（内存 + 磁盘）
- ✅ 淡入动画（0.2s）
- ✅ 失败自动回退到占位图
- ✅ 支持 Retina 屏幕（2x/3x）

**文本头像特性**：
- 自动居中对齐
- 字号随尺寸自适应
- 文字过长时自动缩放（最小 0.5 倍）
- 主题色背景 + 主色调文字

### 2. 七种尺寸档位（AtomicAvatarSize）

| 尺寸 | iOS (pt) | Android (dp) | 文字大小 | 圆角半径 | 适用场景 |
|------|----------|--------------|----------|----------|----------|
| `.xxs` | 14pt | 14dp | 10pt/sp | 4pt/dp | 超小头像、标签、徽章 |
| `.xs` | 24pt | 24dp | 12pt/sp | 4pt/dp | 极小头像、群成员列表 |
| `.s` | 32pt | 32dp | 14pt/sp | 4pt/dp | 消息列表、评论区 |
| `.m` | 40pt | 40dp | 16pt/sp | 4pt/dp | 标准头像、导航栏（默认） |
| `.l` | 48pt | 48dp | 18pt/sp | 8pt/dp | 用户卡片、个人主页 |
| `.xl` | 64pt | 64dp | 28pt/sp | 8pt/dp | 大尺寸展示 |
| `.xxl` | 96pt | 96dp | 36pt/sp | 8pt/dp | 个人资料页、详情页 |

```swift
// 动态修改尺寸
avatar.setSize(.xl)
```

### 3. 三种形状类型（AtomicAvatarShape）

```swift
// 圆形（默认，适合人像）
avatar.setShape(.round)

// 圆角矩形（适合品牌 Logo）
avatar.setShape(.roundRectangle)

// 矩形（适合特殊场景）
avatar.setShape(.rectangle)
```

| 形状 | 说明 | 适用场景 |
|------|------|----------|
| `.round` | 圆形 | 用户头像、个人照片 |
| `.roundRectangle` | 圆角矩形 | 品牌 Logo、机构图标 |
| `.rectangle` | 矩形 | 特殊装饰、占位图标 |

### 4. 徽章系统（AtomicAvatarBadge）

#### 圆点徽章（.dot）

```swift
// 用于在线状态指示
avatar.setBadge(.dot)
```

**徽章特性**：
- 尺寸：8pt × 8pt
- 颜色：`textColorError`（主题红色）
- 位置：右上角，根据形状自动调整

#### 文字徽章（.text）

```swift
// 用于未读消息数
avatar.setBadge(.text("5"))
avatar.setBadge(.text("99+"))

// 移除徽章
avatar.setBadge(.none)
```

**徽章特性**：
- 自适应宽度（最小 16pt 高度）
- 红色背景 + 白色文字
- 圆角矩形（8pt）
- 推荐格式：1 / 99 / 99+

#### 徽章定位算法

- **圆形头像**：徽章位于右上角 45° 方向
- **圆角矩形**：
  - 圆点徽章：贴合圆角边缘
  - 文字徽章：位于右上角顶点
- **矩形**：徽章位于右上角顶点

### 5. 点击交互

```swift
// 初始化时设置点击回调
let clickableAvatar = AtomicAvatar(
    content: .url("...", placeholder: nil),
    onTap: { [weak self] in
        self?.showUserProfile()
    }
)
```

**点击特性**：
- 自动添加手势识别
- 点击区域与可见区域一致
- 建议使用 `[weak self]` 避免循环引用

### 6. 自动主题适配

头像组件通过 `ThemeStore.shared.$currentTheme` 订阅主题变化，**无需手动更新**：

```swift
// 组件会自动跟随主题切换
let avatar = AtomicAvatar(
    content: .text(name: "张三")
)
// 浅色主题 → 深色主题时，背景色、文字色、字体大小自动更新
```

**实现原理**：
```swift
// AtomicAvatar 和 BadgeView 内部通过 Combine 订阅主题变化
ThemeStore.shared.$currentTheme
    .receive(on: DispatchQueue.main)
    .sink { [weak self] theme in
        self?.containerView.backgroundColor = theme.tokens.color.bgColorAvatar
        self?.textLabel.textColor = theme.tokens.color.textColorPrimary
        // 徽章颜色、字体等也会自动更新
    }
    .store(in: &cancellables)
```

**关键设计**：
- **动态计算属性**：`AtomicAvatarSize` 的 `textFont` 和 `borderRadius` 使用计算属性实时获取主题值
- **计算属性 vs 静态常量**：主题相关的常量（如 `BadgeView.Constants` 中的 `textHorizontalPadding`、`textCornerRadius`、`textFont`）使用 `static var` 计算属性，确保主题切换后能获取最新值
- **纯数值常量**：与主题无关的常量（如 `dotSize`、`textHeight`）使用 `static let`，提升访问性能

```swift
// ✅ 主题相关 - 使用计算属性
static var textCornerRadius: CGFloat {
    ThemeStore.shared.currentTheme.tokens.borderRadius.radius8
}

// ✅ 纯数值 - 使用静态常量
static let dotSize: CGFloat = 8
```

---

## API 参数

### 初始化方法

```swift
public init(
    content: AtomicAvatarContent,
    size: AtomicAvatarSize = .m,
    shape: AtomicAvatarShape = .round,
    badge: AtomicAvatarBadge = .none,
    onTap: (() -> Void)? = nil
)
```

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `content` | `AtomicAvatarContent` | 必填 | 头像内容（图片/文本/图标） |
| `size` | `AtomicAvatarSize` | `.m` | 尺寸档位 |
| `shape` | `AtomicAvatarShape` | `.round` | 形状类型 |
| `badge` | `AtomicAvatarBadge` | `.none` | 徽章类型 |
| `onTap` | `(() -> Void)?` | `nil` | 点击回调 |

### 公开方法

```swift
// 设置内容
avatar.setContent(.url("...", placeholder: nil))
avatar.setContent(.text(name: "李四"))
avatar.setContent(.icon(image: icon))

// 设置尺寸
avatar.setSize(.xl)

// 设置形状
avatar.setShape(.roundRectangle)

// 设置徽章
avatar.setBadge(.dot)
avatar.setBadge(.text("5"))
avatar.setBadge(.none)
```

---

## 使用场景

### 场景 1：用户列表

```swift
class UserListCell: UITableViewCell {
    private let avatar = AtomicAvatar(
        content: .url("", placeholder: UIImage(named: "default_avatar")),
        size: .m,
        shape: .round
    )
    
    func configure(with user: User) {
        avatar.setContent(.url(user.avatarURL, placeholder: UIImage(named: "default_avatar")))
        avatar.setBadge(user.isOnline ? .dot : .none)
    }
}
```

### 场景 2：个人主页

```swift
class ProfileViewController: UIViewController {
    private let avatarView = AtomicAvatar(
        content: .url("", placeholder: nil),
        size: .xxl,
        shape: .round,
        onTap: { [weak self] in
            self?.showAvatarEditor()
        }
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadUserProfile()
    }
    
    func loadUserProfile() {
        avatarView.setContent(.url(currentUser.avatarURL, placeholder: nil))
    }
}
```

### 场景 3：消息列表

```swift
class MessageCell: UITableViewCell {
    private let senderAvatar = AtomicAvatar(
        content: .text(name: ""),
        size: .s,
        shape: .round
    )
    
    func configure(with message: Message) {
        if let avatarURL = message.sender.avatarURL {
            senderAvatar.setContent(.url(avatarURL, placeholder: nil))
        } else {
            senderAvatar.setContent(.text(name: message.sender.name))
        }
        
        senderAvatar.setBadge(message.unreadCount > 0 ? .text("\(message.unreadCount)") : .none)
    }
}
```

### 场景 4：群聊头像

```swift
class GroupChatView: UIView {
    func createGroupAvatar(members: [User]) {
        // 显示群成员数量
        let groupAvatar = AtomicAvatar(
            content: .icon(image: UIImage(systemName: "person.3.fill")!),
            size: .l,
            shape: .roundRectangle,
            badge: .text("\(members.count)")
        )
        
        addSubview(groupAvatar)
    }
}
```

### 场景 5：品牌 Logo

```swift
class BrandCell: UICollectionViewCell {
    private let logoAvatar = AtomicAvatar(
        content: .icon(image: UIImage(named: "brand_logo")!),
        size: .xl,
        shape: .roundRectangle
    )
}
```

---

## 设计规范

### 尺寸规格表

| 尺寸 | 容器（iOS/Android） | 文字 | 圆角 | 徽章圆点 | 徽章文字高度 |
|------|---------------------|------|------|----------|--------------|
| xs | 24pt/dp | 12pt/sp | 4pt/dp | 8pt/dp | 16pt/dp |
| s | 32pt/dp | 14pt/sp | 4pt/dp | 8pt/dp | 16pt/dp |
| m | 40pt/dp | 16pt/sp | 4pt/dp | 8pt/dp | 16pt/dp |
| l | 48pt/dp | 18pt/sp | 8pt/dp | 8pt/dp | 16pt/dp |
| xl | 64pt/dp | 28pt/sp | 12pt/dp | 8pt/dp | 16pt/dp |
| xxl | 96pt/dp | 36pt/sp | 12pt/dp | 8pt/dp | 16pt/dp |

### 颜色 Token

| 元素 | Token | 说明 |
|------|-------|------|
| 背景色 | `bgColorAvatar` | 头像容器背景 |
| 文字色 | `textColorPrimary` | 文本头像文字 |
| 徽章背景 | `textColorError` | 徽章红色背景 |
| 徽章文字 | `textColorButton` | 徽章白色文字 |

### 徽章规范

**圆点徽章（.dot）**
- 尺寸：8pt/dp × 8pt/dp
- 颜色：`textColorError`（主题红色）
- 位置：右上角，根据形状自动调整

**文字徽章（.text）**
- 高度：16pt/dp
- 最小宽度：16pt/dp（单字符）
- 水平内边距：5pt/dp
- 圆角：8pt/dp
- 背景色：`textColorError`（主题红色）
- 文字色：`textColorButton`（主题白色）
- 字体：12pt/sp Bold
- 位置：右上角，文字徽章始终位于顶点

---

## 注意事项

### 1. 图片加载

**网络图片自动处理**：
```swift
// ✅ 推荐：提供占位图
let avatar = AtomicAvatar(
    content: .url(
        "https://example.com/avatar.jpg",
        placeholder: UIImage(named: "default_avatar")
    )
)

// ⚠️ 不推荐：无占位图时加载失败会显示空白
let avatar = AtomicAvatar(
    content: .url("https://example.com/avatar.jpg", placeholder: nil)
)
```

### 2. 文本内容建议

```swift
// ✅ 推荐：1-2 个字符
avatar.setContent(.text(name: "张三"))
avatar.setContent(.text(name: "AB"))

// ⚠️ 可用但会缩放：3-4 个字符
avatar.setContent(.text(name: "ABCD"))

// ❌ 不推荐：超过 4 个字符会过度缩小
avatar.setContent(.text(name: "这是一个很长的名字"))
```

### 3. 主线程调用

头像组件涉及 UI 操作，必须在主线程调用：

```swift
// ✅ 正确
DispatchQueue.main.async {
    avatar.setContent(.url("...", placeholder: nil))
}

// ❌ 错误（可能崩溃）
DispatchQueue.global().async {
    avatar.setContent(.url("...", placeholder: nil)) // 崩溃风险
}
```

### 4. 内存管理

```swift
// ✅ 在 Cell 复用时清理
override func prepareForReuse() {
    super.prepareForReuse()
    avatar.setContent(.icon(image: UIImage(named: "default_avatar")!))
    avatar.setBadge(.none)
}

// Kingfisher 自动管理图片缓存，无需手动清理
```

### 5. 徽章数字建议

```swift
// ✅ 推荐格式
avatar.setBadge(.text("1"))      // 个位数
avatar.setBadge(.text("99"))     // 两位数
avatar.setBadge(.text("99+"))    // 超过 99

// ❌ 不推荐：超长文本会撑大徽章
avatar.setBadge(.text("12345"))
```

### 6. 布局约束

```swift
// ✅ 头像会自动计算 intrinsicContentSize
view.addSubview(avatar)
avatar.snp.makeConstraints { make in
    make.top.left.equalToSuperview().inset(16)
    // 无需设置宽高，组件自动计算
}

// ⚠️ 如果有徽章，实际尺寸会略大于容器尺寸
// 徽章会突出到容器外部
```

### 7. 主题切换注意事项

```swift
// ✅ 主题相关的值必须使用计算属性
// 错误示范（主题切换后不会更新）：
static let textFont = ThemeStore.shared.currentTheme.tokens.typography.Medium12

// 正确示范（主题切换后自动更新）：
static var textFont: UIFont {
    ThemeStore.shared.currentTheme.tokens.typography.Medium12
}
```

**原因**：`static let` 在首次访问时计算并缓存，后续不会重新计算。如果需要响应主题变化，必须使用计算属性 `static var` 或实例属性。

---

## 性能优化

### 1. 图片缓存

```swift
// Kingfisher 自动缓存策略：
// - 内存缓存：快速访问
// - 磁盘缓存：持久化存储
// - 自动清理：内存警告时清理

// 手动清理缓存（应用设置页面）
ImageCache.default.clearMemoryCache()
ImageCache.default.clearDiskCache()
```

### 2. 列表优化

```swift
// ✅ 在 Cell 复用时更新内容
override func prepareForReuse() {
    super.prepareForReuse()
    avatar.imageView.kf.cancelDownloadTask() // 取消之前的下载
}

func configure(with user: User) {
    avatar.setContent(.url(user.avatarURL, placeholder: defaultImage))
}
```

### 3. 避免频繁重建

```swift
// ✅ 复用组件实例
private let avatar = AtomicAvatar(content: .text(name: ""), size: .m)

func updateUser(_ user: User) {
    avatar.setContent(.url(user.avatarURL, placeholder: nil))
    avatar.setBadge(user.unreadCount > 0 ? .text("\(user.unreadCount)") : .none)
}

// ❌ 避免频繁创建新实例
func updateUser(_ user: User) {
    let newAvatar = AtomicAvatar(...) // 性能浪费
}
```


## 最佳实践

### ✅ 推荐

```swift
// 1. 网络图片提供占位图
let avatar = AtomicAvatar(
    content: .url(user.avatarURL, placeholder: UIImage(named: "default_avatar")),
    size: .m,
    shape: .round
)

// 2. 文本头像使用 1-2 个字符
avatar.setContent(.text(name: String(user.name.prefix(2))))

// 3. 根据场景选择合适尺寸
// 列表：.s 或 .m
// 卡片：.l 或 .xl
// 详情页：.xxl

// 4. 在线状态使用圆点徽章
avatar.setBadge(user.isOnline ? .dot : .none)

// 5. 未读数使用文字徽章
let count = min(user.unreadCount, 99)
avatar.setBadge(.text(count > 99 ? "99+" : "\(count)"))

// 6. 点击交互使用 weak self
let clickableAvatar = AtomicAvatar(
    content: .url("...", placeholder: nil),
    onTap: { [weak self] in
        self?.showUserProfile()
    }
)
```

### ❌ 避免

```swift
// ❌ 文本过长导致缩小
avatar.setContent(.text(name: "这是一个很长的名字"))

// ❌ 不提供占位图导致加载失败时显示空白
avatar.setContent(.url("...", placeholder: nil))

// ❌ 徽章数字过长
avatar.setBadge(.text("12345"))

// ❌ 在后台线程调用
DispatchQueue.global().async {
    avatar.setContent(.url("...", placeholder: nil)) // 崩溃风险
}

// ❌ 频繁创建新实例
func updateUI() {
    let newAvatar = AtomicAvatar(...) // 应该复用实例
}
```

---

## 平台差异

### iOS vs Android

| 特性 | iOS | Android | 说明 |
|------|-----|---------|------|
| 尺寸单位 | pt | dp | 数值相同 |
| `.xs` 尺寸 | 24pt | 24dp | iOS 与 Android 一致 |
| 图片加载 | Kingfisher | ImageLoader | 框架不同，功能一致 |
| 主题订阅 | Combine | LiveData/Flow | 实现方式不同 |
| 布局约束 | SnapKit | LayoutParams | API 不同，效果一致 |

**注意**：跨平台使用时建议统一使用相同的尺寸档位（`.xs`, `.s`, `.m`, `.l`, `.xl`, `.xxl`），以保证视觉一致性。

---

## 文件结构

```
Avatar/
├── AtomicAvatar.swift     # iOS 头像组件核心实现
├── AtomicAvatar.kt        # Android 头像组件核心实现
└── README.md              # 本文件
```

---

## 依赖项

**iOS**
- UIKit: 基础 UI 框架
- Combine: 主题订阅
- SnapKit: 约束布局
- Kingfisher: 图片加载与缓存

**Android**
- Android SDK: 基础 UI 框架
- ThemeStore: 主题管理
- ImageLoader: 图片加载（Glide/Coil）

---

## 许可证

本组件属于 AtomicX UIKit 项目的一部分。
