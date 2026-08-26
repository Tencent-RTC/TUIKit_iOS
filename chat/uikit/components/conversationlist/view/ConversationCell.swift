import UIKit
import SnapKit
import Kingfisher
import AtomicXCore

final class ConversationCell: UITableViewCell {
    static let reuseIdentifier = "ConversationCell"

    private static let avatarSize: CGFloat = 48

    private static let avatarCornerRadius: CGFloat = CGFloat(RadiusScheme.tipsRadius)

    private static let avatarLeadingPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let avatarTextSpacing: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let minTitleSubtitleSpacing: CGFloat = 2

    private static let textVerticalOffset: CGFloat = 1

    private static let badgeMaxCount = 99

    private static let trailingPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let statusIconSize: CGFloat = 14

    private static let sendingIndicatorSlotSize: CGFloat = 12

    private static let sendingIndicatorScale: CGFloat = 0.6

    private static let muteIconSize: CGFloat = 16

    private static let muteIconTopSpacing: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)

    private static let separatorHeight: CGFloat = 0.5

    private static let titleFontSize: CGFloat = 18

    private static let menuHighlightAlpha: CGFloat = 0.08

    private static let statusSubtitleSpacing: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)

    private let avatarContainer = UIView()

    private let avatarImageView = UIImageView()

    private let avatarTextLabel = UILabel()

    private let avatarBadgeView = ConversationAvatarBadgeView()

    private let titleLabel = UILabel()

    private let subtitleLabel = UILabel()

    private let rightColumnContainer = UIView()

    private let timeLabel = UILabel()

    private let muteImageView = UIImageView()

    private let statusImageView = UIImageView()

    private let sendingIndicator = UIActivityIndicatorView(style: .medium)

    private let separatorView = UIView()

    private let menuHighlightOverlay = UIView()

    private var subtitleLeadingConstraint: Constraint?

    private var muteHeightConstraint: Constraint?

    // MARK: - Init

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

    func setMenuHighlighted(_ highlighted: Bool) {
        menuHighlightOverlay.isHidden = !highlighted
    }

    func setSeparatorHidden(_ hidden: Bool) {
        separatorView.isHidden = hidden
    }

    func configure(with conversation: ConversationInfo) {
        titleLabel.text = conversation.title ?? ""
        subtitleLabel.attributedText = ConversationCellFormatter.subtitleAttributedText(for: conversation)
        timeLabel.text = ConversationCellFormatter.timeText(for: conversation)

        configureAvatar(with: conversation)
        configureStatus(with: conversation)
        configureUnreadIndicators(with: conversation)
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        subtitleLabel.attributedText = nil
        timeLabel.text = nil
        muteImageView.isHidden = true
        statusImageView.isHidden = true
        separatorView.isHidden = false
        sendingIndicator.stopAnimating()
        avatarImageView.kf.cancelDownloadTask()
        avatarImageView.image = nil
        avatarBadgeView.setMode(.none)
    }

    private func constructViewHierarchy() {
        selectionStyle = .none
        contentView.clipsToBounds = false
        clipsToBounds = false
        contentView.addSubview(avatarContainer)
        avatarContainer.addSubview(avatarImageView)
        avatarContainer.addSubview(avatarTextLabel)
        contentView.addSubview(avatarBadgeView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(rightColumnContainer)
        rightColumnContainer.addSubview(timeLabel)
        rightColumnContainer.addSubview(muteImageView)
        contentView.addSubview(statusImageView)
        contentView.addSubview(sendingIndicator)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(separatorView)
        menuHighlightOverlay.isUserInteractionEnabled = false
        contentView.addSubview(menuHighlightOverlay)
    }

    private func activateConstraints() {
        avatarContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.avatarLeadingPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.avatarSize)
        }
        avatarImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        avatarTextLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        avatarBadgeView.snp.makeConstraints { make in
            make.centerX.equalTo(avatarContainer.snp.trailing)
            make.centerY.equalTo(avatarContainer.snp.top)
        }
        rightColumnContainer.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Self.trailingPadding)
            make.centerY.equalToSuperview()
        }
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        timeLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        muteImageView.snp.makeConstraints { make in
            make.top.equalTo(timeLabel.snp.bottom).offset(Self.muteIconTopSpacing)
            make.trailing.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
            make.width.equalTo(Self.muteIconSize)
            muteHeightConstraint = make.height.equalTo(0).constraint
            make.bottom.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarContainer.snp.trailing).offset(Self.avatarTextSpacing)
            make.top.equalTo(avatarContainer).offset(Self.textVerticalOffset)
            make.trailing.lessThanOrEqualTo(rightColumnContainer.snp.leading).offset(-Self.trailingPadding)
        }
        statusImageView.snp.makeConstraints { make in
            make.leading.equalTo(avatarContainer.snp.trailing).offset(Self.avatarTextSpacing)
            make.centerY.equalTo(subtitleLabel)
            make.width.height.equalTo(Self.statusIconSize)
        }
        sendingIndicator.snp.makeConstraints { make in
            make.center.equalTo(statusImageView)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(titleLabel.snp.bottom).offset(Self.minTitleSubtitleSpacing)
            make.bottom.equalTo(avatarContainer).offset(-Self.textVerticalOffset)
            subtitleLeadingConstraint = make.leading.equalTo(statusImageView.snp.trailing).offset(0).constraint
            make.trailing.lessThanOrEqualTo(rightColumnContainer.snp.leading).offset(-Self.trailingPadding)
        }
        separatorView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.bottom.equalToSuperview()
            make.height.equalTo(Self.separatorHeight)
        }
        menuHighlightOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors

        avatarContainer.backgroundColor = colors.bgColorAvatar
        avatarContainer.layer.cornerRadius = Self.avatarCornerRadius
        avatarContainer.layer.masksToBounds = true

        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.isHidden = true

        avatarTextLabel.font = FontScheme.caption1Medium
        avatarTextLabel.textColor = colors.textColorPrimary
        avatarTextLabel.textAlignment = .center

        titleLabel.font = .systemFont(ofSize: Self.titleFontSize, weight: .regular)
        titleLabel.textColor = colors.textColorPrimary
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.font = FontScheme.caption2Regular
        subtitleLabel.textColor = colors.textColorSecondary
        subtitleLabel.numberOfLines = 1
        subtitleLabel.lineBreakMode = .byTruncatingTail

        timeLabel.font = FontScheme.caption3Regular
        timeLabel.textColor = colors.textColorSecondary
        timeLabel.textAlignment = LanguageHelper.isRTL ? .left : .right
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        muteImageView.image = UIImage(systemName: "bell.slash.fill")
        muteImageView.tintColor = colors.textColorSecondary
        muteImageView.contentMode = .scaleAspectFit

        statusImageView.image = UIImage(systemName: "exclamationmark.circle.fill")
        statusImageView.tintColor = colors.textColorError
        statusImageView.contentMode = .scaleAspectFit

        sendingIndicator.color = colors.textColorAntiSecondary
        sendingIndicator.hidesWhenStopped = true
        sendingIndicator.transform = CGAffineTransform(scaleX: Self.sendingIndicatorScale, y: Self.sendingIndicatorScale)

        separatorView.backgroundColor = colors.strokeColorSecondary

        menuHighlightOverlay.backgroundColor = UIColor.black.withAlphaComponent(Self.menuHighlightAlpha)
        menuHighlightOverlay.isHidden = true
    }

    private func configureAvatar(with conversation: ConversationInfo) {
        let urlString = conversation.avatarURL ?? ""
        let displayName = conversation.title ?? conversation.conversationID
        if urlString.isEmpty {
            showTextAvatar(name: displayName)
        } else {
            loadImageAvatar(urlString: urlString, fallbackName: displayName)
        }
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

    private func configureStatus(with conversation: ConversationInfo) {
        switch ConversationCellFormatter.sendStatus(for: conversation) {
        case .error:
            statusImageView.isHidden = false
            sendingIndicator.stopAnimating()
            statusImageView.snp.updateConstraints { $0.width.height.equalTo(Self.statusIconSize) }
            subtitleLeadingConstraint?.update(offset: Self.statusSubtitleSpacing)
        case .sending:
            statusImageView.isHidden = true
            sendingIndicator.startAnimating()
            statusImageView.snp.updateConstraints { $0.width.height.equalTo(Self.sendingIndicatorSlotSize) }
            subtitleLeadingConstraint?.update(offset: Self.statusSubtitleSpacing)
        case .none:
            statusImageView.isHidden = true
            sendingIndicator.stopAnimating()
            statusImageView.snp.updateConstraints { $0.width.height.equalTo(0) }
            subtitleLeadingConstraint?.update(offset: 0)
        }
    }

    private func configureUnreadIndicators(with conversation: ConversationInfo) {
        let isUnread = conversation.unreadCount > 0 || conversation.conversationMarkList.contains(.unread)

        if conversation.shouldShowDoNotDisturbIndicator {
            muteImageView.isHidden = false
            muteHeightConstraint?.update(offset: Self.muteIconSize)
            avatarBadgeView.setMode(isUnread ? .dot : .none)
        } else {
            muteImageView.isHidden = true
            muteHeightConstraint?.update(offset: 0)
            if isUnread {
                let count = conversation.unreadCount
                let text = count > Self.badgeMaxCount ? "\(Self.badgeMaxCount)+" : "\(max(count, 1))"
                avatarBadgeView.setMode(.text(text))
            } else {
                avatarBadgeView.setMode(.none)
            }
        }
    }
}

