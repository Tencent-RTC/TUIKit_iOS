//
//  OverseasHomeViewController.swift
//  main
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

        ContactUsService.registerService()

        addChild(mainViewController)
        view.addSubview(mainViewController.view)
        mainViewController.didMove(toParent: self)

        constructViewHierarchy()
        activateConstraints()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)

        let result = TUICore.callService(TUICore_ContactUsService,
                                         method: TUICore_ContactService_ShowContactEntrance,
                                         param: [:])
        AppLogger.App.debug("TUICore_ConsultService: \(String(describing: result))")

        updateMineCenterImage()
        setupIMUnreadListener()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        let result = TUICore.callService(TUICore_ContactUsService,
                                         method: TUICore_ContactService_HideContactEntrance,
                                         param: [:])
        AppLogger.App.debug("TUICore_ConsultService: \(String(describing: result))")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
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
