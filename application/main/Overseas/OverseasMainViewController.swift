//
//  OverseasMainViewController.swift
//  main
//

import UIKit
import Combine
import SnapKit
import Toast_Swift
import ImSDK_Plus
import TUICore
import AppAssembly
import Login
import AtomicX

class OverseasMainViewController: UIViewController {

    // MARK: - Properties

    private let store = EntranceStore()
    private var cancellables = Set<AnyCancellable>()

    private let discoveryIdentifiers: Set<String> = ["player", "ugsv"]

    private var productsModules: [ResolvedModule] = []
    private var discoveryModules: [ResolvedModule] = []

    // MARK: - UI Elements

    private let topSegmentedView: UISegmentedControl = {
        let segmentedView = UISegmentedControl(items: [
            MainLocalize("Demo.TRTC.Portal.Main.Products"),
            MainLocalize("Demo.TRTC.Portal.Main.DiscoveryLab"),
        ])
        segmentedView.selectedSegmentIndex = 0
        segmentedView.setTitleTextAttributes([
            .foregroundColor: ThemeStore.shared.colorTokens.textColorSecondary,
            .font: ThemeStore.shared.typographyTokens.Regular12,
        ], for: .normal)
        segmentedView.setTitleTextAttributes([
            .foregroundColor: ThemeStore.shared.colorTokens.textColorLink,
            .font: UIFont.boldSystemFont(ofSize: 12),
        ], for: .selected)
        return segmentedView
    }()

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView(frame: .zero)
        scrollView.backgroundColor = .clear
        scrollView.isPagingEnabled = true
        scrollView.bounces = true
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        return scrollView
    }()

    private let containerView: UIView = {
        let view = UIView()
        return view
    }()

    private lazy var productsCollectionView: UICollectionView = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
        flowLayout.minimumLineSpacing = 8
        flowLayout.minimumInteritemSpacing = 0

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.register(OverseasCollectionCell.self,
                                forCellWithReuseIdentifier: "OverseasCollectionCell")
        collectionView.register(OverseasFooterView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                                withReuseIdentifier: "OverseasFooter")
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsVerticalScrollIndicator = false
        return collectionView
    }()

    private lazy var discoveryCollectionView: UICollectionView = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
        flowLayout.minimumLineSpacing = 8
        flowLayout.minimumInteritemSpacing = 0

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.register(OverseasCollectionCell.self,
                                forCellWithReuseIdentifier: "OverseasCollectionCell")
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsVerticalScrollIndicator = false
        return collectionView
    }()

    private let contactUsTipsView: ContactUsTipsView = {
        let view = ContactUsTipsView()
        view.contactUsHandler = {
            TUICore.callService(TUICore_ContactUsService,
                                method: TUICore_ContactService_gotoContactUS,
                                param: [:])
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
                return LoginEntry.shared.userModel
            },
            generateUserSig: { userId in
                GenerateTestUserSig.genTestUserSig(identifier: userId, sdkAppId: SDKAPPID, secretKey: SECRETKEY)
            }
        )

        PrivacyEntry.enableIdCardVerification = false

        #if !OPEN_SOURCE
        AppAssembly.shared.privacyActionHandler = { action in
            switch action {
            case .showHighRiskIPAlert:
                RoomRiskIPPresenter.showHighRiskIPAlert()
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
            case .showLiveTimeOutAlert(let onDismiss):
                TimeLimitPresenter.showLiveTimeOutAlert(onDismiss: onDismiss)
            }
        }
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

        constructViewHierarchy()
        activateConstraints()
        bindInteraction()

        store.loadModules()
        splitModules()

        bindStoreState()

        setupToast()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available(iOS 13.0, *) {
            return .darkContent
        }
        return .default
    }

    override var prefersStatusBarHidden: Bool {
        false
    }

    // MARK: - Module Split

    private func splitModules() {
        let allModules = store.state.modules.filter { $0.isVisible }
        productsModules = allModules.filter { !discoveryIdentifiers.contains($0.config.identifier) }
        discoveryModules = allModules.filter { discoveryIdentifiers.contains($0.config.identifier) }
    }

    // MARK: - State Binding

    private func bindStoreState() {
        store.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.splitModules()
                self.productsCollectionView.reloadData()
                self.discoveryCollectionView.reloadData()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public

    func updateUnreadCount(_ totalUnreadCount: UInt64) {
        guard !productsModules.isEmpty else { return }
        let identifier = productsModules[0].config.identifier
        store.updateBadgeCount(for: identifier, count: totalUnreadCount)
        splitModules()
        DispatchQueue.main.async {
            self.productsCollectionView.reloadItems(at: [IndexPath(item: 0, section: 0)])
        }
    }
}

