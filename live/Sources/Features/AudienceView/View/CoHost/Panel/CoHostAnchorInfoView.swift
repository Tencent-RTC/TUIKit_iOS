//
//  CoHostAnchorInfoView.swift
//  TUILiveKit
//
//

import Foundation
import Combine
import AtomicX
import ImSDK_Plus
import AtomicXCore

class CoHostAnchorInfoView: RTCBaseView {
    private let manager: AudienceStore
    private let routerManager: AudienceRouterManager
    private var seatInfo: SeatInfo

    @Published private var isFollow = false
    @Published private var fansNumber = 0

    private var cancellableSet = Set<AnyCancellable>()

    private var showEnterLiveRoomButton: Bool {
        let targetLiveID = seatInfo.userInfo.liveID
        let currentLiveID = manager.liveListState.currentLive.liveID
        return !targetLiveID.isEmpty && targetLiveID != currentLiveID
    }

    private lazy var avatarView: AtomicAvatar = {
        let avatar = AtomicAvatar(
            content: .url("", placeholder: UIImage.avatarPlaceholderImage),
            size: .l,
            shape: .round
        )
        return avatar
    }()

    private let backgroundView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 12.scale375()
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        return view
    }()

    private lazy var userNameLabel: UILabel = {
        let label = UILabel()
        label.font = .customFont(ofSize: 16)
        label.text = seatInfo.userInfo.displayName
        label.textColor = .g7
        label.textAlignment = .center
        return label
    }()

    private lazy var userIdLabel: UILabel = {
        let label = UILabel()
        label.font = .customFont(ofSize: 12)
        if isRTLLanguage() {
            label.text = seatInfo.userInfo.userID + " :UserId"
        } else {
            label.text = .userIDText.replacingOccurrences(of: "xxx", with: seatInfo.userInfo.userID)
        }
        label.textColor = .greyColor
        label.textAlignment = .center
        return label
    }()

    private lazy var fansLabel: UILabel = {
        let label = UILabel()
        label.font = .customFont(ofSize: 12)
        label.textColor = .greyColor
        label.textAlignment = .center
        return label
    }()

    private lazy var followButton: AtomicButton = {
        let button = AtomicButton(
            variant: .filled,
            colorType: .primary,
            size: .large,
            content: .textOnly(text: .followText)
        )
        return button
    }()

    private lazy var enterLiveRoomButton: AtomicButton = {
        let button = AtomicButton(
            variant: .filled,
            colorType: .primary,
            size: .large,
            content: .textOnly(text: .enterAnchorLiveRoomText)
        )
        return button
    }()

    init(seatInfo: SeatInfo, manager: AudienceStore, routerManager: AudienceRouterManager) {
        self.seatInfo = seatInfo
        self.manager = manager
        self.routerManager = routerManager
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        debugPrint("deinit \(type(of: self))")
    }

    override func constructViewHierarchy() {
        addSubview(backgroundView)
        addSubview(userNameLabel)
        addSubview(userIdLabel)
        addSubview(fansLabel)
        addSubview(followButton)
        addSubview(enterLiveRoomButton)
        addSubview(avatarView)
    }

    override func activateConstraints() {
        avatarView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
        }
        backgroundView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(29.scale375Height())
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(showEnterLiveRoomButton ? 270.scale375Height() : 212.scale375Height())
        }
        userNameLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(65.scale375Height())
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(24.scale375Height())
        }
        userIdLabel.snp.makeConstraints { make in
            make.top.equalTo(userNameLabel.snp.bottom).offset(10.scale375Height())
            make.centerX.equalToSuperview()
            make.height.equalTo(17.scale375Height())
        }
        fansLabel.snp.makeConstraints { make in
            make.top.equalTo(userIdLabel.snp.bottom).offset(10.scale375Height())
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(17.scale375Height())
        }
        followButton.snp.makeConstraints { make in
            make.top.equalTo(fansLabel.snp.bottom).offset(24.scale375Height())
            make.centerX.equalToSuperview()
            make.width.equalTo(275.scale375())
            make.height.equalTo(40.scale375Height())
        }
        enterLiveRoomButton.isHidden = !showEnterLiveRoomButton
        if showEnterLiveRoomButton {
            enterLiveRoomButton.snp.makeConstraints { make in
                make.top.equalTo(followButton.snp.bottom).offset(12.scale375Height())
                make.centerX.equalToSuperview()
                make.width.equalTo(275.scale375())
                make.height.equalTo(40.scale375Height())
            }
        }
    }

    override func bindInteraction() {
        followButton.setClickAction { [weak self] _ in
            self?.followButtonClick()
        }
        enterLiveRoomButton.setClickAction { [weak self] _ in
            self?.enterLiveRoomButtonClick()
        }
        subscribeAnchorInfoState()
    }

    override func setupViewStyle() {
        avatarView.setContent(.url(seatInfo.userInfo.avatarURL, placeholder: UIImage.avatarPlaceholderImage))
        getFansNumber()
        checkFollowType()
    }

    // MARK: - Data fetch

    private func getFansNumber() {
        V2TIMManager.sharedInstance().getUserFollowInfo(userIDList: [seatInfo.userInfo.userID]) { [weak self] followInfoList in
            guard let self = self, let followInfo = followInfoList?.first else { return }
            self.fansNumber = Int(followInfo.followersCount)
        } fail: { code, message in
            debugPrint("CoHostAnchorInfoView getFansNumber failed, code:\(code), message:\(String(describing: message))")
        }
    }

    private func checkFollowType() {
        V2TIMManager.sharedInstance().checkFollowType(userIDList: [seatInfo.userInfo.userID]) { [weak self] checkResultList in
            guard let self = self, let result = checkResultList?.first else { return }
            if result.followType == .FOLLOW_TYPE_IN_BOTH_FOLLOWERS_LIST
                || result.followType == .FOLLOW_TYPE_IN_MY_FOLLOWING_LIST {
                self.isFollow = true
            } else {
                self.isFollow = false
            }
        } fail: { code, message in
            debugPrint("CoHostAnchorInfoView checkFollowType failed, code:\(code), message:\(String(describing: message))")
        }
    }

    private func subscribeAnchorInfoState() {
        $fansNumber
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                guard let self = self else { return }
                self.fansLabel.text = .localizedReplace(.fansCountText, replace: "\(count)")
            }
            .store(in: &cancellableSet)

        $isFollow
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] isFollow in
                guard let self = self else { return }
                if isFollow {
                    self.followButton.setButtonContent(.textOnly(text: .unfollowText))
                    self.followButton.setVariant(.filled)
                    self.followButton.setColorType(.secondary)
                } else {
                    self.followButton.setButtonContent(.textOnly(text: .followText))
                    self.followButton.setVariant(.filled)
                    self.followButton.setColorType(.primary)
                }
            }
            .store(in: &cancellableSet)
    }
}

