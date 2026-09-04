import UIKit
import SnapKit
import AtomicXCore

final class FriendApplicationCell: UITableViewCell {
    static let reuseIdentifier = "FriendApplicationCell"

    private static let rowVerticalPadding: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let avatarTextSpacing: CGFloat = 13

    private static let buttonWidth: CGFloat = 70

    private static let buttonHeight: CGFloat = 32

    private static let buttonCornerRadius: CGFloat = 10

    private static let buttonSpacing: CGFloat = 10

    private static let refuseBorderWidth: CGFloat = 1

    private var onAccept: (() -> Void)?

    private var onRefuse: (() -> Void)?

    private let avatarView = ChatAvatarView(size: .m, isRound: false)

    private let textColumn = UIStackView()

    private let nameLabel = UILabel()

    private let wordingLabel = UILabel()

    private let acceptButton = UIButton(type: .custom)

    private let refuseButton = UIButton(type: .custom)

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

    func configure(with application: FriendApplicationInfo,
                   onAccept: @escaping () -> Void,
                   onRefuse: @escaping () -> Void) {
        self.onAccept = onAccept
        self.onRefuse = onRefuse
        let displayName = ContactDisplayNameFormatter.name(for: application)
        nameLabel.text = displayName
        wordingLabel.text = application.addWording ?? ""
        avatarView.configure(avatarURL: application.avatarURL, fallbackName: displayName)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        wordingLabel.text = nil
        onAccept = nil
        onRefuse = nil
    }

    private func constructViewHierarchy() {
        selectionStyle = .none
        textColumn.axis = .vertical
        textColumn.spacing = 0
        textColumn.addArrangedSubview(nameLabel)
        textColumn.addArrangedSubview(wordingLabel)
        contentView.addSubview(avatarView)
        contentView.addSubview(textColumn)
        contentView.addSubview(acceptButton)
        contentView.addSubview(refuseButton)
    }

    private func activateConstraints() {
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.top.equalToSuperview().offset(Self.rowVerticalPadding)
            make.bottom.equalToSuperview().offset(-Self.rowVerticalPadding)
            make.width.height.equalTo(ChatAvatarSize.m.size)
        }
        textColumn.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(Self.avatarTextSpacing)
            make.centerY.equalTo(avatarView)
            make.trailing.lessThanOrEqualTo(acceptButton.snp.leading).offset(-Self.buttonSpacing)
        }
        acceptButton.snp.makeConstraints { make in
            make.trailing.equalTo(refuseButton.snp.leading).offset(-Self.buttonSpacing)
            make.centerY.equalTo(avatarView)
            make.width.equalTo(Self.buttonWidth)
            make.height.equalTo(Self.buttonHeight)
        }
        refuseButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.centerY.equalTo(avatarView)
            make.width.equalTo(Self.buttonWidth)
            make.height.equalTo(Self.buttonHeight)
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
        nameLabel.font = FontScheme.caption2Regular
        nameLabel.textColor = colors.textColorPrimary
        wordingLabel.font = FontScheme.caption3Regular
        wordingLabel.textColor = colors.textColorSecondary
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
        button.titleLabel?.font = FontScheme.caption2Regular
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = Self.buttonCornerRadius
        button.layer.masksToBounds = true
        if let borderColor = borderColor {
            button.layer.borderWidth = Self.refuseBorderWidth
            button.layer.borderColor = borderColor.cgColor
        }
    }

    @objc private func handleAccept() {
        onAccept?()
    }

    @objc private func handleRefuse() {
        onRefuse?()
    }
}
