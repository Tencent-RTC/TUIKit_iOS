//
//  ParticipantListCell.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/2/14.
//  Copyright © 2026 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import AtomicXCore
import Kingfisher

// MARK: - Participant Sorting
extension Array where Element == RoomParticipant {
    func sortedForParticipantList(localUserID: String) -> [RoomParticipant] {
        return sorted { p1, p2 in
            let rolePriority1 = participantRolePriority(p1, localUserID: localUserID)
            let rolePriority2 = participantRolePriority(p2, localUserID: localUserID)
            if rolePriority1 != rolePriority2 {
                return rolePriority1 < rolePriority2
            }

            let devicePriority1 = participantDevicePriority(p1)
            let devicePriority2 = participantDevicePriority(p2)
            if devicePriority1 != devicePriority2 {
                return devicePriority1 < devicePriority2
            }

            return p1.userName < p2.userName
        }
    }
}

private func participantRolePriority(_ participant: RoomParticipant, localUserID: String) -> Int {
    if participant.userID == localUserID { return 0 }
    if participant.role == .owner { return 1 }
    if participant.role == .admin { return 2 }
    return 3
}

private func participantDevicePriority(_ participant: RoomParticipant) -> Int {
    if participant.screenShareStatus == .on { return 0 }
    if participant.cameraStatus == .on && participant.microphoneStatus == .on { return 1 }
    if participant.cameraStatus == .on { return 2 }
    if participant.microphoneStatus == .on { return 3 }
    return 4
}

// MARK: - BaseParticipantCell
class BaseParticipantCell: UITableViewCell {
    // MARK: - Properties
    var roomID: String = ""

    lazy var participantStore: RoomParticipantStore = {
        RoomParticipantStore.create(roomID: roomID)
    }()

    // MARK: - UI Components
    lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 20
        imageView.layer.masksToBounds = true
        return imageView
    }()

    lazy var containerView: UIView = {
        let view = UIView()
        return view
    }()

    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        label.textColor = RoomColors.g7
        return label
    }()

    lazy var roleIcon: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()

    lazy var roleLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 12, weight: .regular)
        return label
    }()

    lazy var dividerLine: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g3.withAlphaComponent(0.3)
        return view
    }()

    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        setupConstraints()
        setupStyles()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup Methods
    func setupViews() {
        contentView.addSubview(avatarImageView)
        contentView.addSubview(containerView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(roleIcon)
        containerView.addSubview(roleLabel)
        contentView.addSubview(dividerLine)
    }

    func setupConstraints() {
        avatarImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(RoomSpacing.large)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }

        nameLabel.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.top.equalToSuperview()
            make.right.equalToSuperview()
        }

        roleIcon.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.size.equalTo(CGSize(width: 14, height: 14))
            make.centerY.equalTo(roleLabel.snp.centerY)
        }

        roleLabel.snp.makeConstraints { make in
            make.left.equalTo(roleIcon.snp.right).offset(2)
            make.top.equalTo(nameLabel.snp.bottom).offset(2)
            make.bottom.equalToSuperview()
            make.right.equalToSuperview()
        }
    }

    func setupStyles() {
        contentView.backgroundColor = RoomColors.g2
        backgroundColor = .clear
        selectionStyle = .none
    }

    // MARK: - Common Methods
    func configureBasicInfo(participant: RoomParticipant, roomID: String) {
        self.roomID = roomID

        avatarImageView.kf.setImage(
            with: URL(string: participant.avatarURL),
            placeholder: ResourceLoader.loadImage("avatar_placeholder")
        )

        let currentUserID = participantStore.state.value.localParticipant?.userID ?? ""
        nameLabel.text = participant.userID == currentUserID
            ? "\(participant.name)(\(String.me))"
            : participant.name

        updateRoleLabel(role: participant.role)
    }

    func updateRoleLabel(role: ParticipantRole) {
        switch role {
        case .owner:
            roleLabel.text = .owner
            roleLabel.textColor = RoomColors.b1d
            roleIcon.image = ResourceLoader.loadImage("room_owner_tag")
            roleLabel.isHidden = false
            roleIcon.isHidden = false
        case .admin:
            roleLabel.text = .administrator
            roleLabel.textColor = RoomColors.adminTagColor
            roleIcon.image = ResourceLoader.loadImage("room_admin_tag")
            roleLabel.isHidden = false
            roleIcon.isHidden = false
        default:
            roleLabel.isHidden = true
            roleIcon.isHidden = true
        }

        if role == .generalUser {
            nameLabel.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
            }
        } else {
            nameLabel.snp.remakeConstraints { make in
                make.left.top.right.equalToSuperview()
            }

            roleIcon.snp.remakeConstraints { make in
                make.left.equalToSuperview()
                make.size.equalTo(CGSize(width: 14, height: 14))
                make.centerY.equalTo(roleLabel.snp.centerY)
            }

            roleLabel.snp.remakeConstraints { make in
                make.left.equalTo(roleIcon.snp.right).offset(2)
                make.top.equalTo(nameLabel.snp.bottom).offset(2)
                make.bottom.right.equalToSuperview()
            }
        }
    }
}

