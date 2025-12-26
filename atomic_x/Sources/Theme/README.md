# Runtime Theme & Design Tokens

运行时可切换的主题与设计Token系统（Swift + UIKit）

## 概述

本模块提供了一个完整的设计Token系统，支持：

- ✅ **US1**: 运行时全局主题切换（light/dark），设备级持久化
- ✅ **US2**: 组件级外观定制，使用token资源
- ✅ **US3**: 自定义token集不受主题切换影响

## 快速开始

### 1. 基础使用 - 切换主题

```swift

// 切换到深色主题
ThemeStore.shared.setTheme(.darkTheme)

// 切换到浅色主题
ThemeStore.shared.setTheme(.lightTheme)
```

### 2. 订阅主题变化

```swift
import Combine

var cancellables = Set<AnyCancellable>()

ThemeStore.shared.$state
    .receive(on: DispatchQueue.main)
    .sink { themeState in
        print("Current theme: \(themeState.currentTheme.displayName)")
        // 更新UI
    }
    .store(in: &cancellables)
```

### 3. 创建主题化组件

```swift
let liveButtonAppearance = LiveButtonAppearance()
let customButton = LiveThemedButton(title: "Custom", appearance: liveButtonAppearance)

```

### 4. 注册自定义Token, 并自定义UI

```swift
// 创建自定义token集
let CustomTokenSet = DesignTokenSet(id: "custom")

// 注册自定义token集
ThemeStore.shared.registerCustomTokenSet(brandTokenSet)

// 创建一个与自定义 Token 集绑定的组件
let appearance = LiveButtonAppearance(designToken: ThemeStore.shared.getCustomTokenSet(byId: "custom")
let stableButton = LiveThemedButton(
    title: "Brand Button",
    appearance: appearance
)

```

## 架构

### 核心组件

```
ThemeStore (Singleton)
├── @Published state: ThemeState
├── setTheme(_:) - 设置全局主题（带去抖）
├── registerCustomTokenSet(_:) - 注册自定义token集
└── getCustomTokenSet(byId:) - 查询自定义token集

Theme
├── id: String
├── displayName: String
└── tokens: DesignTokenSet

DesignTokenSet
├── id: String
├── displayName: String
├── color: ColorTokens
├── space: SpaceTokens
├── borderRadius: BorderRadiusToken
├── typography: TypographyToken
├── shadows: Shadows
└── isEnabled: Bool
```

### Token类型

#### ColorTokens
- **BrandColorToken**: HSB调色板（Ant Design算法）
  - 10级色阶: color1（最浅）→ color6（基础）→ color10（最深）
- **NeutralColorToken**: HCT中性灰（TDesign算法）
  - 14级灰阶: gray1-gray14，基于12%基色:88%灰色混合
- **BlackColorToken**: 8级黑色透明度
- **WhiteColorToken**: 7级白色透明度

#### SpaceTokens
- space4, space8, space16, space20, space24, space32, space40

#### BorderRadiusToken
- none, radius4, radius8, radius12, radius16, radius20, radiusCircle

#### TypographyToken
- h1, h2, h3, body, caption（含fontSize, fontWeight, lineHeight）

#### Shadows
- smallShadow, mediumShadow

## 特性

### 设备级持久化
- 用户手动设置的主题会持久化到UserDefaults
- 默认跟随系统外观
- 用户手动设置后停止跟随系统

### 去抖处理
- 300ms内的多次主题切换会自动合并
- 防止频繁UI更新导致性能问题

### 布局稳定性
- 主题切换过程中避免可见闪烁
- 使用CATransaction禁用隐式动画
- 满足SC-001、SC-002性能要求

### 单一来源约束
- 每个AppearanceConfig只能绑定一个DesignTokenSet
- 禁止混合多个token来源
- 无效引用自动回退并记录日志

## 性能指标

- ✅ UI更新延迟 ≤ 300ms（95%情况）
- ✅ 交互不中断 ≥ 99%
- ✅ 布局抖动 < 1个可见跳跃
- ✅ 无效token引用100%可审计

## 测试

运行单元测试：

```bash
# 在Xcode中运行
# Product > Test (⌘U)

# 或使用xcodebuild
xcodebuild test -scheme ThemeModule -destination 'platform=iOS Simulator,name=iPhone 15'
```

测试覆盖：
- ✅ ThemeStore状态管理
- ✅ 主题切换去抖
- ✅ 自定义token集注册/查询
- ✅ Color token生成算法
- ✅ Token验证逻辑

## 文件结构

```
atomic-x/ios/theme/
├── ThemeStore.swift              # 全局主题Store
├── Models.swift                  # Theme, ThemeState
├── UserDefaultsHelper.swift      # 持久化工具
├── AppearanceConfig.swift        # 外观配置
├── Tokens/
│   ├── DesignTokenSet.swift     # Token集合
│   ├── ColorTokens.swift        # 颜色tokens
│   ├── SpaceTokens.swift        # 间距tokens
│   ├── BorderRadiusToken.swift  # 圆角tokens
│   ├── TypographyToken.swift    # 字体tokens
│   ├── Shadows.swift            # 阴影tokens
│   └── BuiltInThemes.swift      # 内置主题
├── Components/
│   └── MyThemedButton.swift     # 示例主题化组件
└── Examples/
    └── ThemeExampleViewController.swift

tests/ios/unit/
├── ThemeStoreTests.swift
└── ColorTokensTests.swift
```

## 规范文档

完整规范请查看：`/specs/001-runtime-theme-tokens/`

- `spec.md` - 功能规范
- `plan.md` - 实施计划
- `data-model.md` - 数据模型
- `contracts/api.md` - API契约
- `tasks.md` - 任务列表

## 许可

Copyright © 2025 Tencent. All rights reserved.
