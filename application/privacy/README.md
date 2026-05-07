# Privacy（隐私合规）模块

## 概述

隐私合规模块 — 面向"个人中心进入的隐私管理/协议展示"场景，职责范围与安卓端 `v2/android/.../v2/privacy` 对齐。

提供内容：
- 隐私管理中心主列表 + 二级页面（个人信息与权限、系统权限、单项权限详情、个人信息查看、已收集信息清单）
- 通用协议 WebView（`PrivacyWebViewController`，同时被 auth 模块复用作为协议跳转容器）
- 举报（Report）半屏弹窗
- 模块唯一对外接口 `PrivacyEntry`（协议 URL、页面跳转、实名认证开关、WebViewController 工厂）
- 隐私配置（`PrivacyConfig`，读取 `Privacy.plist`）
- 模块本地化便捷函数（`PrivacyLocalize`，同时被 auth 模块复用）
- 资源文件（`PrivacyAssets.xcassets`、`PrivacyLocalized.strings`）

> 实名认证、反诈提示、高风险 IP、开播体验时长、安全提醒等"认证/风控"弹窗拆到同级 `auth/` 模块。
> 两个模块共享本模块的 `PrivacyLocalize` 函数与 `PrivacyLocalized.strings` 表，`auth/` 发布时将被移除，公共基础设施留在本模块。

## 目录结构

```
privacy/
├── PrivacyEntry.swift                                   ← 对外唯一接口（协议 URL、页面跳转、WebViewController 工厂、实名认证开关）
├── PrivacyConfig.swift                                  ← 隐私配置（读取 Privacy.plist）
├── README.md                                            ← 本文件
├── Extension/
│   └── PrivacyLocalized.swift                           ← 本地化便捷函数（PrivacyLocalize，auth 模块共用）
├── Views/
│   ├── PrivacyCenterViewController.swift                ← 隐私管理中心主列表页面
│   ├── PrivacyPersonalAuthViewController.swift          ← 个人信息与权限枢纽页面
│   ├── PrivacySystemAuthViewController.swift            ← 系统权限列表（实时状态）
│   ├── PrivacyAuthDetailViewController.swift            ← 单个权限详情页面
│   ├── PrivacyDataCollectionViewController.swift        ← 个人信息查看（已收集信息及用途）
│   ├── PrivacyMyInfoViewController.swift                ← 个人信息展示（支持复制）
│   ├── PrivacyWebViewController.swift                   ← 通用 WebView（协议网页展示，auth 模块共用）
│   └── Report/                                          ← 举报功能子模块
│       ├── ReportViewController.swift                   ← 举报页面主控制器（半屏弹窗）
│       ├── ReportTypeView.swift                         ← 举报类型选择视图
│       ├── ReportDescView.swift                         ← 举报描述输入视图
│       └── ReportNetworkService.swift                   ← 举报网络请求（Alamofire + Login）
└── Resource/
    ├── Assets/
    │   └── PrivacyAssets.xcassets/                      ← 图片资源（返回按钮等，auth 模块复用）
    └── Localized/
        ├── zh-Hans.lproj/PrivacyLocalized.strings      ← 中文本地化（auth 相关 key 也在此表中）
        └── en.lproj/PrivacyLocalized.strings           ← 英文本地化
```

## 对外接口

### 1. 隐私协议 URL

```swift
PrivacyEntry.agreementURL       // 用户协议 URL
PrivacyEntry.privacySummaryURL  // 隐私协议摘要 URL
PrivacyEntry.privacyURL         // 隐私协议 URL
```

### 2. 页面跳转

```swift
// 打开隐私管理中心
PrivacyEntry.pushPrivacyPage(.privacyCenter, from: viewController)

// 打开隐私协议 WebView
PrivacyEntry.pushPrivacyPage(.privacy, from: viewController)

// 打开用户协议 WebView
PrivacyEntry.pushPrivacyPage(.agreement, from: viewController)

// 创建自定义 WebView 页面
let vc = PrivacyEntry.makeWebViewController(url: url, title: "标题")
```

### 3. 实名认证开关

```swift
PrivacyEntry.enableIdCardVerification = true  // 默认开启
```

## 核心功能

### 举报（Report）

- **半屏弹窗**：从底部弹出，支持选择举报类型（8 种）和填写描述
- **独立网络请求**：通过 `ReportNetworkService` 发起 POST 请求，使用 `Alamofire` + `Login` 模块鉴权
- **对外调用方式**：通过 `UIViewController` / `UIView` 的 `@objc dynamic showReportAlert(roomId:ownerId:)` 扩展方法，兼容 OC runtime selector 调用

```swift
// 从 UIViewController 调用
viewController.showReportAlert(roomId: "xxx", ownerId: "yyy")

// 从 UIView 调用
someView.showReportAlert(roomId: "xxx", ownerId: "yyy")
```

### 隐私管理中心（PrivacyCenterViewController）

区分国内版和海外版（TencentRTC App）菜单：

| 国内版 | 海外版 |
|-------|-------|
| 个人信息与权限 | System Permissions |
| 个人信息查看 | Personal Information |
| 个人信息收集清单 | Privacy Policy |
| 第三方信息共享清单 | — |
| 隐私政策摘要 | — |
| 隐私保护指引 | — |
| 服务条款 | — |
| 用户协议 | — |

## 注意事项

1. **Privacy.plist**：隐私配置从壳工程 `Bundle.main` 中的 `Privacy.plist` 读取，需确保该文件包含所有必要的 URL 和权限配置字段
2. **海外版差异**：通过 `Bundle.main.bundleIdentifier == "com.tencent.rtc.app"` 判断海外版，海外版隐私中心菜单精简
3. **与 auth/ 的分工**：本模块只承载"隐私管理/协议展示/举报"等个人中心类能力；实名认证、反诈、高风险 IP、体验时长、安全提醒等"认证/风控"弹窗在 `../auth/`
4. **发布边界**：发布开源副本时本模块整体剔除（配置于 `scripts/oss_sync_whitelist.yml`）
