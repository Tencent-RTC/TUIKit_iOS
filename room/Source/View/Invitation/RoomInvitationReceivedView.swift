//
//  RoomInvitationReceivedView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/8/5.
//  Copyright © 2026 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import AtomicXCore
import Kingfisher

public class RoomInvitationReceivedView: UIView, BaseView {

    // MARK: - BaseView
    public weak var routerContext: RouterContext?

    // MARK: - Data
    private let roomInfo: RoomInfo
    private let caller: RoomUser

    // MARK: - UI Components
    private lazy var backgroundImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.alpha = 0.2
        return iv
    }()

    private lazy var avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 25
        iv.clipsToBounds = true
        iv.image = ResourceLoader.loadImage("avatar_placeholder")
        return iv
    }()

    private lazy var invitationLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private lazy var roomNameLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 24, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private lazy var detailsLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private lazy var joinSliderView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        view.layer.cornerRadius = 39
        return view
    }()

    private lazy var joinLabel: UILabel = {
        let label = UILabel()
        label.text = .joinNow
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        label.textAlignment = .center
        return label
    }()

    private lazy var sliderThumbView: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.b1
        view.layer.cornerRadius = 32
        return view
    }()

    private lazy var arrowImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = ResourceLoader.loadImage("room_invite_accept_arrow")
        iv.tintColor = .white
        return iv
    }()

    private lazy var declineButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(.decline, for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.8), for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        button.addTarget(self, action: #selector(handleDeclineTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Init
    public init(roomInfo: RoomInfo, caller: RoomUser) {
        self.roomInfo = roomInfo
        self.caller = caller
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        updateContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - BaseView
    public func setupViews() {
        addSubview(backgroundImageView)
        addSubview(avatarImageView)
        addSubview(invitationLabel)
        addSubview(roomNameLabel)
        addSubview(detailsLabel)
        addSubview(joinSliderView)
        joinSliderView.addSubview(joinLabel)
        joinSliderView.addSubview(sliderThumbView)
        sliderThumbView.addSubview(arrowImageView)
        addSubview(declineButton)
    }

    public func setupConstraints() {
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        avatarImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.height.equalTo(50)
            make.top.equalToSuperview().offset(150)
        }
        invitationLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(avatarImageView.snp.bottom).offset(16)
        }
        roomNameLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.lessThanOrEqualTo(300)
            make.top.equalTo(invitationLabel.snp.bottom).offset(30)
        }
        detailsLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(roomNameLabel.snp.bottom).offset(10)
        }
        declineButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-94)
        }
        joinSliderView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(200)
            make.height.equalTo(78)
            make.bottom.equalTo(declineButton.snp.top).offset(-30)
        }
        joinLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.centerX.equalToSuperview().offset(32)
        }
        sliderThumbView.snp.makeConstraints { make in
            make.left.equalTo(joinSliderView.snp.left).offset(5)
            make.centerY.equalTo(joinSliderView.snp.centerY)
            make.width.height.equalTo(64)
        }
        arrowImageView.snp.makeConstraints { make in
            make.center.equalTo(sliderThumbView)
            make.width.height.equalTo(20)
        }
    }

    public func setupStyles() {
        backgroundColor = .black
    }

    public func setupBindings() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        sliderThumbView.addGestureRecognizer(panGesture)
    }

    // MARK: - Content
    private func updateContent() {
        let callerName = caller.userName.isEmpty ? caller.userID : caller.userName
        invitationLabel.text = .invitationTitle.localizedReplace(callerName)

        roomNameLabel.text = roomInfo.roomName

        let hostName = roomInfo.roomOwner.userName.isEmpty ? roomInfo.roomOwner.userID : roomInfo.roomOwner.userName
        detailsLabel.text = .invitationRoomMeta.localizedReplace(hostName, "\(roomInfo.participantCount)")

        if !caller.avatarURL.isEmpty, let url = URL(string: caller.avatarURL) {
            avatarImageView.kf.setImage(with: url, placeholder: ResourceLoader.loadImage("avatar_placeholder"))
            backgroundImageView.kf.setImage(with: url, placeholder: ResourceLoader.loadImage("avatar_placeholder"))
        }
    }

    // MARK: - Slider Interaction
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: joinSliderView)
        let maxTranslation = joinSliderView.frame.width - sliderThumbView.frame.width - 10

        switch gesture.state {
        case .changed:
            if translation.x >= 0 && translation.x <= maxTranslation {
                sliderThumbView.snp.updateConstraints { make in
                    make.left.equalTo(joinSliderView.snp.left).offset(5 + translation.x)
                }
            }
        case .ended:
            if translation.x >= maxTranslation {
                sliderThumbView.snp.updateConstraints { make in
                    make.left.equalTo(joinSliderView.snp.left).offset(5 + maxTranslation)
                }
                gesture.isEnabled = false
                RoomInvitationManager.shared.acceptCall(roomInfo: roomInfo) { [weak self] error in
                    guard let self = self else { return }
                    if let error = error {
                        showAtomicToast(
                            text: InternalError(code: error.code, message: error.message).localizedMessage,
                            style: .warning,
                            position: .center
                        )
                    }
                }
            } else {
                sliderThumbView.snp.updateConstraints { make in
                    make.left.equalTo(joinSliderView.snp.left).offset(5)
                }
                UIView.animate(withDuration: 0.3) {
                    self.layoutIfNeeded()
                }
            }
        default:
            break
        }
    }

    // MARK: - Actions
    @objc private func handleDeclineTapped() {
        RoomInvitationManager.shared.rejectCall(roomID: roomInfo.roomID) { _ in }
    }
}

// MARK: - Localized strings
private extension String {
    static let invitationTitle = "roomkit_invite_you_to_join_room".localized
    static let invitationRoomMeta = "roomkit_invitation_room_meta".localized
    static let joinNow = "roomkit_join_now".localized
    static let decline = "roomkit_do_not_enter_for_now".localized
}
