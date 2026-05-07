# 模块概览

## 模块简介

AppAssembly 是 iOS 端的**业务模块装配层**，作为 CocoaPods 独立 Pod 存在。它的核心职责是将所有业务场景模块（Call、Live、Room、Chat 等）统一创建、配置并注册，对外仅暴露 `AppAssembly.shared.allModuleProviders(target:)` 一个入口，首页通过此方法获取完整的模块列表进行渲染。

## 核心概念

### ModuleProvider 协议

每个业务模块实现 `ModuleProvider` 协议后注册到首页：

```swift
public protocol ModuleProvider: AnyObject {
    /// 入口配置（标题、图标、卡片样式、点击跳转等）
    var config: ModuleConfig { get }
    /// 未读数（可选，默认 0），首页通过 Combine 订阅变化
    var badgeCountPublisher: AnyPublisher<UInt64, Never> { get }
    /// 是否显示此模块（可选，默认 true），用于条件显隐
    var isVisiblePublisher: AnyPublisher<Bool, Never> { get }
    /// 注入运行环境（美颜 License、用户信息获取等）
    func setup(with environment: ModuleEnvironment)
}
```

### ModuleConfig

描述一个首页入口卡片的全部信息：`identifier`（唯一标识）、`title`、`description`、`iconName`/`iconImage`、`cardStyle`（standard / uiComponent / banner）、`gradientColors`、`isHot`、`targetProvider`（延迟创建目标 VC）、`analyticsEvent`。

### ModuleEnvironment

壳工程在启动时统一注入的运行环境参数，包括美颜 License URL/Key、当前用户获取闭包、UserSig 生成闭包等。

### AppTarget

App 构建目标枚举，对应 3 个 Xcode target：

| 枚举值 | 对应 Target | 说明 |
|--------|------------|------|
| `.domestic` | RTCube | 国内版 |
| `.overseas` | TencentRTC | 海外版 |
| `.lab` | RTCubeLab | 开发测试版 |

### PrivacyAction

隐私模块动作枚举，将反诈提醒、屏幕共享反诈、实名认证、人脸核身、体验时长提示等操作统一为枚举，由 main 模块通过 `privacyActionHandler` 闭包进行分发。

## 对外接口

```swift
// 获取所有场景模块（按首页展示顺序排列）
let providers = AppAssembly.shared.allModuleProviders(target: .domestic)

// 注入隐私动作处理回调
AppAssembly.shared.privacyActionHandler = { action in
    switch action {
    case .showAntifraudReminder: ...
    case .showScreenShareAntifraud(let completion): ...
    case .checkRealNameAuth(let userId, let token, let completion): ...
    case .showFaceIdTokenVerify(let userId, let token, let completion): ...
    case .showLiveTimeLimitAlert: ...
    case .showLiveRemainingOneMinToast: ...
    }
}

// 注册生命周期 handler（阶段 5 完成后启用）
AppAssembly.shared.registerLifecycleHandlers()
```

### 通话态门禁（Call Status Guard）

通过 `AppAssembly` 扩展（实现文件：`AppAssembly+CallGuard.swift`）对 `CallStore.shared.state.value.selfInfo.status` 进行同步查询，
用于在 Live / VoiceRoom / Room 的"开播 / 创建房间"入口阻止并发开启：

| 成员 | 可见性 | 说明 |
|------|--------|------|
| `canStartNewRoom: Bool` | `internal` | `selfInfo.status == .none` → `true`，其它状态（呼出、响铃、接通等）→ `false` |
| `showCannotStartRoomToast()` | `internal` | 在 keyWindow 弹出本地化 Toast "当前正在通话中，请结束后再试"（对应 `Demo.TRTC.Common.cannotStartRoomDuringCall`） |

设计取舍：
- **独立扩展文件承载**——该能力依赖 `AtomicXCore`（CallStore）与 `Toast-Swift`，与装配中心主职责无关；放在 `AppAssembly+CallGuard.swift` 可保持 `AppAssembly.swift` 的 import 清单纯粹，未来移除门禁亦只需删本文件。
- **不订阅 status 变更**——本需求仅在用户点击"创建"按钮时判断一次，`CallStore.state.value` 已提供同步快照，订阅反而引入状态缓存与线程同步复杂度。
- **internal 而非 public**——三个拦截点（`LiveListViewController`、`VoiceRoomViewController`、`RoomModule`）与 `AppAssembly` 同属 AppAssembly Pod module，无需对外暴露。
- **Toast 辅助方法与计算属性同文件**——避免 keyWindow 查找 + `makeToast` 在三处重复。

拦截点分布：

| 模块 | 拦截位置 | 粒度 |
|------|---------|------|
| Live | `LiveListViewController.createRoom()` | 按钮级——列表仍可浏览，仅禁用"创建直播" |
| VoiceRoom | `VoiceRoomViewController.createRoom()` | 按钮级——列表仍可浏览，仅禁用"创建语聊房" |
| Room | `RoomModule.standard.config.targetProvider` | 入口级——会议创建按钮在 `TUIRoomKit` SDK 内部无法精确拦截，故在卡片点击时整体拦截并返回 `nil` |

