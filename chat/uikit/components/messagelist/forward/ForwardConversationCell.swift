import UIKit
import SnapKit
import Kingfisher
import AtomicXCore

final class ForwardConversationCell: UITableViewCell {
    static let reuseIdentifier = "ForwardConversationCell"

    private static let contentHorizontalInset = CGFloat(SpacingScheme.bubbleSpacing)

    private static let checkboxSize: CGFloat = 22

    private static let avatarCornerRadius = CGFloat(RadiusScheme.superLargeRadius)

    private static let horizontalSpacing = CGFloat(SpacingScheme.iconIconSpacing)

    private static let avatarSize: CGFloat = 40

    private static let checkboxIconPointSize: CGFloat = 20

    private let checkboxView = UIImageView()

    private let avatarView = UIImageView()

    private let titleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(conversation: ConversationInfo, isSelected: Bool) {
        let colors = TUIChatKitTheme.colors
        contentView.backgroundColor = colors.bgColorOperate
        titleLabel.textColor = colors.textColorPrimary

        let title = conversation.title?.isEmpty == false ? conversation.title! : conversation.conversationID
        titleLabel.text = title

        configureAvatar(url: conversation.avatarURL, fallbackName: title)
        updateCheckbox(isSelected: isSelected)
    }

    private func setupUI() {
        let colors = TUIChatKitTheme.colors
        contentView.backgroundColor = colors.bgColorOperate

        contentView.addSubview(checkboxView)
        contentView.addSubview(avatarView)
        contentView.addSubview(titleLabel)

        checkboxView.contentMode = .scaleAspectFit
        checkboxView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.contentHorizontalInset)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.checkboxSize)
        }

        avatarView.layer.cornerRadius = Self.avatarCornerRadius
        avatarView.clipsToBounds = true
        avatarView.contentMode = .scaleAspectFill
        avatarView.snp.makeConstraints { make in
            make.leading.equalTo(checkboxView.snp.trailing).offset(Self.horizontalSpacing)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.avatarSize)
        }

        titleLabel.font = FontScheme.caption1Regular
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(Self.horizontalSpacing)
            make.trailing.equalToSuperview().offset(-Self.contentHorizontalInset)
            make.centerY.equalToSuperview()
        }
    }

    private func configureAvatar(url: String?, fallbackName: String) {
        if let urlString = url, !urlString.isEmpty, let imageURL = URL(string: urlString) {
            avatarView.kf.setImage(with: imageURL, placeholder: generateAvatarPlaceholder(name: fallbackName))
        } else {
            avatarView.image = generateAvatarPlaceholder(name: fallbackName)
        }
    }

    private func updateCheckbox(isSelected: Bool) {
        let colors = TUIChatKitTheme.colors
        if isSelected {
            let config = UIImage.SymbolConfiguration(pointSize: Self.checkboxIconPointSize, weight: .regular)
            let image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
            checkboxView.image = image
            checkboxView.tintColor = colors.textColorLink
        } else {
            let config = UIImage.SymbolConfiguration(pointSize: Self.checkboxIconPointSize, weight: .regular)
            let image = UIImage(systemName: "circle", withConfiguration: config)
            checkboxView.image = image
            checkboxView.tintColor = colors.textColorTertiary
        }
    }

    private func generateAvatarPlaceholder(name: String) -> UIImage? {
        let size = CGSize(width: Self.avatarSize, height: Self.avatarSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let colors = TUIChatKitTheme.colors
            colors.buttonColorPrimaryDefault.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let initial = String(name.prefix(1)).uppercased()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: FontScheme.caption1Medium,
                .foregroundColor: UIColor.white
            ]
            let textSize = initial.size(withAttributes: attributes)
            let textPoint = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            initial.draw(at: textPoint, withAttributes: attributes)
        }
    }
}