// MARK: - Action
extension CoHostAnchorInfoView {
    private func followButtonClick() {
        if isFollow {
            V2TIMManager.sharedInstance().unfollowUser(userIDList: [seatInfo.userInfo.userID]) { [weak self] resultList in
                guard let self = self, let result = resultList?.first else { return }
                if result.resultCode == 0 {
                    self.isFollow = false
                    self.fansNumber = max(0, self.fansNumber - 1)
                } else {
                    self.manager.toastSubject.send(("code: \(result.resultCode), message: \(String(describing: result.resultInfo))", .error))
                }
            } fail: { [weak self] code, message in
                guard let self = self else { return }
                self.manager.toastSubject.send(("code: \(code), message: \(String(describing: message))", .error))
            }
        } else {
            V2TIMManager.sharedInstance().followUser(userIDList: [seatInfo.userInfo.userID]) { [weak self] resultList in
                guard let self = self, let result = resultList?.first else { return }
                if result.resultCode == 0 {
                    self.isFollow = true
                    self.fansNumber += 1
                } else {
                    self.manager.toastSubject.send(("code: \(result.resultCode), message: \(String(describing: result.resultInfo))", .error))
                }
            } fail: { [weak self] code, message in
                guard let self = self else { return }
                self.manager.toastSubject.send(("code: \(code), message: \(String(describing: message))", .error))
            }
        }
    }

    private func enterLiveRoomButtonClick() {
        let targetLiveID = seatInfo.userInfo.liveID
        guard !targetLiveID.isEmpty, targetLiveID != manager.liveListState.currentLive.liveID else { return }
        enterLiveRoomButton.isEnabled = false
        let manager = self.manager

        routerManager.dismiss(dismissType: .panel) {
            manager.switchRoomSubject.send(targetLiveID)
        }
    }
}

fileprivate extension String {
    static let fansCountText = internalLocalized("xxx Fans")
    static let followText = internalLocalized("common_follow_anchor")
    static let unfollowText = internalLocalized("common_unfollow_anchor")
    static let userIDText = internalLocalized("common_user_id")
    static let enterAnchorLiveRoomText = internalLocalized("common_enter_anchor_live_room")
}
