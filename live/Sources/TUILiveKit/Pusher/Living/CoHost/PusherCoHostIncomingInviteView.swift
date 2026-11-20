import UIKit
import SnapKit
import Kingfisher

final class PusherCoHostIncomingInviteView: BottomSheetView {
    var onAccept: (() -> Void)?
    var onReject: (() -> Void)?
    var onDidDismiss: (() -> Void)?

    private let scrollView = UIScrollView()
    private let invitationContent = UIView()
    private let titleLabel = UILabel()
    private let avatarContainer = UIView()
    private let avatarView = UIImageView()
    private let badgeView = UIImageView(image: LiveKitResources.image(named: "livekit_cohost_invitation_badge"))
    private let nameLabel = UILabel()
    private let rejectButton = UIButton(type: .custom)
    private let acceptButton = IncomingAcceptButton()
    private var state = PusherCoHostStore.State()
    private var avatarURL: String?

    override var isDismissibleByTappingOutside: Bool { false }

    override var sheetHeight: CGFloat {
        let desired = IncomingInviteStyle.contentHeight + safeAreaInsets.bottom
        return bounds.height > 0 ? min(desired, max(0, bounds.height - 40)) : desired
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    deinit { Task { @MainActor [avatarView] in avatarView.kf.cancelDownloadTask() } }

    func bind(_ state: PusherCoHostStore.State) {
        self.state = state
        guard let applicant = state.applicant else {
            cancelAvatarRequest()
            return
        }
        titleLabel.text = LiveKitResources.localizedString(
            applicant.isMutual ? "tuilivekit.pusher.cohost.incoming_mutual" : "tuilivekit.pusher.cohost.incoming")
        nameLabel.text = applicant.userName
        if avatarURL != applicant.avatarURL {
            cancelAvatarRequest()
            avatarURL = applicant.avatarURL
            avatarView.kf.setImage(
                with: URL(string: applicant.avatarURL),
                placeholder: LiveKitResources.image(named: "livekit_livelist_default_avatar"))
        }
        updateCountdown()
    }

    func show() {
        guard state.applicant != nil else { return }
        bind(state)
        scrollView.setContentOffset(.zero, animated: false)
        present()
    }

    func updateCountdown() {
        let remaining = max(0, Int(ceil(state.applicantDeadline?.timeIntervalSinceNow ?? 0)))
        let busy = state.applicant.map { state.isBusy(liveID: $0.liveID) } ?? true
        rejectButton.setTitle(
            busy
                ? LiveKitResources.localizedString("tuilivekit.common.processing")
                : LiveKitResources.localizedFormat("tuilivekit.pusher.cohost.reject_countdown", remaining), for: .normal
        )
        let enabled = !busy && remaining > 0
        rejectButton.isEnabled = enabled
        acceptButton.isEnabled = enabled
        rejectButton.alpha = enabled ? 1 : 0.46
        acceptButton.alpha = enabled ? 1 : 0.46
    }

    override func sheetWillDismiss() { cancelAvatarRequest() }
    override func sheetDidDismiss() { onDidDismiss?() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { cancelAvatarRequest() } else if isPresented { bind(state) }
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        scrollView.contentInset.bottom = safeAreaInsets.bottom
        updateSheetHeight(animated: false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        avatarContainer.layer.shadowPath = UIBezierPath(ovalIn: avatarContainer.bounds).cgPath
    }

    private func configureUI() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        contentView.addSubview(scrollView)
        scrollView.addSubview(invitationContent)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        invitationContent.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }

        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = IncomingInviteStyle.titleForeground
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.85
        invitationContent.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(22)
            make.top.equalToSuperview().offset(35)
            make.height.equalTo(22)
        }