// MARK: - UI Setup

extension OverseasMainViewController {

    private func constructViewHierarchy() {
        view.addSubview(topSegmentedView)
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        containerView.addSubview(productsCollectionView)
        containerView.addSubview(contactUsTipsView)
        containerView.addSubview(discoveryCollectionView)
    }

    private func activateConstraints() {
        topSegmentedView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalToSuperview().offset(44 + statusBarHeight() + 8)
            make.height.equalTo(32)
        }

        scrollView.snp.makeConstraints { make in
            make.top.equalTo(topSegmentedView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview()
        }

        productsCollectionView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.width.equalTo(ScreenWidth)
            make.left.equalToSuperview()
            make.bottom.equalToSuperview().offset(-12)
        }

        contactUsTipsView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalTo(productsCollectionView.snp.trailing)
            make.trailing.equalToSuperview()
        }

        discoveryCollectionView.snp.makeConstraints { make in
            make.top.equalTo(contactUsTipsView.snp.bottom).offset(4)
            make.width.equalTo(ScreenWidth)
            make.leading.equalTo(productsCollectionView.snp.trailing)
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-12)
        }
    }

    private func bindInteraction() {
        topSegmentedView.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
    }

    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        let page = sender.selectedSegmentIndex
        let targetOffset = CGPoint(x: CGFloat(page) * scrollView.frame.width, y: 0)
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)

        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.scrollView.contentOffset = targetOffset
        }
    }

    private func setupToast() {
        ToastManager.shared.position = .bottom
    }
}

// MARK: - UIScrollViewDelegate

extension OverseasMainViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == self.scrollView else { return }
        let page = scrollView.contentOffset.x / scrollView.frame.width
        topSegmentedView.selectedSegmentIndex = Int(round(page))
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension OverseasMainViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: view.bounds.width - 40.0, height: 74)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForFooterInSection section: Int) -> CGSize {
        if collectionView == productsCollectionView {
            return CGSize(width: view.bounds.width - 40.0, height: 92)
        }
        return .zero
    }
}

// MARK: - UICollectionViewDelegate

extension OverseasMainViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let module: ResolvedModule
        if collectionView == productsCollectionView {
            guard indexPath.item < productsModules.count else { return }
            module = productsModules[indexPath.item]
        } else {
            guard indexPath.item < discoveryModules.count else { return }
            module = discoveryModules[indexPath.item]
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

// MARK: - UICollectionViewDataSource

extension OverseasMainViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if collectionView == productsCollectionView {
            return productsModules.count
        } else {
            return discoveryModules.count
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "OverseasCollectionCell",
            for: indexPath
        ) as! OverseasCollectionCell

        if collectionView == productsCollectionView {
            if indexPath.item < productsModules.count {
                cell.config(productsModules[indexPath.item])
            }
        } else {
            if indexPath.item < discoveryModules.count {
                cell.config(discoveryModules[indexPath.item])
            }
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        if collectionView == productsCollectionView,
           kind == UICollectionView.elementKindSectionFooter {
            let footerView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: "OverseasFooter",
                for: indexPath
            ) as! OverseasFooterView
            let tap = UITapGestureRecognizer(target: self, action: #selector(goScenarioExperience))
            footerView.isUserInteractionEnabled = true
            footerView.addGestureRecognizer(tap)
            return footerView
        }
        return UICollectionReusableView()
    }
}

// MARK: - Navigation

extension OverseasMainViewController {

    @objc private func goScenarioExperience() {
        if let scenesModule = store.state.modules.first(where: { $0.config.identifier == "scenesApplication" }) {
            if let targetVC = scenesModule.config.targetProvider() {
                targetVC.title = MainLocalize("Demo.TRTC.Portal.Main.ScenarioExperience")
                navigationController?.pushViewController(targetVC, animated: true)
            }
        }
    }
}

// MARK: - Analytics

extension OverseasMainViewController {

    private func trackSensorData(_ event: String) {
        let loginType = resolveLoginType()
        AppAnalytics.trackMainClick(
            eventName: "tencent_rtc_main_click_event",
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

        return "external"
    }
}