// MARK: - ParticipantListCell
class ParticipantListCell: BaseParticipantCell {
    // MARK: - Additional UI Components
    private lazy var buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = RoomSpacing.large
        stackView.alignment = .trailing
        stackView.distribution = .equalSpacing
        return stackView
    }()

    private lazy var recordImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = ResourceLoader.loadImage("room_recording_tag")
        imageView.isHidden = true
        return imageView
    }()

    private lazy var screenShareImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = ResourceLoader.loadImage("room_screen_share_tag")
        imageView.isHidden = true
        return imageView
    }()

    private lazy var microphoneImageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()

    private lazy var cameraImageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()

    // MARK: - Setup Methods
    override func setupViews() {
        super.setupViews()
        contentView.addSubview(buttonStackView)
        buttonStackView.addArrangedSubview(recordImageView)
        buttonStackView.addArrangedSubview(screenShareImageView)
        buttonStackView.addArrangedSubview(microphoneImageView)
        buttonStackView.addArrangedSubview(cameraImageView)
    }

    override func setupConstraints() {
        super.setupConstraints()

        containerView.snp.makeConstraints { make in
            make.left.equalTo(avatarImageView.snp.right).offset(RoomSpacing.medium)
            make.centerY.equalTo(avatarImageView.snp.centerY)
            make.right.lessThanOrEqualTo(buttonStackView.snp.left).offset(-5)
        }

        buttonStackView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-18)
            make.centerY.equalToSuperview()
        }

        [recordImageView, screenShareImageView, microphoneImageView, cameraImageView].forEach { imageView in
            imageView.snp.makeConstraints { make in
                make.width.height.equalTo(20)
            }
        }

        dividerLine.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.left.equalTo(nameLabel.snp.left)
            make.right.equalTo(buttonStackView.snp.right)
            make.height.equalTo(1)
        }
    }

    // MARK: - Public Methods
    func configure(with participant: RoomParticipant, roomID: String, roomType: RoomType) {
        configureBasicInfo(participant: participant, roomID: roomID)

        if roomType == .standard {
            screenShareImageView.isHidden = participant.screenShareStatus == .off
            cameraImageView.image = ResourceLoader.loadImage(participant.cameraStatus == .on ? "room_member_camera_on" : "room_member_camera_off")
            microphoneImageView.image = ResourceLoader.loadImage(participant.microphoneStatus == .on ? "room_member_unmute" : "room_member_mute")
        } else {
            screenShareImageView.isHidden = true
            cameraImageView.isHidden = true
            microphoneImageView.image = ResourceLoader.loadImage(participant.microphoneStatus == .on ? "room_member_unmute" : "room_member_mute")
        }
    }
}

