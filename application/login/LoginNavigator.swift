//
//  LoginNavigator.swift
//  login
//
//  登录模块内部导航器（对外不可见）
//

import UIKit
import Combine
import Toast_Swift
#if LOGIN_FULL
import ITLogin
#endif

/// 登录模块内部导航器（对外不可见）
///
/// 职责：
///   - 管理登录流程的页面栈
///   - 协调子模块间跳转
///   - 汇聚登录结果到统一出口
///   - 登录成功后判断是否需要注册（新用户无头像 → push 注册页）
final class LoginNavigator: NSObject {
    
    private let navigationController = UINavigationController()
    private let completion: (Result<LoginResult, LoginError>) -> Void
    
    /// 登录方式变更回调
    ///
    /// 当用户在 menu 中切换登录方式时触发，由 `LoginEntry` 实现，
    /// 负责根据 mode 切换对应的环境配置。Navigator 不关心具体配置细节。
    var onLoginModeChanged: ((LoginMode) -> Void)?

    /// 服务器环境切换回调
    ///
    /// 当用户在 DevLoginMenu 页面切换环境时触发，由 `LoginEntry` 透传到外部。
    var onEnvironmentChanged: ((ServerEnvironment) -> Void)?

    /// 隐私协议弹窗同意/不同意回调
    var onPrivacyAgreed: ((_ isAgree: Bool) -> Void)?
    
    private var cancellables = Set<AnyCancellable>()
    private var hasFinished = false
    private let networkService = LoginNetworkService()
    private var currentMode: LoginMode = .phoneVerify
    
    init(completion: @escaping (Result<LoginResult, LoginError>) -> Void) {
        self.completion = completion
    }
    
    // MARK: - 构建
    
    /// 构建登录页面的 ViewController（不执行 present，交给外部展示）
    func buildViewController(mode: LoginMode) -> UIViewController {
        LoginLogger.Login.info("LoginNavigator.buildViewController mode=\(mode)")
        currentMode = mode
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.modalPresentationStyle = .fullScreen
        navigationController.presentationController?.delegate = self
        
        // 通知 LoginEntry 根据 mode 切换环境配置
        // menu 模式下延迟到用户选择具体登录方式时再触发
        if mode != .menu {
            onLoginModeChanged?(mode)
        }
        
        switch mode {
        case .phoneVerify:
            pushPhoneVerify(animated: false)
        case .emailVerify:
            pushEmailVerify(animated: false)
        case .ioaAuth:
            pushIOAAuth(animated: false)
        case .inviteCode:
            pushInviteCode(animated: false)
        case .debugAuth:
            pushDebugAuthDirect(animated: false)
        case .menu:
            pushDevLoginMenu(animated: false)
        }

        // 展示首次登录隐私协议弹窗（仅 RTCube 国内版）
        #if !RTCUBE_OVERSEAS && !RTCUBE_LAB && !OPEN_SOURCE
        DispatchQueue.main.async { [weak self] in
            self?.showPrivacyAlertIfNeeded()
        }
        #endif

        return navigationController
    }
    
    // MARK: - PhoneVerify
    
    func pushPhoneVerify(animated: Bool = true) {
        let store = PhoneVerifyStore()
        store.onSwitchToIOA = { [weak self] in
            self?.pushIOAAuth()
        }
        subscribeStoreResult(store.resultPublisher)
        
        let vc = UIViewController()
        let view = PhoneVerifyView(store: store)
        view.navigationController = navigationController
        vc.view = view
        showViewController(vc, animated: animated)
    }
    
    // MARK: - EmailVerify
    
    func pushEmailVerify(animated: Bool = true) {
        let store = EmailVerifyStore()
        store.onSwitchToIOA = { [weak self] in
            self?.pushIOAAuth()
        }
        store.onNavigateToInviteCode = { [weak self] email in
            self?.pushInviteCode(emailAddress: email)
        }
        subscribeStoreResult(store.resultPublisher)
        
        let vc = UIViewController()
        let view = EmailVerifyView(store: store)
        view.navigationController = navigationController
        vc.view = view
        showViewController(vc, animated: animated)
    }
    
    // MARK: - IOAAuth