        avatarContainer.layer.shadowColor = UIColor.black.cgColor
        avatarContainer.layer.shadowOpacity = 0.24
        avatarContainer.layer.shadowOffset = CGSize(width: 0, height: 10)
        avatarContainer.layer.shadowRadius = 12.5
        invitationContent.addSubview(avatarContainer)
        avatarContainer.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(31)
            make.size.equalTo(76)
        }
        avatarView.contentMode = .scaleAspectFill
        avatarView.layer.cornerRadius = 38
        avatarView.layer.borderWidth = 3
        avatarView.layer.borderColor = IncomingInviteStyle.avatarBorder.cgColor
        avatarView.clipsToBounds = true
        avatarContainer.addSubview(avatarView)
        avatarView.snp.makeConstraints { $0.edges.equalToSuperview() }

        badgeView.contentMode = .scaleAspectFit
        invitationContent.addSubview(badgeView)
        badgeView.snp.makeConstraints { make in
            // The exported canvas includes 12 pt shadow padding around the 28 pt badge.
            make.leading.equalTo(avatarContainer).offset(39)
            make.top.equalTo(avatarContainer).offset(38)
            make.width.equalTo(52)
            make.height.equalTo(57)
        }

        nameLabel.textColor = .white
        nameLabel.font = .systemFont(ofSize: 17, weight: .bold)
        nameLabel.textAlignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        invitationContent.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.equalTo(avatarContainer.snp.bottom).offset(12)
            make.height.equalTo(24)
        }

        rejectButton.backgroundColor = IncomingInviteStyle.rejectBackground
        rejectButton.setTitleColor(IncomingInviteStyle.rejectForeground, for: .normal)
        rejectButton.addTarget(self, action: #selector(rejectInvitation), for: .touchUpInside)
        acceptButton.setTitle(LiveKitResources.localizedString("tuilivekit.pusher.cohost.accept"), for: .normal)
        acceptButton.setTitleColor(.white, for: .normal)
        acceptButton.addTarget(self, action: #selector(acceptInvitation), for: .touchUpInside)
        let buttons = UIStackView(arrangedSubviews: [rejectButton, acceptButton])
        buttons.axis = .horizontal
        buttons.distribution = .fillEqually
        buttons.spacing = 10
        invitationContent.addSubview(buttons)
        buttons.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.equalTo(nameLabel.snp.bottom).offset(42)
            make.height.equalTo(44)
            make.bottom.equalToSuperview()
        }
        [rejectButton, acceptButton].forEach { button in
            button.layer.cornerRadius = 13
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.8
        }
    }

    private func cancelAvatarRequest() {
        avatarView.kf.cancelDownloadTask()
        avatarURL = nil
    }

    @objc private func acceptInvitation() { onAccept?() }
    @objc private func rejectInvitation() { onReject?() }
}

private final class IncomingAcceptButton: UIButton {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradient.colors = [IncomingInviteStyle.acceptStart.cgColor, IncomingInviteStyle.acceptEnd.cgColor]
        gradient.startPoint = .zero
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = 13
        layer.insertSublayer(gradient, at: 0)
        layer.shadowColor = IncomingInviteStyle.acceptShadow.cgColor
        layer.shadowOpacity = 1
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 11
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 13).cgPath
    }
}

// Ardot 5074:2577, with the bottom safe area supplied by UIKit.
private enum IncomingInviteStyle {
    static let contentHeight: CGFloat = 286
    static let titleForeground = UIColor.white.withAlphaComponent(0.839)
    static let avatarBorder = UIColor(red: 0.447, green: 0.702, blue: 1, alpha: 1)
    static let rejectBackground = UIColor.white.withAlphaComponent(0.09)
    static let rejectForeground = UIColor.white.withAlphaComponent(0.741)
    static let acceptStart = UIColor(red: 0.263, green: 0.835, blue: 1, alpha: 1)
    static let acceptEnd = UIColor(red: 0.325, green: 0.475, blue: 1, alpha: 1)
    static let acceptShadow = UIColor(red: 0.271, green: 0.596, blue: 1, alpha: 0.278)
}
