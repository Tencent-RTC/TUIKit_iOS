//
//  AdminManagerPanelView.swift
//  TUILiveKit
//
//  Aligned with Android AdminManagerDialog.kt under
//  com.trtc.uikit.livekit.features.audienceview.view.userinfo.
//

import AtomicX
import AtomicXCore
import Combine
import Foundation
import UIKit

class AdminManagerPanelView: RTCBaseView {
    private let manager: AudienceStore
    private let routerManager: AudienceRouterManager
    private let user: LiveUserInfo

    private var isMessageDisabled: Bool {
        let userID = user.userID
        return manager.liveAudienceStore.state.value.messageBannedUserList
            .contains(where: { $0.userID == userID })
    }

    private var cancellableSet = Set<AnyCancellable>()

    // MARK: - Subviews

    private lazy var userInfoView: UIView = {
        UIView()
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

    private lazy var designConfig: AudienceFeatureItemDesignConfig = {
        var designConfig = AudienceFeatureItemDesignConfig()
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

    private lazy var disableMessageItem: AudienceFeatureItem = .init(
        normalTitle: .disableChatText,
        normalImage: internalImage("live_enable_chat_icon"),
        selectedTitle: .enableChatText,
        selectedImage: internalImage("live_disable_chat_icon"),
        isSelected: isMessageDisabled,
        designConfig: designConfig,
        actionClosure: { [weak self] sender in
            guard let self = self else { return }
            self.disableMessageClick(sender)
        }
    )

    private lazy var kickOutItem: AudienceFeatureItem = .init(
        normalTitle: .kickOutOfRoomText,
        normalImage: internalImage("live_anchor_kickout_icon"),
        designConfig: designConfig,
        actionClosure: { [weak self] _ in
            guard let self = self else { return }
            self.kickOutClick()
        }
    )

    private lazy var featureClickPanel: AudienceFeatureClickPanel = {
        let model = AudienceFeatureClickPanelModel()
        model.itemSize = CGSize(width: 56.scale375(), height: 56.scale375Height())
        model.itemDiff = 12.scale375()
        model.items.append(disableMessageItem)
        model.items.append(kickOutItem)
        return AudienceFeatureClickPanel(model: model)
    }()

    // MARK: - Init

    init(user: LiveUserInfo, manager: AudienceStore, routerManager: AudienceRouterManager) {
        self.user = user
        self.manager = manager
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

    // MARK: - View Lifecycle

    override func constructViewHierarchy() {
        layer.masksToBounds = true
        addSubview(userInfoView)
        userInfoView.addSubview(avatarView)
        userInfoView.addSubview(userNameLabel)
        userInfoView.addSubview(idLabel)
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
        featureClickPanel.snp.makeConstraints { make in
            make.top.equalTo(userInfoView.snp.bottom).offset(21.scale375())
            make.leading.equalTo(userInfoView)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-16.scale375())
        }
    }

    override func setupViewStyle() {
        backgroundColor = .g2
        layer.cornerRadius = 12
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        avatarView.setContent(.url(user.avatarURL, placeholder: UIImage.avatarPlaceholderImage))
    }

    override func bindInteraction() {
        subscribeState()
    }

    // MARK: - Subscribe

    private func subscribeState() {
        manager.liveAudienceStore.state
            .subscribe(StatePublisherSelector(keyPath: \LiveAudienceState.messageBannedUserList))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] userList in
                guard let self = self else { return }
                let disabled = userList.contains(where: { $0.userID == self.user.userID })
                self.disableMessageItem.isSelected = disabled
            }
            .store(in: &cancellableSet)

        manager.liveAudienceStore.liveAudienceEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onAudienceLeft(audience: let audience):
                    if audience.userID == self.user.userID {
                        self.routerManager.router(action: .dismiss())
                    }
                case .onAudienceMessageDisabled(audience: let audience, isDisable: let isDisable):
                    if audience.userID == self.user.userID {
                        self.disableMessageItem.isSelected = isDisable
                        self.featureClickPanel.updateFeatureItems(newItems: [self.disableMessageItem, self.kickOutItem])
                    }
                default:
                    break
                }
            }
            .store(in: &cancellableSet)

        manager.liveListStore.liveListEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                if case .onLiveEnded(liveID: _, reason: _, message: _) = event {
                    self.routerManager.router(action: .dismiss())
                }
            }
            .store(in: &cancellableSet)
    }
}

// MARK: - Action

extension AdminManagerPanelView {
    private func disableMessageClick(_ sender: AudienceFeatureItemButton) {
        let nextDisabled = !isMessageDisabled
        manager.liveAudienceStore.disableSendMessage(userID: user.userID,
                                                     isDisable: nextDisabled) { [weak self, weak sender] result in
            guard let self = self else { return }
            switch result {
            case .success(()):
                sender?.isSelected = nextDisabled
            case .failure(let err):
                let error = InternalError(code: err.code, message: err.message)
                self.manager.toastSubject.send((error.localizedMessage, .error))
            }
        }
        routerManager.router(action: .dismiss())
    }

    private func kickOutClick() {
        let cancelButton = AlertButtonConfig(text: .cancelText, type: .grey) { alertView in
            alertView.dismiss()
        }

        let confirmButton = AlertButtonConfig(text: .kickOutOfRoomConfirmText, type: .red) { [weak self] alertView in
            guard let self = self else { return }
            self.manager.liveAudienceStore.kickUserOutOfRoom(userID: self.user.userID) { [weak self] result in
                guard let self = self else { return }
                if case .failure(let err) = result {
                    let error = InternalError(code: err.code, message: err.message)
                    self.manager.toastSubject.send((error.localizedMessage, .error))
                }
            }
            alertView.dismiss()
            self.routerManager.dismiss()
        }

        let alertConfig = AlertViewConfig(
            title: .localizedReplace(.kickOutAlertText,
                                     replace: user.userName.isEmpty ? user.userID : user.userName),
            cancelButton: cancelButton,
            confirmButton: confirmButton
        )
        let alertView = AtomicAlertView(config: alertConfig)
        alertView.show()
    }
}

// MARK: - Localized Strings

private extension String {
    static let cancelText = internalLocalized("common_cancel")
    static let userIDText = internalLocalized("common_user_id")
    static let disableChatText = internalLocalized("common_disable_message")
    static let enableChatText = internalLocalized("common_enable_message")
    static let kickOutOfRoomText = internalLocalized("common_kick_out_of_room")
    static let kickOutOfRoomConfirmText = internalLocalized("common_kick_out_of_room")
    static let kickOutAlertText = internalLocalized("common_kick_user_confirm_message")
}
