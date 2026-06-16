//
//  LoginEntry.swift
//  login
//
//  登录模块唯一对外接口（统一入口 + 统一出口）
//

import Combine
import ImSDK_Plus
import Toast_Swift
import UIKit

/// 登录方式枚举 — 外部告诉登录模块"用什么方式登录"
public enum LoginMode: Int {
    /// 手机号验证码登录（页面内可切换至 iOA）
    case phoneVerify = 1
    
    /// 邮箱验证码登录（页面内可切换至 iOA）
    case emailVerify = 2
    
    /// iOA 企业登录
    case ioaAuth = 3
    
    /// 邀请码登录
    case inviteCode = 4
    
    /// Debug 登录（仅调试包可用）
    case debugAuth = 5
    
    /// 登录列表
    case menu = 6
}

/// 登录模块唯一对外接口
///
/// 使用方式：
///   1. `LoginEntry.shared.initialize(...)` — App 启动时调用，配置参数
///   2. `LoginEntry.shared.launch(mode:completion:)` — 拉起登录（如果 initialize 尚未完成会自动等待）
///
/// 自动登录逻辑：
///   - 如果之前登录成功过，`launch` 内部会先静默尝试 Token 自动登录
///   - 自动登录成功 → 直接通过 completion 回调，返回的 VC 可不展示
///   - 自动登录失败 → 清除登录记录，走正常 UI 登录流程
///
/// 对外承诺：
///   - 无论内部经历了多少次页面跳转（phone → iOA → 返回 phone → 登录成功），
///     最终只会通过 completion 回调一次结果
///   - 外部不需要关心内部的导航、子模块、Store 等任何细节
private let loggedInKey = "com.rtcube.login.lastLoginMode"

public final class LoginEntry: NSObject {
    public static let shared = LoginEntry()
    override private init() {}
    
    // MARK: - 登录用户信息
    
    /// 当前已登录用户的 userModel，未登录或登出后为 nil
    @Published public internal(set) var userModel: UserModel?
    
    // MARK: - 沙盒登录状态
    
    /// 是否曾经登录成功过
    public var hasLoggedIn: Bool {
        loggedInMode != nil
    }
    
    public var loggedInMode: LoginMode? {
        let value = UserDefaults.standard.integer(forKey: loggedInKey)
        return LoginMode(rawValue: value)
    }

    private func markLoggedIn(mode: LoginMode) {
        // 仅在自动登录开关开启时存储 loggedInMode，关闭时移除，下次 launch() 不会触发自动登录
        if isAutoLoginEnabled {
            UserDefaults.standard.set(mode.rawValue, forKey: loggedInKey)
            LoginLogger.Login.info("markLoggedIn persisted mode=\(mode)")
        } else {
            UserDefaults.standard.removeObject(forKey: loggedInKey)
            LoginLogger.Login.info("markLoggedIn auto-login OFF, cleared mode key")
        }
        userInfoManager.startListener()
    }

    private func clearLoggedIn() {
        UserDefaults.standard.removeObject(forKey: loggedInKey)
        userInfoManager.stopListener()
        LoginLogger.Login.info("clearLoggedIn done")
    }
    
    // MARK: - 配置
    
    /// 登录模块配置（只读），由 `initialize()` 写入
    public private(set) var config: LoginConfig = .default
    
    /// 正式登录配置（只读）
    ///
    /// 由 `initialize()` 写入，始终保持初始化时传入的正式配置，不会被 `switchToDebugConfig()` 覆盖。
    /// 从 Debug 登录切回正式登录时，通过 `switchToPrimaryConfig()` 恢复。
    public private(set) var primaryConfig: LoginConfig = .default
    
    // MARK: - 外部注入（解耦壳工程依赖）
    
    /// UserSig 生成器（仅 Debug 登录使用）
    ///
    /// 壳工程在启动时注入，根据 identifier + sdkAppId + secretKey 生成 UserSig。
    /// 如果不注入，Debug 登录功能不可用。
    public var userSigGenerator: ((_ identifier: String, _ sdkAppId: Int, _ secretKey: String) -> String)?
    
    /// 隐私协议链接点击处理器
    ///
    /// 壳工程在启动时注入，当登录页面中的隐私/用户协议链接被点击时回调。
    /// 参数：
    ///   - linkType: 链接类型（"privacy" / "privacySummary" / "agreement"）
    ///   - viewController: 当前页面控制器，壳工程可通过其 navigationController push，或直接 present
    ///
    /// 如果不注入，点击协议链接不会有任何响应。
    public var privacyLinkHandler: ((_ linkType: String, _ viewController: UIViewController?) -> Void)?

