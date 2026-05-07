//
//  LiveListViewController.swift
//  main
//

import AtomicX
import AtomicXCore
import Combine
import Login
import SnapKit
import Toast_Swift
import TUICore
import TUILiveKit
import UIKit

// MARK: - LiveListViewController

final class LiveListViewController: UIViewController {
    private var currentStyle = LiveListViewStyle.doubleColumn
    private var cancellableSet = Set<AnyCancellable>()

    private weak var viewController: UIViewController?
    private var transitionCancellable: AnyCancellable?

    // MARK: - Subviews

    private lazy var liveListView: LiveListView = {
        let view = LiveListView(style: currentStyle)
        view.itemClickDelegate = self
        return view
    }()

    private lazy var createRoomBtn = AtomicButton(variant: .filled,
                                                  colorType: .primary,
                                                  size: .large,
                                                  content: .iconLeading(text: AssemblyLocalize("Demo.TRTC.LiveRoom.createroom"),
                                                                        icon: AppAssemblyBundle.image(named: "livekit_ic_add")))

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        ThemeStore.shared.setMode(.dark)
        setupNavigation()
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        ThemeStore.shared.setMode(.dark)
    }

    private func bindInteraction() {
        createRoomBtn.addTarget(self, action: #selector(createRoom), for: .touchUpInside)

        ThemeStore.shared.$currentTheme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] theme in
                guard let self else { return }
                applyAppearance(for: theme)
            }
            .store(in: &cancellableSet)
    }

    private func applyAppearance(for theme: Theme) {
        view.backgroundColor = theme.tokens.color.bgColorTopBar
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        liveListView.refreshLiveList()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            ThemeStore.shared.setMode(.light)
        }
        liveListView.onRouteToNextPage()
    }
}

// MARK: - UI

extension LiveListViewController {
    private func setupNavigation() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        let titleLabel = AssemblyLocalize("Demo.TRTC.LiveRoom.videoLive")
        let titleView = AtomicLabel(titleLabel) { theme in
            LabelAppearance(textColor: theme.tokens.color.textColorPrimary,
                            backgroundColor: theme.tokens.color.clearColor,
                            font: theme.tokens.typography.Medium20,
                            cornerRadius: 0.0)
        }
        titleView.adjustsFontSizeToFitWidth = true
        titleView.font = ThemeStore.shared.currentTheme.tokens.typography.Medium20
        titleView.text = titleLabel
        let width = titleView.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                  height: CGFloat.greatestFiniteMagnitude)).width
        titleView.frame = CGRect(origin: .zero, size: CGSize(width: width, height: 44))
        navigationItem.titleView = titleView

        let debugView = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        debugView.backgroundColor = .clear
        debugView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(debugModeChanged))
        tap.numberOfTapsRequired = 5
        debugView.addGestureRecognizer(tap)
        let debugViewItem = UIBarButtonItem(customView: debugView)

        let switchColumnBtn = UIButton(type: .custom)
        switchColumnBtn.setImage(AppAssemblyBundle.image(named: "live_single_column_icon"), for: .normal)
        switchColumnBtn.setImage(AppAssemblyBundle.image(named: "live_double_column_icon"), for: .selected)
        switchColumnBtn.addTarget(self, action: #selector(switchColumnBtnClick), for: .touchUpInside)
        switchColumnBtn.sizeToFit()
        let switchItem = UIBarButtonItem(customView: switchColumnBtn)
        switchItem.tintColor = .white
        navigationItem.rightBarButtonItems = [switchItem, debugViewItem]

        let backBtn = UIButton(type: .custom)
        backBtn.setImage(AppAssemblyBundle.image(named: "calling_back")?.withTintColor(.white, renderingMode: .alwaysOriginal),
                         for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        backBtn.sizeToFit()
        let backItem = UIBarButtonItem(customView: backBtn)
        backItem.tintColor = .white
        navigationItem.leftBarButtonItem = backItem
    }

    private func constructViewHierarchy() {
        view.addSubview(liveListView)
        view.addSubview(createRoomBtn)
    }

    private func activateConstraints() {
        liveListView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        createRoomBtn.snp.makeConstraints { make in
            make.bottom.equalTo(-(convertPixel(h: 15) + kDeviceSafeBottomHeight))
            make.centerX.equalToSuperview()
            make.height.equalTo(convertPixel(w: 48))
            make.width.equalTo(convertPixel(w: 154))
        }
    }
}

// MARK: - Actions

extension LiveListViewController {
    @objc private func createRoom() {
        guard AppAssembly.shared.canStartNewRoom else {
            AppAssembly.shared.showCannotStartRoomToast()
            return
        }

        let userId = LoginEntry.shared.userModel?.userId ?? ""
        let token = LoginEntry.shared.userModel?.token ?? ""
        if let privacyActionHandler = AppAssembly.shared.privacyActionHandler {
            privacyActionHandler(.checkRealNameAuth(userId: userId, token: token, completion: { [weak self] isAuth, msg in
                guard let self = self else { return }
                if isAuth {
                    let liveRoomId = LiveIdentityGenerator.shared.generateId(userId, type: .live)
                    startLive(roomId: liveRoomId)
                } else {
                    view.makeToast(msg)
                }
            }))
        } else {
            let liveRoomId = LiveIdentityGenerator.shared.generateId(userId, type: .live)
            startLive(roomId: liveRoomId)
        }
    }

