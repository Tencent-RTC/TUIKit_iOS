import UIKit
import SnapKit

final class MentionMemberCell: UITableViewCell {
    static let reuseIdentifier = "MentionMemberCell"

    private static let checkboxSize: CGFloat = 16

    private static let checkboxAvatarSpacing: CGFloat = 10

    private static let avatarTextSpacing: CGFloat = 13

    private static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let endReserved: CGFloat = 26

    private let checkboxView = SelectionCheckBox()

    private let avatarView = ChatAvatarView(size: .m, isRound: false)

    private let nameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(name: String, avatarURL: String?, isSelected: Bool) {
        nameLabel.text = name
        avatarView.configure(avatarURL: avatarURL, fallbackName: name)
        checkboxView.isChecked = isSelected
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        checkboxView.isChecked = false
    }

    private func constructViewHierarchy() {
        selectionStyle = .none
        contentView.addSubview(checkboxView)
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
    }

    private func activateConstraints() {
        checkboxView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.checkboxSize)
        }
        avatarView.snp.makeConstraints { make in
            make.leading.equalTo(checkboxView.snp.trailing).offset(Self.checkboxAvatarSpacing)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(ChatAvatarSize.m.size)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(Self.avatarTextSpacing)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.endReserved)
        }
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        backgroundColor = colors.bgColorOperate
        contentView.backgroundColor = colors.bgColorOperate
        nameLabel.font = FontScheme.caption2Regular
        nameLabel.textColor = colors.textColorPrimary
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
    }
}
