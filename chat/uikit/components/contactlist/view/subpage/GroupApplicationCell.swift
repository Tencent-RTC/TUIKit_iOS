import UIKit
import SnapKit
import AtomicXCore

final class GroupApplicationCell: UITableViewCell {
    static let reuseIdentifier = "GroupApplicationCell"

    private static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let verticalPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let avatarSpacing: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let personFontSize: CGFloat = 13

    private static let requestMsgMaxLines = 2

    private static let buttonWidth: CGFloat = 60

    private static let buttonHeight: CGFloat = 32

    private static let buttonCornerRadius: CGFloat = CGFloat(RadiusScheme.smallRadius)

    private static let buttonSpacing: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let refuseBorderWidth: CGFloat = 1

    private var onAccept: (() -> Void)?

    private var onRefuse: (() -> Void)?

    private let avatarView = ChatAvatarView(size: .m, isRound: false)

    private let textStackView = UIStackView()

    private let typeLabel = UILabel()

    private let personLabel = UILabel()

    private let groupNameLabel = UILabel()

    private let requestMsgLabel = UILabel()

    private let statusLabel = UILabel()

    private let acceptButton = UIButton(type: .custom)

    private let refuseButton = UIButton(type: .custom)

    private let actionStackView = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with application: GroupApplicationInfo,
                   onAccept: @escaping () -> Void,
                   onRefuse: @escaping () -> Void) {
        self.onAccept = onAccept
        self.onRefuse = onRefuse
        typeLabel.text = Self.applicationTypeText(application)
        personLabel.text = Self.personText(application)
        groupNameLabel.text = "\(LocalizedChatString("GroupID"))  \u{FF1A}\(application.groupID)"
        if let requestMsg = application.requestMsg, !requestMsg.isEmpty {
            requestMsgLabel.text = requestMsg
            requestMsgLabel.isHidden = false
        } else {
            requestMsgLabel.text = nil
            requestMsgLabel.isHidden = true
        }
        let displayName = Self.fromUserDisplayName(application)
        avatarView.configure(avatarURL: application.fromUserAvatarURL, fallbackName: displayName)
        applyHandledState(application)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        typeLabel.text = nil
        personLabel.text = nil
        groupNameLabel.text = nil
        requestMsgLabel.text = nil
        statusLabel.text = nil
        onAccept = nil
        onRefuse = nil
    }

    private func constructViewHierarchy() {
        selectionStyle = .none
        textStackView.axis = .vertical
        textStackView.spacing = 0
        textStackView.addArrangedSubview(typeLabel)
        textStackView.addArrangedSubview(personLabel)
        textStackView.addArrangedSubview(groupNameLabel)
        textStackView.addArrangedSubview(requestMsgLabel)

        actionStackView.axis = .horizontal
        actionStackView.spacing = Self.buttonSpacing
        actionStackView.addArrangedSubview(acceptButton)
        actionStackView.addArrangedSubview(refuseButton)

        contentView.addSubview(avatarView)
        contentView.addSubview(textStackView)
        contentView.addSubview(actionStackView)
        contentView.addSubview(statusLabel)
    }

    private func activateConstraints() {
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.top.equalToSuperview().offset(Self.verticalPadding)
            make.bottom.lessThanOrEqualToSuperview().offset(-Self.verticalPadding)
            make.width.height.equalTo(ChatAvatarSize.m.size)
        }
        textStackView.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(Self.avatarSpacing)
            make.top.equalToSuperview().offset(Self.verticalPadding)
            make.bottom.equalToSuperview().offset(-Self.verticalPadding)
            make.trailing.lessThanOrEqualTo(actionStackView.snp.leading).offset(-Self.buttonSpacing)
        }
        actionStackView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.centerY.equalToSuperview()
        }
        acceptButton.snp.makeConstraints { make in
            make.width.equalTo(Self.buttonWidth)
            make.height.equalTo(Self.buttonHeight)
        }
        refuseButton.snp.makeConstraints { make in
            make.width.equalTo(Self.buttonWidth)
            make.height.equalTo(Self.buttonHeight)
        }
        statusLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.centerY.equalToSuperview()
        }
    }

    private func bindInteraction() {
        acceptButton.addTarget(self, action: #selector(handleAccept), for: .touchUpInside)
        refuseButton.addTarget(self, action: #selector(handleRefuse), for: .touchUpInside)
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        backgroundColor = colors.bgColorOperate
        contentView.backgroundColor = colors.bgColorOperate
        typeLabel.font = FontScheme.caption2Regular
        typeLabel.textColor = colors.textColorPrimary
        personLabel.font = .systemFont(ofSize: Self.personFontSize)
        personLabel.textColor = colors.textColorSecondary
        groupNameLabel.font = .systemFont(ofSize: Self.personFontSize)
        groupNameLabel.textColor = colors.textColorSecondary
        requestMsgLabel.font = FontScheme.caption3Regular
        requestMsgLabel.textColor = colors.textColorSecondary
        requestMsgLabel.numberOfLines = Self.requestMsgMaxLines
        statusLabel.font = FontScheme.caption3Regular
        statusLabel.textColor = colors.textColorSecondary
        styleActionButton(
            acceptButton,
            title: LocalizedChatString("Agree"),
            titleColor: colors.textColorButton,
            backgroundColor: colors.buttonColorPrimaryDefault,
            borderColor: nil
        )
        styleActionButton(
            refuseButton,
            title: LocalizedChatString("Decline"),
            titleColor: colors.textColorError,
            backgroundColor: .clear,
            borderColor: colors.strokeColorPrimary
        )
    }

    private func styleActionButton(_ button: UIButton,
                                   title: String,
                                   titleColor: UIColor,
                                   backgroundColor: UIColor,
                                   borderColor: UIColor?) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(titleColor, for: .normal)
        button.titleLabel?.font = FontScheme.caption3Regular
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = Self.buttonCornerRadius
        button.layer.masksToBounds = true
        if let borderColor = borderColor {
            button.layer.borderWidth = Self.refuseBorderWidth
            button.layer.borderColor = borderColor.cgColor
        }
    }

    private static func applicationTypeText(_ application: GroupApplicationInfo) -> String {
        switch application.type {
        case .joinApprovedByAdmin:
            return LocalizedChatString("GroupApplicationTypeApply")
        case .inviteApprovedByInvitee, .inviteApprovedByAdmin:
            return LocalizedChatString("GroupApplicationTypeInvite")
        }
    }

    private static func personText(_ application: GroupApplicationInfo) -> String {
        if application.type == .joinApprovedByAdmin {
            return "\(LocalizedChatString("GroupApplicationApplicant"))\u{FF1A}\(fromUserDisplayName(application))"
        }
        return "\(LocalizedChatString("GroupApplicationInvitee"))\u{FF1A}\(application.toUser ?? "")"
    }

    private static func fromUserDisplayName(_ application: GroupApplicationInfo) -> String {
        if let nickname = application.fromUserNickname, !nickname.isEmpty {
            return nickname
        }
        return application.fromUser ?? ""
    }

    private func applyHandledState(_ application: GroupApplicationInfo) {
        let canHandle = application.handledStatus == .unhandled || application.handledStatus == nil
        actionStackView.isHidden = !canHandle
        statusLabel.isHidden = canHandle
        if !canHandle {
            statusLabel.text = Self.handledStatusText(application)
        }
    }

    private static func handledStatusText(_ application: GroupApplicationInfo) -> String {
        switch application.handledStatus {
        case .unhandled:
            return LocalizedChatString("GroupApplicationStatusPending")
        case .byOther:
            return LocalizedChatString("GroupApplicationStatusByOther")
        case .byMyself:
            switch application.handledResult {
            case .refused:
                return LocalizedChatString("Disclined")
            case .agreed:
                return LocalizedChatString("Agreed")
            default:
                return LocalizedChatString("UserStatusUnknown")
            }
        default:
            return LocalizedChatString("UserStatusUnknown")
        }
    }

    @objc private func handleAccept() {
        onAccept?()
    }

    @objc private func handleRefuse() {
        onRefuse?()
    }
}
