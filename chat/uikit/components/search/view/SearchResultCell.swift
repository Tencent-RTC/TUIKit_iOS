import UIKit
import SnapKit

final class SearchResultCell: UITableViewCell {
    static let reuseIdentifier = "SearchResultCell"

    private static let avatarSize: CGFloat = 36

    private static let avatarCornerRadius: CGFloat = CGFloat(RadiusScheme.tipsRadius)

    private static let avatarPlaceholderFontSize: CGFloat = 16

    private static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.contentSpacing)

    private static let verticalPadding: CGFloat = 12.5

    private static let avatarTextGap: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let titleSubtitleGap: CGFloat = 2

    private static let dividerHeight: CGFloat = 0.5

    private static let dividerBottomInset: CGFloat = 3

    private let avatarView = ChatAvatarView(cornerRadius: SearchResultCell.avatarCornerRadius, fontSize: SearchResultCell.avatarPlaceholderFontSize)

    private let titleLabel = UILabel()

    private let subtitleLabel = UILabel()

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

    // MARK: - Configure

    func configure(avatarURL: String?,
                   avatarName: String,
                   title: NSAttributedString,
                   subtitle: NSAttributedString?,
                   showDivider: Bool) {
        configureAvatar(url: avatarURL, name: avatarName)
        titleLabel.attributedText = title
        if let subtitle = subtitle {
            subtitleLabel.attributedText = subtitle
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.attributedText = nil
            subtitleLabel.isHidden = true
        }
        dividerView.isHidden = !showDivider
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.attributedText = nil
        subtitleLabel.attributedText = nil
        subtitleLabel.isHidden = false
        dividerView.isHidden = true
        avatarView.reset()
    }

    private func constructViewHierarchy() {
        selectionStyle = .default
        contentView.addSubview(avatarView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(dividerView)
    }

    private func activateConstraints() {
        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.top.equalToSuperview().offset(Self.verticalPadding)
            make.bottom.equalToSuperview().offset(-Self.verticalPadding)
            make.width.height.equalTo(Self.avatarSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(Self.avatarTextGap)
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.top.equalTo(avatarView)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.top.equalTo(titleLabel.snp.bottom).offset(Self.titleSubtitleGap)
        }
        dividerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.trailing.equalToSuperview().offset(-Self.horizontalPadding)
            make.bottom.equalToSuperview().offset(-Self.dividerBottomInset)
            make.height.equalTo(Self.dividerHeight)
        }
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        contentView.backgroundColor = colors.bgColorOperate
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.numberOfLines = 1
        subtitleLabel.lineBreakMode = .byTruncatingTail
        dividerView.backgroundColor = colors.strokeColorPrimary
    }

    private func configureAvatar(url: String?, name: String) {
        avatarView.configure(avatarURL: url, fallbackName: name)
    }
}