// MARK: - AudienceListCell
class AudienceListCell: BaseParticipantCell {
    // MARK: - Setup Methods
    override func setupConstraints() {
        super.setupConstraints()

        containerView.snp.makeConstraints { make in
            make.left.equalTo(avatarImageView.snp.right).offset(RoomSpacing.medium)
            make.centerY.equalTo(avatarImageView.snp.centerY)
            make.right.equalToSuperview().offset(-RoomSpacing.large)
        }

        dividerLine.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.left.equalTo(nameLabel.snp.left)
            make.right.equalTo(containerView.snp.right)
            make.height.equalTo(1)
        }
    }

    // MARK: - Public Methods
    func configure(with audience: RoomParticipant, roomID: String) {
        configureBasicInfo(participant: audience, roomID: roomID)
    }
}

// MARK: - PendingListCell
class PendingListCell: BaseParticipantCell {
    // MARK: - Additional UI Components
    private lazy var trailingStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.alignment = .center
        return stackView
    }()

    private lazy var rejectedTipLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        label.textColor = RoomColors.segmentTitleColor
        label.text = .notJoinForNow
        label.alpha = 0
        return label
    }()

    private lazy var callButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 12, weight: .regular)
        button.backgroundColor = RoomColors.b1
        button.layer.cornerRadius = 4
        button.setTitle(.call, for: .normal)
        button.addTarget(self, action: #selector(callButtonTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - State
    var inCalling: Bool = false {
        didSet {
            if inCalling {
                callButton.setTitle(.calling, for: .normal)
                callButton.backgroundColor = .clear
                callButton.setTitleColor(RoomColors.segmentTitleColor, for: .normal)
                callButton.isEnabled = false
            } else {
                callButton.setTitle(.call, for: .normal)
                callButton.backgroundColor = RoomColors.b1
                callButton.setTitleColor(.white, for: .normal)
                callButton.isEnabled = true
            }
        }
    }

    var onCallTapped: ((RoomParticipant) -> Void)?
    private var participant: RoomParticipant?

    // MARK: - Setup Methods
    override func setupViews() {
        super.setupViews()
        contentView.addSubview(trailingStackView)
        trailingStackView.addArrangedSubview(rejectedTipLabel)
        trailingStackView.addArrangedSubview(callButton)
    }

    override func setupConstraints() {
        super.setupConstraints()

        containerView.snp.makeConstraints { make in
            make.left.equalTo(avatarImageView.snp.right).offset(RoomSpacing.medium)
            make.centerY.equalTo(avatarImageView.snp.centerY)
            make.right.lessThanOrEqualTo(trailingStackView.snp.left).offset(-8)
        }

        trailingStackView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-RoomSpacing.large)
            make.centerY.equalToSuperview()
        }

        callButton.snp.makeConstraints { make in
            make.width.equalTo(68)
            make.height.equalTo(28)
        }

        dividerLine.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.left.equalTo(nameLabel.snp.left)
            make.right.equalTo(trailingStackView.snp.right)
            make.height.equalTo(1)
        }
    }

    // MARK: - Public Methods
    func configure(with participant: RoomParticipant, roomID: String, showRejectedTip: Bool = false) {
        configureBasicInfo(participant: participant, roomID: roomID)
        self.participant = participant
        self.inCalling = participant.roomStatus == .inCalling
        rejectedTipLabel.alpha = showRejectedTip ? 1 : 0
    }

    // MARK: - Actions
    @objc private func callButtonTapped() {
        guard let participant = participant else { return }
        inCalling = true
        onCallTapped?(participant)
    }
}

// MARK: - Localized
fileprivate extension String {
    static let me = "roomkit_me".localized
    static let owner = "roomkit_role_owner".localized
    static let administrator = "roomkit_role_admin".localized
    static let calling = "roomkit_calling".localized
    static let call = "roomkit_call".localized
    static let notJoinForNow = "roomkit_not_join_for_now".localized
}
