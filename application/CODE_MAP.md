# application Code Map

## 入口和边界

`App-UIKit.xcodeproj` 保留 App-UIKit 与 TUIKitReplay 两个 target，使用 Xcode 27，最低 iOS 15.0。共享 Scheme 为 App-UIKit；工程纯用 SPM，没有 workspace，也不含 Pods。Call / Room 接入层随文件同步组编译；旧 VoiceRoom Controller 保留源码，通过文件同步例外排除编译。

```text
AppDelegate                     # Bugly、许可证初始化、账号事件与根导航切换
└── SceneDelegate                # Window 和初始 LoginViewController
    └── AppNavigationController
        ├── Login/               # 账号缓存、自动登录、防重、等待 LoginStore 用户资料
        ├── Register/            # 首次昵称头像设置，经 LoginStore.setSelfInfo
        ├── Main/                # 首页卡片：Call / Live / Room 三个入口
        ├── Call/
        │   ├── Entry/           # G1 通话入口、好友 / 字幕抽屉、会话内设置
        │   ├── Settings/        # G2 更多设置
        │   └── Common/          # 主题、抽屉、Toast、文案
        ├── Room/
        │   ├── RoomHomeView/VC          # 会议首页：快速会议 / 加入 / 设置 / 登出
        │   ├── RoomQuickStartView/VC    # 快速会议
        │   ├── RoomJoinView/VC          # 加入会议
        │   └── LogShare/                # 日志分享
        ├── Mine/                # 个人信息、语言、头像、日志分享和登出
        └── Live/
            ├── LiveViewController           # 原 Live 二级菜单
            ├── VideoLiveViewController      # 两列选择列表与开播按钮
            ├── LiveSelectListView/ItemView  # 两列列表 UI
            ├── LiveSelectListStore          # AtomicXCore 分页、去重、请求状态
            ├── LiveListSupport              # 列表调色板、图片请求
            ├── PlayerViewController         # LiveListView 初始数据与分页注入
            └── PusherViewController         # PusherView 宿主与退出回调
```

Live 的四个列表文件和两个薄宿主迁自 `../live/LiveKitAccess/LiveKitAccess/`；VideoLiveViewController 适配自其 WaterfallViewController。Call 接入层迁自 `../call/CallKitAccess/CallKitAccess/`，Room 接入层迁自 `../room/RoomKitAccess/RoomKitAccess/`。三者只复用接入层源码，不启动另一个 App，也不引入其 AppDelegate 或登录流程。首页 `gotoCallView` push `CallEntryViewController`；`gotoRoomView` push `RoomHomeViewController`，并把 `onLoggedOut` 接到 AppDelegate 的换根逻辑。

## 账号状态

- AtomicXCore LoginStore 是登录、用户资料和登出的唯一事实来源；原 TUILogin 二次登录与 V2TIM 资料缓存链路已解除。
- LoginViewController 保存本次请求 ID、加载和短期订阅；退出或请求完成后使旧回调失效，最多等待资料 5 秒。
- AppDelegate 订阅 loginEventPublisher：被踢且当前是 Pusher 时保留组件自己的 Summary，退出后返回登录；登录过期和其他账号事件直接移除旧页面并返回登录。
- 账号失效后的登录页不执行本次自动登录，避免自动抢回会话；个人资料和登录输入缓存仍按原壳维护。
- Mine / Register 只通过 LoginStore 写用户资料，回调回主线程后更新自己的界面。

## 业务与资源归属

- LiveListView、PlayerView、PusherView 及其生命周期仍属于 `../live/TUILiveKit`，本轮未改产品业务实现或公开 API。
- Call、Room 已接入各自组件库；Live 内的 Voice Room 入口仍提示暂未接入。原 Chat 入口结构未扩展。
- Support 从旧 AtomicX 迁入壳实际使用的颜色、缩放、圆角、Window 帮助，以及文本 Toast。壳不依赖整个旧 AtomicX。
- 壳原素材与 Localized.xcstrings 留在 Resource；`Resource/Access/` 统一存放接入层资源：`Assets.xcassets`、`CallAccess.xcassets`、`RoomAccess.xcassets` 三个图集，以及一份合并了 Live / Call / Room key 的 `Localizable.strings`（en / zh-Hans）。组件库自身的图集与文案仍由各自 SPM `Bundle.module` 提供。
- Live、Gift 和远程 UI 库资源通过各自 SPM bundle；TUICore、美颜、特效的原命名 bundle 通过 App 的 SDK Resources 复制阶段进入主 bundle。
- 礼物许可证在联网时初始化；美颜本轮未接入，App 不注册美颜 Wrapper、不初始化美颜许可证，当前基础美颜仍按 Live / AtomicXCore 的既有能力执行，不增加高级美颜帧处理。

