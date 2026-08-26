import UIKit
import SnapKit
import Kingfisher

final class AZOrderedListCell: UITableViewCell {
    static let reuseIdentifier = "AZOrderedListCell"

    var titleFontSize: CGFloat = 14 {
        didSet { titleLabel.font = .systemFont(ofSize: titleFontSize) }
    }

    private static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let avatarSize: CGFloat = 40

    private static let avatarCornerRadius: CGFloat = CGFloat(RadiusScheme.tipsRadius)

    private static let avatarTextSpacing: CGFloat = 12

    private static let dividerHeight: CGFloat = 0.5

    private static let dividerLeadingInset: CGFloat = 68

    private let avatarContainer = UIView()

    private let avatarImageView = UIImageView()

    private let avatarTextLabel = UILabel()

    private let titleLabel = UILabel()

    private let dividerView = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: AZOrderedListItem, showsDivider: Bool = false) {
        let displayName = item.title ?? item.userID
        titleLabel.text = displayName
        titleLabel.font = .systemFont(ofSize: titleFontSize)
        dividerView.isHidden = !showsDivider
        let urlString = item.avatarURL ?? ""
        if urlString.isEmpty {
            showTextAvatar(name: displayName)
        } else {
            loadImageAvatar(urlString: urlString, fallbackName: displayName)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.kf.cancelDownloadTask()
        avatarImageView.image = nil
        titleLabel.text = nil
        dividerView.isHidden = true
    }

    private func constructViewHierarchy() {
        selectionStyle = .none
        contentView.addSubview(avatarContainer)
        avatarContainer.addSubview(avatarImageView)
        avatarContainer.addSubview(avatarTextLabel)
        contentView.addSubview(titleLabel)
        contentView.addSubview(dividerView)
    }

    private func activateConstraints() {
        avatarContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.avatarSize)
        }
        avatarImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        avatarTextLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarContainer.snp.trailing).offset(Self.avatarTextSpacing)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.horizontalPadding)
            make.centerY.equalToSuperview()
        }
        dividerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.dividerLeadingInset)
            make.trailing.bottom.equalToSuperview()
            make.height.equalTo(Self.dividerHeight)
        }
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        backgroundColor = colors.bgColorOperate
        contentView.backgroundColor = colors.bgColorOperate

        avatarContainer.backgroundColor = colors.bgColorAvatar
        avatarContainer.layer.cornerRadius = Self.avatarCornerRadius
        avatarContainer.layer.masksToBounds = true

        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.isHidden = true

        avatarTextLabel.font = FontScheme.caption1Medium
        avatarTextLabel.textColor = colors.textColorPrimary
        avatarTextLabel.textAlignment = .center

        titleLabel.font = .systemFont(ofSize: titleFontSize)
        titleLabel.textColor = colors.textColorPrimary
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        dividerView.backgroundColor = colors.strokeColorSecondary
        dividerView.isHidden = true
    }

    private func showTextAvatar(name: String) {
        avatarImageView.isHidden = true
        avatarImageView.image = nil
        avatarTextLabel.isHidden = false
        avatarTextLabel.text = name.first.map { String($0).uppercased() } ?? ""
    }

    private func loadImageAvatar(urlString: String, fallbackName: String) {
        avatarTextLabel.isHidden = true
        avatarImageView.isHidden = false
        avatarImageView.kf.setImage(with: URL(string: urlString)) { [weak self] result in
            guard let self else { return }
            if case .failure = result {
                self.showTextAvatar(name: fallbackName)
            }
        }
    }
}
