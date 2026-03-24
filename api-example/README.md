# AtomicXCore API 示例 Demo — iOS

[English](./README_EN.md) | 中文

## 项目简介

本项目是 **AtomicXCore SDK** 的 iOS 端 API 示例 Demo，通过四个渐进式阶段完整展示了从基础推拉流到复杂互动直播的全部核心功能。项目采用 Swift 语言开发，使用 UIKit 纯代码布局（SnapKit）+ Combine 响应式状态管理，适合开发人员快速了解和集成 AtomicXCore SDK。

## 功能概览

| 阶段 | 功能模块 | 说明 |
|:---:|:---|:---|
| 1 | **BasicStreaming** 基础推拉流 | 直播创建/加入、摄像头/麦克风管理、视频渲染 |
| 2 | **Interactive** 实时互动 | 弹幕消息、礼物系统（含 SVGA 动画）、点赞、美颜、音效 |
| 3 | **MultiConnect** 观众连线 | 观众申请上麦、主播邀请连线、麦位管理、多人视频 |
| 4 | **LivePK** 直播 PK 对战 | 跨房连线、PK 对战、实时积分、战斗结果展示 |

> 四个阶段层层递进，每个后续阶段都包含前一阶段的全部功能并增加新能力。

## 技术栈

| 类别 | 技术 | 版本 |
|:---:|:---|:---|
| 语言 | Swift | 5.0 |
| UI 框架 | UIKit（纯代码布局） | — |
| 布局引擎 | SnapKit | ~> 5.6 |
| 状态管理 | Combine | 系统内置 |
| 核心 SDK | AtomicXCore | 4.0.3 |
| RTAV SDK | TXLiteAVSDK_Professional（传递依赖） | 13.1.20476 |
| IM SDK | TXIMSDK_Plus_iOS_XCFramework（传递依赖） | 8.9.7511 |
| 图片加载 | Kingfisher | ~> 8.0 |
| 动画引擎 | SVGAPlayer | 2.5.7 |
| Toast 提示 | Toast-Swift | ~> 5.1.1 |
| 下拉刷新 | MJRefresh | ~> 3.7 |
| 项目生成 | XcodeGen | — |
| 依赖管理 | CocoaPods | — |
| 最低部署版本 | iOS 16.0 | — |

## 项目架构

### 架构模式

项目采用 **MVC + Store** 模式：

- **Store 模式**：AtomicXCore SDK 通过各种 Store 对象（如 `LoginStore.shared`、`DeviceStore.shared`、`BarrageStore.create(liveID:)` 等）暴露状态（Combine Publisher）和操作方法
- **ViewController 层**：直接与 Store 交互，通过 Combine 的 `.sink` 订阅状态变化并在主线程更新 UI
- **组件化复用**：`Components/` 目录下的可复用 UI 组件被多个 ViewController 共享
- **事件分发**：Store 的 `xxxEventPublisher` 以 Combine Publisher 形式分发事件通知

### Store 类型与生命周期

| 类型 | 创建方式 | 说明 | 示例 |
|:---:|:---|:---|:---|
| 全局单例 | `.shared` | 全应用共享，生命周期与 App 一致 | `LoginStore.shared`、`DeviceStore.shared`、`BaseBeautyStore.shared`、`AudioEffectStore.shared` |
| 按房间创建 | `.create(liveID:)` | 每个直播间独立实例，进房创建、离房销毁 | `BarrageStore.create(liveID:)`、`GiftStore.create(liveID:)`、`CoGuestStore.create(liveID:)` |

### 目录结构