    /// 隐私协议弹窗同意/不同意回调
    ///
    /// 首次登录弹窗中用户点击「同意」或「不同意」后触发。
    /// 壳工程可根据 `isAgree` 决定是否延迟初始化数据采集 SDK（Bugly、神策等）。
    public var onPrivacyAgreed: ((_ isAgree: Bool) -> Void)?
    
    /// 服务器环境切换回调（仅 Debug 菜单页可用）
    ///
    /// 壳工程在启动时注入，当用户在 DevLoginMenu 页面切换环境时回调。
    /// 外部根据 `ServerEnvironment` 执行对应的环境切换逻辑（如切换 baseUrl、重新初始化等）。
    ///
    /// 如果不注入，切换环境不会有任何响应。
    public var onEnvironmentChanged: ((_ environment: ServerEnvironment) -> Void)?
    
    /// 被动登出回调（Token 过期 / 被踢下线等非用户主动操作触发的登出）
    ///
    /// 壳工程在启动时注入，当登录模块检测到 Token 失效或被踢下线后，
    /// 内部会自动完成 logout 清理，然后通过此回调通知壳工程重新拉起登录页。
    ///
    /// 如果不注入，被动登出后不会自动拉起登录页。
    public var onPassiveLogout: (() -> Void)?

    /// Token / UserSig 过期回调（**仅**凭证失效事件，不含主动 logout）
    ///
    /// 触发时机（精确语义）：
    ///   - `LoginNetworkService.loginByToken` 自动登录失败（token 过期）
    ///   - `TUILoginListenerHandler.onUserSigExpired`（在线时 IM userSig 过期）
    ///
    /// 与 `onPassiveLogout` 的区别：
    ///   - `onPassiveLogout` 由 `userOverdueState == .loggedAndOverdue` 触发，
    ///     该状态机也会被 **用户主动 logout** 路径写入，语义上不能等同于"凭证过期"
    ///   - `onTokenExpired` 仅在确定的"凭证失效"事件源触发，可用于壳工程做与
    ///     "重新登录仪式"挂钩的副作用（如清除开屏动画播放记录、清理特定缓存等）
    ///
    /// 注意：触发本回调时不保证 `onPassiveLogout` 已经执行；两者各自独立、互不依赖。
    public var onTokenExpired: (() -> Void)?
    
    /// 测试环境的 baseUrl（可选）
    ///
    /// 由 `initialize(testBaseUrl:)` 传入。
    /// 当环境切换到 .test 时，`switchConfig` 会用此 URL 替换 config 中的 httpBaseUrl。
    public private(set) var testBaseUrl: String?
    
    /// Debug 登录专用配置（只读）
    ///
    /// 由 `initialize(debugSdkAppId:debugSecretKey:)` 写入。
    /// 进入 Debug 登录前，内部会自动用此配置重新 `applyConfig`，外部无需关心。
    public private(set) var debugConfig: LoginConfig?
    
    // MARK: - 初始化就绪状态
    
    /// initialize 是否已完成
    private var isInitialized = false
    
    /// launch 先于 initialize 完成时挂起的闭包队列
    private var pendingLaunchActions: [() -> Void] = []
    
    let debugAuthStore = DebugAuthStore()
    private var debugCancellable: AnyCancellable?
    
    private let userInfoManager = UserInfoManager()

    private(set) var currentEnvironment: ServerEnvironment = .production

    /// 是否已经执行过到测试环境的外部切换（EnvironmentOperation.switchEnvironment(testEnv: true) 被调用过）
    private(set) var hasAppliedTestEnvironment: Bool = false
    
    // MARK: - 对外方法
    
