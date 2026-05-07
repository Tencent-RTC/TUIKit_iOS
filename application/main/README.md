# 模块概览

## 模块简介

Main 模块是 App 首页，负责展示所有业务模块的入口卡片，用户点击卡片后跳转到对应的业务模块。

根目录下有 **两个入口控制器**，分别服务于不同的 Xcode Target：

| 入口控制器 | 服务 Target | 说明 |
|-----------|------------|------|
| `EntranceViewController` | **RTCube** / **RTCubeLab** | 国内版 / 开发测试版首页，瀑布流卡片布局 |
| `OverseasHomeViewController` | **TencentRTC** | 海外版首页容器，内嵌 `OverseasMainViewController` 双 Tab 布局 |

模块采用**动态注册**的设计，所有业务模块的创建与配置集中在独立的 `AppAssembly` Pod 中，首页通过 `AppAssembly.shared.allModuleProviders(target:)` 获取模块列表，不直接 import 任何业务模块代码。

## UI 结构

### 国内版 / Lab 版（EntranceViewController）

```
EntranceViewController.view (背景色: #EBEDF5)
  ├── MainNavigationView              ← 顶部导航栏
  │     ├── iconView                  ← 应用 Logo（根据语言切换中/英文 Logo）
  │     └── avatarButton              ← 用户头像按钮 → 跳转个人中心
  ├── EntranceReportView              ← 举报提示横条（仅中文环境 + 非 MOA 用户显示）
  ├── SafetyReminderView              ← 安全提醒弹窗（5 秒倒计时，首次进入时触发）
  └── UICollectionView                ← 核心内容区，瀑布流展示模块入口
        ├── EntranceCollectionCell × N   ← 各模块卡片
        └── EntranceFooterView           ← 底部"UI组件"说明文字
```

### 海外版（OverseasHomeViewController）

```
OverseasHomeViewController.view (渐变背景: F7F9FC → F0F2F5)
  ├── naviBackView                    ← 白色导航栏背景
  ├── OverseasNavigationView          ← 顶部导航栏（英文 Logo + 头像）
  └── OverseasMainViewController      ← 内容子控制器（双 Tab）
        ├── UISegmentedControl         ← Products / Discovery Lab 切换
        ├── UIScrollView (分页)        ← 左右滑动切换 Tab
        │     ├── productsCollectionView     ← Products Tab（Call、AI、Interpretation、Room、Live、Chat、Beauty）
        │     │     ├── OverseasCollectionCell × N
        │     │     └── OverseasFooterView   ← 底部场景体验入口
        │     ├── ContactUsTipsView          ← 联系我们提示
        │     └── discoveryCollectionView    ← Discovery Lab Tab（Player、UGSV）
        │           └── OverseasCollectionCell × N
        └── ContactUsService                 ← TUICore 联系我们服务（viewWillAppear 显示 / viewWillDisappear 隐藏）
```

### CollectionView 布局规则（国内版）

| 卡片类型 | 宽度 | 高度 | 排列 |
|----------|------|------|------|
| `.standard` / `.uiComponent` | `ScreenWidth / 2 - 13` | `106` | 两列 |
| `.banner` | `ScreenWidth - 24` | `58` | 通栏 |

Section 内边距：`UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)`，使用左对齐自定义 `LeftAlignedFlowLayout`。

### CollectionView 布局规则（海外版）

| 卡片类型 | 宽度 | 高度 | 排列 |
|----------|------|------|------|
| 所有卡片 | `ScreenWidth - 40` | `74` | 单列 |

Section 内边距：`UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)`，行间距 `8`。

### 卡片样式枚举

```swift
// 定义在 assembly/Modules/Interface/EntranceCardStyle.swift
public enum EntranceCardStyle {
    case standard       // 标准模块卡片（白色背景，图标 + 标题 + 描述）
    case uiComponent    // UI 组件卡片（渐变背景，额外显示蓝色"UI组件"标签）
    case banner         // 通栏卡片（带箭头和背景图，蓝色标题 + 渐变）
}
```

## 核心设计：动态注册

### 设计原则

1. **AppAssembly 集中装配**：所有业务模块的创建逻辑集中在 `AppAssembly` Pod 中，通过 `allModuleProviders(target:)` 按 Target 返回不同的模块列表
2. **首页零依赖**：首页不 import 任何业务模块，通过 `ModuleProvider` 协议 + 闭包延迟创建目标 VC，实现完全解耦
3. **环境注入**：壳工程通过 `ModuleEnvironment` 向各模块注入运行时依赖（美颜 License、用户信息获取、UserSig 生成等）
4. **生命周期解耦**：需要 App 生命周期回调的模块，通过 `AppLifecycleRegistry` 动态注册 handler，AppDelegate 只做转发
5. **壳工程按需导入**：Podfile 中按首页实际展示的模块导入对应 Pod

### 模块接入协议