## SPM 与 Replay

新工程引用本地 TUILiveKit、TUICallKit_Swift、TUIRoomKit、TCGiftPlayerKit、TCEffectPlayerKit、Bugly，以及官方远程 SwiftPM 包 TUICore_SwiftPM、Chat_SDK_SwiftPM、Professional_SwiftPM、GfitAR_SwiftPM、`sensorsdata/sa-sdk-ios-spm`、SnapKit、Kingfisher、SDWebImage。AtomicXCore 不在 App 直接声明，由前三个本地 Kit 各自声明 `Tencent-RTC/AtomicXCore_SwiftPM` 传递引入，相同 package identity 统一到 5.3.0，只链接一份。

不再有本地 SDK 准备脚本：IM、LiteAV、TUICore、礼物特效（TCEffectPlayer / TCMediaX / YTCommonXMagic）和神策统一由官方远程包提供，版本在 `Package.resolved` 锁定。Replay 扩展链接 `Professional_SwiftPM` 的 `TXLiteAVSDK_ReplayKit` 产品。ObjC 服务由 TCEffectPlayerKit package 提供；Gift Kit 不依赖或直接引用 Effect Kit；App 主动链接可选的 TCEffectPlayerKit，通过现有 `-ObjC` 链接配置保留插件的 `+load` 自动注册；AppDelegate 不导入插件、不调用注册函数，只配置礼物许可证。未选择插件的宿主只保留 SVGA，MP4 返回失败并推进队列。打包转发头导出同一注册函数，宿主保留 `-ObjC`。

`Devops/atomicxcore_spm_local_dependency.sh` 与 `atomicxcore_src_local_dependency.sh` 用于把 AtomicXCore 临时换成本地二进制产物或 `atomic_engine` 源码包。因 App 无自身 `Package.swift`，两个脚本都一次切齐 TUILiveKit / TUICallKit_Swift / TUIRoomKit 三个 `Package.swift`，让它们指向同一个 path 包（否则 path 包与远端 `atomicxcore_swiftpm` 会形成两份同名 module）。首次修改前在对应 Kit 旁写 `Package.swift.appbak`，`--restore` 据此回到远端；两个脚本共用这份备份，可互相来回切。产物与 zip 放 `SDK/`，已加 gitignore。

TUIKitReplay 只链接 SDK 的 ReplayKitExt 产品，不继承主 App 的全部 SDK。App 与 extension 的 entitlements 组名和 SampleHandler 常量统一为 `group.com.tencent.liveadapter.demo`；四个 Bundle ID（App / 扩展 × Debug / Release）也统一为 `com.tencent.liveadapter.demo(.upload)`，与 RoomKitAccess 一致。扩展 target 另有 `Embed Frameworks` 阶段（`dstSubfolderSpec = 10`、`CodeSignOnCopy`）把 `TXLiteAVSDK_ReplayKitExt.framework` 复制进 `.appex/Frameworks/`：它是动态库且 SPM 不会自动嵌入，缺这一步扩展会因 dyld 找不到库而直接启动失败，与 RoomKitAccess 的 `RoomKitScreenShare` 配置一致。签名和实际录屏需独立真机验证。

Room 会中的屏幕共享复用 `TUIKitReplay`：AppDelegate 启动时调用 `RoomScreenShareLauncher.shared.configure`，`appGroup` 为 `group.com.tencent.liveadapter.demo`，与 `TUIKitReplay/SampleHandler.swift` 的 `APPGROUP` 及 App / 扩展的 Debug、Release 四份 entitlements 一致；`preferredExtension` 由 `Bundle.main.bundleIdentifier` 拼接 `.upload` 得到，等于 `com.tencent.liveadapter.demo.upload`。`TXReplayKitExt` 是单例且一次广播只绑一个 App Group，因此 Live 与 Room 共用同一扩展和通道、不能并发录屏。SampleHandler 的结束回调保持 Live 原实现，Room 停止时系统会多弹一个提示。工程使用 Manual 签名：App 与扩展的 Debug / Release 四份配置都指向包含该 App Group 的描述文件（`All-In-One-App-Group` / `All-In-One-App-Group-Upload`）。Release 曾误用不含 group 的 `All-In-One-APP`，此时 `containerURLForSecurityApplicationGroupIdentifier` 拿不到容器、扩展与主进程 IPC 建不起来，表现就是本端显示共享中而对端无画面；现已与 Debug 对齐。

构建、配置和验证命令见 [README](README.md)。