    /// 登录模块统一初始化（支持重复调用）
    ///
    /// 构建不可变的 `LoginConfig` 并存储在 `LoginEntry` 实例中，
    /// 模块内部通过 `LoginEntry.shared.config` 只读访问。
    ///
    /// **重复调用行为**：
    ///   - 如果当前已登录且 `sdkAppId` 发生变化，会先自动 logout（清除缓存 + IM 登出），
    ///     然后再应用新配置。
    ///   - 如果未登录或 sdkAppId 未变化，直接覆盖配置，同步返回。
    ///
    /// 初始化完成后，之前被 `launch()` 挂起的操作会自动执行。
    ///
    /// - Parameters:
    ///   - baseUrl: 服务端基础 URL（必须），如 `"https://demos.trtc.tencent-cloud.com/prod/"`
    ///   - sdkAppId: 本地调试用 SDKAPPID（默认 0，仅 isSetupService == false 时生效）
    ///   - secretKey: 本地生成 UserSig 的密钥（仅 Debug 登录使用，默认空字符串）
    ///   - debugSdkAppId: Debug 登录专用 SDKAPPID（可选）。传入后内部自动构建 `debugConfig`，
    ///     Debug 登录前会自动切换到此配置，无需外部注入闭包。
    ///   - debugSecretKey: Debug 登录专用 SecretKey（可选）。与 `debugSdkAppId` 配对使用。
    ///   - isSetupService: 是否使用正式后台服务（默认 true）
    ///   - apaasAppId: aPaaS 应用 ID（默认空字符串）
    ///   - testBaseUrl: 测试环境 baseUrl（可选）。传入后，切换到测试环境时会替换 config 中的 httpBaseUrl。
    ///   - ioaAppKey: iOA SDK AppKey（可选，传入后自动初始化 ITLogin SDK）
    ///   - ioaAppId: iOA SDK AppId（可选，传入后自动初始化 ITLogin SDK）
    public func initialize(
        baseUrl: String,
        testBaseUrl: String? = nil,
        sdkAppId: Int = 0,
        secretKey: String = "",
        debugSdkAppId: Int? = nil,
        debugSecretKey: String? = nil,
        isSetupService: Bool = true,
        apaasAppId: String = "",
        ioaAppKey: String? = nil,
        ioaAppId: String? = nil
    ) {
        // 注册 TUILogin 监听（被踢下线 / UserSig 过期 → UserOverdueLogicManager）
        TUILoginListenerHandler.shared.register()

        // 激活 IM 连接 settled 等待门
        // 必须早于 TUILogin.login 调用——首个 onConnectSuccess 在冷启动后会立刻投递，
        // 晚装 listener 会漏掉这次回调，使 IMConnectGate.waitOnce 只能依赖超时兜底。
        IMConnectGate.shared.activate()

        self.testBaseUrl = testBaseUrl

        let newConfig = LoginConfig(
            httpBaseUrl: baseUrl,
            isSetupService: isSetupService,
            sdkAppId: sdkAppId,
            apaasAppId: apaasAppId,
            secretKey: secretKey
        )
        
        // 构建 Debug 登录专用配置（如果传入了 debugSdkAppId）
        if let debugSdkAppId = debugSdkAppId {
            debugConfig = LoginConfig(
                httpBaseUrl: baseUrl,
                isSetupService: false,
                sdkAppId: debugSdkAppId,
                apaasAppId: apaasAppId,
                secretKey: debugSecretKey ?? secretKey
            )
        }
        
        // 初始化 iOA SDK（仅在传入 appKey 和 appId 时执行）
        #if LOGIN_FULL
        if let ioaAppKey = ioaAppKey, let ioaAppId = ioaAppId {
            IOAAuthManager.shared.setupIOA(appKey: ioaAppKey, appId: ioaAppId)
        }
        #endif
        
        // 判断是否需要 logout：已登录 + sdkAppId 变化
        let oldSdkAppId = config.sdkAppId
        let hasNetworkLoggedIn: Bool
        if let loggedInMode = loggedInMode {
            switch loggedInMode {
            case .phoneVerify, .emailVerify, .ioaAuth, .inviteCode:
                hasNetworkLoggedIn = true
            default:
                hasNetworkLoggedIn = false
            }
        } else {
            hasNetworkLoggedIn = false
        }
        let needsLogout = hasNetworkLoggedIn
            && oldSdkAppId != newConfig.sdkAppId
            && config != .default // 首次初始化无需 logout
        
        // **先同步更新 config**，确保后续代码（如 genTestUserSig / loginIM）
        // 立即读到最新配置，避免异步 logout 导致 config 延迟更新的时序问题。
        primaryConfig = newConfig
        applyConfig(newConfig)
        
        if needsLogout {
            debugPrint(" sdkAppId changed (\(oldSdkAppId) → \(newConfig.sdkAppId)), logging out before re-initialize")
            performLogout { [weak self] in
                self?.markInitialized()
            }
        } else {
            markInitialized()
        }
    }
    
