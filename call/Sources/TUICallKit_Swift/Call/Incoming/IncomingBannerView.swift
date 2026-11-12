import AtomicXCore
import SnapKit
import UIKit

final class IncomingBannerView: UIControl {

    var onAccept: (() -> Void)?
    var onReject: (() -> Void)?
    var onExpand: (() -> Void)?

    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let kickerLabel = UILabel()

    init(mediaType: CallMediaType?) {
        super.init(frame: .zero)
        setupViews(isVideo: mediaType == .video)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews(isVideo: Bool) {
        layer.cornerRadius = 18
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.38
        layer.shadowRadius = 15
        layer.shadowOffset = CGSize(width: 0, height: 12)
        addTarget(self, action: #selector(handleCardTap), for: .touchUpInside)

        blurView.layer.cornerRadius = 18
        blurView.clipsToBounds = true
        blurView.isUserInteractionEnabled = false
        addSubview(blurView)
        blurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        let tint = UIView()
        tint.backgroundColor = CallKitTheme.bannerBackground
        blurView.contentView.addSubview(tint)
        tint.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        avatarImageView.image = CallKitResources.image(named: "callkit_default_avatar")
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.cornerRadius = 12
        blurView.contentView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(44)
        }

        nameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.lineBreakMode = .byTruncatingTail
        kickerLabel.font = .systemFont(ofSize: 11)
        kickerLabel.textColor = CallKitTheme.textOnDarkSecondary

        let rejectButton = UIButton(type: .custom)
        rejectButton.backgroundColor = CallKitTheme.callRed
        rejectButton.layer.cornerRadius = 22
        rejectButton.clipsToBounds = true
        let rejectIcon = UIImageView(image: CallKitResources.image(named: "callkit_icon_reject"))
        rejectIcon.contentMode = .scaleAspectFit
        rejectButton.addSubview(rejectIcon)
        rejectIcon.snp.makeConstraints { make in make.edges.equalToSuperview() }
        rejectButton.addTarget(self, action: #selector(handleReject), for: .touchUpInside)

        let acceptButton = UIButton(type: .custom)
        acceptButton.backgroundColor = CallKitTheme.callGreen
        acceptButton.layer.cornerRadius = 22
        acceptButton.clipsToBounds = true
        let acceptIcon = UIImageView(image: isVideo
            ? CallKitResources.image(named: "callkit_icon_video_glyph")?.withRenderingMode(.alwaysTemplate)
            : CallKitResources.image(named: "callkit_icon_accept"))
        acceptIcon.contentMode = .scaleAspectFit
        acceptIcon.tintColor = .white
        acceptButton.addSubview(acceptIcon)
        acceptIcon.snp.makeConstraints { make in make.edges.equalToSuperview().inset(isVideo ? 10 : 0) }
        acceptButton.addTarget(self, action: #selector(handleAccept), for: .touchUpInside)
        addSubview(rejectButton)
        addSubview(acceptButton)
        acceptButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-16)
            make.size.equalTo(44)
        }
        rejectButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(acceptButton.snp.leading).offset(-12)
            make.size.equalTo(44)
        }

        let textStack = UIStackView(arrangedSubviews: [nameLabel, kickerLabel])
        textStack.axis = .vertical
        blurView.contentView.addSubview(textStack)
        textStack.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(rejectButton.snp.leading).offset(-8)
        }
    }

    func reload() {
        let call = CallStore.shared.state.value.activeCall
        let inviterID = call.inviterId
        guard !inviterID.isEmpty else { return }
        let base = CallKitResources.text(call.mediaType == .video ? "callkit.incoming.video" : "callkit.incoming.audio")
        kickerLabel.text = CallKitConfig.shared.enableMuteMode
            ? base + CallKitResources.text("callkit.incoming.muted_suffix")
            : base
        nameLabel.text = inviterID
        CallKitContactLoader.load(userIDs: [inviterID]) { [weak self] _, nickname, image in
            if let nickname, !nickname.isEmpty { self?.nameLabel.text = nickname }
            if let image { self?.avatarImageView.image = image }
        }
    }

    @objc private func handleAccept() { onAccept?() }
    @objc private func handleReject() { onReject?() }
    @objc private func handleCardTap() { onExpand?() }
}
