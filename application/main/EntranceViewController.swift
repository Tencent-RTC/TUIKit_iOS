//
//  EntranceViewController.swift
//  main
//

import AppAssembly
import AtomicX
import Combine
import Login
#if !OPEN_SOURCE
import RTCExperienceRoom
#endif
import SnapKit
import Toast_Swift
import TUICore
import UIKit
#if !RTCUBE_OVERSEAS && !OPEN_SOURCE
import HuiYanPublicSDK
#endif

class EntranceViewController: UIViewController {
    // MARK: - Properties

    private let store = EntranceStore()
    private var cancellables = Set<AnyCancellable>()

    private var hasPerformedRiskCheck = false

    // MARK: - UI Elements

    private let safeReminderWarningView: SafetyReminderView = {
        let safeReminderView = SafetyReminderView()
        safeReminderView.confirmTimeCount = 5
        safeReminderView.clickConfirmBlock = {
            safeReminderView.removeFromSuperview()
        }
        return safeReminderView
    }()

    private lazy var mainNavigationView: MainNavigationView = {
        let view = MainNavigationView(frame: .zero)
        view.delegate = self
        return view
    }()

    private lazy var collectionView: UICollectionView = {
        let flowLayout = LeftAlignedFlowLayout()
        flowLayout.sectionInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        flowLayout.itemSize = CGSize(width: ScreenWidth / 2 - 12, height: 106)
        flowLayout.minimumLineSpacing = 0
        flowLayout.minimumInteritemSpacing = 0

        let cv = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        cv.register(EntranceCollectionCell.self,
                    forCellWithReuseIdentifier: "EntranceCollectionCell")
        cv.register(EntranceFooterView.self,
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                    withReuseIdentifier: "footer")
        cv.backgroundColor = .clear
        cv.delegate = self
        cv.dataSource = self
        cv.isScrollEnabled = true
        cv.isPagingEnabled = true
        return cv
    }()

    private let reportView: EntranceReportView = {
        let view = EntranceReportView()
        view.backgroundColor = ThemeStore.shared.colorTokens.toastColorError
        view.reportHandler = {
            if let url = URL(string: "https://cloud.tencent.com/act/event/report-platform") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        return view
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        let appEnvironment = ModuleEnvironment(
            beautyLicenseURL: "https://license.example.com/live",
            beautyLicenseKey: "YOUR_SECRET_KEY_123",
            getCurrentUserModel: {
                LoginEntry.shared.userModel
            },
            generateUserSig: { userId in
                GenerateTestUserSig.genTestUserSig(identifier: userId, sdkAppId: SDKAPPID, secretKey: SECRETKEY)
            }
        )

        #if !RTCUBE_LAB
        AppAssembly.shared.privacyActionHandler = { action in
            switch action {
            case .showAntifraudReminder:
                AntifraudAlertManager.showAntifraudReminder()
            case .showScreenShareAntifraud(let completion):
                AntifraudAlertManager.showScreenShareAntifraudReminder(completion: completion)
            case .checkRealNameAuth(let userId, let token, let completion):
                AntifraudAlertManager.checkRealNameAuth(userId: userId, token: token, completion: completion)
            case .showFaceIdTokenVerify(let userId, let token, let completion):
                AntifraudAlertManager.checkRealNameToAuthFace(userId: userId, token: token, completion: completion)
            case .showLiveTimeLimitAlert:
                TimeLimitPresenter.showLiveTimeLimitAlert()
            case .showLiveRemainingOneMinToast:
                TimeLimitPresenter.showRemainingOneMinToast()
            case .showHighRiskIPAlert:
                RoomRiskIPPresenter.showHighRiskIPAlert()
            case .showLiveTimeOutAlert(let onDismiss):
                TimeLimitPresenter.showLiveTimeOutAlert(onDismiss: onDismiss)
            }
        }
        #else
        PrivacyEntry.enableIdCardVerification = false
        #endif

        #if RTCUBE_OVERSEAS
        let providers = AppAssembly.shared.allModuleProviders(target: .overseas)
        #elseif RTCUBE_LAB
        let providers = AppAssembly.shared.allModuleProviders(target: .lab)
        #else
        let providers = AppAssembly.shared.allModuleProviders(target: .domestic)
        #endif
        let registry = ModuleRegistry.shared
        for provider in providers {
            provider.setup(with: appEnvironment)
            registry.register(provider)
        }

        AppAssembly.shared.registerLifecycleHandlers()

        setupUI()

        store.loadModules()

        bindStoreState()

        ModulePermissionService.shared.loadUserBlackList()

        #if !RTCUBE_OVERSEAS && !OPEN_SOURCE
        HuiYanSDKKit.sharedInstance().initSDK(with: self)
        #endif

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
        setupToast()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        performRiskCheckIfNeeded()
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

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault

        constructViewHierarchy()
        activateConstraints()
    }

    private var shouldShowReportView: Bool {
        #if RTCUBE_LAB
        return false
        #else
        guard TUIGlobalization.isChineseAppLocale() else { return false }
        guard let userModel = LoginManager.shared.getCurrentUser() else { return true }
        return !userModel.isMoa()
        #endif
    }

    private func constructViewHierarchy() {
        view.addSubview(mainNavigationView)

        if shouldShowReportView {
            view.addSubview(reportView)
        }

        view.addSubview(collectionView)
    }

    private func activateConstraints() {
        let statusBarH = statusBarHeight()

        mainNavigationView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(statusBarH)
            make.height.equalTo(44)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
        }

        if shouldShowReportView {
            reportView.snp.makeConstraints { make in
                make.top.equalTo(mainNavigationView.snp.bottom)
                make.left.right.equalToSuperview()
                let height: CGFloat = TUIGlobalization.isChineseAppLocale() ? 52 : 0
                make.height.equalTo(height)
            }

            collectionView.snp.makeConstraints { make in
                make.top.equalTo(reportView.snp.bottom).offset(12)
                make.left.right.bottom.equalToSuperview()
            }
        } else {
            collectionView.snp.makeConstraints { make in
                make.top.equalTo(mainNavigationView.snp.bottom).offset(12)
                make.left.right.bottom.equalToSuperview()
            }
        }
    }