    /// 拉起登录流程
    ///
    /// 如果 `initialize()` 尚未完成，`launch` 会自动挂起，待初始化完成后再执行。
    ///
    /// 如果之前登录成功过，会先静默尝试 Token 自动登录：
    ///   - 自动登录成功 → 直接回调 completion，返回的 VC 无需展示
    ///   - 自动登录失败 → 清除登录记录，继续走正常 UI 登录流程
    ///
    /// - Parameters:
    ///   - mode: 登录方式（必传），决定用什么方式登录
    ///   - completion: 登录结果回调（成功/失败/取消）— 这是唯一出口
    /// - Returns: 登录页面的 ViewController，由外部决定如何展示
    @discardableResult
    public func launch(
        mode: LoginMode,
        completion: @escaping (Result<LoginResult, LoginError>) -> Void
    ) -> UIViewController {
        #if !LOGIN_FULL
        if mode == .ioaAuth {
            completion(.failure(.ioaAuthFailed(
                message: "iOA login is not available in the open-source build"
            )))
            return UIViewController()
        }
        #endif
        
        let wrappedCompletion: (Result<LoginResult, LoginError>) -> Void = { [weak self] result in
            if case .success(let loginResult) = result {
                self?.userModel = loginResult.userModel
                self?.userInfoManager.updateSelfInfo(userModel: loginResult.userModel)
                self?.markLoggedIn(mode: loginResult.loginMode)
            }
            self?.navigator = nil
            #if LOGIN_FULL
            IOAAuthManager.shared.activeIOAViewController = nil
            #endif
            completion(result)
        }
        // 仅在从未切过测试环境时重置为正式；已切过测试则保持测试状态（需重启 App 才能回正式）
        if !hasAppliedTestEnvironment {
            currentEnvironment = .production
        }
        let navigator = LoginNavigator(completion: wrappedCompletion)
        navigator.onLoginModeChanged = { [weak self] mode in
            self?.switchConfig(for: mode)
        }
        navigator.onEnvironmentChanged = { [weak self] env in
            self?.currentEnvironment = env
        }
        navigator.onPrivacyAgreed = onPrivacyAgreed
        self.navigator = navigator
        let viewController = navigator.buildViewController(mode: mode)
        
        // 将 navigator 注册到 IOAAuthManager，接收票据回调
        #if LOGIN_FULL
        IOAAuthManager.shared.activeNavigator = navigator
        #endif
        
        let launchAction: () -> Void = { [weak self] in
            guard let self = self else { return }
            // 如果之前登录成功过，先尝试 Token 自动登录
            LoginLogger.Login.info("launchAction begin requestedMode=\(mode) persistedMode=\(loggedInMode.map { String(describing: $0) } ?? "nil")")
            if let loggedInMode = loggedInMode {
                // 自动登录时也需要根据上次的登录方式切配置
                // （menu 模式下 buildViewController 不会触发 onLoginModeChanged，
                //   而 initialize 总是重置为 primaryConfig，debugAuth 需要切回 debugConfig）
                switchConfig(for: loggedInMode, isAutoLogin: true)
                switch loggedInMode {
                case .phoneVerify, .emailVerify, .ioaAuth, .inviteCode:
                    performTokenAuth(originalMode: loggedInMode) { [weak self] result in
                        switch result {
                        case .success(let loginResult):
                            LoginLogger.Login.info("launchAction token-auth SUCCESS")
                            // 自动登录成功，直接回调
                            wrappedCompletion(.success(loginResult))
                        case .failure(let error):
                            LoginLogger.Login.warn("launchAction token-auth FAILED error=\(error), clearing cache")
                            self?.clearLoggedIn()
                            LoginManager.shared.removeLoginCache()
                            ProfileManager.shared.removeLoginCache()
                            completion(.failure(error))
                        }
                    }
                case .debugAuth:
                    debugAuthStore.login()
                    debugCancellable = debugAuthStore.resultPublisher.receive(on: RunLoop.main)
                        .sink { [weak self] result in
                            switch result {
                            case .success(let loginResult):
                                LoginLogger.Login.info("launchAction debug-auth SUCCESS")
                                wrappedCompletion(.success(loginResult))
                            case .failure(let err):
                                LoginLogger.Login.warn("launchAction debug-auth FAILED err=\(err), clearing cache")
                                self?.clearLoggedIn()
                                LoginManager.shared.removeLoginCache()
                                ProfileManager.shared.removeLoginCache()
                                completion(.failure(err))
                            }
                            self?.debugCancellable = nil
                        }
                default:
                    LoginLogger.Login.warn("launchAction unsupported loggedInMode=\(loggedInMode), skip auto-login")
                    break
                }
            }
        }

        if isInitialized {
            launchAction()
        } else {
            LoginLogger.Login.info("launch deferred (initialize not finished), queued in pendingLaunchActions")
            pendingLaunchActions.append(launchAction)
        }

        return viewController
    }
    
