# 模块概览

## 模块简介

Login 模块是一个**自包含**的 iOS 登录组件，提供多种登录方式的完整实现。模块对外仅暴露 `LoginEntry` 单例作为唯一接口，内部采用 **Store/State 单向数据流** 架构，各登录方式独立封装、互不影响。

## 支持的登录方式

| 登录方式 | 枚举值 | 有 UI | 说明 |
|----------|--------|-------|------|
| 手机号验证码 | `.phoneVerify` | ✓ | 输入手机号 → 人机验证 → 发送短信验证码 → 登录，页面内可切换至 iOA |
| 邮箱验证码 | `.emailVerify` | ✓ | 输入邮箱 → 人机验证 → 发送邮箱验证码 → 登录，页面内可切换至 iOA |
| iOA 企业登录 | `.ioaAuth` | ✓ | 通过 iOA/MOA SDK 进行企业身份认证 |
| 邀请码登录 | `.inviteCode` | ✓ | 输入邀请码完成登录 |
| Debug 登录 | `.debugAuth` | ✓ | 仅调试包可用，手动输入 SDKAppID/UserID/UserSig 登录 |
| 登录菜单 | `.menu` | ✓ | RTCubeLab 专用，展示所有登录方式的选择面板 |

## 对外接口

模块对外仅暴露以下接口，内部一切实现细节对外不可见：

```swift
// 第一步：初始化（在 App 启动时调用一次）
LoginEntry.shared.initialize(
    baseUrl: "https://demos.trtc.tencent-cloud.com/prod/",
    testBaseUrl: "https://demos-test.trtc.tencent-cloud.com/intl-dev/", // 可选，测试环境 baseUrl
    sdkAppId: SDKAPPID,
    ioaAppKey: IOAAPPKEY,     // 可选，传入后自动初始化 ITLogin SDK
    ioaAppId: IOAAPPID        // 可选，传入后自动注册 AppLifecycleHandler 处理 SSO 回调
)

// 注入被动登出回调（Token 过期 / 被踢下线时自动拉起登录页）
LoginEntry.shared.onPassiveLogout = { [weak self] in
    self?.showLogin()
}

// 第二步：拉起登录（如果 initialize 尚未完成会自动等待）
let loginVC = LoginEntry.shared.launch(
    mode: .phoneVerify,       // 登录方式
    completion: { (result: Result<LoginResult, LoginError>) in
        switch result {
        case .success(let loginResult):
            // loginResult.userModel 包含 userId、token、userSig、phone、email、name、avatar
        case .failure(let error):
            // error: .cancelled / .networkError / .verifyCodeFailed / .loginFailed / .tokenExpired / .ioaAuthFailed / .unknown
        }
    }
)
// 返回 UIViewController，由外部决定如何展示（present / push / 设为 rootVC）

// 登出
LoginEntry.shared.logout { result in
    // ...
}

// 注销账户（删除用户数据，不可恢复）
LoginEntry.shared.logoff { result in
    // ...
}

// 只读属性
LoginEntry.shared.userModel          // 当前已登录用户的 UserModel，未登录时为 nil
LoginEntry.shared.hasLoggedIn        // 是否曾经登录成功过
LoginEntry.shared.loggedInMode       // 上次登录成功的 LoginMode，未登录时为 nil
LoginEntry.shared.isAutoLoginEnabled // 自动登录开关（可读写，持久化到 UserDefaults）
```

### iOA（ITLogin SDK）集成说明

iOA 相关的 SDK 初始化、ITLoginDelegate 回调、SSO URL 处理已全部收拢到 `IOAAuthManager` 内部：

- **SDK 初始化**：在 `LoginEntry.initialize(ioaAppKey:ioaAppId:)` 中触发，由 `IOAAuthManager.shared.setupIOA()` 完成（`ITLogin.start` / `disableLoginPage` / 设置 delegate）
- **SSO URL 处理**：`IOAAuthManager` 实现 `AppLifecycleHandler` 协议并自动注册到 `AppLifecycleRegistry`，由 AppDelegate 转发 URL 回调
- **票据登录**：ITLoginDelegate 收到票据后通过 `LoginNavigator.handleIOATicket()` 触发登录