## 目录结构

```
assembly/
├── AppAssembly.podspec                        ← Pod 配置（OpenSource / Full 两个 subspec，详见下文）
├── AppAssembly.swift                          ← 装配中心入口（AppAssembly 单例、AppTarget、PrivacyAction）
├── AppAssembly+CallGuard.swift                ← 通话态门禁扩展（canStartNewRoom / showCannotStartRoomToast，依赖 AtomicXCore + Toast-Swift）
├── README.md
│
├── Extension/                                 ← 公共 UI 扩展
│   ├── LayoutDefine.swift                     ← 布局常量与工具函数（屏幕尺寸、安全区、像素转换）
│   ├── UIColor+Extension.swift                ← UIColor 十六进制创建、颜色转图片
│   └── UIView+Extension.swift                 ← 手势、圆角、渐变等 UIView 扩展
│
└── Modules/                                   ← 业务场景模块
    ├── Interface/                             ← 模块接口定义
    │   ├── ModuleProvider.swift               ← 模块提供者协议
    │   ├── ModuleConfig.swift                 ← 模块配置数据模型
    │   ├── ModuleEnvironment.swift            ← 模块运行环境参数
    │   └── EntranceCardStyle.swift            ← 卡片样式枚举（standard / uiComponent / banner）
    │
    ├── AtomicXCoreLogin.swift                 ← AtomicXCore 自动登录桥接（监听 LoginEntry 用户变化）
    │
    ├── Resource/                              ← 公共资源
    │   ├── AppAssemblyBundle.swift            ← Resource Bundle 加载工具（图片、本地化、JSON）
    │   ├── AppAssemblyAssets.xcassets/         ← 图片资源（入口图标、通话/直播相关图标等）
    │   └── Localized/                         ← 国际化字符串
    │       ├── AssemblyLocalized.swift         ← 本地化便捷函数
    │       ├── en.lproj/                      ← 英文
    │       └── zh-Hans.lproj/                 ← 中文
    │
    ├── Call/                                  ← 通话模块（TUICallKit）
    │   ├── CallModule.swift                   ← ModuleProvider 实现 + 工厂方法
    │   ├── CallSettings/                      ← 通话设置页面
    │   ├── CustomViews/                       ← 自定义 UI 组件（下拉菜单、单选按钮等）
    │   ├── Guide/                             ← 通话引导页
    │   ├── Model/                             ← 数据模型（菜单、机器人等）
    │   ├── Resource/                          ← 通话模块本地化资源
    │   ├── Service/                           ← 服务层（反诈处理、生命周期、机器人 HTTP 请求）
    │   └── UI/                                ← 页面（入口菜单、联系人选择、群组通话等）
    │
    ├── Live/                                  ← 直播模块（TUILiveKit）
    │   ├── LiveModule.swift                   ← ModuleProvider 实现 + 美颜 License 初始化
    │   ├── LiveListViewController.swift       ← 直播列表页
    │   ├── AnchorPrepareViewController.swift  ← 主播开播准备页
    │   ├── AnchorViewController.swift         ← 主播直播页
    │   └── AudienceViewController.swift       ← 观众观看页
    │
    ├── Room/                                  ← 多人音视频房间模块（TUIRoomKit）
    │   └── RoomModule.swift
    │
    ├── Chat/                                  ← 即时通讯模块（TIMAppKit）
    │   └── ChatModule.swift
    │
    ├── AIConversation/                        ← AI 对话模块（AIConversationKit）
    │   ├── Sources/                           ← 源码（入口页、设置页、请求管理、服务层等）
    │   └── Resource/                          ← 资源（图片、JSON 配置、本地化）
    │
    ├── Interpretation/                        ← 同声传译模块
    │   ├── InterpretationModule.swift
    │   ├── Sources/                           ← 源码（VC、请求管理、状态管理、视图等）
    │   └── Resource/                          ← 本地化资源
    │
    ├── VoiceRoom/                             ← 语音聊天室模块
    │   ├── VoiceRoomModule.swift
    │   └── VoiceRoomViewController.swift
    │
    ├── Beauty/                                ← 美颜特效模块（TencentEffect）
    │   └── BeautyModule.swift
    │
    ├── Player/                                ← 播放器模块（VodPlay）
    │   └── PlayerModule.swift
    │
    ├── UGSV/                                  ← 短视频制作模块（XiaoShiPinApp）
    │   └── UGSVModule.swift
    │
    └── ScenesApplication/                     ← 场景化应用模块（仅国内版/Lab 版）
        └── ScenesApplicationModule.swift
```

## 模块注册顺序

`allModuleProviders(target:)` 按首页展示顺序返回模块列表，不同 target 顺序不同：

**国内版 / Lab 版**：Call → Live → Room → Chat → AIConversation → Interpretation → VoiceRoom → Beauty → Player → UGSV → ScenesApplication

**海外版**：Call → AIConversation → Interpretation → Room → Live → Chat → Beauty → Player → UGSV