每个业务模块实现 `ModuleProvider` 协议，提供入口配置和可选的动态行为：

```swift
/// 模块配置 — 描述一个首页入口卡片的全部信息
/// 定义在 assembly/Modules/Interface/ModuleConfig.swift
public struct ModuleConfig {
    public let identifier: String             // 唯一标识（用于权限控制、埋点、去重）
    public let title: String                  // 卡片标题
    public let description: String            // 卡片描述文字
    public let iconName: String               // 图标名（xcassets 中的图片名，也支持 http URL）
    public let iconImage: UIImage?            // 预加载的图标图片（优先级高于 iconName，用于跨 Bundle 加载）
    public let cardStyle: EntranceCardStyle   // 卡片样式
    public let gradientColors: [UIColor]      // 渐变背景色（uiComponent/banner 样式使用）
    public let isHot: Bool                    // 是否显示"热门"标签
    public let targetProvider: () -> UIViewController?  // 点击后创建的目标 VC（闭包延迟创建）
    public let analyticsEvent: String         // 埋点事件名
}
```

```swift
/// 模块提供者协议 — 业务模块实现此协议后注册到首页
/// 定义在 assembly/Modules/Interface/ModuleProvider.swift
public protocol ModuleProvider: AnyObject {
    var config: ModuleConfig { get }

    /// 未读数（可选，默认 0）。首页会通过 Combine 订阅此属性的变化
    var badgeCountPublisher: AnyPublisher<UInt64, Never> { get }

    /// 是否显示此模块（可选，默认 true）。用于条件显隐
    var isVisiblePublisher: AnyPublisher<Bool, Never> { get }

    /// 环境注入（可选）。壳工程在 viewDidLoad 中调用，传入运行时依赖
    func setup(with environment: ModuleEnvironment)
}

// 提供默认实现，让纯静态场景无需实现这些方法
public extension ModuleProvider {
    var badgeCountPublisher: AnyPublisher<UInt64, Never> {
        Just(0).eraseToAnyPublisher()
    }
    var isVisiblePublisher: AnyPublisher<Bool, Never> {
        Just(true).eraseToAnyPublisher()
    }
    func setup(with environment: ModuleEnvironment) {}
}
```

```swift
/// 模块运行环境 — 壳工程在启动时统一注入
/// 定义在 assembly/Modules/Interface/ModuleEnvironment.swift
public struct ModuleEnvironment {
    public let beautyLicenseURL: String                    // 美颜 License URL
    public let beautyLicenseKey: String                    // 美颜 License Key
    public let getCurrentUserModel: () -> UserModel?       // 动态获取当前用户
    public let generateUserSig: (_ userId: String) -> String  // UserSig 生成算法
}
```

### AppAssembly — 业务模块装配中心

所有模块的创建逻辑集中在 `AppAssembly`（`assembly/AppAssembly.swift`）中，按 Target 返回不同的模块列表：

```swift
/// assembly/AppAssembly.swift
public final class AppAssembly {
    public static let shared = AppAssembly()

    /// 隐私模块统一动作回调（由壳工程 / main 模块设置）
    public var privacyActionHandler: ((PrivacyAction) -> Void)?

    /// 获取所有场景模块（按首页展示顺序排列）
    public func allModuleProviders(target: AppTarget) -> [ModuleProvider] {
        switch target {
        case .overseas:
            // 海外版：Call→AI→Interpretation→Room→Live→Chat→Beauty→Player→UGSV
            ...
        case .domestic, .lab:
            // 国内版/Lab：Call→Live→Room→Chat→AI→Interpretation→VoiceRoom→Beauty→Player→UGSV→ScenesApplication
            ...
        }
    }

    /// 注册需要 App 生命周期回调的 handler
    public func registerLifecycleHandlers() { ... }
}
```

### 入口类初始化流程

#### EntranceViewController.viewDidLoad()（国内版 / Lab 版）

```
① 创建 ModuleEnvironment（注入美颜 License、用户信息、UserSig 生成）
② 设置 AppAssembly.shared.privacyActionHandler（反诈提醒、实名认证、人脸核身等）
③ 注册 PrivacyEntry TUICore 服务
④ 通过 AppAssembly.shared.allModuleProviders(target:) 获取模块列表
⑤ 遍历 providers：调用 setup(with:) + 注册到 ModuleRegistry
⑥ AppAssembly.shared.registerLifecycleHandlers()
⑦ setupUI()
⑧ store.loadModules()
⑨ bindStoreState()
⑩ ModulePermissionService.shared.loadUserBlackList()
⑪ HuiYanSDK 初始化（仅非海外版）
⑫ viewDidAppear 中触发 performRiskCheckIfNeeded()（高风险用户检查 + 安全提醒弹窗）
```

#### OverseasHomeViewController.viewDidLoad()（海外版）

```
① 注册 ContactUsService TUICore 服务
② 嵌入 OverseasMainViewController 子控制器
③ 构建导航栏 UI
```

