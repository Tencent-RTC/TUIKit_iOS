import Kingfisher
import UIKit
import SnapKit

final class LiveAudiencePresenceView: UIView {
    var onTap: (() -> Void)?

    private let avatarStack = UIStackView()
    private let countView = UIView()
    private let countLabel = LiveText(.caption, alignment: .center)
    private var avatarViews: [AudienceAvatarView] = []
    private var countLeadingConstraint: Constraint!
    private var countWidthConstraint: Constraint!
    private var renderedAvatarURLs: [String] = []
    private var renderedCount: Int?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(audience: [PusherAudienceStore.User], count: Int) {
        let visibleAudience = count > 0 ? Array(audience.prefix(3)) : []
        let avatarURLs = visibleAudience.map(\.avatarURL)
        if renderedCount == nil || renderedAvatarURLs != avatarURLs {
            renderedAvatarURLs = avatarURLs
            avatarStack.isHidden = avatarURLs.isEmpty
            countLeadingConstraint.update(offset: avatarURLs.isEmpty ? 0 : 4)
            for (index, avatarView) in avatarViews.enumerated() {
                avatarView.isHidden = index >= avatarURLs.count
                avatarView.bind(avatarURL: index < avatarURLs.count ? avatarURLs[index] : "")
            }
        }

        guard renderedCount != count else { return }
        renderedCount = count
        let countText = Self.formattedCount(count)
        countLabel.text = countText
        let textWidth = ceil(countLabel.sizeThatFits(
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: 26)
        ).width)
        countWidthConstraint.update(offset: max(26, textWidth + 14))
        isHidden = false
        accessibilityLabel = LiveKitResources.localizedString("tuilivekit.player.online_audience")
        accessibilityValue = String(count)
    }

    private func configureUI() {
        isHidden = true
        isAccessibilityElement = true
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap)))

        avatarStack.axis = .horizontal
        avatarStack.alignment = .fill
        avatarStack.distribution = .fill
        avatarStack.spacing = 2
        addSubview(avatarStack)

        for _ in 0 ..< 3 {
            let avatarView = AudienceAvatarView()
            avatarStack.addArrangedSubview(avatarView)
            avatarViews.append(avatarView)
            avatarView.snp.makeConstraints { make in
                make.width.equalTo(32).priority(.high)
                make.height.equalTo(26)
            }
        }

        countView.backgroundColor = LiveVideoOverlayStyle.capsuleBackground
        countView.layer.cornerRadius = 13
        countView.layer.masksToBounds = true
        addSubview(countView)

        countLabel.adjustsFontSizeToFitWidth = false
        countView.addSubview(countLabel)

        avatarStack.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }
        countView.snp.makeConstraints { make in
            countLeadingConstraint = make.leading.equalTo(avatarStack.snp.trailing).offset(4).constraint
            make.trailing.top.equalToSuperview()
            countWidthConstraint = make.width.equalTo(26).constraint
            make.height.equalTo(26)
        }
        countLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(7)
            make.centerY.equalToSuperview()
        }
    }

    private static func formattedCount(_ count: Int) -> String {
        let safeCount = max(0, count)
        guard safeCount >= 10_000 else { return String(safeCount) }
        return LiveKitResources.localizedFormat(
            "tuilivekit.pusher.living.audience_count_compact",
            min(10, safeCount / 10_000)
        )
    }

    @objc private func tap() {
        onTap?()
    }
}

private final class AudienceAvatarView: UIView {
    private let avatarView = UIImageView()
    private var representedAvatarURL: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(avatarURL: String) {
        guard representedAvatarURL != avatarURL else { return }
        representedAvatarURL = avatarURL

        avatarView.kf.cancelDownloadTask()
        avatarView.kf.setImage(with: URL(string: avatarURL), placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"))
    }

    deinit {
        Task { @MainActor [avatarView] in
            avatarView.kf.cancelDownloadTask()
        }
    }

    private func configureUI() {
        clipsToBounds = true

        avatarView.contentMode = .scaleAspectFill
        avatarView.image = LiveKitResources.image(named: "livekit_livelist_default_avatar")
        avatarView.layer.cornerRadius = 13
        avatarView.layer.masksToBounds = true
        addSubview(avatarView)

        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(3)
            make.top.equalToSuperview()
            make.size.equalTo(26)
        }
    }
}
