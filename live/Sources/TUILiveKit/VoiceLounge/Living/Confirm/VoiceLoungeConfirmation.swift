import SnapKit
import UIKit

final class VoiceLoungeEndPanel: BottomSheetView {
    var onConfirmEnd: (() -> Void)?

    private let audienceStatusLabel = UILabel()
    private let confirmationLabel = LiveText.voiceLounge(.sheetTitle, alignment: .center)
    private let emptyLabel = LiveText.voiceLounge(.body, tone: .secondary, alignment: .center)
    private let continueButton = UIButton(type: .custom)
    private let endButton = UIButton(type: .custom)
    private var buttonTopConstraint: Constraint!
    private var hasAudience = false

    override var sheetHeight: CGFloat { hasAudience ? 244 : 208 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    func show(viewerCount: Int) {
        hasAudience = viewerCount > 0
        audienceStatusLabel.isHidden = !hasAudience
        confirmationLabel.isHidden = !hasAudience
        emptyLabel.isHidden = hasAudience
        buttonTopConstraint.update(offset: hasAudience ? 150 : 116)
        if hasAudience { audienceStatusLabel.attributedText = makeAudienceStatus(count: viewerCount) }
        present()
    }

    private func setupViews() {
        contentView.addSubview(audienceStatusLabel)
        contentView.addSubview(confirmationLabel)
        contentView.addSubview(emptyLabel)
        contentView.addSubview(continueButton)
        contentView.addSubview(endButton)
    }

    private func setupConstraints() {
        audienceStatusLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            make.top.equalToSuperview().offset(48)
            make.height.equalTo(31)
        }
        confirmationLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            make.top.equalToSuperview().offset(92)
            make.height.equalTo(24)
        }
        emptyLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(28)
            make.top.equalToSuperview().offset(54)
        }
        continueButton.snp.makeConstraints { make in
            make.trailing.equalTo(contentView.snp.centerX).offset(-8)
            buttonTopConstraint = make.top.equalToSuperview().offset(116).constraint
            make.leading.equalToSuperview().offset(20)
            make.height.equalTo(46)
        }
        endButton.snp.makeConstraints { make in
            make.leading.equalTo(contentView.snp.centerX).offset(8)
            make.trailing.equalToSuperview().inset(20)
            make.top.width.height.equalTo(continueButton)
        }
    }

    private func setupStyles() {
        audienceStatusLabel.textAlignment = .center
        audienceStatusLabel.adjustsFontSizeToFitWidth = true
        audienceStatusLabel.minimumScaleFactor = 0.8
        confirmationLabel.text = .confirm
        emptyLabel.numberOfLines = 0
        emptyLabel.text = .empty
        configureButton(continueButton, title: .endContinue, background: EndPanelStyle.cancelBackground)
        configureButton(endButton, title: .end, background: EndPanelStyle.endBackground)
    }

    private func setupBindings() {
        continueButton.addTarget(self, action: #selector(dismiss), for: .touchUpInside)
        endButton.addTarget(self, action: #selector(confirmEnd), for: .touchUpInside)
    }

    private func configureButton(_ button: UIButton, title: String, background: UIColor) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(EndPanelStyle.buttonForeground, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = background
        button.layer.cornerRadius = 12
    }

    private func makeAudienceStatus(count: Int) -> NSAttributedString {
        let countString = String(count)
        let text = String.audienceCount(countString)
        let result = NSMutableAttributedString(
            string: text,
            attributes: [.font: UIFont.systemFont(ofSize: 15), .foregroundColor: EndPanelStyle.messageForeground])
        if let range = text.range(of: countString) {
            result.addAttributes(
                [.font: UIFont.systemFont(ofSize: 24, weight: .bold), .foregroundColor: EndPanelStyle.countForeground],
                range: NSRange(range, in: text))
        }
        return result
    }
}

extension VoiceLoungeEndPanel {
    @objc private func confirmEnd() {
        isHidden = true
        onConfirmEnd?()
    }
}

private enum EndPanelStyle {
    static let cancelBackground = VoiceLoungeColor.overlayBase
    static let endBackground = UIColor(red: 0.769, green: 0.267, blue: 0.314, alpha: 1)
    static let buttonForeground = UIColor.white.withAlphaComponent(0.94)
    static let messageForeground = UIColor.white.withAlphaComponent(0.76)
    static let countForeground = VoiceLoungeColor.statHighlight
}

private extension String {
    static func audienceCount(_ args: CVarArg...) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.end.audience_count", args)
    }
    static var confirm: String { LiveKitResources.localizedString("tuilivekit.voiceroom.end.confirm") }
    static var empty: String { LiveKitResources.localizedString("tuilivekit.voiceroom.end.empty") }
    static var end: String { LiveKitResources.localizedString("tuilivekit.voiceroom.end.end") }
    static var endContinue: String { LiveKitResources.localizedString("tuilivekit.voiceroom.end.continue") }
}