#### OverseasMainViewController.viewDidLoad()（海外版内容页）

```
① 创建 ModuleEnvironment
② 设置 AppAssembly.shared.privacyActionHandler
③ 通过 AppAssembly.shared.allModuleProviders(target:) 获取模块列表
④ 遍历 providers：调用 setup(with:) + 注册到 ModuleRegistry
⑤ AppAssembly.shared.registerLifecycleHandlers()
⑥ 构建 UI（双 Tab + ScrollView）
⑦ store.loadModules() + splitModules()（按 identifier 分为 Products / Discovery 两组）
⑧ bindStoreState()
```

### App 生命周期集成：AppLifecycleRegistry

需要 App 生命周期回调的模块（如 iOA SSO、SDK Licence 设置、推送等），通过 `AppLifecycleRegistry` 动态注册，无需在 AppDelegate 中添加任何业务代码：

```swift
/// 壳工程已有的协议（application/RTCube/AppLifecycleRegistry.swift）
public protocol AppLifecycleHandler: AnyObject {
    func handleOpenURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool
    func applicationDidFinishLaunching(_ application: UIApplication)
    func applicationWillEnterForeground(_ application: UIApplication)
    func applicationDidEnterBackground(_ application: UIApplication)
}
// 所有方法都有默认空实现，模块只需实现自己关心的回调
```

### 模块注册中心

```swift
/// main/Shared/ModuleRegistry.swift — 管理所有首页入口模块（单例）
final class ModuleRegistry {
    static let shared = ModuleRegistry()

    /// 已注册的 ModuleProvider 列表（按注册顺序排列）
    private(set) var providers: [ModuleProvider] = []

    /// 注册模块（根据 config.identifier 去重）
    func register(_ provider: ModuleProvider) { ... }

    /// 获取已合并的模块列表，由 EntranceStore 订阅 Publisher 驱动动态更新
    func resolvedModules() -> [ResolvedModule] { ... }

    /// 重置注册中心（测试用）
    func reset() { ... }
}
```

### 多 Target 差异化配置

通过编译宏 + `AppTarget` 枚举控制不同 Target 展示的模块列表：

```swift
// EntranceViewController.viewDidLoad() 中
#if RTCUBE_OVERSEAS
let providers = AppAssembly.shared.allModuleProviders(target: .overseas)
#elseif RTCUBE_LAB
let providers = AppAssembly.shared.allModuleProviders(target: .lab)
#else
let providers = AppAssembly.shared.allModuleProviders(target: .domestic)
#endif
```

`AppAssembly.allModuleProviders(target:)` 内部按 Target 返回不同顺序和组合的模块：

| Target | 模块列表 |
|--------|---------|
| `.domestic` / `.lab` | Call → Live → Room → Chat → AI → Interpretation → VoiceRoom → Beauty → Player → UGSV → ScenesApplication |
| `.overseas` | Call → AI → Interpretation → Room → Live → Chat → Beauty → Player → UGSV |

海外版中 `OverseasMainViewController` 进一步按 `discoveryIdentifiers = ["player", "ugsv"]` 将模块分为 Products / Discovery Lab 两个 Tab。

## 架构分层

```
┌─────────────────────────────────────────────────────────────────┐
│                    壳工程 (application/)                          │
│  AppDelegate → AppLifecycleRegistry（纯转发，零业务代码）          │
│  SceneDelegate → EntranceViewController (国内/Lab)               │
│               → OverseasHomeViewController (海外)                │
└──────────────────────────┬──────────────────────────────────────┘
                           │ import Main / AppAssembly
┌──────────────────────────▼──────────────────────────────────────┐
│                    Main 模块 (main/)                              │
│                                                                  │
│  ┌─ 国内版/Lab ─────────────────────────────────────────────┐    │
│  │ EntranceViewController                                    │    │
│  │   └── viewDidLoad: AppAssembly → setup → register         │    │
│  │   └── collectionView → EntranceCollectionCell             │    │
│  │   └── MainNavigationView / EntranceReportView             │    │
│  │   └── SafetyReminderView / performRiskCheckIfNeeded       │    │
│  └───────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─ 海外版 ─────────────────────────────────────────────────┐    │
│  │ OverseasHomeViewController                                │    │
│  │   └── OverseasNavigationView + ContactUsService           │    │
│  │   └── OverseasMainViewController (子控制器)                │    │
│  │         └── viewDidLoad: AppAssembly → setup → register   │    │
│  │         └── Products Tab → productsCollectionView         │    │
│  │         └── Discovery Tab → discoveryCollectionView       │    │
│  └───────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─ 共享层 ─────────────────────────────────────────────────┐    │
│  │ EntranceStore (@Published state: EntranceState)           │    │
│  │   └── 从 ModuleRegistry 获取模块列表                       │    │
│  │   └── 订阅各 ModuleProvider 的 badge/visibility 变化       │    │
│  │   └── 权限过滤（黑名单检查）                                │    │
│  │ ModuleRegistry (单例，去重 + resolvedModules)              │    │
│  └───────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                AppAssembly Pod (assembly/)                        │
│                                                                  │
│  AppAssembly.swift         ← 装配中心，allModuleProviders()       │
│  Modules/Interface/        ← 协议定义层                           │
│    ├── ModuleProvider.swift                                      │
│    ├── ModuleConfig.swift                                        │
│    ├── ModuleEnvironment.swift                                   │
│    └── EntranceCardStyle.swift                                   │
│  Modules/{Module}/         ← 各业务模块实现                       │
│    ├── Live/LiveModule.swift                                     │
│    ├── Call/CallModule.swift                                     │
│    ├── Room/RoomModule.swift                                     │
│    ├── Chat/ChatModule.swift                                     │
│    ├── AIConversation/Sources/AIConversationModule.swift          │
│    ├── Interpretation/InterpretationModule.swift                  │
│    ├── Beauty/BeautyModule.swift                                 │
│    ├── Player/PlayerModule.swift                                 │
│    ├── UGSV/UGSVModule.swift                                     │
│    ├── VoiceRoom/VoiceRoomModule.swift                           │
│    └── ScenesApplication/ScenesApplicationModule.swift           │
└──────────────────────────────────────────────────────────────────┘
```

