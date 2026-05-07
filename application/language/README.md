# 模块概览

## 模块简介

Language 模块是一个**轻量级、职责单一**的语言切换组件，提供应用内语言选择的完整 UI 和切换逻辑。模块对外仅暴露 `LanguageEntry` 单例作为唯一接口，底层语言切换依赖 `TUICore` 框架的 `TUIGlobalization` 类。

## 支持的语言

| 语言标识 | 显示名称 |
|----------|----------|
| `zh-Hans` | 简体中文 |
| `en` | English |

默认语言为 `en`（当 `TUIGlobalization.tk_localizableLanguageKey()` 返回 `nil` 时的兜底值）。

## 对外接口

模块对外仅暴露以下接口，内部一切实现细节对外不可见：

```swift
// 方式一：Push 语言选择页面（推荐）
LanguageEntry.shared.pushLanguageSelect(from: navigationController) { changed in
    if changed {
        // 用户切换了语言，外部需要刷新 UI（如重建页面栈）
    }
}

// 方式二：构建 ViewController，由外部自行展示
let vc = LanguageEntry.shared.buildLanguageSelectViewController { languageID in
    // languageID 为用户选中的语言标识，如 "zh-Hans"、"en"
}

// 便捷查询
let currentID = LanguageEntry.shared.currentLanguageID   // 如 "zh-Hans"、"en"
let isCN = LanguageEntry.shared.isChinese                // true / false
```

### 对外 API 一览

| API | 签名 | 说明 |
|-----|------|------|
| 单例 | `LanguageEntry.shared` | 全局唯一入口 |
| Push 语言选择页 | `pushLanguageSelect(from:completion:)` | 自动 push 到指定导航栈，切换后 `completion(true)` |
| 构建语言选择 VC | `buildLanguageSelectViewController(completion:)` | 只创建 VC 不 push，由调用方自行展示 |
| 当前语言标识 | `currentLanguageID: String`（只读） | 返回如 `"zh-Hans"` / `"en"` |
| 是否中文 | `isChinese: Bool`（只读） | `currentLanguageID` 以 `"zh"` 开头则为 `true` |

## 实际目录结构

```
language/
├── README.md                          ← 本文档
├── LanguageEntry.swift                ← 统一入口（对外唯一接口，单例模式）
└── LanguageSelectViewController.swift ← 语言选择页面 + 数据模型 + Cell
```

### 内部组件说明

| 组件 | 说明 |
|------|------|
| `LanguageEntry` | 对外门面类（单例），封装所有公开 API |
| `LanguageSelectViewController` | UIViewController，包含一个 plain style UITableView，展示语言列表 |
| `LanguageCellModel` | 值类型 struct：`languageID`、`languageName`、`selected` |
| `LanguageSelectCell` | 自定义 UITableViewCell，左侧语言名称，右侧蓝色对勾（代码绘制，不依赖外部图片） |

## 依赖关系

| 依赖 | 用途 |
|------|------|
| `UIKit` | 标准 iOS UI 框架 |
| `TUICore` | 提供 `TUIGlobalization` 进行实际的语言读取与切换 |
| `SnapKit` | Auto Layout 布局（tableView 约束） |

## 架构要点

1. **门面模式** — `LanguageEntry` 作为模块唯一对外接口，隐藏内部实现（`LanguageSelectViewController` 为 `internal`）。
2. **单一职责** — 本模块仅负责语言选择 UI 交互，实际的多语言翻译资源由各业务模块自行管理，底层切换由 `TUIGlobalization` 完成。
3. **回调通知** — 语言切换后通过闭包回调通知外部，外部自行决定如何刷新 UI（如重建页面栈）。

## 使用场景

该模块主要被 `login` 模块的 `LoginNavigator` 使用，在登录流程中提供"切换语言"功能。语言切换后 `LoginNavigator` 会调用 `rebuildCurrentLoginPage()` 重建整个登录页面栈，确保所有本地化文案使用新语言。