壳工程的 AppDelegate **不需要** `import ITLogin` 或编写任何 iOA 相关代码。

### 被动登出回调

Token 过期、被踢下线等非用户主动操作触发的登出场景，登录模块会在内部完成 logout 清理后，通过 `onPassiveLogout` 回调通知壳工程重新拉起登录页：

```swift
LoginEntry.shared.onPassiveLogout = { [weak self] in
    self?.showLogin()
}
```

### 对外数据模型

```swift
/// 登录结果
public struct LoginResult {
    public let userModel: UserModel
}

/// 用户数据
public struct UserModel {
    public var userId: String     // 用户 ID
    public var token: String      // 登录 Token
    public var userSig: String    // IM UserSig
    public var phone: String      // 手机号
    public var email: String      // 邮箱
    public var name: String       // 昵称
    public var avatar: String     // 头像 URL
}

/// 错误类型
public enum LoginError: Error {
    case cancelled                          // 用户取消
    case networkError(message: String)      // 网络错误
    case verifyCodeFailed(message: String)  // 验证码发送失败
    case loginFailed(code: Int, message: String) // 服务端登录失败
    case tokenExpired                       // Token 过期
    case ioaAuthFailed(message: String)     // iOA 认证失败
    case unknown(message: String)           // 未知错误
}
```

## 实际目录结构

```
login/
├── DevLoginMenuViewController.swift           ← RTCubeLab 登录方式选择面板（所有登录方式的总入口）
├── LoginEntry.swift                           ← 统一入口 + 统一出口（对外唯一接口）
├── LoginNavigator.swift                       ← 内部导航器（页面跳转协调、结果汇聚）
├── LoginSubStore.swift                        ← 子模块 Store 协议定义
│
├── PhoneVerify/                               ← 手机号验证码登录
│   ├── PhoneVerifyView.swift
│   ├── Store/
│   │   ├── PhoneVerifyStore.swift
│   │   └── PhoneVerifyState.swift
│   ├── SubViews/
│   │   └── PhoneInputView.swift
│   └── Utils/
│       └── PhoneValidator.swift
│
├── EmailVerify/                               ← 邮箱验证码登录
│   ├── EmailVerifyView.swift
│   ├── Store/
│   │   ├── EmailVerifyStore.swift
│   │   └── EmailVerifyState.swift
│   ├── SubViews/
│   │   └── EmailInputView.swift
│   └── Utils/
│       └── EmailValidator.swift
│
├── IOAAuth/                                   ← iOA 企业登录
│   ├── IOAAuthView.swift
│   ├── IOAAuthManager.swift                   ← iOA SDK 生命周期管理（ITLoginDelegate + AppLifecycleHandler）
│   ├── Store/
│   │   └── IOAAuthStore.swift
│   └── Utils/
│       └── IOAService.swift
│
├── TokenAuth/                                 ← Token 自动登录（无 UI）
│   ├── Store/
│   │   └── TokenAuthStore.swift
│   └── Utils/
│       └── TokenCacheManager.swift
│
├── InviteCode/                                ← 邀请码登录
│   ├── InviteCodeView.swift
│   ├── AlphanumericKeyboardView.swift         ← 仿系统风格的自定义字母数字键盘（避免多输入框切换焦点时键盘面板重置）
│   └── Store/
│       └── InviteCodeStore.swift
│
├── DebugAuth/                                 ← Debug 登录（仅调试包）
│   ├── DebugAuthView.swift
│   ├── Store/
│   │   ├── DebugAuthStore.swift
│   │   └── DebugAuthState.swift
│   └── SubViews/
│       └── DebugConfigView.swift
│
├── Components/                                ← 公共组件
│   ├── Model/
│   │   ├── LoginResult.swift                  ← 登录结果模型（对外可见）
│   │   ├── LoginError.swift                   ← 错误枚举（对外可见）
│   │   ├── UserModel.swift                    ← 用户数据模型（对外可见）
│   │   └── AvatarModel.swift                  ← 头像列表数据源
│   ├── Service/
│   │   ├── LoginNetworkService.swift          ← 登录网络请求统一封装（使用 AtomicXCore）
│   │   ├── CaptchaService.swift               ← 人机验证服务
│   │   └── BusinessServiceBridge/             ← 从 BusinessService 迁移的底层网络代码
│   │       └── HttpService/
│   │           ├── Base/
│   │           │   └── NetworkManager.swift
│   │           ├── Logic/
│   │           │   └── HttpLogicRequest.swift
│   │           ├── Login/
│   │           │   ├── LoginConstants.swift
│   │           │   ├── LoginManager.swift
│   │           │   ├── LoginNetworkManager.swift
│   │           │   └── ProfileManager.swift
│   │           └── Model/
│   │               ├── AccountModel.swift
│   │               ├── HttpJsonModel.swift
│   │               ├── LoginConfig.swift
│   │               └── UserOverdueLogicManager.swift
│   └── Views/
│       ├── LoginHeaderView.swift              ← 登录页公共头部（logo、语言切换）
│       ├── LoginTextField.swift               ← 统一输入框样式
│       ├── VerifyCodeInputView.swift          ← 验证码输入框
│       ├── CountdownButton.swift              ← 倒计时按钮
│       ├── PrivacyAgreementView.swift         ← 隐私协议勾选
│       ├── PrivacyAlertView.swift             ← 隐私协议弹窗
│       ├── PrivacyPanelView.swift             ← 隐私协议面板
│       ├── FullScreenLoadingView.swift        ← 全屏 loading 遮罩
│       ├── RegisterView.swift                 ← 新用户注册（设置昵称/头像）
│       ├── AvatarListAlertView.swift          ← 头像选择弹窗
│       ├── WebViewController.swift            ← 通用 WebView
│       └── UserAgreementView.swift            ← 用户协议页
│
└── Resource/                                  ← 资源文件
    ├── VerifyPicture.html                     ← 人机验证 H5 页面
    ├── Assets/
    │   └── LoginAssets.xcassets/              ← 图片资源
    └── Localized/
        ├── LoginLocalized.swift               ← 本地化函数
        ├── en.lproj/LoginLocalized.strings    ← 英文
        └── zh-Hans.lproj/LoginLocalized.strings ← 中文
```