## 实际目录结构

```
main/
├── EntranceViewController.swift           ← RTCube / RTCubeLab 入口（国内版首页主控制器）
├── OverseasHomeViewController.swift       ← TencentRTC 入口（海外版首页容器控制器）
├── README.md
│
├── Domestic/                              ← 国内版专属
│   ├── EntranceStore.swift                ← 首页状态管理（@Published state + Combine 订阅）
│   ├── EntranceState.swift                ← 首页 UI 状态定义
│   ├── Service/
│   │   └── ModulePermissionService.swift  ← 模块权限检查（人脸核身 > 高风险用户 > 黑名单）
│   └── Views/
│       ├── EntranceCollectionCell.swift    ← 模块入口卡片 Cell（standard/uiComponent/banner 三种样式）
│       ├── EntranceFooterView.swift        ← 底部试用提示文字
│       ├── EntranceReportView.swift        ← 举报提示横条（中文环境 + 非 MOA 显示）
│       ├── LeftAlignedFlowLayout.swift     ← 左对齐瀑布流布局
│       └── SafetyReminderView.swift        ← 安全提醒弹窗（5 秒倒计时）
│
├── Overseas/                              ← 海外版专属
│   ├── OverseasMainViewController.swift   ← 海外版内容页（双 Tab：Products / Discovery Lab）
│   ├── OverseasNavigationView.swift       ← 海外版导航栏（白色背景、英文 Logo）
│   ├── OverseasCollectionCell.swift       ← 海外版模块卡片 Cell
│   ├── OverseasFooterView.swift           ← 海外版底部场景体验入口
│   ├── ContactUsService.swift             ← TUICore 联系我们服务注册
│   ├── ContactUsButtonView.swift          ← 联系我们按钮视图
│   ├── ContactUsTipsView.swift            ← 联系我们提示视图
│   └── ContactUsConstants.swift           ← 联系我们常量定义
│
├── Shared/                                ← 国内版与海外版共享
│   ├── ModuleRegistry.swift               ← 模块注册中心（单例，去重 + resolvedModules）
│   ├── Model/
│   │   └── ResolvedModule.swift           ← 合并后的最终模块数据（含 weak provider 引用）
│   └── Views/
│       └── MainNavigationView.swift       ← 顶部导航栏（Logo + 头像，根据语言切换 Logo 图片）
│
└── Resource/
    ├── Assets/
    │   └── MainAssets.xcassets/            ← 首页图片资源（Logo、模块图标）
    └── Localized/
        ├── MainLocalized.swift            ← 本地化函数 MainLocalize(_:)
        ├── en.lproj/MainLocalized.strings
        └── zh-Hans.lproj/MainLocalized.strings
```

```
assembly/                                  ← AppAssembly Pod（独立于 main 模块）
├── AppAssembly.swift                      ← 装配中心（allModuleProviders + registerLifecycleHandlers）
└── Modules/
    ├── Interface/                         ← 协议定义层
    │   ├── ModuleProvider.swift
    │   ├── ModuleConfig.swift
    │   ├── ModuleEnvironment.swift
    │   └── EntranceCardStyle.swift
    ├── Live/LiveModule.swift              ← 直播模块
    ├── Call/CallModule.swift              ← 音视频通话模块（含 CallSettings、Guide、Service 等子目录）
    ├── Room/RoomModule.swift              ← 会议模块
    ├── Chat/ChatModule.swift              ← 聊天模块
    ├── AIConversation/Sources/AIConversationModule.swift  ← AI 对话模块
    ├── Interpretation/InterpretationModule.swift          ← 同传模块
    ├── Beauty/BeautyModule.swift          ← 美颜特效模块
    ├── Player/PlayerModule.swift          ← 播放器模块
    ├── UGSV/UGSVModule.swift              ← 短视频模块
    ├── VoiceRoom/VoiceRoomModule.swift    ← 语聊房模块
    ├── ScenesApplication/ScenesApplicationModule.swift    ← 行业场景模块
    └── Resource/                          ← AppAssembly 共享资源（图标、本地化）
```

