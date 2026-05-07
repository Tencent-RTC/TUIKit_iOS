# Mine（个人中心）模块

## 概述

个人中心模块，提供用户个人信息展示与编辑功能。

从旧版 `iOS/App/RT-Cube/Mine/` 迁移至 v2 模块化架构。

## 目录结构

```
mine/
├── MineEntry.swift                          ← 对外唯一接口
├── README.md                                ← 本文件
├── Model/
│   ├── MineViewModel.swift                  ← 个人中心 ViewModel
│   └── ProfileInfoModel.swift               ← 个人资料数据模型
├── Views/
│   ├── MineViewController.swift             ← 个人中心主控制器
│   ├── MineRootView.swift                   ← 个人中心主视图（含设置项列表）
│   ├── MineAboutViewController.swift        ← 关于页面
│   ├── MineAboutResignViewController.swift  ← 账号注销页面
│   ├── ProfileController.swift              ← 个人资料编辑页
│   ├── ProfileTableViewCell.swift           ← 个人资料 Cell
│   ├── ProfileUpdateInfoView.swift          ← 修改昵称/签名弹窗
│   ├── ProfileDatePickerView.swift          ← 日期选择器
│   ├── AvatarPickerViewController.swift     ← 头像选择页（自研，替代 TUISelectAvatarController，完整适配 ThemeStore）
│   └── RTCExperienceRoomButtonView.swift    ← 体验房入口按钮
└── Resource/
    └── Localized/
        ├── MineLocalized.swift              ← 本地化辅助函数
        ├── zh-Hans.lproj/MineLocalized.strings
        └── en.lproj/MineLocalized.strings
```

## 对外接口

```swift
// 构建个人中心 ViewController
let mineVC = MineEntry.shared.buildMineViewController(
    onLogout: {
        // 执行退出登录逻辑
        LoginEntry.shared.logout { ... }
    },
    onLanguageChanged: { languageID in
        // 语言切换后刷新 UI
    },
    onExperienceRoomClicked: {
        // 体验房按钮点击，外部自行处理跳转
    }
)
navigationController?.pushViewController(mineVC, animated: true)
```

## 迁移变更

| 旧版依赖 | v2 替代方案 |
|---------|-----------|
| `import BusinessService` | `import Login`（使用 `LoginManager` / `LoginEntry`） |
| `import RTCCommon` | `assembly/Extension/LayoutDefine.swift` 中的工具函数 |
| `import AtomicXCore` / `import ITLogin` | `LoginEntry.shared.logout()` 统一登出 |
| `LanguageSelectViewControllerDelegate` | `onLanguageChanged` 闭包回调 |
| `ApplicationUtils.appVersionWithBuild` | 内联 `Bundle.main` 获取版本号 |
| `WindowUtils.getCurrentWindow()` | `UIApplication.shared.connectedScenes` 获取 window |
| `AppDelegate.showLoginViewController()` | `onLogout` 回调，外部自行处理 |

## 注意事项

1. **图片资源**：Mine 模块使用的图片（如 `mine_goback`、`mine_bg_icon`、`main_mine_privacy` 等）需要在壳工程的 `Assets.xcassets` 中包含
2. **LiteAVPrivacy**：隐私页面依赖 `LiteAVPrivacy` Pod，需在壳工程 Podfile 中引入
3. **TUIContact**：个人资料编辑中选择头像依赖 `TUISelectAvatarController`，需在壳工程中引入 `TUIContact`
