//
//  AnchorCoHostOperatePanelView.swift
//  TUILiveKit
//
//  Created on 2026/4/1.
//

import UIKit
import Combine
import ImSDK_Plus
import AtomicXCore
import AtomicX

class AnchorCoHostOperatePanelView: RTCBaseView {
    private let store: AnchorStore
    private let routerManager: AnchorRouterManager
    private let user: LiveUserInfo
    @Published private var isFollow: Bool = false
    private var cancellableSet = Set<AnyCancellable>()

    private var isRemoteHostAudioMuted: Bool {
        store.seatState.seatList.first(where: { $0.userInfo.userID == user.userID })?.userInfo.microphoneStatus == .off
    }

    private var remoteLiveID: String? {
        store.coHostState.connected.first(where: { $0.userID == user.userID })?.liveID
    }

    // MARK: - Init

    init(user: LiveUserInfo, store: AnchorStore, routerManager: AnchorRouterManager) {
        self.user = user
        self.store = store
        self.routerManager = routerManager
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        debugPrint("deinit \(self)")
    }

    // MARK: - Subviews

    private lazy var userInfoView: UIView = {
        let view = UIView()
        return view
    }()

    private lazy var avatarView: AtomicAvatar = {
        let avatar = AtomicAvatar(
            content: .url("", placeholder: UIImage.avatarPlaceholderImage),
            size: .m,
            shape: .round
        )
        return avatar
    }()

    private lazy var userNameLabel: UILabel = {
        let label = UILabel()
        label.text = user.userName.isEmpty ? user.userID : user.userName
        label.font = .customFont(ofSize: 16)
        label.textColor = .g7
        return label
    }()

    private lazy var idLabel: UILabel = {
        let label = UILabel()
        label.font = .customFont(ofSize: 12)
        label.text = .userIDText.replacingOccurrences(of: "xxx", with: user.userID)
        label.textColor = .greyColor
        return label
    }()

    private lazy var followButton: AtomicButton = {
        let button = AtomicButton(
            variant: .filled,
            colorType: .primary,
            size: .medium,
            content: .textOnly(text: .followText)
        )
        return button
    }()

    private lazy var featureClickPanel: AnchorFeatureClickPanel = {
        let model = generateFeatureClickPanelModel()
        let featureClickPanel = AnchorFeatureClickPanel(model: model)
        return featureClickPanel
    }()

    // MARK: - RTCBaseView Lifecycle

    override func constructViewHierarchy() {
        layer.masksToBounds = true
        addSubview(userInfoView)
        userInfoView.addSubview(avatarView)
        userInfoView.addSubview(userNameLabel)
        userInfoView.addSubview(idLabel)
        userInfoView.addSubview(followButton)
        addSubview(featureClickPanel)
    }

