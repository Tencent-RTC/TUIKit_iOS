//
//  LoginEntry.swift
//  login
//

import Combine
import ImSDK_Plus
import Toast_Swift
import UIKit

public enum LoginMode: Int {
    case phoneVerify = 1
    
    case emailVerify = 2
    
    case ioaAuth = 3
    
    case inviteCode = 4
    
    case debugAuth = 5
    
    case menu = 6
}

private let loggedInKey = "com.rtcube.login.lastLoginMode"

public final class LoginEntry: NSObject {
    public static let shared = LoginEntry()
    override private init() {}
    
    @Published public internal(set) var userModel: UserModel?
    
    public var hasLoggedIn: Bool {
        loggedInMode != nil
    }
    
    public var loggedInMode: LoginMode? {
        let value = UserDefaults.standard.integer(forKey: loggedInKey)
        return LoginMode(rawValue: value)
    }

    private func markLoggedIn(mode: LoginMode) {
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
    
    public private(set) var config: LoginConfig = .default
    
    public private(set) var primaryConfig: LoginConfig = .default
    
    public var userSigGenerator: ((_ identifier: String, _ sdkAppId: Int, _ secretKey: String) -> String)?
    
    public var privacyLinkHandler: ((_ linkType: String, _ viewController: UIViewController?) -> Void)?

    public var onPrivacyAgreed: ((_ isAgree: Bool) -> Void)?
    
    public var onEnvironmentChanged: ((_ environment: ServerEnvironment) -> Void)?
    
    public var onPassiveLogout: (() -> Void)?

    public var onTokenExpired: (() -> Void)?
    
    public private(set) var testBaseUrl: String?
    
    public private(set) var debugConfig: LoginConfig?
    
    private var isInitialized = false
    
    private var pendingLaunchActions: [() -> Void] = []
    
    let debugAuthStore = DebugAuthStore()
    private var debugCancellable: AnyCancellable?
    
    private let userInfoManager = UserInfoManager()

    private(set) var currentEnvironment: ServerEnvironment = .production

    private(set) var hasAppliedTestEnvironment: Bool = false
    
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
        TUILoginListenerHandler.shared.register()

        IMConnectGate.shared.activate()

        self.testBaseUrl = testBaseUrl

        let newConfig = LoginConfig(
            httpBaseUrl: baseUrl,
            isSetupService: isSetupService,
            sdkAppId: sdkAppId,
            apaasAppId: apaasAppId,
            secretKey: secretKey
        )
        
        if let debugSdkAppId = debugSdkAppId {
            debugConfig = LoginConfig(
                httpBaseUrl: baseUrl,
                isSetupService: false,
                sdkAppId: debugSdkAppId,
                apaasAppId: apaasAppId,
                secretKey: debugSecretKey ?? secretKey
            )
        }
        
        #if LOGIN_FULL
        if let ioaAppKey = ioaAppKey, let ioaAppId = ioaAppId {
            IOAAuthManager.shared.setupIOA(appKey: ioaAppKey, appId: ioaAppId)
        }
        #endif
        
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
            && config != .default
        
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
        
        #if LOGIN_FULL
        IOAAuthManager.shared.activeNavigator = navigator
        #endif
        
        let launchAction: () -> Void = { [weak self] in
            guard let self = self else { return }
            LoginLogger.Login.info("launchAction begin requestedMode=\(mode) persistedMode=\(loggedInMode.map { String(describing: $0) } ?? "nil")")
            if let loggedInMode = loggedInMode {
                switchConfig(for: loggedInMode, isAutoLogin: true)
                switch loggedInMode {
                case .phoneVerify, .emailVerify, .ioaAuth, .inviteCode:
                    performTokenAuth(originalMode: loggedInMode) { [weak self] result in
                        switch result {
                        case .success(let loginResult):
                            LoginLogger.Login.info("launchAction token-auth SUCCESS")
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
    
    public func logout(completion: ((Result<Void, LoginError>) -> Void)? = nil) {
        performLogout {
            completion?(.success(()))
        }
    }
    
    public func logoff(completion: @escaping (Result<Void, LoginError>) -> Void) {
        let networkService = LoginNetworkService()
        networkService.deleteAccount { [weak self] result in
            switch result {
            case .success:
                self?.clearLoggedIn()
                self?.userModel = nil
                LoginManager.shared.removeLoginCache()
                ProfileManager.shared.removeLoginCache()
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Private
    
    private func markInitialized() {
        isInitialized = true
        let actions = pendingLaunchActions
        pendingLaunchActions.removeAll()
        actions.forEach { $0() }
    }
    
    private func applyConfig(_ newConfig: LoginConfig) {
        debugPrint("Environment: set sdkappid: \(newConfig.sdkAppId)")
        config = newConfig
        HttpLogicRequest.resetSdkAppIdCache()
    }
    
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
        if currentEnvironment == .test, let testUrl = testBaseUrl {
            targetConfig = targetConfig.withBaseUrl(testUrl)
        }
        guard targetConfig != config else {
            return  // no-op
        }
        applyConfig(targetConfig)
        if !isAutoLogin {
            V2TIMManager.sharedInstance().unInitSDK()
        }
        LoginLogger.Login.info("switchConfig mode=\(mode) sdkAppId=\(targetConfig.sdkAppId) isAutoLogin=\(isAutoLogin) unInit=\(!isAutoLogin)")
        fireEnvironmentChangedIfNeeded()
    }
    
    ///
    ///   - currentEnvironment == .production：
    private func fireEnvironmentChangedIfNeeded() {
        switch currentEnvironment {
        case .production:
            if hasAppliedTestEnvironment {
                DispatchQueue.main.async {
                    UIApplication.shared.windows
                        .first(where: { $0.isKeyWindow })?
                        .makeToast(LoginLocalize("login_menu_env_changed_restart"))
                }
            }
            return
        case .test:
            hasAppliedTestEnvironment = true
            onEnvironmentChanged?(currentEnvironment)
        }
    }

    private func performLogout(completion: @escaping () -> Void) {
        clearLoggedIn()
        userModel = nil
        LoginManager.shared.removeLoginCache()
        ProfileManager.shared.removeLoginCache()
        LoginSubStoreLogoutSignal.shared.subject.send()
        #if LOGIN_FULL
        IOAAuthManager.shared.logoutIOA()
        #endif
        let networkService = LoginNetworkService()
        networkService.logout { _ in
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
    
    private static let autoLoginKey = "com.rtcube.login.autoLoginEnabled"

    public var initialAutoLoginEnabled: Bool = false

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