    func pushIOAAuth(animated: Bool = true) {
        #if LOGIN_FULL
        // 使用 PassthroughSubject 桥接模态 VC 的结果到现有的 subscribeStoreResult 管线
        let resultBridge = PassthroughSubject<Result<LoginResult, LoginError>, Never>()
        subscribeStoreResult(resultBridge.eraseToAnyPublisher())

        let ioaVC = IOAAuthViewController { [weak self] result in
            switch result {
            case .success(let loginResult):
                resultBridge.send(.success(loginResult))
            case .failure:
                // 错误已在 IOAAuthViewController 中 toast 展示，不再传播
                break
            case .cancelled:
                // 如果 IOA 是初始（根）模式，导航栈中只有一个 VC → 通知外部取消
                // 如果 IOA 是从手机/邮箱页切换来的 → 模态已 dismiss，用户回到原页面，无需操作
                if self?.navigationController.viewControllers.count ?? 0 <= 1 {
                    self?.finish(result: .failure(.cancelled))
                }
            }
        }

        IOAAuthManager.shared.activeIOAViewController = ioaVC
        navigationController.present(ioaVC, animated: animated)
        #endif
    }

    /// 处理 iOA SDK 回调的登录票据
    ///
    /// 由 `IOAAuthManager`（ITLoginDelegate）在收到票据后调用。
    /// 转发给当前模态呈现的 IOAAuthViewController。
    #if LOGIN_FULL
    func handleIOATicket(_ ticket: String) {
        IOAAuthManager.shared.activeIOAViewController?.handleTicket(ticket)
    }
    #endif
    
    // MARK: - InviteCode
    
    func pushInviteCode(emailAddress: String? = nil, animated: Bool = true) {
        let store = InviteCodeStore(emailAddress: emailAddress)
        store.onBack = { [weak self] in
            self?.pop()
        }
        subscribeStoreResult(store.resultPublisher)
        
        let vc = UIViewController()
        let view = InviteCodeView(store: store)
        vc.view = view
        showViewController(vc, animated: animated)
    }
    
    // MARK: - DebugAuth
    
    /// RTCubeLab: 展示登录方式选择面板，点击后跳转到对应登录页
    private func pushDevLoginMenu(animated: Bool = true) {
        let menuVC = DevLoginMenuViewController()
        menuVC.onSelectMode = { [weak self] selectedMode in
            guard let self = self else { return }
            // menu 进入子模式后，currentMode 必须同步切换。
            // 否则 handleLoginSuccessWithRegistrationCheck 会按 .menu 走非 Debug 注册分支。
            LoginLogger.Login.info("LoginNavigator.devMenu.onSelectMode \(selectedMode) (currentMode \(self.currentMode) -> \(selectedMode))")
            self.currentMode = selectedMode
            // 通知 LoginEntry 根据所选方式切换环境配置
            self.onLoginModeChanged?(selectedMode)
            switch selectedMode {
            case .phoneVerify:
                self.pushPhoneVerify()
            case .emailVerify:
                self.pushEmailVerify()
            case .ioaAuth:
                self.pushIOAAuth()
            case .inviteCode:
                self.pushInviteCode()
            case .debugAuth:
                self.pushDebugAuthDirect()
            default:
                break
            }
        }
        menuVC.onEnvironmentChanged = { [weak self] env in
            self?.onEnvironmentChanged?(env)
        }
        showViewController(menuVC, animated: animated)
    }
    
    /// 原始 Debug 登录页（userId 直接登录）
    ///
    /// Debug 登录使用独立的 SDKAppID + SecretKey（DEBUG_SDKAPPID / DEBUG_SECRETKEY），
    /// 与正式登录（Phone/Email/IOA）使用的 SDKAPPID / SECRETKEY 不同。
    /// 进入 Debug 登录前，自动切换到 `debugConfig`。
    private func pushDebugAuthDirect(animated: Bool = true) {
        LoginLogger.Login.info("LoginNavigator.pushDebugAuthDirect")
        let store = LoginEntry.shared.debugAuthStore
        store.onNeedsRegister = { [weak self] in
            guard let self = self else { return }
            self.pushDebugRegister(store: store)
        }
        subscribeStoreResult(store.resultPublisher)

        let vc = UIViewController()
        let view = DebugAuthView(store: store)
        vc.view = view
        showViewController(vc, animated: animated)
    }