## Store/State 设计

```swift
/// 首页 UI 状态（Domestic/EntranceState.swift）
struct EntranceState {
    var modules: [ResolvedModule] = []       // 当前展示的模块列表（已过滤权限）
    var isReportViewVisible: Bool = false     // 举报提示栏是否可见
    var userAvatarURL: String = ""           // 用户头像 URL
    var isNeedFaceAuth: Bool = false         // 是否需要人脸核身
}

/// 合并后的模块数据（供 Cell 渲染）（Shared/Model/ResolvedModule.swift）
struct ResolvedModule {
    let config: ModuleConfig                 // 静态配置
    var badgeCount: UInt64 = 0               // 动态未读数（由 badgeCountPublisher 驱动更新）
    var isVisible: Bool = true               // 动态可见性（由 isVisiblePublisher 驱动更新）
    weak var provider: ModuleProvider?       // 弱引用，用于保持 Publisher 订阅关系
}
```

```swift
/// 首页 Store（Domestic/EntranceStore.swift）
final class EntranceStore {
    @Published private(set) var state = EntranceState()

    /// 从 ModuleRegistry 加载模块，订阅动态变化，过滤权限
    func loadModules() { ... }

    /// 处理模块点击
    func selectModule(at index: Int) -> UIViewController? { ... }

    /// 获取指定模块的未读数
    func badgeCount(at index: Int) -> UInt64 { ... }

    /// 更新指定模块的未读数（海外版 IM 未读数使用）
    func updateBadgeCount(for identifier: String, count: UInt64) { ... }
}
```

> **注意**：`EntranceStore` 同时被国内版 `EntranceViewController` 和海外版 `OverseasMainViewController` 使用，虽然文件位于 `Domestic/` 目录下。

## 当前模块状态

所有 11 个业务模块均已完成迁移，实现文件位于 `assembly/Modules/` 下：

| 模块 | identifier | 实现文件 | 国内版 | 海外版 | 说明 |
|------|-----------|---------|--------|--------|------|
| 音视频通话 | `call` | `Call/CallModule.swift` | ✅ | ✅ | 含 CallSettings、Guide、Service 等子模块 |
| 直播 | `live` | `Live/LiveModule.swift` | ✅ | ✅ | 含 AnchorVC、AudienceVC、LiveListVC |
| 会议 | `room` | `Room/RoomModule.swift` | ✅ | ✅ | |
| 聊天 | `chat` | `Chat/ChatModule.swift` | ✅ | ✅ | |
| AI 对话 | `conversational_ai` | `AIConversation/Sources/AIConversationModule.swift` | ✅ | ✅ | 含设置页、服务页等完整 UI |
| 同传 | `simultaneous_interpretation` | `Interpretation/InterpretationModule.swift` | ✅ | ✅ | 含评价、语言选择等完整 UI |
| 语聊房 | `voice_chat` | `VoiceRoom/VoiceRoomModule.swift` | ✅ | ❌ | 仅国内版 |
| 美颜特效 | `beautyar` | `Beauty/BeautyModule.swift` | ✅ | ✅ | |
| 播放器 | `player` | `Player/PlayerModule.swift` | ✅ | ✅ (Discovery) | 海外版归入 Discovery Lab Tab |
| 短视频 | `ugsv` | `UGSV/UGSVModule.swift` | ✅ | ✅ (Discovery) | 海外版归入 Discovery Lab Tab |
| 行业场景 | `scenesApplication` | `ScenesApplication/ScenesApplicationModule.swift` | ✅ | ❌ | 仅国内版，Banner 样式 |

## 安全与权限机制

### 国内版安全流程（EntranceViewController）

`EntranceViewController` 包含完整的安全检查链路：

1. **安全提醒弹窗**（`SafetyReminderView`）：5 秒倒计时，倒计时期间按钮灰色禁用，结束后变蓝色可点击
2. **高风险用户检查**（`performRiskCheckIfNeeded()`）：在 `viewDidAppear` 中触发，每次登录会话执行 1 次
3. **人脸核身**（`showFaceAuthAlert()` + `getFaceAuth()`）：通过 HuiYanSDK 进行人脸核身
4. **隐私动作分发**（`PrivacyAction` 枚举）：通过 `AppAssembly.shared.privacyActionHandler` 统一分发反诈提醒、实名认证等操作