### 依赖关系

| 依赖 | 用途 |
|------|------|
| `RTCCommon` | 项目公共库（ObservableState、StateSelector 等） |
| `AtomicXCore` | 内部核心库（LoginNetworkService 使用） |
| `TUICore` | 腾讯 IM SDK 核心 |
| `ImSDK_Plus` | 腾讯 IM SDK |
| `ITLogin` | iOA/MOA 企业登录 SDK |
| `TXLiteAVSDK_Professional` | 腾讯音视频 SDK（DebugConfigView 使用） |
| `Alamofire` | 网络请求（通过 BusinessServiceBridge 使用） |
| `Kingfisher` | 图片加载（头像显示） |
| `SnapKit` | Auto Layout 布局 |
| `Toast_Swift` | Toast 提示 |

## 架构要点

1. **Store/State 单向数据流** — 每个登录子模块遵循 `State → Store → View` 架构，View 只读 State、调用 Store 方法，Store 更新 State 驱动 UI 刷新。
2. **LoginSubStore 协议** — 所有子模块 Store 实现 `resultPublisher`，通过 Combine 发出登录结果。
3. **LoginNavigator 结果汇聚** — Navigator 订阅所有 Store 的 `resultPublisher`，统一汇聚后通过 `completion` 回调给 `LoginEntry`，保证结果只回调一次。
4. **自动登录** — `LoginEntry` 检查 `hasLoggedIn`（UserDefaults），为 true 时先通过 `TokenAuthStore` 尝试 Token 自动登录，失败则清除记录走正常 UI 流程。
5. **新用户注册拦截** — 登录成功后 Navigator 检查用户头像是否为空，为空则自动 push 注册页设置昵称/头像，注册完成后再回调最终结果。DebugAuth 自行管理注册流程，不走此拦截。
6. **BusinessServiceBridge** — 原 BusinessService 模块中 login 相关的底层网络代码已复制到 `Components/Service/BusinessServiceBridge/`，login 模块不再依赖 BusinessService。
7. **iOA SDK 收拢** — ITLogin SDK 的初始化、ITLoginDelegate 回调、SSO URL 处理全部封装在 `IOAAuthManager` 内部，`LoginEntry` 不再 import ITLogin，壳工程 AppDelegate 无需感知 ITLogin 的存在。
8. **AppLifecycleHandler 注册机制** — `IOAAuthManager` 实现 `AppLifecycleHandler` 协议并注册到壳工程的 `AppLifecycleRegistry`，通过注册表分发 AppDelegate 回调，多模块互不干扰。
9. **initialize/launch 挂起机制** — `launch()` 内部会检查 `initialize()` 是否已完成，如果尚未完成则自动挂起，待初始化完成后再执行自动登录等逻辑，外部不需要用回调嵌套。
10. **被动登出回调** — Token 过期、被踢下线等被动登出场景，登录模块内部完成 logout 清理后通过 `onPassiveLogout` 闭包通知壳工程拉起登录页，壳工程在初始化时注入回调即可。