    /// 登出
    public func logout(completion: ((Result<Void, LoginError>) -> Void)? = nil) {
        performLogout {
            completion?(.success(()))
        }
    }
    
    /// 注销账户（删除用户数据，不可恢复）
    ///
    /// 调用后端 `user_delete` 接口删除账户，成功后自动清除本地登录状态。
    /// - Parameter completion: 结果回调，成功返回 `.success`，失败返回 `.failure`
    public func logoff(completion: @escaping (Result<Void, LoginError>) -> Void) {
        let networkService = LoginNetworkService()
        networkService.deleteAccount { [weak self] result in
            switch result {
            case .success:
                self?.clearLoggedIn()
                self?.userModel = nil
                // 清除 LoginManager / ProfileManager 中的 UserDefaults 本地缓存
                LoginManager.shared.removeLoginCache()
                ProfileManager.shared.removeLoginCache()
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Private
    
    /// 标记初始化完成，并执行所有挂起的 launch 操作
    private func markInitialized() {
        isInitialized = true
        let actions = pendingLaunchActions
        pendingLaunchActions.removeAll()
        actions.forEach { $0() }
    }
    
    /// 应用新配置并清除旧 sdkAppId 缓存
    private func applyConfig(_ newConfig: LoginConfig) {
        debugPrint("Environment: set sdkappid: \(newConfig.sdkAppId)")
        config = newConfig
        // 清除 HttpLogicRequest 中缓存的 sdkAppId，让下次读取时使用新 config
        HttpLogicRequest.resetSdkAppIdCache()
    }
    
    /// 根据登录方式切换对应配置（带防重处理）
    ///
    /// - debugAuth → 切换到 `debugConfig`
    /// - 其余 → 切换回 `primaryConfig`（`initialize()` 时传入的正式配置）
    ///
    /// 如果目标配置与当前 `config` 相同，则跳过切换，避免重复触发副作用。
    func switchConfig(for mode: LoginMode, isAutoLogin: Bool = false) {
        var targetConfig: LoginConfig
        switch mode {
        case .debugAuth:
            guard let debugConfig = debugConfig else {
                LoginLogger.Login.warn("switchConfig debugConfig is nil for .debugAuth, EARLY RETURN")
                return
            }
            targetConfig = debugConfig
        default:
            targetConfig = primaryConfig
        }
        // 测试环境：替换 httpBaseUrl
        if currentEnvironment == .test, let testUrl = testBaseUrl {
            targetConfig = targetConfig.withBaseUrl(testUrl)
        }
        guard targetConfig != config else {
            return  // no-op
        }
        applyConfig(targetConfig)
        // 自动登录路径下，IM SDK 还未真正建立用户会话，不需要 unInit。
        // 如果此时调用 unInitSDK，它的 offline 任务会与紧随其后的 TUILogin.login 在 SDK 内部并发，
        // 触发 getUsersInfo 返回 6222、被业务层误判为 IM 登录失败，最终弹出"登录状态失效"。
        if !isAutoLogin {
            /// 切换 sdkappid 或环境，需要先反初始化 im sdk
            V2TIMManager.sharedInstance().unInitSDK()
        }
        LoginLogger.Login.info("switchConfig mode=\(mode) sdkAppId=\(targetConfig.sdkAppId) isAutoLogin=\(isAutoLogin) unInit=\(!isAutoLogin)")
        fireEnvironmentChangedIfNeeded()
    }
    
    /// 带环境防护的外部回调触发
    ///
    /// 规则：
    ///   - currentEnvironment == .production：
    ///     - hasAppliedTestEnvironment == false → 正式→正式，不触发（冗余）
    ///     - hasAppliedTestEnvironment == true  → 测试→正式（切回来），弹 Toast，不触发
    ///   - currentEnvironment == .test：正式→测试，触发切换
    private func fireEnvironmentChangedIfNeeded() {
        switch currentEnvironment {
        case .production:
            if hasAppliedTestEnvironment {
                // 已经切过测试环境，现在试图切回正式 → 弹 Toast 提示重启
                DispatchQueue.main.async {
                    UIApplication.shared.windows
                        .first(where: { $0.isKeyWindow })?
                        .makeToast(LoginLocalize("login_menu_env_changed_restart"))
                }
            }
            // 正式→正式 或 测试→正式：均不触发外部切换
            return
        case .test:
            hasAppliedTestEnvironment = true
            onEnvironmentChanged?(currentEnvironment)
        }
    }

    /// 内部 logout 实现（清除登录记录 + 网络登出 + IM 登出）
    ///
    /// `completion` 在登出流程结束后回调（无论成功/失败都会回调，确保流程不卡住）
    private func performLogout(completion: @escaping () -> Void) {
        clearLoggedIn()
        userModel = nil
        // 清除 LoginManager / ProfileManager 中的 UserDefaults 本地缓存
        LoginManager.shared.removeLoginCache()
        ProfileManager.shared.removeLoginCache()
        // 通过 LoginSubStore 协议的登出信号通知所有 Store 重置状态
        LoginSubStoreLogoutSignal.shared.subject.send()
        // 清除 ITLogin SDK 缓存的登录态，避免下次 IOA 登录时复用过期票据
        #if LOGIN_FULL
        IOAAuthManager.shared.logoutIOA()
        #endif
        let networkService = LoginNetworkService()
        networkService.logout { _ in
            // 无论网络登出成功/失败都继续，避免阻塞后续流程
            completion()
        }
    }
    
    private func performTokenAuth(originalMode: LoginMode, completion: @escaping (Result<LoginResult, LoginError>) -> Void) {
        tokenStore.resultPublisher
            .first()
            .receive(on: RunLoop.main)
            .sink { result in
                completion(result)
            }
            .store(in: &tokenCancellable)
        tokenStore.performAutoLogin(originalMode: originalMode)
    }
    
    private var tokenCancellable = Set<AnyCancellable>()
    private var navigator: LoginNavigator?
    private lazy var tokenStore = TokenAuthStore()
    
    // MARK: - 自动登录状态持久化

    private static let autoLoginKey = "com.rtcube.login.autoLoginEnabled"

    /// 用户从未手动切换过开关时的默认值。
    ///
    /// 壳工程在 `initialize()` 前设置：
    ///   - RTCube / TencentRTC → `true`（默认开启自动登录）
    ///   - RTCubeLab → `false`（开发包默认关闭）
    public var initialAutoLoginEnabled: Bool = false

    /// 自动登录开关状态（持久化到 UserDefaults）
    ///
    /// 当用户从未手动切换过开关时（key 不存在），返回 `initialAutoLoginEnabled`。
    public var isAutoLoginEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.autoLoginKey) != nil {
                return UserDefaults.standard.bool(forKey: Self.autoLoginKey)
            }
            return initialAutoLoginEnabled
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.autoLoginKey) }
    }

    public private(set) var hiddenCredentials: HiddenConfigCredentials?

    func switchSDKAppID(credentials: HiddenConfigCredentials) {
        hiddenCredentials = credentials

        guard let sdkAppIdInt = Int(credentials.sdkAppId) else {
            debugPrint("[HiddenConfig] switchSDKAppID failed: invalid sdkAppId '\(credentials.sdkAppId)'")
            return
        }

        let newConfig = LoginConfig(
            httpBaseUrl: config.httpBaseUrl,
            isSetupService: false,
            sdkAppId: sdkAppIdInt,
            apaasAppId: config.apaasAppId,
            secretKey: config.secretKey
        )

        applyConfig(newConfig)

        V2TIMManager.sharedInstance().unInitSDK()
        debugPrint("[HiddenConfig] switchSDKAppID: sdkAppId=\(credentials.sdkAppId), userId=\(credentials.userId)")
        fireEnvironmentChangedIfNeeded()
    }

    func loginWithHiddenCredentials(_ credentials: HiddenConfigCredentials) {
        navigator?.pushDebugAuthWithCredentials(credentials)
    }

    func resetSDKAppID() {
        hiddenCredentials = nil

        applyConfig(primaryConfig)

        V2TIMManager.sharedInstance().unInitSDK()
        debugPrint("[HiddenConfig] resetSDKAppID: restored to primaryConfig sdkAppId=\(primaryConfig.sdkAppId)")
        fireEnvironmentChangedIfNeeded()
    }
}