    // MARK: - State Binding

    private func bindStoreState() {
        store.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)
    }

    // MARK: - Toast

    private func setupToast() {
        ToastManager.shared.position = .bottom
    }

    private func showBannedToast() {
        guard !ModulePermissionService.shared.isNeedFaceAuth else { return }
        view.makeToast(MainLocalize("Demo.TRTC.Portal.Main.MoudleBannedMessage"))
    }

    // MARK: - Risk Check Entry Point

    private func performRiskCheckIfNeeded() {
        #if RTCUBE_LAB
        return
        #endif

        if presentedViewController != nil {
            hasPerformedRiskCheck = false
            return
        }
        guard !hasPerformedRiskCheck else { return }
        guard let userModel = LoginManager.shared.getCurrentUser(), !userModel.isMoa() else { return }

        hasPerformedRiskCheck = true

        #if !RTCUBE_OVERSEAS
        if ModulePermissionService.shared.checkHighRiskUser() {
            showFaceAuthAlert(user: userModel)
        } else {
            showSafetyReminderAlert()
        }
        #endif
    }

    #if !RTCUBE_OVERSEAS
    private func showFaceAuthAlert(user: BSUserModel) {
        AppAssembly.shared.privacyActionHandler?(.showFaceIdTokenVerify(userId: user.userId, token: user.token, completion: { [weak self] isAuth, faceToken in
            guard let self = self else { return }
            if isAuth {
                getFaceAuth(token: faceToken)
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    showSafetyReminderAlert()
                }
            }
        }))
    }
    #endif

    #if !RTCUBE_OVERSEAS
    private func getFaceAuth(token: String) {
        #if !OPEN_SOURCE
        let config = AuthConfig()
        config.token = token
        if let path = Bundle.main.path(forResource: "HuiYanPublicSDK", ofType: "license") {
            config.licencePath = path
        }

        HuiYanSDKKit.sharedInstance().startHuiYanAuth(
            with: config,
            withProcessSucceed: { [weak self] resultInfo, _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.dismiss(animated: true)
                    ModulePermissionService.shared.updateNeedFaceAuth(false)
                    self.showSafetyReminderAlert()
                }
                AppLogger.App.info(" startHuiYanAuth succeed: \(resultInfo)")
            },
            withProcessFailedBlock: { [weak self] error, _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.view.makeToast(
                        MainLocalize("Demo.TRTC.Portal.Main.FaceAuthFailedMessage"),
                        position: .bottom
                    )
                }
                AppLogger.App.info(" startHuiYanAuth error: \(error) - \(error.localizedDescription)")
            }
        )
        #endif
    }
    #endif

    // MARK: - Safety Reminder

    private func showSafetyReminderAlert() {
        safeReminderWarningView.resetTimer()
        view.addSubview(safeReminderWarningView)
        safeReminderWarningView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

// MARK: - UICollectionViewDataSource

extension EntranceViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int
    {
        return store.state.modules.filter { $0.isVisible }.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "EntranceCollectionCell",
            for: indexPath
        ) as! EntranceCollectionCell

        let visibleModules = store.state.modules.filter { $0.isVisible }
        if indexPath.row < visibleModules.count {
            cell.config(visibleModules[indexPath.row])
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView
    {
        if kind == UICollectionView.elementKindSectionFooter {
            let footerView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: "footer",
                for: indexPath
            ) as! EntranceFooterView

            footerView.footerLabel.text = MainLocalize("Demo.TRTC.Portal.Main.trial")
            return footerView
        }
        return UICollectionReusableView()
    }
}