## 开源 / 内部双 subspec

`Login.podspec` 声明两个 subspec，`default_subspecs = 'OpenSource'`：

| subspec | 使用方 | 包含内容 | 依赖 | 编译宏 |
|---------|--------|----------|------|--------|
| `OpenSource` | 开源版 Podfile | **剔除** `IOAAuth/` 目录源码；共用文件中 iOA 分支由宏屏蔽 | `TUICore` / `Alamofire` / `SnapKit` / `Kingfisher` / `Toast-Swift` / `AtomicX` | 无 |
| `Full` | 内部 Podfile（`application/Podfile`） | **全量源码**，含 `IOAAuth/` | 公共依赖 + `ITLogin` | `LOGIN_FULL` |

内部 Podfile 显式声明 `pod 'Login/Full'`，开源 Podfile 使用默认 `pod 'Login'`（即 `OpenSource`）。

涉及 iOA 的共用文件通过 `#if LOGIN_FULL` 包裹 iOA 分支，单一真相源，避免开源 / 内部代码漂移：

- `LoginEntry.swift`：`IOAAuthManager.shared.setupIOA` / `activeNavigator` 赋值；`launch(mode:)` 在 `!LOGIN_FULL` 时对 `.ioaAuth` 入参进行兜底 —— 立即回调 `.ioaAuthFailed` 并返回占位 `UIViewController()`，避免走入无 UI 的空壳页面
- `LoginNavigator.swift`：`import ITLogin` / `pushIOAAuth`（开源版保留空方法） / `handleIOATicket`
- `PhoneVerifyView.swift`：`ioaLoginButton` / `dividerContainerView` 的 `addSubview`、约束、`addTarget`、显隐
- `DevLoginMenuViewController.swift`：菜单项中 `.ioaAuth` 条目

`PhoneVerifyStore` / `EmailVerifyStore` 的 `onSwitchToIOA` / `switchToIOA()` 是纯闭包回调，不直接依赖 iOA SDK，开源版保留不屏蔽；`LoginError.ioaAuthFailed` 枚举 case 同理保留，仅生产它的 `LoginNetworkService.loginByMOA` 业务链条本身不引入 ITLogin 符号。

## 多 Target 支持

壳工程包含 3 个 target，通过编译宏区分行为：

| Target | 用途 | 编译宏 | 默认登录方式 |
|--------|------|--------|-------------|
| **RTCube** | 国内版发布 | （无额外宏） | `.phoneVerify`（手机号 + iOA） |
| **TencentRTC** | 海外版发布 | `RTCUBE_OVERSEAS` | `.emailVerify`（邮箱登录，默认英文） |
| **RTCubeLab** | 开发与测试 | `RTCUBE_LOCAL_BUILD` + `RTCUBE_LAB` | `.debugAuth`（登录方式选择面板） |

### RTCubeLab 登录入口

RTCubeLab target 使用 `DevLoginMenuViewController` 作为入口页面，列出所有可用登录方式：

- 📱 手机号登录
- 📧 邮箱登录
- 🏢 iOA 企业登录
- 🎟️ 邀请码登录
- 🔧 Debug 登录（userId 直接登录）

点击后通过 `LoginNavigator` 跳转到对应的登录页面，方便开发和测试所有登录流程。