```
ios/
├── App/                              # 应用入口
│   ├── AppDelegate.swift             # @main 入口，全局 Toast 配置
│   └── SceneDelegate.swift           # 窗口创建，设置根视图控制器
├── Scenes/                           # 业务场景页面（ViewController 层）
│   ├── Login/
│   │   ├── LoginViewController.swift           # 用户登录页
│   │   └── ProfileSetupViewController.swift    # 资料完善页（昵称 + 头像）
│   ├── FeatureList/
│   │   └── FeatureListViewController.swift     # 功能列表首页（4 个功能卡片）
│   ├── BasicStreaming/
│   │   └── BasicStreamingViewController.swift  # 阶段 1: 基础推拉流
│   ├── Interactive/
│   │   └── InteractiveViewController.swift     # 阶段 2: 实时互动
│   ├── MultiConnect/
│   │   └── MultiConnectViewController.swift    # 阶段 3: 观众连线
│   └── LivePK/
│       └── LivePKViewController.swift          # 阶段 4: 直播 PK 对战
├── Components/                       # 可复用 UI 组件
│   ├── AudioEffectSettingView.swift   # 音效设置面板（变声/混响/耳返）
│   ├── BarrageView.swift             # 弹幕消息列表 + 输入框
│   ├── BeautySettingView.swift       # 美颜设置面板（磨皮/美白/红润）
│   ├── CoHostUserListView.swift      # 跨房连线主播列表
│   ├── DeviceSettingView.swift       # 设备管理面板（摄像头/麦克风/镜像/清晰度）
│   ├── GiftAnimationView.swift       # 礼物动画展示（SVGA 全屏 + 弹幕滑动）
│   ├── GiftPanelView.swift           # 礼物选择面板（分页网格 + 发送）
│   ├── LikeButton.swift              # 点赞按钮（爱心粒子动效）
│   ├── LocalizedManager.swift        # 本地化管理器（中英文切换）
│   ├── Role.swift                    # 角色枚举（anchor/audience）
│   └── SettingPanelController.swift  # 通用半屏设置面板容器
├── Debug/
│   └── GenerateTestUserSig.swift     # 调试用 UserSig 本地生成工具
├── Resources/
│   ├── Info.plist                    # 应用配置与权限声明
│   ├── LaunchScreen.storyboard       # 启动画面
│   ├── Assets.xcassets/              # 图标和图片资源
│   ├── zh-Hans.lproj/Localizable.strings  # 中文本地化（232 个 key）
│   └── en.lproj/Localizable.strings       # 英文本地化（232 个 key）
├── Podfile                           # CocoaPods 依赖配置
├── Podfile.lock                      # 依赖版本锁定
└── project.yml                       # XcodeGen 项目配置
```

### 应用流程

```
LaunchScreen.storyboard (启动画面)
  │
  ▼
SceneDelegate → LoginViewController (输入 UserID → SDK 登录)
  │
  ├─ 昵称为空 ──→ ProfileSetupViewController (设置昵称 + 头像)
  │                    │
  │                    ▼
  └─ 昵称已设置 ──→ FeatureListViewController (4 个功能卡片)
                       │
                       ├─ 选择角色（主播 / 观众）+ 房间 ID
                       │
                       ├──→ BasicStreamingViewController  (阶段 1)
                       ├──→ InteractiveViewController     (阶段 2)
                       ├──→ MultiConnectViewController    (阶段 3)
                       └──→ LivePKViewController          (阶段 4)
```

导航说明：
- 使用 `UINavigationController` 管理页面栈
- 登录成功后使用 `setViewControllers` 替换整个导航栈（不可回退到登录页）
- 所有直播场景页面禁用手势返回（`interactivePopGestureRecognizer?.isEnabled = false`）
- 角色选择通过 `UIAlertController` ActionSheet 实现
- 观众输入房间号通过 `UIAlertController` 带 TextField 实现

## AtomicXCore SDK API 使用说明

### 阶段 1：BasicStreaming — 基础推拉流

| Store | 关键 API | 功能 |
|:---|:---|:---|
| `LoginStore` | `login()`, `setSelfInfo()`, `state.loginState` | 用户登录与状态管理 |
| `LiveListStore` | `createLive()`, `joinLive()`, `endLive()`, `leaveLive()` | 直播房间生命周期管理 |
| `DeviceStore` | `openLocalCamera()`, `openLocalMicrophone()`, `switchCamera()` | 本地设备控制 |
| `LiveCoreView` | `pushView` / `playView` 模式 | 视频渲染组件 |

### 阶段 2：Interactive — 实时互动