    override func activateConstraints() {
        userInfoView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview().inset(24)
            make.height.equalTo(43.scale375())
        }
        avatarView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }
        userNameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalTo(avatarView.snp.trailing).offset(12.scale375())
            make.height.equalTo(20.scale375())
            make.width.lessThanOrEqualTo(170.scale375())
        }
        idLabel.snp.makeConstraints { make in
            make.leading.equalTo(userNameLabel)
            make.top.equalTo(userNameLabel.snp.bottom).offset(5.scale375())
            make.height.equalTo(17.scale375())
            make.width.lessThanOrEqualTo(200.scale375())
        }
        followButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }
        featureClickPanel.snp.makeConstraints { make in
            make.top.equalTo(userInfoView.snp.bottom).offset(21.scale375())
            make.leading.equalTo(userInfoView)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-16.scale375())
        }
    }

    override func bindInteraction() {
        subscribeState()
        followButton.setClickAction { [weak self] _ in
            self?.followButtonClick()
        }
    }

    override func setupViewStyle() {
        backgroundColor = .g2
        layer.cornerRadius = 12
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        userNameLabel.text = user.userName.isEmpty ? user.userID : user.userName
        avatarView.setContent(.url(user.avatarURL, placeholder: UIImage.avatarPlaceholderImage))
        checkFollowStatus()
    }

    // MARK: - State Subscription

    private func subscribeState() {
        $isFollow.receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] isFollow in
                guard let self = self else { return }
                if isFollow {
                    followButton.setButtonContent(.iconOnly(icon: internalImage("live_user_followed_icon")))
                    followButton.setVariant(.filled)
                    followButton.setColorType(.secondary)
                } else {
                    followButton.setButtonContent(.textOnly(text: .followText))
                    followButton.setVariant(.filled)
                    followButton.setColorType(.primary)
                }
            }
            .store(in: &cancellableSet)

        store.subscribeState(StatePublisherSelector(keyPath: \CoHostState.connected))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] connectedList in
                guard let self = self else { return }
                if !connectedList.contains(where: { $0.userID == self.user.userID }) {
                    routerManager.router(action: .dismiss())
                }
            }
            .store(in: &cancellableSet)

        let hostConnectedPublisher = store.subscribeState(StatePublisherSelector(keyPath: \CoHostState.connected))
        store.subscribeState(StatePublisherSelector(keyPath: \LiveSeatState.seatList))
            .removeDuplicates()
            .combineLatest(hostConnectedPublisher.removeDuplicates())
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                guard let self = self else { return }
                updateFeatureItems()
            }
            .store(in: &cancellableSet)
    }

    // MARK: - Feature Panel

    private lazy var designConfig: AnchorFeatureItemDesignConfig = {
        var designConfig = AnchorFeatureItemDesignConfig()
        designConfig.type = .imageAboveTitleBottom
        designConfig.imageTopInset = 14.scale375()
        designConfig.imageLeadingInset = 14.scale375()
        designConfig.imageSize = CGSize(width: 28.scale375(), height: 28.scale375())
        designConfig.titileColor = .g7
        designConfig.titleFont = .customFont(ofSize: 12)
        designConfig.backgroundColor = .g3.withAlphaComponent(0.3)
        designConfig.cornerRadius = 8.scale375Width()
        designConfig.titleHeight = 20.scale375Height()
        return designConfig
    }()

    private lazy var muteCoHostAudioItem: AnchorFeatureItem = .init(
        normalTitle: .muteRemoteAudioText,
        normalImage: internalImage("live_disable_audio_icon"),
        selectedTitle: .unMuteRemoteAudioText,
        selectedImage: internalImage("live_anchor_unmute_icon"),
        isSelected: isRemoteHostAudioMuted,
        designConfig: designConfig,
        actionClosure: { [weak self] sender in
            guard let self = self else { return }
            self.muteCoHostAudioClick(sender)
        }
    )

    private func generateFeatureClickPanelModel() -> AnchorFeatureClickPanelModel {
        let model = AnchorFeatureClickPanelModel()
        model.itemSize = CGSize(width: 56.scale375(), height: 56.scale375Height())
        model.itemDiff = 12.scale375()
        model.items.append(muteCoHostAudioItem)
        return model
    }

    private func updateFeatureItems() {
        muteCoHostAudioItem.isSelected = isRemoteHostAudioMuted
        let newItems = generateFeatureClickPanelModel().items
        featureClickPanel.updateFeatureItems(newItems: newItems)
    }

    // MARK: - Follow

    private func checkFollowStatus() {
        V2TIMManager.sharedInstance().checkFollowType(userIDList: [user.userID]) { [weak self] checkResultList in
            guard let self = self, let result = checkResultList?.first else { return }
            if result.followType == .FOLLOW_TYPE_IN_BOTH_FOLLOWERS_LIST || result.followType == .FOLLOW_TYPE_IN_MY_FOLLOWING_LIST {
                self.isFollow = true
            } else {
                self.isFollow = false
            }
        } fail: { _, _ in
        }
    }

    private func followButtonClick() {
        if isFollow {
            V2TIMManager.sharedInstance().unfollowUser(userIDList: [user.userID]) { [weak self] followResultList in
                guard let self = self, let result = followResultList?.first else { return }
                if result.resultCode == 0 {
                    isFollow = false
                } else {
                    store.toastSubject.send(("code: \(result.resultCode), message: \(String(describing: result.resultInfo))", .error))
                }
            } fail: { [weak self] code, message in
                guard let self = self else { return }
                store.toastSubject.send(("code: \(code), message: \(String(describing: message))", .error))
            }
        } else {
            V2TIMManager.sharedInstance().followUser(userIDList: [user.userID]) { [weak self] followResultList in
                guard let self = self, let result = followResultList?.first else { return }
                if result.resultCode == 0 {
                    isFollow = true
                } else {
                    store.toastSubject.send(("code: \(result.resultCode), message: \(String(describing: result.resultInfo))", .error))
                }
            } fail: { [weak self] code, message in
                guard let self = self else { return }
                store.toastSubject.send(("code: \(code), message: \(String(describing: message))", .error))
            }
        }
    }

    // MARK: - Mute Action

    private func muteCoHostAudioClick(_ sender: AnchorFeatureItemButton) {
        guard let liveID = remoteLiveID else { return }
        let isMuted = !isRemoteHostAudioMuted
        store.coHostStore.muteRemoteHostAudio(liveID: liveID, isMuted: isMuted) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(()):
                break
            case .failure(let err):
                let error = InternalError(code: err.code, message: err.message)
                store.toastSubject.send((error.localizedMessage, .error))
            }
        }
        routerManager.router(action: .dismiss())
    }
}

private extension String {
    static let followText = internalLocalized("common_follow_anchor")
    static let userIDText = internalLocalized("common_user_id")
    static let muteRemoteAudioText = internalLocalized("common_mute_audio")
    static let unMuteRemoteAudioText = internalLocalized("common_unmute_audio")
}
