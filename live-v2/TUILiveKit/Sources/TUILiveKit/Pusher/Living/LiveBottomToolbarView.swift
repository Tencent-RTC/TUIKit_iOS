import UIKit
import SnapKit

final class LiveBottomToolbarView: UIView {
    var onCoGuest: (() -> Void)?
    var onMore: (() -> Void)?

    private let coGuestAction = LivingActionControl(title: LiveKitResources.localizedString("tuilivekit.pusher.living.coguest"), assetName: "livekit_living_coguest", iconSize: CGSize(width: 46, height: 38), iconTop: -6, unreadAssetName: "livekit_living_coguest_unread")
    private let moreAction = LivingActionControl(title: LiveKitResources.localizedString("tuilivekit.common.more"), assetName: "livekit_living_more", iconSize: CGSize(width: 27, height: 27))

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureUI() {
        backgroundColor = LiveTheme.Color.controlBase

        [coGuestAction, moreAction].forEach {
            addSubview($0)
        }
        coGuestAction.addTarget(self, action: #selector(showCoGuest), for: .touchUpInside)
        moreAction.addTarget(self, action: #selector(showMore), for: .touchUpInside)

        coGuestAction.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.top.equalToSuperview().offset(16)
        }
        moreAction.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            make.top.equalToSuperview().offset(16)
        }
    }

    func setCoGuestStageActive(_ isActive: Bool) {
        backgroundColor = isActive
            ? .clear
            : LiveTheme.Color.controlBase
    }

    func setCoGuestUnread(_ hasUnread: Bool) {
        coGuestAction.setUnread(hasUnread)
    }

    @objc private func showCoGuest() {
        onCoGuest?()
    }

    @objc private func showMore() {
        onMore?()
    }

    func likeAnimationOrigin(in view: UIView) -> CGPoint {
        convert(
            CGPoint(x: moreAction.frame.midX, y: moreAction.frame.minY - 10),
            to: view
        )
    }
}

private final class LivingActionControl: UIControl {
    private let iconView = UIImageView()
    private let normalImage: UIImage?
    private let unreadImage: UIImage?

    init(title: String, assetName: String, iconSize: CGSize, iconTop: CGFloat = 0, unreadAssetName: String? = nil) {
        normalImage = LiveKitResources.image(named: assetName)
        unreadImage = unreadAssetName.flatMap { LiveKitResources.image(named: $0) }
        super.init(frame: .zero)

        iconView.image = normalImage
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        addSubview(iconView)

        let titleLabel = LiveText(.control, tone: .secondary, alignment: .center)
        titleLabel.text = title
        titleLabel.layer.shadowColor = PusherToolbarStyle.titleShadow.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        titleLabel.layer.shadowRadius = 2
        titleLabel.layer.shadowOpacity = 1
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        snp.makeConstraints { make in
            make.width.equalTo(max(34, ceil(titleLabel.intrinsicContentSize.width)))
            make.height.equalTo(46)
        }
        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(iconTop)
            make.centerX.equalToSuperview()
            make.size.equalTo(iconSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(30)
            make.height.equalTo(16)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUnread(_ hasUnread: Bool) {
        iconView.image = hasUnread ? (unreadImage ?? normalImage) : normalImage
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum PusherToolbarStyle {
    static let titleShadow: UIColor = UIColor.black.withAlphaComponent(0.35)
}
