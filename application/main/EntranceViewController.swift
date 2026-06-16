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
            liveLicenseURL: LIVE_LICENSE_URL,
            liveLicenseKey: LIVE_LICENSE_KEY,
            effectLicenseURL: TENCENT_EFFECT_LICENSE_URL,
            effectLicenseKey: TENCENT_EFFECT_LICENSE_KEY,
            playerLicenseURL: PLAYER_LICENSE_URL,
            playerLicenseKey: PLAYER_LICENSE_KEY,
            copyrightedMusicLicenseKey: COPYRIGHTED_MUSIC_LICENSE_KEY,
            copyrightedMusicLicenseUrl: COPYRIGHTED_MUSIC_LICENSE_URL,
            getCurrentUserModel: {
                LoginEntry.shared.userModel
            },
            generateUserSig: { userId in
                GenerateTestUserSig.genTestUserSig(identifier: userId, sdkAppId: SDKAPPID, secretKey: SECRETKEY)
            }
        )

        #if !RTCUBE_LAB
        AppAssembly.shared.privacyActionHandler = { action in
            if LoginManager.shared.getCurrentUser()?.isMoa() == true {
                switch action {
                case .checkRealNameAuth(_, _, let completion):
                    completion(true, "success")
                case .showFaceIdTokenVerify(_, _, let completion):
                    completion(true, "")
                default:
                    break
                }
                return
            }

            switch action {
            case .showAntifraudReminder:
                AntifraudAlertManager.showAntifraudReminder()
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
        AppAssembly.shared.analyticEventHandler = { action in
            switch action {
            case .liveEvent(let name, let params):
                AppAnalytics.trackModuleEvent(moduleId: "live", event: name, params: params)
            case .voiceRoomEvent(let name, let params):
                AppAnalytics.trackModuleEvent(moduleId: "voice_room", event: name, params: params)
            case .aiConversationEvent(let name, let params):
                AppAnalytics.trackModuleEvent(moduleId: "conversation_ai", event: name, params: params)
            case .interpretationEvent(let name, let params):
                AppAnalytics.trackModuleEvent(moduleId: "simultaneous_interpretation", event: name, params: params)
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

        #if !RTCUBE_OVERSEAS && !RTCUBE_LAB && !OPEN_SOURCE
        ModulePermissionService.shared.loadUserBlackList()
        #endif

        #if !DEBUG
        initAnalytics()
        ModuleAnalytics.start()
        #endif

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
        view.makeToast(MainLocalize("main_module_banned_message"))
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
                        MainLocalize("main_face_auth_failed_message"),
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

            footerView.footerLabel.text = MainLocalize("main_trial_hint")
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

        if module.config.identifier == "scenes_application" {
            if let url = URL(string: "https://trtc.io/exhibition/details?lang=zh&from=app") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            return
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

        if module.config.cardStyle == .banner {
            return CGSize(width: ScreenWidth - 24, height: 58)
        }

        let cellWidth = ScreenWidth / 2 - 13

        let rowHeight = calculateRowHeight(for: indexPath.item, visibleModules: visibleModules, cellWidth: cellWidth)

        return CGSize(width: cellWidth, height: rowHeight)
    }

    private func calculateRowHeight(for itemIndex: Int,
                                    visibleModules: [ResolvedModule],
                                    cellWidth: CGFloat) -> CGFloat
    {
        var nonBannerIndices: [Int] = []
        for (i, m) in visibleModules.enumerated() {
            if m.config.cardStyle != .banner {
                nonBannerIndices.append(i)
            }
        }

        guard let positionInNonBanner = nonBannerIndices.firstIndex(of: itemIndex) else {
            return 106
        }

        let rowStartPosition = (positionInNonBanner / 2) * 2

        var maxHeight: CGFloat = 106
        for offset in 0..<2 {
            let pos = rowStartPosition + offset
            guard pos < nonBannerIndices.count else { break }
            let idx = nonBannerIndices[pos]
            let h = EntranceCollectionCell.calculateHeight(for: visibleModules[idx], cellWidth: cellWidth)
            maxHeight = max(maxHeight, h)
        }

        return maxHeight
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForFooterInSection section: Int) -> CGSize
    {
        let text = MainLocalize("main_trial_hint")
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
    private func initAnalytics() {
        let userId = LoginEntry.shared.userModel?.userId ?? ""
        let sdkAppId = LoginEntry.shared.config.sdkAppId
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let loginMode = LoginEntry.shared.loggedInMode?.rawValue ?? LoginMode.debugAuth.rawValue
        #if RTCUBE_OVERSEAS
        let appTarget = "overseas"
        #else
        let appTarget = "domestic"
        #endif
        AppAnalytics.initialize(sdkAppId: sdkAppId, userId: userId, appTarget: appTarget, appVersion: appVersion, loginMode: "\(loginMode)")
    }

    private func trackSensorData(_ event: String) {
        let loginType = resolveLoginType()
        #if RTCUBE_OVERSEAS
        let eventName = AnalyticName.tencentRTCMainClick
        #else
        let eventName = AnalyticName.rtcubeMainClick
        #endif
        AppAnalytics.trackMainClick(
            eventName: eventName,
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