### 模块权限控制

权限通过 `ModulePermissionService`（`Domestic/Service/ModulePermissionService.swift`）统一管理：
- 检查优先级：人脸核身 > 高风险用户 > 黑名单
- banner 类型（行业场景）仅检查高风险，不检查黑名单
- 当前策略：所有模块都展示卡片，点击时通过 `isModuleEnabled()` 拦截
- 业务模块无需关心权限逻辑

### 海外版

海外版（`OverseasHomeViewController` / `OverseasMainViewController`）不包含安全提醒、人脸核身等国内版安全逻辑，通过 `#if !RTCUBE_OVERSEAS` 编译宏排除。

## 对外接口

Main 模块对外暴露以下接口：

```swift
/// EntranceViewController — 国内版 / Lab 版首页主控制器
/// 壳工程直接实例化并设为 rootViewController 即可
/// 内部 viewDidLoad 自动完成模块注册和生命周期注册
let entranceVC = EntranceViewController()

/// OverseasHomeViewController — 海外版首页容器控制器
/// 壳工程直接实例化并设为 rootViewController 即可
/// 内部自动嵌入 OverseasMainViewController 并完成模块注册
let overseasVC = OverseasHomeViewController()

/// ModuleRegistry — 模块注册中心（对外只读）
/// 所有注册逻辑在入口控制器内部完成
/// 外部可通过 ModuleRegistry.shared.providers 查询已注册模块
```

## 模块接入速查

### 新增一个业务模块

1. 在 `assembly/Modules/` 目录创建一个类实现 `ModuleProvider` 协议，定义入口配置
2. 在 `assembly/AppAssembly.swift` 的 `allModuleProviders(target:)` 中添加该模块（按 Target 决定是否包含）
3. 如需运行时依赖（美颜 License、用户信息等），在 `setup(with:)` 中读取 `ModuleEnvironment`
4. 在 `main/Resource/` 中添加对应的图标资源和国际化字符串
5. 完成 ✅

### 新增一个需要 App 生命周期的模块

1. 在模块内部创建一个类实现 `AppLifecycleHandler` 协议
2. 在 `ModuleProvider` 的 `init()` 中调用 `AppLifecycleRegistry.shared.register(handler)`
3. 或在 `AppAssembly.registerLifecycleHandlers()` 中统一注册
4. 完成 ✅（AppDelegate 无需任何改动）

## 与旧版对比

| 维度 | 旧版 | 新版 |
|------|------|------|
| 模块接入方式 | 修改 `EntranceViewController.configData()` 硬编码 | 实现 `ModuleProvider` 协议，在 `AppAssembly` 中注册 |
| 首页对业务模块的依赖 | `import` 所有业务模块（14 个 import） | 零依赖（通过协议 + 闭包延迟创建 VC） |
| 模块装配 | `EntranceViewController+Module.swift` 手动注册 | `AppAssembly.shared.allModuleProviders(target:)` 统一获取 |
| 环境注入 | 各模块自行获取全局变量 | `ModuleEnvironment` 统一注入 |
| App 生命周期 | 全部硬编码在 AppDelegate 中 | 各模块通过 `AppLifecycleRegistry` 动态注册 |
| 点击跳转 | 每个模块一个 `goto{Module}()` 方法 | 统一通过 `config.targetProvider()` |
| 权限检查 | 散落在各 `goto` 方法中 | 集中在 `ModulePermissionService` |
| 未读数更新 | 手动回调刷新 | Combine 响应式订阅（`@Published` + `$state`） |
| 多 Target 差异 | `#if` 散落在 `configData()` 各处 | `AppTarget` 枚举 + `AppAssembly` 按 Target 返回不同列表 |
| 海外版 | 独立的 `HomeViewController` 硬编码 | `OverseasHomeViewController` + `OverseasMainViewController` 复用 Store/Registry |
| 安全机制 | 散落在 viewDidLoad 各处 | 集中在 `performRiskCheckIfNeeded()` + `PrivacyAction` 枚举 |

## 依赖关系

| 依赖 | 用途 |
|------|------|
| `AppAssembly` | 业务模块装配层（ModuleProvider、ModuleConfig、ModuleEnvironment 等协议定义 + 各模块实现） |
| `Login` | LoginEntry / LoginManager / UserModel |
| `TUICore` | TUI 基础框架、`TUIGlobalization` 语言判断、TUICore 服务注册 |
| `SnapKit` | Auto Layout 布局 |
| `Kingfisher` | 头像图片加载 |
| `Toast-Swift` | Toast 提示 |
| `Combine` | 响应式订阅（系统原生） |
| `AppAnalytics`（壳工程门面） | 埋点调用统一走 `application/RTCube/Analytics/AppAnalytics.swift`；main 模块不再直接依赖神策 SDK |
| `ImSDK_Plus` | IM 未读消息监听（海外版） |
| `HuiYanPublicSDK` | 人脸核身（仅国内版，`#if !RTCUBE_OVERSEAS`） |
| `RTCExperienceRoom` | 体验房入口（国内版个人中心） |

