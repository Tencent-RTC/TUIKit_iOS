import Kingfisher
import UIKit
import SnapKit

final class LiveHeaderView: UIView {
    var onClose: (() -> Void)?
    var onAudience: (() -> Void)?
    var onStatus: (() -> Void)?

    private let hostCapsule = UIView()
    private let hostGradient = CAGradientLayer()
    private let avatarView = UIImageView()
    private let titleLabel = LiveText(.caption)
    private let likeLabel = UILabel()
    private let fanButton = UIButton(type: .custom)

    private var representedAvatarURL: String?
    private var renderedHostName: String?
    private var renderedLikeCount: Int?
    private var renderedElapsedSeconds: Int?
    private var renderedNetworkQuality: UInt?
    private let audiencePresenceView = LiveAudiencePresenceView()
    private let closeButton = UIButton(type: .custom)
    private let statusView = UIButton(type: .custom)
    private let statusIconView = UIImageView()
    private let statusLabel = LiveText(.metadata, alignment: .right)
    private let statusChevronView = UIImageView()
    private var statusWidthConstraint: Constraint?
    private var statusLabelLeadingConstraint: Constraint?
    private var statusIconWidthConstraint: Constraint?
    private var statusChevronTrailingConstraint: Constraint?
    private var statusChevronWidthConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hostGradient.frame = hostCapsule.bounds
    }

    deinit {
        Task { @MainActor [avatarView] in
            avatarView.kf.cancelDownloadTask()
        }
    }

    func bindHost(name: String, avatarURL: String) {
        if renderedHostName != name {
            renderedHostName = name
            titleLabel.text = name.isEmpty ? LiveKitResources.localizedString("tuilivekit.common.host") : name
        }
        guard representedAvatarURL != avatarURL else { return }
        representedAvatarURL = avatarURL

        avatarView.kf.cancelDownloadTask()
        avatarView.kf.setImage(with: URL(string: avatarURL), placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"))
    }

    func bindAudience(_ audience: [PusherAudienceStore.User], count: Int) {
        audiencePresenceView.bind(audience: audience, count: count)
    }

    func bindLikeCount(_ count: Int) {
        guard renderedLikeCount != count else { return }
        renderedLikeCount = count
        likeLabel.text = LiveKitResources.localizedFormat("tuilivekit.pusher.living.like_count", count)
    }

    func bindElapsedSeconds(_ seconds: Int) {
        guard renderedElapsedSeconds != seconds else { return }
        renderedElapsedSeconds = seconds
        statusView.accessibilityValue = Self.formatDuration(seconds)
    }

    func bindNetworkQuality(_ quality: UInt) {
        guard renderedNetworkQuality != quality else { return }
        renderedNetworkQuality = quality
        renderNetworkStatus(quality)
    }

    private func configureUI() {
        hostCapsule.layer.cornerRadius = LiveHeaderStyle.capsuleRadius
        hostCapsule.layer.masksToBounds = true
        hostCapsule.layer.borderWidth = 1
        hostCapsule.layer.borderColor = LiveHeaderStyle.border.cgColor
        addSubview(hostCapsule)

        hostGradient.colors = [
            LiveVideoOverlayStyle.capsuleBackground.cgColor,
            LiveHeaderStyle.middle.cgColor,
            LiveHeaderStyle.purple.cgColor,
            LiveHeaderStyle.rose.cgColor,
        ]
        hostGradient.locations = [0, 0.52, 0.82, 1]
        hostGradient.startPoint = CGPoint(x: 0, y: 0.5)
        hostGradient.endPoint = CGPoint(x: 1, y: 0.5)
        hostCapsule.layer.insertSublayer(hostGradient, at: 0)

        avatarView.image = LiveKitResources.image(named: "livekit_livelist_default_avatar")
        avatarView.contentMode = .scaleAspectFill
        avatarView.layer.cornerRadius = LiveHeaderStyle.avatarRadius
        avatarView.layer.masksToBounds = true
        hostCapsule.addSubview(avatarView)

        titleLabel.lineBreakMode = .byTruncatingTail
        hostCapsule.addSubview(titleLabel)

        likeLabel.textColor = UIColor.white.withAlphaComponent(0.68)
        likeLabel.font = LiveHeaderViewTypography.likeFont
        hostCapsule.addSubview(likeLabel)

        let fanImage = LiveKitResources.image(named: "livekit_living_fan")?.withRenderingMode(.alwaysOriginal)
        fanButton.setImage(fanImage, for: .normal)
        fanButton.imageView?.contentMode = .scaleAspectFit
        fanButton.adjustsImageWhenHighlighted = false
        hostCapsule.addSubview(fanButton)

        audiencePresenceView.onTap = { [weak self] in self?.onAudience?() }
        addSubview(audiencePresenceView)

        styleDarkCapsule(closeButton, radius: 13, hasBorder: true)
        closeButton.setImage(LiveKitResources.image(named: "livekit_living_close"), for: .normal)
        closeButton.imageView?.contentMode = .scaleAspectFit
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        addSubview(closeButton)

        statusView.isAccessibilityElement = true
        statusView.backgroundColor = LiveVideoOverlayStyle.capsuleBackground
        statusView.layer.cornerRadius = 9.5
        statusView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        statusView.layer.masksToBounds = true
        statusView.addTarget(self, action: #selector(showStatus), for: .touchUpInside)
        addSubview(statusView)

        statusIconView.contentMode = .scaleAspectFit
        statusView.addSubview(statusIconView)

        statusLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        statusView.addSubview(statusLabel)

        statusChevronView.contentMode = .scaleAspectFit
        statusView.addSubview(statusChevronView)

        hostCapsule.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.height.equalTo(36)
            make.width.equalTo(165).priority(.high)
            make.trailing.lessThanOrEqualTo(audiencePresenceView.snp.leading).offset(-4)
        }
        avatarView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(2)
            make.size.equalTo(32)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(40)
            make.top.equalToSuperview().offset(5)
            make.trailing.equalTo(fanButton.snp.leading).offset(-2)
            make.height.equalTo(15)
        }
        likeLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalToSuperview().offset(20)
            make.trailing.equalTo(titleLabel)
            make.height.equalTo(11)
        }
        fanButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(2)
            make.top.equalToSuperview().offset(4)
            make.size.equalTo(CGSize(width: 42, height: 28))
        }
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(5)
            make.size.equalTo(26)
        }
        audiencePresenceView.snp.makeConstraints { make in
            make.trailing.equalTo(closeButton.snp.leading).offset(-4)
            make.top.equalTo(closeButton)
            make.height.equalTo(26)
        }
        statusView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(12)
            make.top.equalToSuperview().offset(42)
            make.height.equalTo(19)
            statusWidthConstraint = make.width.equalTo(68).constraint
        }
        statusIconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(7)
            make.centerY.equalToSuperview()
            statusIconWidthConstraint = make.width.equalTo(13).constraint
            make.height.equalTo(13)
        }
        statusLabel.snp.makeConstraints { make in
            statusLabelLeadingConstraint = make.leading.equalToSuperview().offset(9).constraint
            make.centerY.equalToSuperview()
            make.height.equalTo(12)
            make.trailing.equalTo(statusChevronView.snp.leading).offset(-3)
        }
        statusChevronView.snp.makeConstraints { make in
            statusChevronTrailingConstraint = make.trailing.equalToSuperview().inset(9.7).constraint
            make.centerY.equalToSuperview()
            statusChevronWidthConstraint = make.width.equalTo(3.5).constraint
            make.height.equalTo(6.2)
        }

        bindNetworkQuality(0)
    }

    private func styleDarkCapsule(_ view: UIView, radius: CGFloat, hasBorder: Bool) {
        view.backgroundColor = LiveVideoOverlayStyle.capsuleBackground
        view.layer.cornerRadius = radius
        view.layer.masksToBounds = true
        if hasBorder {
            view.layer.borderWidth = 1
            view.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        }
    }

    private static func formatDuration(_ seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
    }

    private func renderNetworkStatus(_ quality: UInt) {
        let presentation = NetworkStatusPresentation(quality: quality)
        let title = LiveKitResources.localizedString(presentation.titleKey)
        statusLabel.text = title
        statusLabel.textColor = presentation.tintColor
        statusIconView.image = presentation.iconName.flatMap { LiveKitResources.image(named: $0) }
        statusIconView.isHidden = presentation.iconName == nil
        statusIconWidthConstraint?.update(offset: presentation.iconWidth)
        statusChevronView.image = LiveKitResources.image(named: presentation.chevronName)
        statusLabelLeadingConstraint?.update(offset: presentation.labelLeading)
        statusChevronTrailingConstraint?.update(inset: presentation.chevronTrailing)
        statusChevronWidthConstraint?.update(offset: presentation.chevronWidth)

        let contentWidth = presentation.labelLeading
            + ceil(statusLabel.intrinsicContentSize.width)
            + 3
            + presentation.chevronWidth
            + presentation.chevronTrailing
        statusWidthConstraint?.update(offset: max(presentation.minimumWidth, contentWidth))
        statusView.accessibilityLabel = title
    }

    @objc private func close() {
        onClose?()
    }

    @objc private func showStatus() {
        onStatus?()
    }
}