final class VoiceLoungeAlertView: UIView {
    private let cardView = UIView()
    private let titleLabel = LiveText.voiceLounge(.sheetTitle, alignment: .center)
    private let messageLabel = LiveText.voiceLounge(.body, tone: .secondary, alignment: .center)
    private let buttonRow = UIStackView()
    private let cancelButton = UIButton(type: .custom)
    private let confirmButton = UIButton(type: .custom)
    private var onConfirm: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(
        title: String, message: String, confirmTitle: String, skin: VoiceLoungeSkin, onConfirm: @escaping () -> Void
    ) {
        titleLabel.text = title
        messageLabel.text = message
        confirmButton.setTitle(confirmTitle, for: .normal)
        confirmButton.backgroundColor = skin.mid
        self.onConfirm = onConfirm
        superview?.bringSubviewToFront(self)
        isHidden = false
        alpha = 0
        cardView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut]) {
            self.alpha = 1
            self.cardView.transform = .identity
        }
    }

    func dismiss() {
        guard !isHidden else { return }
        onConfirm = nil
        UIView.animate(
            withDuration: 0.15, animations: { self.alpha = 0 }, completion: { [weak self] _ in self?.isHidden = true })
    }

    private func setupViews() {
        addSubview(cardView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(messageLabel)
        cardView.addSubview(buttonRow)
        buttonRow.addArrangedSubview(cancelButton)
        buttonRow.addArrangedSubview(confirmButton)
    }

    private func setupConstraints() {
        cardView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(40)
            make.width.equalTo(300).priority(.high)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        buttonRow.snp.makeConstraints { make in
            make.top.equalTo(messageLabel.snp.bottom).offset(22)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(20)
            make.height.equalTo(44)
        }
    }

    private func setupStyles() {
        isHidden = true
        backgroundColor = LiveTheme.Color.sheetScrim
        cardView.backgroundColor = VoiceLoungeColor.dialogBackground
        cardView.layer.cornerRadius = 20
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = VoiceLoungeColor.overlayHair.cgColor
        titleLabel.numberOfLines = 0
        messageLabel.numberOfLines = 0
        buttonRow.axis = .horizontal
        buttonRow.distribution = .fillEqually
        buttonRow.spacing = 12
        styleButton(cancelButton, background: VoiceLoungeColor.overlayBase)
        cancelButton.setTitle(.cancel, for: .normal)
        styleButton(confirmButton, background: VoiceLoungeColor.rose)
    }

    private func setupBindings() {
        cancelButton.addTarget(self, action: #selector(tapCancel), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(tapConfirm), for: .touchUpInside)
    }

    private func styleButton(_ button: UIButton, background: UIColor) {
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = background
        button.layer.cornerRadius = 12
    }
}

extension VoiceLoungeAlertView {
    @objc private func tapCancel() { dismiss() }

    @objc private func tapConfirm() {
        let action = onConfirm
        dismiss()
        action?()
    }
}

private extension String { static var cancel: String { LiveKitResources.localizedString("tuilivekit.common.cancel") } }
