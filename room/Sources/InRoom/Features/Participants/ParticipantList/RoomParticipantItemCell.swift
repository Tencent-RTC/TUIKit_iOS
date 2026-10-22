import UIKit
import SnapKit
import AtomicXCore

final class RoomParticipantItemCell: UITableViewCell {

    static let reuseIdentifier = "RoomParticipantItemCell"

    private let avatar = RoomAvatar()
    private let nameText = UILabel()
    private let tagStack = UIStackView()
    private let selfTag = RoomTagLabel()
    private let ownerTag = RoomTagLabel()
    private let adminTag = RoomTagLabel()
    private let sharingTag = UIView()
    private let sharingIcon = UIImageView()
    private let sharingLabel = UILabel()
    private let micStatus = UIImageView()
    private let camStatus = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        setupConstraints()
        setupStyles()
        selectionStyle = .none
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    private func setupViews() {
        contentView.addSubview(avatar)
        contentView.addSubview(nameText)
        contentView.addSubview(tagStack)
        contentView.addSubview(micStatus)
        contentView.addSubview(camStatus)
        sharingTag.addSubview(sharingIcon)
        sharingTag.addSubview(sharingLabel)
        [selfTag, ownerTag, adminTag, sharingTag].forEach { tagStack.addArrangedSubview($0) }
    }

    private func setupConstraints() {
        avatar.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(32)
        }
        nameText.snp.makeConstraints {
            $0.leading.equalTo(avatar.snp.trailing).offset(12)
            $0.centerY.equalToSuperview()
            $0.width.lessThanOrEqualTo(160)
        }
        tagStack.snp.makeConstraints {
            $0.leading.equalTo(nameText.snp.trailing).offset(6)
            $0.centerY.equalToSuperview()
            $0.trailing.lessThanOrEqualTo(micStatus.snp.leading).offset(-16)
        }
        [selfTag, ownerTag, adminTag].forEach {
            $0.snp.makeConstraints { $0.height.equalTo(18) }
        }
        sharingTag.snp.makeConstraints { $0.height.equalTo(18) }
        sharingIcon.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(6)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(10)
        }
        sharingLabel.snp.makeConstraints {
            $0.leading.equalTo(sharingIcon.snp.trailing).offset(3)
            $0.trailing.equalToSuperview().offset(-6)
            $0.centerY.equalToSuperview()
        }
        camStatus.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-22)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(14)
        }
        micStatus.snp.makeConstraints {
            $0.trailing.equalTo(camStatus.snp.leading).offset(-18)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(14)
        }
    }

    private func setupStyles() {
        nameText.font = .systemFont(ofSize: 13)
        nameText.textColor = UIColor.roomKitFgPrimary
        nameText.lineBreakMode = .byTruncatingTail
        nameText.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tagStack.spacing = 6
        tagStack.setContentCompressionResistancePriority(.required, for: .horizontal)
        [selfTag, ownerTag, adminTag].forEach { tag in
            tag.font = .systemFont(ofSize: 10, weight: .semibold)
            tag.textAlignment = .center
            tag.layer.cornerRadius = 9
            tag.layer.masksToBounds = true
            tag.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        selfTag.textColor = UIColor.roomKitRoleSelfFg
        selfTag.backgroundColor = UIColor.roomKitRoleSelfBg
        ownerTag.textColor = UIColor.roomKitRoleOwnerFg
        ownerTag.backgroundColor = UIColor.roomKitRoleOwnerBg
        adminTag.textColor = UIColor.roomKitRoleAdminFg
        adminTag.backgroundColor = UIColor.roomKitRoleAdminBg
        selfTag.text = .participantsMe
        ownerTag.text = .participantsOwner
        adminTag.text = .participantsAdmin
        sharingTag.backgroundColor = UIColor.roomKitRoleOwnerBg
        sharingTag.layer.cornerRadius = 9
        sharingTag.layer.masksToBounds = true
        sharingTag.setContentCompressionResistancePriority(.required, for: .horizontal)
        sharingIcon.contentMode = .scaleAspectFit
        sharingIcon.image = RoomKitResources.image(named: "roomkit_icon_screen_share_tag")
        sharingLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        sharingLabel.textColor = UIColor.roomKitRoleOwnerFg
        sharingLabel.text = .participantsSharing
        micStatus.contentMode = .scaleAspectFit
        camStatus.contentMode = .scaleAspectFit
    }


    func bind(participant: RoomParticipant, isSelf: Bool, isSharing: Bool) {
        let displayName = participant.displayName
        avatar.url = participant.avatarURL
        avatar.text = displayName
        nameText.text = displayName
        selfTag.isHidden = !isSelf
        ownerTag.isHidden = participant.role != .owner
        adminTag.isHidden = participant.role != .admin
        sharingTag.isHidden = !isSharing
        let microphoneOn = participant.microphoneStatus == .on
        let cameraOn = participant.cameraStatus == .on
        micStatus.image = RoomKitResources.image(named: microphoneOn ? "roomkit_icon_microphone" : "roomkit_icon_microphone_off")
        camStatus.image = RoomKitResources.image(named: cameraOn ? "roomkit_icon_camera" : "roomkit_icon_camera_off")
    }
}

private final class RoomTagLabel: UILabel {

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.insetBy(dx: 6, dy: 0))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 12, height: size.height)
    }
}

private extension String {
    static var participantsMe: String { RoomKitResources.localizedString("roomkit.participants.me") }
    static var participantsOwner: String { RoomKitResources.localizedString("roomkit.participants.owner") }
    static var participantsAdmin: String { RoomKitResources.localizedString("roomkit.participants.admin") }
    static var participantsSharing: String { RoomKitResources.localizedString("roomkit.participants.sharing") }
}
