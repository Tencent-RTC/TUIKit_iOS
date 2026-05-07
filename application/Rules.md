# Swift UIKit开发规范

## 架构规范
功能开发使用**Store**架构模式实现指南
### 核心概念
- State：状态数据，通常是struct，描述组件在某一时刻的完整UI状态。
- Store：状态管理器，负责管理状态数据，提供状态数据的读写接口，并通知状态变化。职责如下：1、持有 current state；2、暴露修改状态的方法 (Methods/Functions)；3、处理业务逻辑和副作用 (API 请求）；
- View：视图组件，组件对外暴露，负责渲染状态数据，并响应用户交互事件。

### 数据流向
- View 监听 Store 的状态变化。
- 用户在 View 产生交互，调用 Store 的方法。
- Store 执行业务逻辑（如网络请求），更新 State。
- State 变更触发 View 重新渲染。

### 模式示例
1. 状态定义

```swift
public struct XxxState {
    public var property1: Type1 = defaultValue
    public var property2: Type2 = defaultValue
    // ...
}
```

2. 事件定义（可选）

```swift
public enum XxxEvent {
    case event1(param1: Type1, param2: Type2)
    case event2(message: String)
    // ...
}
```

3. Store 实现
```swift
import RTCCommon

public class XxxStore {
    // 状态发布器
    public let observerState: ObservableState<XxxState> = .init(initialState: XxxState())
    // 读取瞬时状态
    var state: XxxState {
        observerState.state
    }
    
    // 事件发布器（可选）
    public let xxxEventPublisher: PassthroughSubject<XxxEvent, Never> = .init()
    
    // 对外接口
    public func methodName(param: Type, completion: CompletionClosure?) {
    }
}
```

4、UI层订阅store数据
```swift
class demoView {
    var cancellables = Set<AnyCancellable>()
    let store: XxxStore 
    store.observerState
        .subscribe(StateSelector(keyPath: \XxxState.property1))
        .sink { value in
            // 更新UI
        }
    }
    .store(in: &cancellables)
}
```

## 目录规范
每个功能页面的目录的物理结构要映射逻辑架构，标准结构树如下：
```
{FeatureName}/                    <-- 模块根目录
├── {FeatureName}View.swift       <-- [Entry] 模块入口视图，组装 SubViews
├── Store/                        <-- [Logic] 状态管理层
│   ├── {FeatureName}Store.swift  <-- 业务逻辑与方法 (优先复用 AtomicXCore)
│   └── {FeatureName}State.swift  <-- 状态定义 (Struct)
├── SubViews/                     <-- [UI] 拆分的子视图 (扁平化管理)
│   └── ...
└── Utils/                        <-- [Optional] 仅限该模块内部使用的工具/Model定义等
    └── ...
```

## Xcode 工程文件同步规范
当发生以下文件操作时，**必须**同步修改 Xcode 工程文件（`.xcodeproj/project.pbxproj`）中的引用路径，确保工程可以正常编译：
- **新增文件**：在 `PBXFileReference` 中添加文件引用，在对应的 `PBXGroup` 中添加子项，并在 `PBXBuildFile` / `PBXSourcesBuildPhase`（源码）或 `PBXResourcesBuildPhase`（资源）中添加编译条目。
- **删除文件**：从 `PBXFileReference`、`PBXGroup`、`PBXBuildFile`、`PBXSourcesBuildPhase` / `PBXResourcesBuildPhase` 中移除所有相关条目。
- **重命名 / 移动文件**：更新 `PBXFileReference` 中的 `path`、`PBXGroup` 中的引用名称，以及 `PBXBuildFile` 中的注释名称。

> ⚠️ 忘记同步工程文件是最常见的编译失败原因之一，每次文件变更后请务必检查 `project.pbxproj` 是否已同步更新。

## 模块文档规范
每个独立模块（如 `login`、`language` 等）都需要在模块根目录下维护一个 `README.md` 文件，用于描述该模块的功能与用法。README 应包含以下内容：
- **模块简介**：模块的定位与核心职责
- **对外接口**：公开的 API 及使用示例
- **目录结构**：模块内部文件组织
- **依赖关系**：模块依赖的外部库/框架
- **架构要点**：关键设计决策说明

> ⚠️ **更新要求**：在对模块进行代码变更后，必须同步检查并更新该模块的 `README.md`，确保文档与代码保持一致。

## 页面与视图开发规范
新增的页面在 didMoveToWindow 中触发初始化流程，必须实现以下四个标准方法：
```
class testView: UIView {
    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy() // 第一步：构建层级
        activateConstraints()    // 第二步：设置约束
        bindInteraction()        // 第三步：绑定事件/状态
        setupViewStyle()         // 第四步：初始样式
        isViewReady = true
    }

    // MARK: - UI Lifecycle Methods (必须实现)

    /// 仅负责 addSubview 操作，构建视图层级树
    func constructViewHierarchy() {
        // ...
    }

    /// 仅负责布局约束代码 (SnapKit / AutoLayout)
    func activateConstraints() {
        // ...
    }

    /// 负责添加 Target-Action 和 订阅 Store 状态
    func bindInteraction() {
        // ...
    }

    /// 处理初始化的静态样式（圆角、阴影等），禁止硬编码，需使用 DesignToken
    func setupViewStyle() {
        // ...
    }
}
```