// MARK: - ConversationAvatarBadgeView

private final class ConversationAvatarBadgeView: UIView {
    enum Mode {
        case none
        case dot
        case text(String)
    }

    override var intrinsicContentSize: CGSize {
        switch mode {
        case .none:
            return .zero
        case .dot:
            return CGSize(width: Self.dotSize, height: Self.dotSize)
        case .text(let text):
            let textWidth = (text as NSString).size(withAttributes: [.font: Self.textFont]).width
            return CGSize(
                width: ceil(textWidth) + Self.textHorizontalPadding * 2,
                height: Self.textHeight
            )
        }
    }

    private static let textHeight: CGFloat = 16

    private static let textHorizontalPadding: CGFloat = 5

    private static let dotSize: CGFloat = 8

    private static let textFont = FontScheme.caption3Bold

    private let textLabel = UILabel()

    private var mode: Mode = .none

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = ChatUIKitTheme.colors.textColorError
        textLabel.font = Self.textFont
        textLabel.textColor = ChatUIKitTheme.colors.textColorButton
        textLabel.textAlignment = .center
        addSubview(textLabel)
        textLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(
                top: 0,
                left: Self.textHorizontalPadding,
                bottom: 0,
                right: Self.textHorizontalPadding
            )).priority(.high)
        }
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setMode(_ mode: Mode) {
        self.mode = mode
        switch mode {
        case .none:
            isHidden = true
        case .dot:
            isHidden = false
            textLabel.text = nil
            layer.cornerRadius = Self.dotSize / 2
        case .text(let text):
            isHidden = false
            textLabel.text = text
            layer.cornerRadius = Self.textHeight / 2
        }
        layer.masksToBounds = true
        invalidateIntrinsicContentSize()
    }
}