private enum NetworkStatusPresentation {
    case normal
    case poor
    case veryPoor
    case disconnected

    init(quality: UInt) {
        switch quality {
        case 3: self = .poor
        case 4, 5: self = .veryPoor
        case 6: self = .disconnected
        default: self = .normal
        }
    }

    var titleKey: String {
        switch self {
        case .normal: return "tuilivekit.pusher.status.title"
        case .poor: return "tuilivekit.pusher.living.network_poor"
        case .veryPoor: return "tuilivekit.pusher.living.network_very_poor"
        case .disconnected: return "tuilivekit.pusher.living.network_disconnected"
        }
    }

    var iconName: String? {
        switch self {
        case .normal: return nil
        case .poor: return "livekit_living_network_poor"
        case .veryPoor: return "livekit_living_network_very_poor"
        case .disconnected: return "livekit_living_network_disconnected"
        }
    }

    var chevronName: String {
        switch self {
        case .normal: return "livekit_living_status_chevron"
        case .poor: return "livekit_living_network_poor_chevron"
        case .veryPoor: return "livekit_living_network_very_poor_chevron"
        case .disconnected: return "livekit_living_network_disconnected_chevron"
        }
    }

    var tintColor: UIColor {
        switch self {
        case .normal: return .white
        case .poor: return UIColor(red: 1, green: 0.816, blue: 0.541, alpha: 1)
        case .veryPoor: return UIColor(red: 1, green: 0.573, blue: 0.490, alpha: 1)
        case .disconnected: return UIColor(red: 1, green: 0.412, blue: 0.471, alpha: 1)
        }
    }

    var minimumWidth: CGFloat {
        switch self {
        case .normal: return 68
        case .poor: return 82
        case .veryPoor, .disconnected: return 94
        }
    }

    var iconWidth: CGFloat {
        switch self {
        case .normal, .poor: return 13
        case .veryPoor, .disconnected: return 17
        }
    }

    var labelLeading: CGFloat {
        switch self {
        case .normal: return 8.8
        case .poor: return 25
        case .veryPoor, .disconnected: return 29
        }
    }

    var chevronTrailing: CGFloat {
        switch self {
        case .normal: return 9.7
        case .poor: return 10.1
        case .veryPoor, .disconnected: return 8.08
        }
    }

    var chevronWidth: CGFloat {
        switch self {
        case .normal: return 3.5
        case .poor: return 3.89
        case .veryPoor, .disconnected: return 3.92
        }
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum LiveHeaderViewTypography {
    static let likeFont: UIFont = UIFont.systemFont(ofSize: 8)
}
