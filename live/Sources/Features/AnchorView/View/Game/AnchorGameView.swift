//
//  AnchorGameView.swift
//  TUILiveKit
//
//  Created on 2026/3/27.
//

import UIKit
import SnapKit
import Combine
import Kingfisher
import ReplayKit
import AtomicXCore
import AtomicX


class AnchorGameView: UIView {

    /// Called when the guide view cancel button is tapped → AnchorView should stop live.
    var onStopLive: (() -> Void)?

    // MARK: - Private Properties

    private let liveID: String
    private let store: AnchorStore
    private let routerManager: AnchorRouterManager
    private var cancellableSet = Set<AnyCancellable>()
    private var screenShareGuideView: ScreenShareGuideView?

    private static let kAppGroup = "group.com.tencent.liteav.RPLiveStreamRelease"

    // MARK: - Subviews

    private lazy var backgroundImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.kf.setImage(with: URL(string: Constants.URL.defaultBackground))
        return iv
    }()

    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = .gameLivePlaceholderText
        label.textColor = .white
        label.font = .customFont(ofSize: 16, weight: .regular)
        label.textAlignment = .center
        return label
    }()

    private lazy var seatListView: AnchorSeatListView = {
        let view = AnchorSeatListView(liveID: liveID) { [weak self] seatInfo in
            self?.handleSeatTap(seatInfo)
        }
        return view
    }()

    private lazy var labelSpacerView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }()

    // MARK: - Init

    init(liveID: String, store: AnchorStore, routerManager: AnchorRouterManager) {
        self.liveID = liveID
        self.store = store
        self.routerManager = routerManager
        super.init(frame: .zero)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopScreenShare()
    }

    // MARK: - Layout

    private func setupViews() {
        addSubview(backgroundImageView)
        addSubview(labelSpacerView)
        addSubview(placeholderLabel)
        addSubview(seatListView)

        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        seatListView.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }

        labelSpacerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(seatListView.snp.top).offset(50.scale375())
        }

        placeholderLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(labelSpacerView)
        }

        seatListView.isHidden = true
    }

    // MARK: - Public API

    func showSeatList(_ show: Bool) {
        seatListView.isHidden = !show
    }

    /// Start screen share flow: begin TRTC screen capture + show guide if needed.
    func startScreenShare() {
        showScreenShareGuideView()
        beginScreenCapture()
    }

    /// Stop screen capture (call when ending live or in deinit).
    func stopScreenShare() {
        store.deviceStore.stopScreenShare()
    }

    /// Restore screen share mode when re-joining a room that was already screen-sharing.
    func restoreScreenShare() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            showSeatList(true)
            startScreenShare()
        }
    }

    // MARK: - Screen Share Internal

    private func beginScreenCapture() {
        store.deviceStore.startScreenShare(appGroup: AnchorGameView.kAppGroup)
        launchReplayKitBroadcast()
    }

    private func showScreenShareGuideView() {
        guard !UIScreen.main.isCaptured else { return }

        let guideView = ScreenShareGuideView()
        screenShareGuideView = guideView

        guideView.onCancel = { [weak self] in
            guard let self = self else { return }
            guideView.removeFromSuperview()
            screenShareGuideView = nil
            onStopLive?()
        }

        guideView.onStartBroadcast = { [weak self] in
            guard let self = self else { return }
            launchReplayKitBroadcast()
        }

        guideView.onScreenCaptureStarted = { [weak self] in
            guard let self = self else { return }
            guideView.removeFromSuperview()
            screenShareGuideView = nil
        }

        addSubview(guideView)
        guideView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func launchReplayKitBroadcast() {
        if #available(iOS 12.0, *) {
            let pickerView = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
            pickerView.preferredExtension = Bundle.main.bundleIdentifier.map { $0 + ".TUIKitReplay" }
            pickerView.showsMicrophoneButton = true

            for subview in pickerView.subviews {
                if let button = subview as? UIButton {
                    button.sendActions(for: .allTouchEvents)
                    break
                }
            }
        }
    }

    // MARK: - Seat Tap Handling

    private func handleSeatTap(_ seatInfo: SeatInfo) {
        guard !seatInfo.userInfo.userID.isEmpty else { return }
        let liveUserInfo = LiveUserInfo(seatUserInfo: seatInfo.userInfo)
        let panel = AnchorUserManagePanelView(user: liveUserInfo, store: store, routerManager: routerManager, type: .mediaAndSeat)
        routerManager.present(view: panel, config: .bottomDefault())
    }
}

private extension String {
    static let gameLivePlaceholderText = internalLocalized("common_live_game")
}
