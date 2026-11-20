import UIKit
import SnapKit

final class PusherCoHostActionsView: BottomSheetView {
    var onInviteMore: (() -> Void)?
    var onEnd: (() -> Void)?
    var onDidDismiss: (() -> Void)?

    private let connectionLabel = UILabel()
    private let endButton = UIButton(type: .custom)
    private let inviteButton = CoHostInviteMoreButton()

    // Ardot 5074:1454, with the PK section outside the current product scope.
    override var sheetHeight: CGFloat { 148 + safeAreaInsets.bottom }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    func bind(_ state: PusherCoHostStore.State) {
        if state.connected.count == 1, let user = state.connected.first {
            connectionLabel.text = LiveKitResources.localizedFormat(
                "tuilivekit.pusher.cohost.connected_with", user.userName)
        } else {
            connectionLabel.text = LiveKitResources.localizedFormat(
                "tuilivekit.pusher.cohost.connected_count", state.connected.count + 1)
        }
        endButton.setTitle(
            LiveKitResources.localizedString(
                state.isExiting ? "tuilivekit.common.processing" : "tuilivekit.pusher.cohost.end"), for: .normal)
        endButton.isEnabled = state.isConnected && !state.isExiting && state.pendingLiveIDs.isEmpty
        inviteButton.isEnabled = state.isConnected && !state.isExiting
        endButton.alpha = endButton.isEnabled ? 1 : 0.46
        inviteButton.alpha = inviteButton.isEnabled ? 1 : 0.46
    }

    func show() { present() }

    override func sheetDidDismiss() { onDidDismiss?() }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateSheetHeight(animated: false)
    }

    private func configureUI() {
        connectionLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        connectionLabel.textColor = .white
        connectionLabel.lineBreakMode = .byTruncatingTail
        connectionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentView.addSubview(connectionLabel)

        endButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        endButton.setTitleColor(CoHostActionsStyle.endForeground, for: .normal)
        endButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        endButton.addTarget(self, action: #selector(endConnection), for: .touchUpInside)
        contentView.addSubview(endButton)

        inviteButton.addTarget(self, action: #selector(inviteMore), for: .touchUpInside)
        contentView.addSubview(inviteButton)
        connectionLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalTo(endButton)
            make.trailing.lessThanOrEqualTo(endButton.snp.leading).offset(-12)
        }
        endButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(28)
            make.trailing.equalToSuperview().inset(16)
            make.height.equalTo(44)
            make.width.greaterThanOrEqualTo(64)
        }
        inviteButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(83)
            make.height.equalTo(41)
        }
    }

    @objc private func endConnection() { onEnd?() }
    @objc private func inviteMore() { onInviteMore?() }
}

private final class CoHostInviteMoreButton: UIControl {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradient.colors = [CoHostActionsStyle.gradientStart.cgColor, CoHostActionsStyle.gradientEnd.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        gradient.cornerRadius = 12
        layer.insertSublayer(gradient, at: 0)
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = CoHostActionsStyle.border.cgColor
        layer.shadowColor = CoHostActionsStyle.shadow.cgColor
        layer.shadowOpacity = 1
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 10

        let icon = UIImageView(image: LiveKitResources.image(named: "livekit_cohost_add"))
        icon.contentMode = .scaleAspectFit
        let title = UILabel()
        title.text = LiveKitResources.localizedString("tuilivekit.pusher.cohost.invite_more")
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.textColor = .white
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.8
        let content = UIStackView(arrangedSubviews: [icon, title])
        content.axis = .horizontal
        content.alignment = .center
        content.spacing = 4
        content.isUserInteractionEnabled = false
        addSubview(content)
        icon.snp.makeConstraints { make in
            make.width.equalTo(14)
            make.height.equalTo(17)
        }
        content.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().inset(16)
        }
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = title.text
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 12).cgPath
    }
}

// Ardot 5074:1458 / 5074:1467.
private enum CoHostActionsStyle {
    static let endForeground = UIColor(red: 1, green: 0.408, blue: 0.455, alpha: 1)
    static let gradientStart = UIColor(red: 0.016, green: 0.271, blue: 0.698, alpha: 1)
    static let gradientEnd = UIColor(red: 0.216, green: 0.431, blue: 0.694, alpha: 1)
    static let border = UIColor(red: 0.392, green: 0.675, blue: 1, alpha: 0.373)
    static let shadow = UIColor(red: 0, green: 0.322, blue: 0.851, alpha: 0.18)
}
