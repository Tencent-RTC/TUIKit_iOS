# TUIRoomKit

UIKit 会议组件 Pod。当前包含 `Base/` 基础组件分区，按 Android `tuiroomkit` 的 `base/` 一一翻译（API 命名、Tokens 数值、事件语义保持 1:1，详见 `android/room/docs/base/BASE_SPEC.md`）。

## Base 组件

对齐 Android 最新精简后的 base（`feat(base): base精简组件，支持浅色模式和蓝色皮肤`）：**只收「原生无平替的行为组件」**，Button / Input / Switch / Icon / Badge / Loading / Popover / Tooltip 用平台原生件（UIKit 控件）+ 颜色常量自绘，不再抽组件。

| 组件 | 文件 | 说明 |
|---|---|---|
| RoomDialog | `Base/Dialog/RoomDialog.swift` | Builder 链式、`Variant`（primary / ghost / danger）、`contentView`、`closable`。遮罩 `scrim`，卡片 `bg-surface` 圆角 12。 |
| RoomPopup | `Base/Popup/RoomPopup.swift` | 底部抽屉外壳（原稿 `.h5-popup`）：贴底面板 + 拖拽条、点遮罩 / 下拉关闭（`onDismiss(reason)`）、内容高度上限 90%、键盘让位。所有底部面板都用它。 |
| RoomToast | `Base/Toast/RoomToast.swift` | 挂窗口居中、自动顶掉上一条、任意线程转主线程、最多 3 行。 |
| RoomAvatar | `Base/Avatar/RoomAvatar.swift` | url 异步加载 + 首字母兜底 + 圆形裁剪。 |
| ErrorLocalized | `Base/Error/ErrorLocalized.swift` | 统一错误提示（当前直接展示 code + message）。 |
| RoomKitColors | `Base/Theme/RoomKitColors.swift` | `UIColor.roomKitXxx` 常量，对齐 Android `values/colors.xml`（单浅色 + 蓝色品牌色），派生色为预计算值，不做运行时混色。 |
| RoomImageLoader / RoomKitResources / RoomParticipant+DisplayName / RoomRandomUtils / RoomLocalMediaUtils / RouterContext | `Base/Util/` | 工具与导航协议。 |

## 使用

```swift
import TUIRoomKit

let avatar = RoomAvatar()
avatar.url = "https://example.com/avatar.png"

RoomToast.show("已开启麦克风")
```

## 页面

页面遵循 `ios/room/PAGE_ARCHITECTURE.md`：VC + View 成对、View 业务闭环、SnapKit 布局、文案走 `RoomKitResources.localizedString`。

| 页面 | 文件 | 说明 |
|---|---|---|
| RoomHomeViewController / RoomHomeView | `Home/` | 会前首页（对应交互稿 room-next native `pre-home`）：Hi 行（头像 / 昵称 / 登录 chip）+ 双入口（快速会议 / 加入会议，点按经 `routerContext` push 对应页面）。登录态与昵称 / 头像由 View 订阅 `LoginStore.shared.state` 自闭环；动作出口 `onAvatarTapped` / `onLoginTapped`。本期不做日程与预定会议。 |
| HomeEntryCard | `Home/HomeEntryCard.swift` | 首页入口卡片（圆形渐变图标 + 标题），`Tone.create / .join` 自含图标与渐变配色。 |
| QuickStartViewController / QuickStartView | `QuickStart/` | 快速会议（交互稿 `data-sub="create"`）：会议名称（placeholder 取 `LoginStore` 昵称）+ 麦克风 / 扬声器 / 视频开关，提交调 `RoomStore.createAndJoinRoom`（随机 6 位 roomID），成功后按开关应用 `DeviceStore` 本地媒体并回传 `onEnterRoom(roomID)`；`isSubmitting` 防重 + 按钮 loading。 |
| JoinMeetingViewController / JoinMeetingView | `Join/` | 加入会议（交互稿 `data-sub="join"`）：会议号码（数字键盘、回车提交）+ 三开关，空号 toast 拦截，提交调 `RoomStore.joinRoom(.standard)`，成功后同上回传 `onEnterRoom(roomID)`。 |

## 组件

| 组件 | 文件 | 说明 |
|---|---|---|
| RouterContext | `Base/Util/RouterContext.swift` | View 唯一依赖的导航协议；`RouterContext where Self: UIViewController` 提供 push / pop / popToRoot 默认实现，VC 声明遵循即可。 |
| RoomFormCard / RoomFormRow / RoomFormSubmit | `PreRoom/` | 会前场景组件（场景件不放 base）。 会前表单组件：圆角 12 卡片（`bg-surface`，内边距 4/16）；56 高行（label 固定 88，输入框 15px / `fgSecondary` / 右对齐 / placeholder `fgTertiary`，开关行右对齐）；提交按钮 48 高、圆角 8、accent 底、15px 居中，按下 alpha 0.88。 |
| RoomRandomUtils | `Base/Util/RoomRandomUtils.swift` | 会议号生成（`generateRoomID(completion:)`：随机 6 位 + `getRoomInfo` 查重，重试 5 次仍重复则 `roomID-时间戳前6位`），页面不得各自写随机实现。 |
| RoomLocalMediaUtils | `Base/Util/RoomLocalMediaUtils.swift` | 本地设备开启统一入口：`apply(roomID:isMicrophoneOn:isSpeakerOn:isCameraOn:)` 进房成功后把进房前开关同步到会中；`openMicrophone(roomID:completion:)`（权限 → `DeviceStore.openLocalMicrophone` → `unmuteMicrophone`）/ `openCamera(completion:)`（权限 → `openLocalCamera`）回传 `RoomDeviceOpenResult`（`.opened` / `.permissionDenied` / `.failed`，仅 `.failed` 由工具 toast）；`isPermissionDenied(_:)` 查系统权限是否被拒。`setAudioOutput(_:)` 切换声音输出（`.speaker` / `.earpiece` / `.mute`，SDK 无静音路由，静音 = 输出音量置 0 并记住原音量，状态见 `isAudioOutputMuted`），进房前扬声器开关「关」即静音。每次开启尝试结束发 `deviceOpenDidFinishNotification`，会中底栏据此刷新「无权限」角标。 |

## 主题

- 对齐 Android：**单浅色 + 蓝色品牌色（`#0071E3`）**，不再支持深色模式与多品牌色切换；设置页的「深色模式」行已移除。
- 颜色是常量不是代码：全部落在 `Base/Theme/RoomKitColors.swift` 的 `UIColor.roomKitXxx`，命名与 Android `colors.xml` 一一对应；派生色（浅底、描边等）为预计算值，禁止在页面里写裸色值或运行时混色。