    @objc private func backBtnClick() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func switchColumnBtnClick(sender: UIButton) {
        let newStyle: LiveListViewStyle = currentStyle == .doubleColumn ? .singleColumn : .doubleColumn
        currentStyle = newStyle
        liveListView.setColumnStyle(style: newStyle)
        sender.isSelected = currentStyle == .singleColumn
        createRoomBtn.isHidden = currentStyle == .singleColumn
    }

    @objc private func debugModeChanged() {
        NotificationCenter.default.post(Notification(name: Notification.Name("__kTUILiveKitTestModeChanged__")))
    }

    private func startLive(roomId: String) {
        if FloatWindow.shared.isShowingFloatWindow() {
            if let ownerId = FloatWindow.shared.getRoomOwnerId(), ownerId == LoginStore.shared.state.value.loginUserInfo?.userID {
                view.showAtomicToast(text: .pushingToReturnText, style: .error)
                return
            }
            FloatWindow.shared.releaseFloatWindow()
        }
        LiveListStore.shared.fetchLiveInfo(liveID: roomId) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let liveInfo):
                if liveInfo.keepOwnerOnSeat {
                    showPrepareViewController(roomId: roomId)
                } else {
                    showAnchorViewController(roomId: roomId, seatTemplate: liveInfo.seatTemplate)
                }
            case .failure:
                showPrepareViewController(roomId: roomId)
            }
        }
    }

    private func showPrepareViewController(roomId: String) {
        let vc = AnchorPrepareViewController(roomId: roomId)
        vc.modalPresentationStyle = .fullScreen
        vc.willStartLive = { [weak self] controller in
            guard let self = self else { return }
            self.viewController = controller
        }
        present(vc, animated: true)
    }

    private func showAnchorViewController(roomId: String, seatTemplate: SeatLayoutTemplate) {
        var liveInfo = LiveInfo(seatTemplate: seatTemplate)
        liveInfo.liveID = roomId
        let anchorVC = AnchorViewController(liveInfo: liveInfo, behavior: .enterRoom)
        anchorVC.modalPresentationStyle = .fullScreen
        present(anchorVC, animated: true)
    }
}

// MARK: - OnItemClickDelegate

extension LiveListViewController: OnItemClickDelegate {
    func onItemClick(liveInfo: LiveInfo, frame: CGRect) {
        if FloatWindow.shared.isShowingFloatWindow() {
            if FloatWindow.shared.getCurrentRoomId() == liveInfo.liveID {
                FloatWindow.shared.resumeLive(atViewController: navigationController ?? self)
                return
            } else if let ownerId = FloatWindow.shared.getRoomOwnerId(),
                      ownerId == LoginStore.shared.state.value.loginUserInfo?.userID
            {
                view.showAtomicToast(text: .pushingToReturnText, style: .error)
                return
            } else {
                FloatWindow.shared.releaseFloatWindow()
            }
        }

        let roomType = LiveIdentityGenerator.shared.getIDType(liveInfo.liveID)
        let isOwner = liveInfo.liveOwner.userID == (LoginStore.shared.state.value.loginUserInfo?.userID ?? "")

        switch roomType {
        case .voice:
            let vc = TUIVoiceRoomViewController(roomId: liveInfo.liveID, behavior: isOwner ? .autoCreate : .join)
            vc.modalPresentationStyle = .custom
            let transitionDelegate = LiveListTransitioningDelegate(originFrame: frame)
            vc.transitioningDelegate = transitionDelegate
            present(vc, animated: true)
        default:
            if isOwner {
                let vc = AnchorViewController(liveInfo: liveInfo, behavior: .enterRoom)
                vc.modalPresentationStyle = .custom
                let transitionDelegate = LiveListTransitioningDelegate(originFrame: frame)
                vc.transitioningDelegate = transitionDelegate
                present(vc, animated: true)
            } else {
                let isSingleColumn: Bool = frame.size == UIScreen.main.bounds.size
                let snapshotView = isSingleColumn ? view.snapshotView(afterScreenUpdates: true) : nil
                let vc = AudienceViewController(roomId: liveInfo.liveID)
                vc.modalPresentationStyle = .custom
                let transitionDelegate = LiveListTransitioningDelegate(originFrame: frame, snapshotView: snapshotView)
                vc.transitioningDelegate = transitionDelegate
                present(vc, animated: true)
                if isSingleColumn {
                    bindSnapshotDismissal(transitionDelegate: transitionDelegate)
                }
            }
        }
    }

    private func bindSnapshotDismissal(transitionDelegate: LiveListTransitioningDelegate) {
        transitionCancellable = LiveListStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \LiveListState.currentLive))
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] currentLive in
                guard let self else { return }
                if !currentLive.isEmpty {
                    transitionDelegate.dismissSnapshotOverlay()
                    transitionCancellable = nil
                }
            }
    }
}

// MARK: - Localized Strings

private extension String {
    static let pushingToReturnText = AssemblyLocalize("Demo.TRTC.LiveRoom.exitFloatWindowTip")
}
