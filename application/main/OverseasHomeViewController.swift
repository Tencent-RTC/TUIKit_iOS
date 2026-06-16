//
//  OverseasHomeViewController.swift
//  main
//
//  海外版首页容器控制器 — 从 Tencent-RTC/HomeViewController.swift 迁移
//
//  变更说明：
//    - 移除 `import RTCCommon`、`import BusinessService` 依赖
//    - 头像更新改为通过 LoginManager 获取 URL，与 v2 架构一致
//    - 导航栏使用独立的 OverseasNavigationView（白色背景、英文 Logo）
//    - 嵌入 OverseasMainViewController 作为内容页
//    - 监听 IM 未读消息并传递给内容页更新红点
//    - 管理联系我们入口的显示/隐藏
//

import UIKit
import AtomicX
import SnapKit
import TUICore
import Toast_Swift
import ImSDK_Plus
import Login
#if !OPEN_SOURCE
import RTCExperienceRoom
#endif

class OverseasHomeViewController: UIViewController {

    // MARK: - Properties

    private var logFilesArray: [String] = []
    private let mainViewController = OverseasMainViewController()

    // MARK: - UI Elements

    private lazy var naviBackView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        return view
    }()

    private lazy var mainNavigationView: OverseasNavigationView = {
        let view = OverseasNavigationView(frame: .zero)
        view.delegate = self
        return view
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // 注册"联系我们"TUICore 服务（需在 viewWillAppear 调用 callService 之前完成）
        ContactUsService.registerService()

        // 嵌入内容子控制器
        addChild(mainViewController)
        view.addSubview(mainViewController.view)
        mainViewController.didMove(toParent: self)

        constructViewHierarchy()
        activateConstraints()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)

        // 显示联系我们入口
        let result = TUICore.callService(TUICore_ContactUsService,
                                         method: TUICore_ContactService_ShowContactEntrance,
                                         param: [:])
        AppLogger.App.debug("TUICore_ConsultService: \(String(describing: result))")

        updateMineCenterImage()
        setupIMUnreadListener()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // 隐藏联系我们入口
        let result = TUICore.callService(TUICore_ContactUsService,
                                         method: TUICore_ContactService_HideContactEntrance,
                                         param: [:])
        AppLogger.App.debug("TUICore_ConsultService: \(String(describing: result))")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 渐变背景 F7F9FC → F0F2F5
        let gradientLayer = view.gradient(colors: [
            UIColor(red: 247 / 255.0, green: 249 / 255.0, blue: 252 / 255.0, alpha: 1),
            UIColor(red: 240 / 255.0, green: 242 / 255.0, blue: 245 / 255.0, alpha: 1),
        ])
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available(iOS 13.0, *) {
            return .darkContent
        }
        return .default
    }

    override var prefersStatusBarHidden: Bool {
        return false
    }
}

// MARK: - UI Setup

extension OverseasHomeViewController {

    private func constructViewHierarchy() {
        view.addSubview(naviBackView)
        view.addSubview(mainNavigationView)
    }

    private func activateConstraints() {
        let statusBarH = statusBarHeight()

        naviBackView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.height.equalTo(44 + statusBarH)
            make.left.right.equalToSuperview()
        }

        mainNavigationView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(statusBarH)
            make.height.equalTo(44)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
        }
    }

    private func updateMineCenterImage() {
        let avatarURL = LoginManager.shared.getCurrentUser()?.avatar
        mainNavigationView.updateAvatarImage(urlString: avatarURL)
    }

    private func setupIMUnreadListener() {
        V2TIMManager.sharedInstance().addConversationListener(listener: self)
        V2TIMManager.sharedInstance().getTotalUnreadMessageCount { _ in
        } fail: { _, _ in
        }
    }
}

// MARK: - MainNavigationViewDelegate

extension OverseasHomeViewController: MainNavigationViewDelegate {

    func jumpProfileController() {
        let mineVC = MineEntry.shared.buildMineViewController(
            onLogout: {
                LoginEntry.shared.logout { result in
                    AppLogger.App.info(" logout result: \(result)")
                    guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                          let sceneDelegate = scene.delegate as? SceneDelegate else { return }
                    sceneDelegate.showLogin()
                }
            },
            onLanguageChanged: { languageID in
                AppLogger.App.info(" language changed to: \(languageID)")
                guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                      let sceneDelegate = scene.delegate as? SceneDelegate else { return }
                sceneDelegate.showLogin()
            }
        )
        navigationController?.pushViewController(mineVC, animated: true)
    }

    func showLogUploadView(pressGesture: UILongPressGestureRecognizer) {
        if pressGesture.state == .began {
            LogUploadManager.sharedInstance.startUpload(withSuccessHandler: nil) {
                AppLogger.App.info(" Log upload cancelled")
            }
        }
    }

    func dismissLogUploadView(tapGesture: UITapGestureRecognizer) {
        // No-op
    }
}

// MARK: - V2TIMConversationListener

extension OverseasHomeViewController: V2TIMConversationListener {
    func onTotalUnreadMessageCountChanged(totalUnreadCount: UInt64) {
        mainViewController.updateUnreadCount(totalUnreadCount)
    }
}

// MARK: - Toast

extension OverseasHomeViewController {

    private func setupToast() {
        ToastManager.shared.position = .bottom
    }

    func makeToast(message: String) {
        view.makeToast(message)
    }
}