---

## 迁移方案与计划

### 一、迁移总览

将旧版 `iOS/App/RT-Cube/` 的首页架构迁移到 `v2/ios/main/` 新架构，核心变化：

| 变化项 | 旧版 | 新版 |
|--------|------|------|
| 首页入口 | `EntranceViewController` 硬编码 11 个模块 + 14 个 import | `AppAssembly.shared.allModuleProviders(target:)` 动态获取 |
| 海外版入口 | `HomeViewController` 硬编码 | `OverseasHomeViewController` + `OverseasMainViewController` 复用 Store/Registry |
| App 生命周期 | `AppDelegate` 硬编码 600+ 行 | `AppDelegate` 仅转发 → `AppLifecycleRegistry` → 各模块自行注册 handler |
| 模块跳转 | 每模块一个 `goto{Module}()` 方法（10 个方法） | 统一 `config.targetProvider()` |
| 模块装配 | `EntranceViewController+Module.swift` 手动注册 | `AppAssembly` Pod 集中装配 |

### 二、分阶段迁移计划

#### 阶段 1：基础框架搭建 ✅ 已完成

| 任务 | 状态 | 说明 |
|------|------|------|
| `AppLifecycleRegistry` | ✅ | 已在壳工程实现 |
| `AppDelegate` 转发 | ✅ | 已精简为纯转发层，零业务代码 |
| `AppLifecycleHandler` 协议 | ✅ | 已定义，所有方法有默认空实现 |
| Login 模块（`IOAAuthManager`） | ✅ | 已实现 `AppLifecycleHandler`，自行注册到 Registry |

#### 阶段 2：Main 模块核心实现 ✅ 已完成

| 任务 | 状态 | 涉及文件 |
|------|------|----------|
| 实现 `ModuleConfig` | ✅ | `assembly/Modules/Interface/ModuleConfig.swift` |
| 实现 `ModuleProvider` 协议 | ✅ | `assembly/Modules/Interface/ModuleProvider.swift` |
| 实现 `ModuleEnvironment` | ✅ | `assembly/Modules/Interface/ModuleEnvironment.swift` |
| 实现 `EntranceCardStyle` | ✅ | `assembly/Modules/Interface/EntranceCardStyle.swift` |
| 实现 `ModuleRegistry` | ✅ | `main/Shared/ModuleRegistry.swift` |
| 实现 `EntranceStore` / `EntranceState` | ✅ | `main/Domestic/EntranceStore.swift`、`main/Domestic/EntranceState.swift` |
| 实现 `ResolvedModule` | ✅ | `main/Shared/Model/ResolvedModule.swift` |
| 实现 `ModulePermissionService` | ✅ | `main/Domestic/Service/ModulePermissionService.swift` |

#### 阶段 3：UI 视图迁移 ✅ 已完成

| 任务 | 状态 | 目标文件 |
|------|------|----------|
| `EntranceViewController` | ✅ | `main/EntranceViewController.swift` |
| `OverseasHomeViewController` | ✅ | `main/OverseasHomeViewController.swift` |
| `OverseasMainViewController` | ✅ | `main/Overseas/OverseasMainViewController.swift` |
| `MainNavigationView` | ✅ | `main/Shared/Views/MainNavigationView.swift` |
| `OverseasNavigationView` | ✅ | `main/Overseas/OverseasNavigationView.swift` |
| `EntranceCollectionCell` | ✅ | `main/Domestic/Views/EntranceCollectionCell.swift` |
| `OverseasCollectionCell` | ✅ | `main/Overseas/OverseasCollectionCell.swift` |
| `EntranceFooterView` | ✅ | `main/Domestic/Views/EntranceFooterView.swift` |
| `OverseasFooterView` | ✅ | `main/Overseas/OverseasFooterView.swift` |
| `EntranceReportView` | ✅ | `main/Domestic/Views/EntranceReportView.swift` |
| `LeftAlignedFlowLayout` | ✅ | `main/Domestic/Views/LeftAlignedFlowLayout.swift` |
| `SafetyReminderView` | ✅ | `main/Domestic/Views/SafetyReminderView.swift` |
| `ContactUsService` 等 | ✅ | `main/Overseas/ContactUs*.swift` |
| 本地化资源 | ✅ | `main/Resource/Localized/` |
| `AppAssembly` Pod | ✅ | `assembly/AppAssembly.swift` |

#### 阶段 4：业务模块迁移到 AppAssembly ✅ 已完成

所有 11 个业务模块已迁移到 `assembly/Modules/` 下：

