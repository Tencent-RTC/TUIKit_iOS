import UIKit
import SnapKit

final class RoomScreenSharingPlaceholderView: UIView {
    private static let blinkKey = "roomkit.share.live.blink"
    var onStop: (() -> Void)?

    override var isHidden: Bool {
        didSet { isHidden ? stopBlink() : startBlink() }
    }

    private let contentStack = UIStackView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let liveRow = UIStackView()
    private let liveDot = UIView()
    private let liveLabel = UILabel()
    private let hintLabel = UILabel()
    private let stopButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        setupViews()
        setupConstraints()
        setupStyles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { startBlink() } else { stopBlink() }
    }

    private func setupViews() {
        liveRow.addArrangedSubview(liveDot)
        liveRow.addArrangedSubview(liveLabel)
        contentStack.addArrangedSubview(iconView)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(liveRow)
        contentStack.addArrangedSubview(hintLabel)
        contentStack.addArrangedSubview(stopButton)
        addSubview(contentStack)
        stopButton.addTarget(self, action: #selector(handleStopTap), for: .touchUpInside)
    }

    private func setupConstraints() {
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 8
        contentStack.setCustomSpacing(14, after: iconView)
        contentStack.setCustomSpacing(22, after: hintLabel)

        liveRow.axis = .horizontal
        liveRow.alignment = .center
        liveRow.spacing = 6

        iconView.snp.makeConstraints { $0.size.equalTo(48) }
        liveDot.snp.makeConstraints { $0.size.equalTo(6) }
        hintLabel.snp.makeConstraints { $0.width.lessThanOrEqualTo(248) }
        stopButton.snp.makeConstraints {
            $0.height.equalTo(36)
            $0.width.greaterThanOrEqualTo(128)
        }

        contentStack.snp.makeConstraints {
            $0.centerX.centerY.equalToSuperview()
            $0.top.greaterThanOrEqualToSuperview().offset(24).priority(.high)
            $0.bottom.lessThanOrEqualToSuperview().offset(-36).priority(.high)
            $0.leading.greaterThanOrEqualToSuperview().offset(40).priority(.high)
            $0.trailing.lessThanOrEqualToSuperview().offset(-40).priority(.high)
        }
    }

    private func setupStyles() {
        backgroundColor = .roomKitSharePlaceholderBg

        iconView.image = RoomKitResources.image(named: "roomkit_icon_screen_share_accent")
        iconView.contentMode = .scaleAspectFit

        titleLabel.text = .screenSharingPhoneTitle
        titleLabel.textColor = .roomKitFgPrimary
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        liveDot.backgroundColor = .roomKitDanger
        liveDot.layer.cornerRadius = 3

        liveLabel.text = .screenSharingLive
        liveLabel.textColor = .roomKitDanger
        liveLabel.font = .systemFont(ofSize: 12)
        liveLabel.textAlignment = .center

        hintLabel.attributedText = Self.attributed(text: .screenSharingPhoneHint, fontSize: 12, lineHeight: 1.6)
        hintLabel.textColor = .roomKitFgSecondary
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0

        stopButton.setTitle(.screenSharingStop, for: .normal)
        stopButton.setTitleColor(.roomKitFgOnDanger, for: .normal)
        stopButton.titleLabel?.font = .systemFont(ofSize: 14)
        stopButton.setBackgroundImage(.solid(.roomKitDanger), for: .normal)
        stopButton.setBackgroundImage(.solid(.roomKitDangerPressed), for: .highlighted)
        stopButton.layer.cornerRadius = 6
        stopButton.layer.masksToBounds = true
        stopButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
    }

    @objc private func handleStopTap() {
        onStop?()
    }

    private func startBlink() {
        guard !isHidden, window != nil, !UIAccessibility.isReduceMotionEnabled else { return }
        guard liveDot.layer.animation(forKey: Self.blinkKey) == nil else { return }
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [1, 0.35, 1]
        animation.duration = 1.4
        animation.repeatCount = .greatestFiniteMagnitude
        liveDot.layer.add(animation, forKey: Self.blinkKey)
    }

    private func stopBlink() {
        liveDot.layer.removeAnimation(forKey: Self.blinkKey)
    }

    private static func attributed(text: String, fontSize: CGFloat, lineHeight: CGFloat) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: fontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = max(fontSize * lineHeight - font.lineHeight, 0)
        return NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: paragraph])
    }
}

// MARK: - localized strings

private extension String {
    static var screenSharingPhoneTitle: String { RoomKitResources.localizedString("roomkit.main.screen_share_sharing_phone") }
    static var screenSharingLive: String { RoomKitResources.localizedString("roomkit.main.screen_share_live") }
    static var screenSharingPhoneHint: String { RoomKitResources.localizedString("roomkit.main.screen_share_sharing_phone_hint") }
    static var screenSharingStop: String { RoomKitResources.localizedString("roomkit.main.screen_share_stop") }
}