    func pushDebugAuthWithCredentials(_ credentials: HiddenConfigCredentials) {
        let store = LoginEntry.shared.debugAuthStore
        store.updateUserName(credentials.userId)
        store.onNeedsRegister = { [weak self] in
            guard let self = self else { return }
            self.pushDebugRegister(store: store)
        }
        subscribeStoreResult(store.resultPublisher)

        let vc = UIViewController()
        let debugAuthView = DebugAuthView(store: store)
        debugAuthView.isUserIdEditable = false
        debugAuthView.onBack = { [weak self] in
            self?.pop()
        }
        vc.view = debugAuthView
        navigationController.pushViewController(vc, animated: true)

        store.loginWithCredentials(credentials)
    }
    
    // MARK: - DebugRegister
    
    private func pushDebugRegister(store: DebugAuthStore) {
        LoginLogger.Login.info("LoginNavigator.pushDebugRegister")
        let vc = UIViewController()
        vc.title = LoginLocalize("login_profile_title")
        let registerView = RegisterView()
        registerView.setAvatarURL(store.state.avatarURL)
        
        registerView.onRegisterButtonTapped = { [weak store] nickName, _ in
            store?.register(nickName: nickName)
        }
        registerView.onHeadImageTapped = { [weak self, weak registerView] in
            guard let self = self else { return }
            let viewModel = AvatarViewModel()
            let alertView = AvatarListAlertView(viewModel: viewModel)
            alertView.didClickConfirmBtn = { [weak store, weak registerView] in
                guard let selectedModel = viewModel.currentSelectAvatarModel else { return }
                store?.updateAvatar(selectedModel.url)
                registerView?.setAvatarURL(selectedModel.url)
            }
            if let window = self.navigationController.view.window {
                window.addSubview(alertView)
                alertView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
                alertView.show()
            }
        }
        
        vc.view = registerView
        navigationController.pushViewController(vc, animated: true)
    }
    
    // MARK: - Register (非 Debug 登录的注册页)
    
    /// 登录成功后的注册流程（新用户无头像 → push 注册页设置昵称和头像）
    /// - Parameter pendingResult: 登录成功的 LoginResult，注册完成后更新并回调
    private func pushRegister(pendingResult: LoginResult) {
        LoginLogger.Login.info("LoginNavigator.pushRegister mode=\(currentMode) userId=\(pendingResult.userModel.userId)")
        let vc = UIViewController()
        vc.title = LoginLocalize("login_profile_title")
        let registerView = RegisterView()
        
        registerView.onRegisterButtonTapped = { [weak self] nickName, avatarURL in
            guard let self = self else { return }
            self.performRegister(nickName: nickName, avatarURL: avatarURL, pendingResult: pendingResult)
        }
        
        registerView.onHeadImageTapped = { [weak self, weak registerView] in
            guard let self = self else { return }
            let viewModel = AvatarViewModel()
            let alertView = AvatarListAlertView(viewModel: viewModel)
            alertView.didClickConfirmBtn = { [weak registerView] in
                guard let selectedModel = viewModel.currentSelectAvatarModel else { return }
                registerView?.setAvatarURL(selectedModel.url)
            }
            if let window = self.navigationController.view.window {
                window.addSubview(alertView)
                alertView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
                alertView.show()
            }
        }
        
        vc.view = registerView
        navigationController.pushViewController(vc, animated: true)
    }
    