// MARK: - UICollectionViewDelegate

extension EntranceViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath)
    {
        let visibleModules = store.state.modules.filter { $0.isVisible }
        guard indexPath.row < visibleModules.count else { return }
        let module = visibleModules[indexPath.row]

        guard ModulePermissionService.shared.isModuleEnabled(module) else {
            #if !RTCUBE_OVERSEAS
            if ModulePermissionService.shared.isNeedFaceAuth,
               let user = LoginManager.shared.getCurrentUser()
            {
                showFaceAuthAlert(user: user)
            } else {
                showBannedToast()
            }
            #endif
            return
        }

        if !module.config.analyticsEvent.isEmpty {
            trackSensorData(module.config.analyticsEvent)
        }

        if let targetVC = module.config.targetProvider() {
            if targetVC.modalPresentationStyle == .fullScreen {
                present(targetVC, animated: true)
            } else {
                navigationController?.pushViewController(targetVC, animated: true)
            }
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension EntranceViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        let visibleModules = store.state.modules.filter { $0.isVisible }
        guard indexPath.item < visibleModules.count else {
            return CGSize(width: ScreenWidth / 2 - 13, height: 106)
        }

        let module = visibleModules[indexPath.item]
        return module.config.cardStyle == .banner
            ? CGSize(width: ScreenWidth - 24, height: 58)
            : CGSize(width: ScreenWidth / 2 - 13, height: 106)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForFooterInSection section: Int) -> CGSize
    {
        let text = MainLocalize("Demo.TRTC.Portal.Main.trial")
        let font = ThemeStore.shared.typographyTokens.Regular12
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let maxSize = CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude)
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let boundingRect = attributedString.boundingRect(with: maxSize,
                                                         options: options,
                                                         context: nil)
        let textHeight = ceil(boundingRect.height)
        return CGSize(width: collectionView.frame.width, height: textHeight)
    }
}

// MARK: - MainNavigationViewDelegate

extension EntranceViewController: MainNavigationViewDelegate {
    func jumpProfileController() {
        let mineVC = MineEntry.shared.buildMineViewController(
            onLogout: { [weak self] in
                guard let self = self else { return }
                hasPerformedRiskCheck = false
                LoginEntry.shared.logout { [weak self] result in
                    AppLogger.App.info(" logout result: \(result)")
                    guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                          let sceneDelegate = scene.delegate as? SceneDelegate else { return }
                    sceneDelegate.showLogin()
                    self?.navigationController?.popToRootViewController(animated: false)
                }
            },
            onLanguageChanged: { [weak self] languageID in
                self?.hasPerformedRiskCheck = false
                AppLogger.App.info(" language changed to: \(languageID)")
                guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                      let sceneDelegate = scene.delegate as? SceneDelegate else { return }
                sceneDelegate.showLogin()
            },
            onExperienceRoomClicked: { [weak self] in
                #if !OPEN_SOURCE
                let vc = RTCExperienceRoomLoginViewController(
                    userId: TUILogin.getUserID() ?? "",
                    language: LanguageEntry.shared.currentLanguageID
                )
                self?.navigationController?.pushViewController(vc, animated: true)
                #endif
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
        // No-op for now
    }
}

// MARK: - Analytics

extension EntranceViewController {
    private func trackSensorData(_ event: String) {
        let loginType = resolveLoginType()
        AppAnalytics.trackMainClick(
            eventName: "rtcube_main_click_event",
            mainEvent: event,
            loginType: loginType
        )
    }

    private func resolveLoginType() -> String {
        guard let userModel = LoginManager.shared.getCurrentUser() else {
            return "external"
        }

        if userModel.isMoa() {
            return "internal_moa"
        }

        if !userModel.phone.isEmpty {
            let phone = userModel.phone.trimmingCharacters(in: .whitespaces)

            let phoneLength = 11
            let phoneToCheck: String
            if phone.count > phoneLength {
                phoneToCheck = String(phone.suffix(phoneLength))
            } else {
                phoneToCheck = phone
            }

            if let phoneNumber = Int64(phoneToCheck),
               phoneNumber >= 10000000001 && phoneNumber <= 10000000050
            {
                return "internal_test"
            }
        }

        return "external"
    }
}