| Store | 关键 API | 功能 |
|:---|:---|:---|
| `BarrageStore` | `sendTextMessage()`, `state.messageList` | 弹幕消息收发 |
| `GiftStore` | `sendGift()`, `refreshUsableGifts()`, `giftEventPublisher` | 礼物系统 |
| `LikeStore` | `sendLike()`, `likeEventPublisher` | 点赞互动 |
| `BaseBeautyStore` | `setSmoothLevel()`, `setWhitenessLevel()`, `setRuddyLevel()` | 美颜调节 |
| `AudioEffectStore` | `setAudioChangerType()`, `setAudioReverbType()`, `enableInEarMonitoring()` | 音效控制 |

### 阶段 3：MultiConnect — 观众连线

| Store | 关键 API | 功能 |
|:---|:---|:---|
| `CoGuestStore` | `applyForSeat()`, `inviteToSeat()`, `acceptApplication()` | 连线请求管理 |
| `LiveSeatStore` | `openRemoteCamera()`, `openRemoteMicrophone()`, `kickUserOutOfSeat()` | 麦位与远端设备管理 |
| `LiveAudienceStore` | `fetchAudienceList()` | 观众列表 |
| `VideoViewDelegate` | `createCoGuestView(userInfo:)` | 连线用户视频覆盖层代理 |

### 阶段 4：LivePK — 直播 PK 对战

| Store | 关键 API | 功能 |
|:---|:---|:---|
| `CoHostStore` | `requestHostConnection()`, `acceptHostConnection()`, `exitHostConnection()` | 跨房连线管理 |
| `BattleStore` | `requestBattle()`, `acceptBattle()`, `exitBattle()`, `state.battleScoreMap` | PK 对战管理与实时积分 |
| `LiveListStore` | `fetchLiveList()` | 获取可连线直播列表 |

## 环境要求

- **macOS**: Ventura 13.0 或更高版本
- **Xcode**: 15.0 或更高版本
- **CocoaPods**: 1.14.0 或更高版本
- **XcodeGen**（可选）: 用于从 `project.yml` 生成 Xcode 项目文件
- **最低部署版本**: iOS 16.0
- **支持设备**: iPhone + iPad

## 快速开始

### 1. 克隆项目

```bash
git clone <repository-url>
cd atomic-api-example/ios
```

### 2. 安装依赖

```bash
pod install
```

### 3. 配置 SDK 凭证

编辑 `Debug/GenerateTestUserSig.swift`，填入你的腾讯云应用凭证：

```swift
static let SDKAPPID: Int = 0          // 替换为你的 SDKAPPID
static let SECRETKEY = ""             // 替换为你的 SECRETKEY
```

> ⚠️ **安全提示**: `SECRETKEY` 仅用于本地调试。生产环境中，UserSig 必须由后端服务生成，切勿将 SECRETKEY 嵌入客户端发布包中。

### 4. 打开项目

```bash
open AtomicXCoreExample.xcworkspace
```

> 注意：请使用 `.xcworkspace` 而非 `.xcodeproj` 打开项目，以确保 CocoaPods 依赖正确加载。

### 5. 构建运行

在 Xcode 中选择目标设备或模拟器，点击 Run 即可编译运行。

## 权限说明

应用运行需要以下权限（已在 `Info.plist` 中声明）：

| 权限 | 用途 |
|:---|:---|
| `NSCameraUsageDescription` | 摄像头采集（直播推流） |
| `NSMicrophoneUsageDescription` | 麦克风采集（直播推流） |
| `NSLocalNetworkUsageDescription` | 本地网络访问（直播通信） |

## 本地化支持

项目支持中英文双语切换，可在登录页面右上角点击地球图标切换语言：

- `Resources/zh-Hans.lproj/Localizable.strings` — 简体中文
- `Resources/en.lproj/Localizable.strings` — 英文

本地化管理通过 `LocalizedManager` 单例实现：
- 支持 `String.localized` 扩展属性直接获取本地化文本
- 语言偏好通过 `UserDefaults` 持久化
- 切换语言后自动重置 `rootViewController` 刷新整个 UI