    /// 执行注册（更新昵称）
    private func performRegister(nickName: String, avatarURL: String, pendingResult: LoginResult) {
        LoginLogger.Login.info("LoginNavigator.performRegister begin mode=\(currentMode) nickName.len=\(nickName.count) avatarEmpty=\(avatarURL.isEmpty)")
        networkService.updateUserName(name: nickName) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                // 从 LoginManager 获取最新数据（已被 IMLogicRequest.synchronizUserInfo 更新），
                // 确保 name/avatar 与服务端及 IM SDK 完全一致，避免使用 pendingResult 中的旧值。
                let latestUser: UserModel
                if let rawUser = LoginManager.shared.getCurrentUser() {
                    latestUser = UserModel(
                        userId: rawUser.userId,
                        token: rawUser.token,
                        userSig: rawUser.userSig,
                        phone: rawUser.phone,
                        email: rawUser.email,
                        name: rawUser.name,
                        avatar: rawUser.avatar
                    )
                } else {
                    latestUser = UserModel(
                        userId: pendingResult.userModel.userId,
                        token: pendingResult.userModel.token,
                        userSig: pendingResult.userModel.userSig,
                        phone: pendingResult.userModel.phone,
                        email: pendingResult.userModel.email,
                        name: nickName,
                        avatar: avatarURL.isEmpty ? pendingResult.userModel.avatar : avatarURL
                    )
                }
                let updatedResult = LoginResult(userModel: latestUser, mode: currentMode)

                if let topView = self.navigationController.topViewController?.view {
                    topView.makeToast(LoginLocalize("login_profile_toast_register_success"))
                }
                LoginLogger.Login.info("LoginNavigator.performRegister SUCCESS userId=\(latestUser.userId) -> finish")
                self.finish(result: .success(updatedResult))
            case .failure(let error):
                if let topView = self.navigationController.topViewController?.view {
                    topView.makeToast(error.message)
                }
                LoginLogger.Login.warn("LoginNavigator.performRegister FAILED error=\(error.message), pop after 1s")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.navigationController.popViewController(animated: true)
                }
            }
        }
    }
    
    // MARK: - LanguageSelect
    
    /// 重建当前登录页面
    ///
    /// 重新创建 Store + View，替换 navigationController 的整个页面栈为
    /// [新登录页, 语言选择页]，确保所有本地化文案使用新语言。
    private func rebuildCurrentLoginPage() {
        // 先清除旧的订阅，避免重复触发
        cancellables.removeAll()
        
        // 重建登录页（不 push，直接替换栈底）
        navigationController.setNavigationBarHidden(true, animated: false)
        
        switch currentMode {
        case .phoneVerify:
            rebuildPhoneVerify()
        case .emailVerify:
            rebuildEmailVerify()
        case .debugAuth:
            rebuildDebugAuth()
        case .menu:
            rebuildDebugMenu()
        case .ioaAuth, .inviteCode:
            // IOA 和邀请码页面无语言切换按钮，不应走到这里
            navigationController.popViewController(animated: true)
        }
    }
    
    private func rebuildPhoneVerify() {
        let store = PhoneVerifyStore()
        store.onSwitchToIOA = { [weak self] in
            self?.pushIOAAuth()
        }
        subscribeStoreResult(store.resultPublisher)
        
        let vc = UIViewController()
        let view = PhoneVerifyView(store: store)
        view.navigationController = navigationController
        vc.view = view
        navigationController.setViewControllers([vc], animated: false)
    }
    
    private func rebuildEmailVerify() {
        let store = EmailVerifyStore()
        store.onSwitchToIOA = { [weak self] in
            self?.pushIOAAuth()
        }
        store.onNavigateToInviteCode = { [weak self] email in
            self?.pushInviteCode(emailAddress: email)
        }
        subscribeStoreResult(store.resultPublisher)
        
        let vc = UIViewController()
        let view = EmailVerifyView(store: store)
        view.navigationController = navigationController
        vc.view = view
        navigationController.setViewControllers([vc], animated: false)
    }
    
    private func rebuildDebugAuth() {
        let store = DebugAuthStore()
        store.onNeedsRegister = { [weak self] in
            guard let self = self else { return }
            self.pushDebugRegister(store: store)
        }
        subscribeStoreResult(store.resultPublisher)
        
        let vc = UIViewController()
        let view = DebugAuthView(store: store)
        vc.view = view
        navigationController.setViewControllers([vc], animated: false)
    }
    
    private func rebuildDebugMenu() {
        // Lab 模式下重建选择面板
        let menuVC = DevLoginMenuViewController()
        menuVC.onSelectMode = { [weak self] selectedMode in
            guard let self = self else { return }
            // 与 pushDevLoginMenu 保持一致，菜单选择子模式时同步 currentMode
            LoginLogger.Login.info("LoginNavigator.rebuildDebugMenu.onSelectMode \(selectedMode) (currentMode \(self.currentMode) -> \(selectedMode))")
            self.currentMode = selectedMode
            // 通知 LoginEntry 根据所选方式切换环境配置
            self.onLoginModeChanged?(selectedMode)
            switch selectedMode {
            case .phoneVerify:
                self.pushPhoneVerify()
            case .emailVerify:
                self.pushEmailVerify()
            case .ioaAuth:
                self.pushIOAAuth()
            case .inviteCode:
                self.pushInviteCode()
            case .debugAuth:
                self.pushDebugAuthDirect()
            default: break
            }
        }
        menuVC.onEnvironmentChanged = { [weak self] env in
            self?.onEnvironmentChanged?(env)
        }
        navigationController.setViewControllers([menuVC], animated: false)
    }
    
    /// 首个页面用 setViewControllers 设为 root，后续页面用 push
    private func showViewController(_ vc: UIViewController, animated: Bool) {
        if navigationController.viewControllers.isEmpty {
            navigationController.setViewControllers([vc], animated: false)
        } else {
            navigationController.pushViewController(vc, animated: animated)
        }
    }
    
    func pop(animated: Bool = true) {
        navigationController.popViewController(animated: animated)
    }

    // MARK: - 隐私协议弹窗

    /// 隐私协议已同意的持久化 key
    private static let privacyAgreedKey = "com.rtcube.login.privacyAlertAgreed"

    /// 展示首次登录隐私协议弹窗（对标旧版 LiteAVPrivacyAlertViewController）
    ///
    /// 条件：用户从未点击过「同意」（UserDefaults 持久化，与登录态无关）。
    /// 弹窗添加到当前登录页 VC 的 view 上（非 navigationController.view），
    /// 这样点击链接 push 协议详情页时，弹窗会随登录页一起滑出，返回时自动恢复。
    private func showPrivacyAlertIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.privacyAgreedKey) else { return }
        guard let topVC = navigationController.topViewController else { return }
        let alertView = FirstLaunchPrivacyAlertView(superVC: navigationController)
        alertView.didClickConfirmBtn = { [weak self] in
            UserDefaults.standard.set(true, forKey: LoginNavigator.privacyAgreedKey)
            self?.onPrivacyAgreed?(true)
        }
        alertView.didClickCancelBtn = { [weak self] in
            self?.onPrivacyAgreed?(false)
        }
        topVC.view.addSubview(alertView)
        alertView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    // MARK: - 结果汇聚（统一出口的核心）
    
    /// 订阅任意子模块 Store 的结果，汇聚到统一出口
    /// 登录成功时判断是否需要注册（新用户无头像），需要则 push 注册页
    private func subscribeStoreResult(_ publisher: AnyPublisher<Result<LoginResult, LoginError>, Never>) {
        publisher
            .first()
            .receive(on: RunLoop.main)
            .sink { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let loginResult):
                    LoginLogger.Login.info("LoginNavigator.subscribeStoreResult success userId=\(loginResult.userModel.userId) mode=\(currentMode)")
                    self.handleLoginSuccessWithRegistrationCheck(loginResult: loginResult)
                case .failure(let error):
                    LoginLogger.Login.warn("LoginNavigator.subscribeStoreResult failure error=\(error)")
                    self.finish(result: result)
                }
            }
            .store(in: &cancellables)
    }
    
    /// 登录成功后检查是否需要注册
    /// 旧版逻辑：avatar == "" 时跳注册页
    /// DebugAuth 自行处理注册流程，此处仅处理 Phone/Email/IOA/InviteCode
    private func handleLoginSuccessWithRegistrationCheck(loginResult: LoginResult) {
        // DebugAuth 自行管理注册流程，直接回调结果
        if case .debugAuth = currentMode {
            LoginLogger.Login.info("LoginNavigator.handleLoginSuccess debugAuth -> finish (skip register check)")
            finish(result: .success(loginResult))
            return
        }

        // 使用 loginResult 中的 avatar 判断是否需要注册，而非重新从 LoginManager 获取
        if loginResult.userModel.avatar.isEmpty {
            LoginLogger.Login.info("LoginNavigator.handleLoginSuccess avatar empty mode=\(currentMode) -> pushRegister")
            pushRegister(pendingResult: loginResult)
        } else {
            LoginLogger.Login.info("LoginNavigator.handleLoginSuccess mode=\(currentMode) -> finish")
            finish(result: .success(loginResult))
        }
    }
    
    /// 登录流程结束，回调结果
    /// 注意：不再由内部 dismiss，外部根据 completion 结果自行决定页面去留
    private func finish(result: Result<LoginResult, LoginError>) {
        guard !hasFinished else {
            LoginLogger.Login.info("LoginNavigator.finish ignored (already finished)")
            return
        }
        hasFinished = true
        switch result {
        case .success(let loginResult):
            LoginLogger.Login.info("LoginNavigator.finish SUCCESS userId=\(loginResult.userModel.userId) mode=\(loginResult.loginMode)")
        case .failure(let error):
            LoginLogger.Login.warn("LoginNavigator.finish FAILURE error=\(error)")
        }
        completion(result)
    }
}

// MARK: - 用户手动关闭 → 视为取消
extension LoginNavigator: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        LoginLogger.Login.info("LoginNavigator.presentationControllerDidDismiss -> finish(.cancelled)")
        finish(result: .failure(.cancelled))
    }
}