| 序号 | 模块 | 实现文件 | 状态 |
|------|------|---------|------|
| 1 | 直播 | `Live/LiveModule.swift` | ✅ |
| 2 | 音视频通话 | `Call/CallModule.swift` | ✅ |
| 3 | 会议 | `Room/RoomModule.swift` | ✅ |
| 4 | 聊天 | `Chat/ChatModule.swift` | ✅ |
| 5 | AI 对话 | `AIConversation/Sources/AIConversationModule.swift` | ✅ |
| 6 | 同传 | `Interpretation/InterpretationModule.swift` | ✅ |
| 7 | 美颜特效 | `Beauty/BeautyModule.swift` | ✅ |
| 8 | 播放器 | `Player/PlayerModule.swift` | ✅ |
| 9 | 短视频 | `UGSV/UGSVModule.swift` | ✅ |
| 10 | 语聊房 | `VoiceRoom/VoiceRoomModule.swift` | ✅ |
| 11 | 行业场景 | `ScenesApplication/ScenesApplicationModule.swift` | ✅ |

#### 阶段 5：全局生命周期迁移 🚧 进行中

将旧版 AppDelegate 中的全局初始化逻辑拆分为独立的 `AppLifecycleHandler`：

| 旧版 AppDelegate 逻辑 | 迁移到 | 状态 |
|------------------------|--------|------|
| ITLogin SDK 初始化 + SSO | `IOAAuthManager` (login 模块内) | ✅ |
| V2TXLivePremier / TXLiteAVSDK Licence | `LicenceLifecycleHandler` | 🔲 |
| 远程推送注册 + APNS Token | `PushNotificationHandler` | 🔲 |
| V2TIM 会话监听 + APNS 配置 | `IMLifecycleHandler` | 🔲 |
| 推送通知清理 (willEnterForeground) | `NotificationLifecycleHandler` | 🔲 |
| Bugly 崩溃上报 | `BuglyLifecycleHandler` | 🔲 |
| 神策 SDK 初始化 + URL Scheme | `SensorsLifecycleHandler` | 🔲 |
| TUICallKit 配置（悬浮窗、虚拟背景等） | `CallModuleProvider.init()` 内部 | 🔲 |
| 网络监控 (NWPathMonitor) | `NetworkMonitorHandler` | 🔲 |

#### 阶段 6：Podfile 重构

```
旧版 Podfile:
  shared_pods → 所有依赖混在一起

新版 Podfile:
  third_party_pods   → 三方开源库（Alamofire、SnapKit、Kingfisher...）
  local_pods         → 内部基础模块（TUICore、RTCCommon、TUILiveKit...）
  AppAssembly Pod    → 业务模块装配层（含所有模块实现）
```

#### 阶段 7：验证与收尾

| 任务 | 说明 |
|------|------|
| 功能验证 | 逐个模块验证点击跳转、权限控制、埋点上报 |
| 生命周期验证 | 验证 ITLogin SSO 回调、Licence 设置、推送注册等 |
| 内存验证 | 确认 AppLifecycleRegistry 弱引用正常，无内存泄漏 |
| 多 Target 验证 | RTCube / TencentRTC / RTCubeLab 三个 Target 分别编译和运行 |
| 清理旧代码 | 确认新版完全可用后，删除旧版硬编码逻辑 |

### 三、迁移优先级

```
阶段 1（✅ 已完成）
  │
  ▼
阶段 2 → 阶段 3（✅ 已完成）  ← Main 模块核心 + UI 迁移
  │
  ▼
阶段 4（✅ 已完成）            ← 所有 11 个业务模块已迁移到 AppAssembly
  │
  ▼
阶段 5（🚧 进行中）           ← 全局生命周期迁移
  │
  ▼
阶段 6                  ← Podfile 重构
  │
  ▼
阶段 7                  ← 验证与收尾
```

### 四、风险点与注意事项

1. **TUICallKit 全局配置**：旧版在 TUILogin 成功后启用悬浮窗、虚拟背景、AI 转写等，需要在 `CallModule` 中通过监听登录成功通知来触发
2. **HuiYanSDK 人脸核身**：已在 `EntranceViewController` 中实现，通过 `#if !RTCUBE_OVERSEAS` 编译宏排除海外版
3. **PrivacyAction 回调时序**：必须在 `privacyActionHandler` 赋值之后、模块加载之前注册 `PrivacyEntry` 服务，确保 TUICallKit 等组件调用时回调已就绪
4. **海外版 IM 未读数**：`OverseasHomeViewController` 通过 `V2TIMConversationListener` 监听未读数变化，传递给 `OverseasMainViewController.updateUnreadCount()`
5. **弱引用清理时机**：`AppLifecycleRegistry` 使用弱引用持有 handler，注册的 handler 需确保生命周期足够长
6. **RTCubeLab 模式**：Lab 版通过 `#if RTCUBE_LAB` 编译宏跳过所有安全提示弹窗、不注册 `privacyActionHandler`、不显示举报入口，确保开源发布时可与 `privacy/` 模块一同物理剔除；模块列表与国内版一致