## 依赖关系

AppAssembly 通过两个 subspec 区分"开源发布"与"内部完整"两种形态。**公共依赖统一声明在 podspec 根节点**，`OpenSource` / `Full` subspec 仅各自声明专属的源码、资源与追加依赖。

### 公共依赖（根 spec 声明，两个 subspec 都会继承）

| 依赖 | 用途 |
|------|------|
| `TUICore` | 腾讯 IM SDK 核心（本地化语言获取等） |
| `RTCCommon` | 项目公共库 |
| `Alamofire` | 网络请求 |
| `SnapKit` | Auto Layout 布局 |
| `Login` | 登录模块（用户信息、AtomicXCore 自动登录） |
| `AtomicX` | 内部核心库（Design Token） |
| `AtomicXCore` | 内部核心库（登录桥接） |
| `TUICallKit_Swift` | 通话 SDK（Call） |
| `JXSegmentedView` | 分段选择器（Call） |
| `JXPagingView` | 分页容器（Call） |
| `Toast-Swift` | Toast 提示（Call） |
| `TUILiveKit` | 直播 SDK（Live / VoiceRoom） |
| `TUIRoomKit` | 多人音视频房间 SDK（Room / Interpretation） |

### OpenSource subspec（默认）

用于开源发布版，仅包含对外可公开的模块：Call / Live / VoiceRoom / Room / Interpretation / ScenesApplication。**不追加任何依赖**（全部由根 spec 提供）。

使用方式（开源 Podfile）：
```ruby
pod 'AppAssembly', :path => '../assembly/AppAssembly.podspec'
```

### Full subspec（内部版）

用于内部完整版。**采用全量 glob 声明源码与资源**（`Modules/**/*` / `Extension/**/*`），与本次改造前的 podspec 行为完全一致——未来新增内部模块无需修改 podspec。

Full 与 OpenSource 为 **互斥形态**（Full **不** 依赖 `AppAssembly/OpenSource`），避免两个 subspec 声明相同文件导致重复编译 / 重复符号。

除继承根 spec 的公共依赖外，Full 额外声明内部模块专属的外部 Pod：

| 追加依赖 | 用途 |
|------|------|
| `TIMAppKit` | IM 应用层 SDK（Chat） |
| `AIConversationKit` | AI 对话 SDK（AIConversation） |
| `TencentEffect` | 美颜特效 SDK（Beauty） |
| `VodPlay` | 播放器 SDK（Player） |
| `XiaoShiPinApp` | 短视频制作 SDK（UGSV） |

使用方式（内部 Podfile）：
```ruby
pod 'AppAssembly', :path => '../assembly/AppAssembly.podspec', :subspecs => ['Full']
```

### 资源 Bundle

两个 subspec 的 `resource_bundles` 同名为 `AppAssemblyBundle`，业务代码通过 `AppAssemblyBundle` 工具类统一加载，无需感知形态差异。

### 条件编译

`AppAssembly.swift` 的 `allModuleProviders(target:)` 中对 Full-only 模块（`ChatModule` / `AIConversationModule` / `BeautyModule` / `PlayerModule` / `UGSVModule`）的引用通过 `#if APPASSEMBLY_FULL` 条件编译。该宏由 Full subspec 自身在 `pod_target_xcconfig` 中通过 `SWIFT_ACTIVE_COMPILATION_CONDITIONS` 注入，壳工程与开源工程均**无需**任何手工配置——选用哪个 subspec，宏就自动随之生效或缺失。

## 架构要点

1. **装配中心模式** — `AppAssembly` 单例集中管理所有业务模块的创建与注册，首页仅需调用 `allModuleProviders()` 即可获得完整模块列表，无需感知各模块的具体实现。
2. **协议驱动** — 所有业务模块实现 `ModuleProvider` 协议，通过 `ModuleConfig` 描述入口信息，通过 Combine Publisher 提供动态数据（未读数、显隐状态）。
3. **延迟创建** — `ModuleConfig.targetProvider` 使用闭包延迟创建目标 VC，避免提前 import 和初始化业务模块，降低启动开销。
4. **环境注入** — 壳工程通过 `ModuleEnvironment` 统一注入运行时依赖（美颜 License、用户信息等），业务模块通过 `setup(with:)` 接收，解耦壳工程与业务模块。
5. **隐私动作统一分发** — 反诈提醒、实名认证等隐私相关操作通过 `PrivacyAction` 枚举 + `privacyActionHandler` 闭包统一分发，业务模块无需直接依赖隐私 UI 组件。
6. **AtomicXCore 自动登录** — `AtomicXCoreLogin` 通过 Combine 监听 `LoginEntry.shared.$userModel` 变化，自动完成 AtomicXCore 的登录/登出同步。
7. **Resource Bundle 隔离** — 通过 CocoaPods `resource_bundles` 将图片、本地化字符串、JSON 等资源打包到独立的 `AppAssemblyBundle.bundle`，`AppAssemblyBundle` 工具类提供统一的资源加载接口。
