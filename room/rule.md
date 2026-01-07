# TUIRoomKit iOS V2 - AI 代码生成规则

[![Platform](https://img.shields.io/badge/platform-iOS-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/swift-5.0-orange.svg)](https://swift.org/)

> **重要说明**: 本文档是为AI工具设计的代码生成规则，用于指导AI生成符合项目规范的代码。

## 🤖 AI代码生成核心原则
1. **UI组件化设计原则（最高优先级）**: 将复杂View拆分为细粒度的小组件，采用搭积木式设计
   - 每个组件职责单一、功能独立、可自由组合
   - 便于后期根据需求定制和扩展

2. **字符串国际化**: 绝对禁止硬编码字符串，必须在资源文件中配置多语言，暂时支持中文、英文多语言

3. **响应式架构**: ViewController → View ↔ Store（双向响应式绑定，无ViewModel层）

4. **布局规范**: 优先使用SnapKit库，实现自动化布局

5. **命名规范**: 类名前缀为 `Room` + 模块名 + 功能类型

6. **代码质量**: 使用SwiftLint强制执行，符合Apple Swift Style Guide

7. **主题适配**: 所有视图都需要使用RoomThemeManager.swift进行Color,Font的适配，支持苹果的 Light/Dark 模式自动适配

## 📂 目录结构
```
├── rule.md 代码规范文档 用于让AI工具理解项目结构和代码规范
├── .swiftlint.yml SwiftLint 配置文件
├── TUIRoomKit.podspec TUIRoomKit 集成文件
├── Resources 资源文件目录
│   ├── Localized 本地化文件目录
│   │   └── TUIRoomKitLocalized.xcstrings 本地化资源文件
│   └── TUIRoomKit.xcassets 图片资源文件管理
│       ├── avatar_placeholder.imageset 头像占位图
│       ├── back_arrow.imageset 返回箭头
│       ├── camera_close.imageset 摄像头关闭图标
│       ├── camera_open.imageset 摄像头开启图标
│       └── ... 其他图标资源
└── Source 源代码目录
    ├── RoomCreateViewController.swift 创建房间控制器
    ├── RoomHomeViewController.swift 首页控制器
    ├── RoomJoinViewController.swift 加入房间控制器
    ├── RoomMainViewController.swift 房间主页面控制器
    ├── Base 基础模块目录
    │   ├── Extension 扩展模块目录
    │   │   └── Roomparticipant+Extension.swift 参与者扩展
    │   ├── Localized 本地化模块目录
    │   │   ├── ErrorLocalized.swift 错误信息本地化
    │   │   └── TUIRoomKitLocalized.swift 本地化加载器
    │   ├── Log 日志模块目录
    │   │   └── RoomKitLog.swift 日志工具类
    │   └── UI 基础UI组件目录
    │       ├── BasePanel.swift 基础面板组件
    │       ├── BaseView.swift 基础视图协议
    │       ├── RoomActionSheet.swift 底部操作面板组件
    │       ├── RoomIconButton.swift 图标按钮组件
    │       ├── RoomToast.swift 吐司提示组件
    │       ├── RouterContext.swift 路由上下文协议
    │       └── Utils 工具模块目录
    │           ├── ResourceLoader.swift 资源加载器
    │           └── RoomThemeManager.swift 主题管理器，所有视图都需要使用该类进行Color,Font的适配
    └── View 视图模块目录
        ├── RoomCreateView.swift 创建房间视图
        ├── RoomHomeView.swift 首页视图
        ├── RoomJoinView.swift 加入房间视图
        ├── RoomMainView.swift 房间主页面视图
        └── Main 房间主页面子组件目录
            ├── ParticipantListView.swift 参与者列表视图
            ├── ParticipantManagerView.swift 参与者管理视图
            ├── RoomBottomBarView.swift 房间底部工具栏视图
            ├── RoomChangeNicknameView.swift 修改昵称视图
            ├── RoomInfoView.swift 房间信息视图
            ├── RoomTopBarView.swift 房间顶部栏视图
            ├── RoomView.swift 房间视图容器
            └── RoomView 房间视图子组件目录
                ├── RoomViewCell.swift 房间视图单元格
                └── RoomViewFlowLayout.swift 房间视图流式布局
```

## 📝 架构设计规范
### AtomicX 架构（基于 AtomicXCore）

**重要说明**: 本项目采用基于 **AtomicXCore** 的状态驱动架构，实现单向数据流和响应式UI更新。

**核心原则**：
- **应用层**：只负责UI和交互，不维护业务状态
- **引擎层**：提供所有业务逻辑、状态管理和数据接口

#### 架构分层

```
┌─────────────────────────────────────────────────────────────┐
│ 应用层 (TUIRoomKit V2)                                       │
│ - ViewController: 页面生命周期、导航控制                       │
│ - View: UI展示、用户交互、订阅State/Event                      │
└─────────────────────────────────────────────────────────────┘
                            ↓ 调用 & 订阅
┌─────────────────────────────────────────────────────────────┐
│ 引擎层 (AtomicXCore)                                         │
│ - RoomStore: 房间生命周期管理（创建、加入、离开、预约）            │
│ - RoomParticipantStore: 成员管理（角色、权限、设备控制）         │ 
│ - RoomParticipantView: 成员音视频渲染组件                      │
│ - State: 不可变状态数据（RoomState, RoomParticipantState）     │
│ - EventPublisher: 事件发布（房间事件、成员事件、设备事件等）       │
└─────────────────────────────────────────────────────────────┘
```

#### 数据流向

##### 1️⃣ State订阅流程（状态驱动UI更新）
```
┌─────────────┐   用户交互    ┌──────────────────────┐
│   用户操作   │ ──────────>  │   View (UI层)        │
│ (点击/输入)  │              │  - handleAction()    │
└─────────────┘              └───────────┬──────────┘
                                         │
                             ① 直接调用Store方法
                                         │
                                         ▼
                              ┌──────────────────────┐
                              │  Store (状态管理)     │
                              │ RoomStore            │
                              │  - createAndJoin()   │
                              │  - joinRoom()        │
                              │ ParticipantStore     │
                              │  - toggleMic()       │
                              │  - kickUser()        │
                              └───────────┬──────────┘
                                         │
                               ② 更新State
                                         │
                                         ▼
                              ┌──────────────────────┐
                              │   State (数据)       │
                              │  - roomListState     │
                              │  - participantState  │
                              │  - renderState       │
                              └───────────┬──────────┘
                                         │
                          ③ 触发订阅回调（通知State变化）
                                         │
                                         ▼
                              ┌──────────────────────┐
                              │   View (UI层)        │
                              │  - updateUI()        │
                              │  - 刷新界面           │
                              └──────────────────────┘
```

##### 2️⃣ Event订阅流程（事件驱动处理）
```
                              ┌──────────────────────┐
                              │  Store (状态管理)     │
                              │                      │
                              │  业务逻辑执行中...    │
                              └───────────┬──────────┘
                                         │
                          ④ 触发业务事件(Event)
                                         │
                                         ▼
                              ┌──────────────────────┐
                              │  EventPublisher      │
                              │  - onUserJoined      │
                              │  - onUserLeft        │
                              │  - onError           │
                              │  - onNetworkChanged  │
                              └───────────┬──────────┘
                                         │
                          ⑤ 发布事件通知
                                         │
                                         ▼
                              ┌──────────────────────┐
                              │   View (UI层)        │
                              │  - handleEvent()     │
                              │  - 显示Toast/弹窗     │
                              │  - 触发动画           │
                              └──────────────────────┘
```

**State vs Event 区别**：
- **State（状态）**：描述"是什么"，用于UI渲染（如成员列表、麦克风状态）
- **Event（事件）**：描述"发生了什么"，用于一次性响应（如成员加入提示、错误弹窗）

**详细流程**：
1. **用户交互** → 用户在View上进行操作（点击按钮、输入文本等）
2. **View调用Store** → View直接调用Store提供的业务方法（如`createAndJoinRoom()`, `toggleMicrophone()`）
3. **Store更新State** → Store内部修改State数据
4. **触发订阅回调** → State变化触发所有订阅者的回调函数
5. **View刷新UI** → View在回调中接收新State，更新界面显示
6. **Store发布Event** → 业务执行过程中触发事件（如成员加入、错误发生）
7. **View处理Event** → View订阅EventPublisher，接收事件并响应（如显示Toast、播放动画）

## 🎯 标准代码模板
#### ViewController 模板 

> **重要说明**: 所有自定义的 UIViewController 必须遵守 RouterContext 协议

```swift
class RoomXXXViewController: UIViewController, RouterContext {
    // MARK: - Properties
    private lazy var rootView: RoomXXXView = {
        let view = RoomXXXView()
        view.routerContext = self
        return view
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()
        setupStyles()
    }
    
    // MARK: - Setup Methods
    private func setupViews() {
        // 添加视图层级关系
    }

    private func setupConstraints() {
        // 添加视图布局约束
    }
    
    private func setupStyles() {
       // 添加视图样式风格
    }
}
```

#### View 模板

> **重要说明**: 所有自定义的 View 必须遵守 BaseView 协议

```swift
class RoomXXXView: UIView, BaseView {
    // MARK: - BaseView Properties
    weak var routerContext: RouterContext?

    private var cancellables = Set<AnyCancellable>()

    // 持有RoomStore引用
    private let roomXXXStore = RoomXXXStore.shared

    // MARK: - UI Components
    private let createButton = UIButton(type: .system)
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        subscribeState()
        subscribeEvents()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - BaseView Implementation
    func setupViews() {
       // 添加视图层级关系
    }
    
    func setupConstraints() {
       // 添加视图布局约束
    }
    
    func setupStyles() {
       // 添加视图样式风格
    }
    
    func setupBindings() {
        // 设置视图数据绑定及事件绑定
    }
}
extension RoomXXXView { 
     // 订阅State变化（数据驱动UI）
    private func subscribeState() {
        roomXXXStore.state.subscribe { [weak self] state in
            guard let self = self else { return }
            // State变化时自动调用此回调
            updateUI(with: state)
        }
    }
    
    // 订阅Event事件（事件驱动响应）
    private func subscribeEvents() {
        // 监听房间创建成功事件
		 roomXXXStore.eventPublisher.onRoomCreated
            .sink { [weak self] roomInfo in
                guard let self = self else { return }
                handleRoomCreated(roomInfo)
            }
            .store(in: &cancellables)
        
        // 监听错误事件
        roomXXXStore.eventPublisher.onError
            .sink { [weak self] error in
                guard let self = self else { return }
                showError(error)
            }
            .store(in: &cancellables)
    }
    
    // State变化时刷新UI
    private func updateUI(with state: RoomXXXState) {
        // 更新房间列表
        roomTableView.reloadData()
        
        // 更新当前房间信息
        if let currentRoom = state.currentRoom {
            roomNameLabel.text = currentRoom.roomName
            memberCountLabel.text = "\(currentRoom.memberCount)人"
        }
    }
    
    // Event响应处理
    private func handleRoomCreated(_ roomInfo: RoomInfo) {
        // 显示成功提示
        showToast("房间创建成功")
        // ✅ 正确：使用 RouterContext 进行路由跳转
        let createVC = RoomCreateViewController()
        routerContext?.push(createVC, animated: true)
    }

}

extension RoomXXXView {
    // MARK: - Actions
    @objc private func createButtonTapped() {
        let params = RoomParams(
            roomName: roomNameTextField.text,
            isMicOn: micSwitch.isOn,
            isCameraOn: cameraSwitch.isOn
        )
        // 直接调用Store业务方法
        roomXXXStore.createAndJoinRoom(params: params)
    }
}
```

## 📝 UI开发规范
### 📝 强制性要求

#### 🚫 绝对禁止
- **硬编码字符串**: 所有文字必须在TUIRoomKitLocalized.xcstrings中配置
- **硬编码颜色**: 所有颜色必须在RoomThemeManager.swift中定义
- **嵌套布局**: View嵌套最多3层, 布局使用SnapKit库

#### ✅ 必须遵循
- **lazy延迟初始化**: 所有UI组件属性使用lazy
- **多语言支持**: 提供中英文多语言版本

### 🌐 国际化字符串使用规范

#### 核心原则
- **绝对禁止硬编码字符串**: 所有用户可见的文字必须通过国际化系统管理
- **统一使用方式**: 项目统一使用 `.localized` 扩展方法获取国际化字符串
- **集中定义**: 在文件级别的 extension 中定义常量，提高可维护性

#### ✅ 正确的使用方式

##### 1. 基础用法 - 使用 `.localized` 扩展

```swift
// ✅ 正确：在文件级别 extension 中定义常量（推荐）
fileprivate extension String {
    static let welcomeMessage = "Welcome to TUIRoomKit V2".localized
    static let joinRoom = "Join room".localized
    static let enterRoomID = "Enter roomID".localized
}

// 使用定义的常量
titleLabel.text = .welcomeMessage
button.setTitle(.joinRoom, for: .normal)
placeholder = .enterRoomID
```

##### 2. 带参数替换的字符串

```swift
// ✅ 正确：
// 步骤1: 先在文件级别 extension 中定义常量
fileprivate extension String {
    static let transferHost = "Transfer the host to xxx"
}

// 步骤2: 使用 `.localizedReplace()` 方法替换参数
let message = .transferHost.localizedReplace("Alice")
titleLabel.text = message
```

##### 3. 在 fileprivate extension 中集中定义（最佳实践）

```swift
class RoomJoinView: UIView {
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = .joinRoom  // 使用常量
        return label
    }()
}

// 文件末尾集中定义
fileprivate extension String {
    static let joinRoom = "Join room".localized
    static let enterRoomID = "Enter roomID".localized
    static let audio = "Audio".localized
}
```

#### ❌ 错误的使用方式

```swift
// ❌ 禁止：硬编码字符串
titleLabel.text = "欢迎使用 TUIRoomKit V2"
button.setTitle("Join Room", for: .normal)

// ❌ 禁止：使用旧的静态方法（已废弃）
let text = TUIRoomKitLocalized.localizedString("Welcome")
```

#### 国际化字符串扩展 API

```swift
extension String {
    /// 获取本地化字符串
    var localized: String
    
    /// 获取带默认值的本地化字符串
    func localized(defaultValue: String = "") -> String
    
    /// 获取带参数替换的本地化字符串（替换 "xx"）
    func localizedReplace(_ replace: String) -> String
    
    /// 获取带多个参数替换的本地化字符串
    func localizedReplace(_ replace_xxx: String, _ replace_yyy: String) -> String
}
```

### UI 协议定义

#### RouterContext 协议

```swift
protocol RouterContext: AnyObject {
    /// 当前导航控制器
    var navigationController: UINavigationController? { get }
    
    /// 推入新的视图控制器
    func push(_ viewController: UIViewController, animated: Bool)
    
    /// 弹出当前视图控制器
    @discardableResult
    func pop(animated: Bool) -> UIViewController?
    
    /// 弹出到根视图控制器
    @discardableResult
    func popToRoot(animated: Bool) -> [UIViewController]?
    
    /// 模态展示视图控制器
    func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)?)
    
    /// 关闭模态视图控制器
    func dismiss(animated: Bool, completion: (() -> Void)?)
}

// 默认实现（仅对 UIViewController 有效）
extension RouterContext where Self: UIViewController {
    func push(_ viewController: UIViewController, animated: Bool = true) {
        navigationController?.pushViewController(viewController, animated: animated)
    }
    
    @discardableResult
    func pop(animated: Bool = true) -> UIViewController? {
        return navigationController?.popViewController(animated: animated)
    }
    
    @discardableResult
    func popToRoot(animated: Bool = true) -> [UIViewController]? {
        return navigationController?.popToRootViewController(animated: animated)
    }
    
    func present(_ viewController: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        present(viewController, animated: animated, completion: completion)
    }
    
    func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        dismiss(animated: animated, completion: completion)
    }
}
```

**重要说明**：

- `AnyObject` 约束确保只有类可以遵守此协议
- `where Self: UIViewController` 确保默认实现只对视图控制器有效
- `@discardableResult` 允许忽略返回值（pop 操作）
- 默认参数 `animated: Bool = true` 提供便利调用

#### BaseView 协议

```swift
protocol BaseView: AnyObject {
    /// 路由上下文，用于触发路由跳转（弱引用避免循环引用）
    weak var routerContext: RouterContext? { get set }
    
    /// 设置子视图
    func setupViews()
    
    /// 设置约束
    func setupConstraints()
    
    /// 设置样式
    func setupStyles()
    
    /// 设置数据绑定
    func setupBindings()
}

// 默认实现
extension BaseView {
    func setupViews() {}
    func setupConstraints() {}
    func setupStyles() {}
    func setupBindings() {}
}
```

**重要说明**：

- `AnyObject` 约束确保只有类可以遵守（UIView 是类）
- `routerContext` 必须声明为 `weak`，实现时必须使用 `weak var`
- 四个 setup 方法提供默认空实现，可按需重写
- 推荐在 `init` 中按顺序调用：setupViews → setupConstraints → setupStyles → setupBindings

## 🔄 生命周期管理

### 订阅模式
- **订阅时机**: View 的 init 中订阅 Store 中 State 数据和 Event 事件
- **用户操作**: 直接调用 Store 方法修改数据

### 代码组织（MARK 注释, 所有AI生成的注释必须是英文注释）
```swift
// MARK: - Properties
// MARK: - Lifecycle
// MARK: - Setup Methods
// MARK: - Public Methods
// MARK: - Actions
// MARK: - Private Methods
```
## 🎯 组件化设计示例

### 组件设计原则
- 每个组件职责单一、功能独立
- 组件可独立使用、不依赖父容器
- 主View仅负责组装和布局
- 根据需求灵活添加或移除组件

## 🚫 严格禁止的操作

### 字符串硬编码（最高优先级禁止）
- ❌ 代码中出现任何硬编码字符串文字
- ❌ `button.text = "加入房间"` 或 `"Create Room"` 等直接字符串
- ❌ Toast、Dialog、Log中使用硬编码文字


### 颜色硬编码（错误的颜色使用方式 - 严禁直接使用）

```swift
func wrongSetupStyles() {
    // ❌ 禁止：直接使用 UIColor
    view.backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0)
    
    // ❌ 禁止：直接使用十六进制颜色
    titleLabel.textColor = UIColor(hex: "#333333")
    
    // ❌ 禁止：使用系统颜色（除非在 RoomThemeManager 中定义）
    button.backgroundColor = .systemBlue
    
    // ❌ 禁止：硬编码颜色值
    view.layer.borderColor = UIColor.black.cgColor
}
```

**允许的例外情况**（极少数场景）：
- `UIColor.clear` - 透明色
- `UIColor.white` - 纯白色（用于按钮文字等）
- `UIColor.black` - 纯黑色（用于特殊场景）

**其他所有颜色必须通过 RoomThemeManager 定义使用。**

## ✅ 必须遵守的操作
### 内存管理
- **RouterContext 引用**：View 中的 `routerContext` 必须使用 `weak` 修饰
- **协议约束**：RouterContext 和 BaseView 都继承自 `AnyObject`，确保只能被类遵守
- **闭包捕获**：使用 `[weak self]` 捕获列表避免循环引用, 避免使用 `self` 直接访问

```swift
// ✅ 正确的内存管理
class MyView: UIView, BaseView {
    weak var routerContext: RouterContext?  // 必须 weak
    
    func fetchData() {
        someService.fetchData { [weak self] result in
            guard let self = self else { return }
            self.handleResult(result)
        }
    }
}

// ❌ 错误的内存管理
class WrongView: UIView {
    var routerContext: RouterContext?  // ❌ 缺少 weak，会导致循环引用
}
```

##  代码检查清单
### 架构检查
- [ ] 视图控制器正确遵守 `RouterContext` 协议
- [ ] 自定义视图正确遵守 `BaseView` 协议
- [ ] 为子视图正确设置 `routerContext` 引用
- [ ] View 路由跳转使用 `routerContext?.push/pop/present/dismiss`
- [ ] **禁止**直接访问 `navigationController` 进行路由操作

### 颜色使用检查
- [ ] **所有颜色**通过 `RoomThemeManager.shared` 获取
- [ ] 新增颜色前先在 `RoomThemeManager` 中定义
- [ ] **禁止**直接使用 `UIColor()` 创建颜色
- [ ] **禁止**使用 `.systemBlue`、`.systemRed` 等系统颜色
- [ ] 仅在特殊场景使用 `.clear`、`.white`、`.black`

### 内存管理检查
- [ ] View 中的 `routerContext` 使用 `weak` 修饰
- [ ] 协议遵守 `AnyObject` 约束（仅限类）
- [ ] 闭包中使用 `[weak self]` 捕获列表
- [ ] Delegate 属性使用 `weak` 修饰
- [ ] 避免强引用循环（View ↔ ViewController）

### 代码质量检查
- [ ] 遵循命名规范（PascalCase/camelCase）
- [ ] 使用 MARK 注释组织代码结构
- [ ] 使用 SnapKit 进行布局
- [ ] 代码中的注释必须是英文注释
- [ ] 代码中字面量（Magic Value/魔法值）进行集中管理
- [ ] 为可选值使用 `guard` 或 `if let` 解包

### 实现完整性检查
- [ ] 实现 `setupViews()`
- [ ] 实现 `setupConstraints()`
- [ ] 实现 `setupStyles()`
- [ ] 实现 `setupBindings()`
- [ ] 在 `init` 中按顺序调用上述方法

## 🔒 安全和规范
- **安全规范**: 不得在代码中硬编码密钥、证书等敏感信息，使用安全存储方案
- **内存安全**: 注意循环引用，合理使用weak引用，及时释放观察者和定时器
- **线程安全**: UI操作必须在主线程，网络操作在后台线程，使用GCD或async/await管理并发
- **代码审查**: 通过MR进行代码审查，遵循团队编码规范，运行代码格式化脚本

## 📚 集成方式

### 1. 此目录下的TUIRoomKit的运行调试开发依赖于App-UIKit工程，App-UIKit工程目录为： client_uikit/atomic-x/ios/application/App-UIKit.xcworkspace

### 2. 在App-UIKit工程中，打开client_uikit/atomic-x/ios/application/App-UIKit/Podfile文件，在target 'App-UIKit' do 下添加如下代码：

```ruby
pod 'TUIRoomKit', :path => '../room_v2/TUIRoomKit'
```

### 3. 在App-UIKit工程中，Podfile 文件目录下执行 pod install 命令，安装TUIRoomKit依赖库

### 4. 执行完成后，打开App-UIKit.xcworkspace文件，编译运行App-UIKit工程，即可看到TUIRoomKit集成效果

## 📚 使用方式备注
- 工具类相关方法请在当前工具类中添加使用示例注释
- 视图类相关不需要添加使用示例注释

**开发团队**: Tencent Cloud  
**最后更新**: 2025-11-12
