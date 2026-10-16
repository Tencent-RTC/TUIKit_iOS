import UIKit
import SnapKit

final class PusherEndConfirmationView: BottomSheetView {
    var onConfirmEnd: (() -> Void)?

    private let audienceStatusLabel = UILabel()
    private let confirmationLabel = LiveText(.sheetTitle, alignment: .center)
    private let emptyAudienceLabel = LiveText(.body, tone: .secondary, alignment: .center)
    private let continueButton = UIButton(type: .custom)
    private let endButton = UIButton(type: .custom)
    private var buttonTopConstraint: Constraint!
    private var hasAudience = false

    override var sheetHeight: CGFloat { hasAudience ? 250 : 210 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    func show(viewerCount: Int) {
        hasAudience = viewerCount > 0
        audienceStatusLabel.isHidden = !hasAudience
        confirmationLabel.isHidden = !hasAudience
        emptyAudienceLabel.isHidden = hasAudience
        buttonTopConstraint.update(offset: hasAudience ? 153 : 118)
        if hasAudience {
            audienceStatusLabel.attributedText = makeAudienceStatus(count: viewerCount)
        }
        present()
    }

    private func configureUI() {
        audienceStatusLabel.textAlignment = .center
        audienceStatusLabel.adjustsFontSizeToFitWidth = true
        audienceStatusLabel.minimumScaleFactor = 0.8
        contentView.addSubview(audienceStatusLabel)

        confirmationLabel.text = LiveKitResources.localizedString("tuilivekit.pusher.end.confirm")
        contentView.addSubview(confirmationLabel)

        emptyAudienceLabel.numberOfLines = 0
        emptyAudienceLabel.text = LiveKitResources.localizedString("tuilivekit.pusher.end.empty_audience")
        contentView.addSubview(emptyAudienceLabel)

        configureButton(
            continueButton,
            title: LiveKitResources.localizedString("tuilivekit.pusher.end.continue"),
            backgroundColor: EndConfirmationStyle.cancelBackground
        )
        continueButton.addTarget(self, action: #selector(dismiss), for: .touchUpInside)
        contentView.addSubview(continueButton)

        configureButton(
            endButton,
            title: LiveKitResources.localizedString("tuilivekit.pusher.end.end"),
            backgroundColor: EndConfirmationStyle.endBackground
        )
        endButton.layer.shadowColor = UIColor.black.withAlphaComponent(0.28).cgColor
        endButton.layer.shadowOpacity = 1
        endButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        endButton.layer.shadowRadius = 12
        endButton.addTarget(self, action: #selector(confirmEnd), for: .touchUpInside)
        contentView.addSubview(endButton)

        audienceStatusLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            make.top.equalToSuperview().offset(49)
            make.height.equalTo(31)
        }
        confirmationLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            make.top.equalToSuperview().offset(94)
            make.height.equalTo(24)
        }
        emptyAudienceLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(28)
            make.top.equalToSuperview().offset(56)
            make.bottom.lessThanOrEqualTo(continueButton.snp.top).offset(-12)
        }
        continueButton.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualToSuperview().offset(20)
            make.trailing.equalTo(contentView.snp.centerX).offset(-12)
            buttonTopConstraint = make.top.equalToSuperview().offset(118).constraint
            make.width.equalTo(max(108, ceil(continueButton.intrinsicContentSize.width) + 24)).priority(.high)
            make.height.equalTo(44)
        }
        endButton.snp.makeConstraints { make in
            make.trailing.lessThanOrEqualToSuperview().inset(20)
            make.leading.equalTo(contentView.snp.centerX).offset(12)
            make.top.equalTo(continueButton)
            make.width.equalTo(max(108, ceil(continueButton.intrinsicContentSize.width) + 24)).priority(.high)
            make.height.equalTo(44)
        }
    }

    private func configureButton(_ button: UIButton, title: String, backgroundColor: UIColor) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(EndConfirmationStyle.buttonForeground, for: .normal)
        button.titleLabel?.font = PusherEndConfirmationViewTypography.buttonFont
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.85
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = 10
    }

    private func makeAudienceStatus(count: Int) -> NSAttributedString {
        let countString = String(count)
        let text = LiveKitResources.localizedFormat("tuilivekit.pusher.end.audience_count", count)
        let result = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: EndConfirmationStyle.messageForeground,
            ]
        )
        if let range = text.range(of: countString) {
            result.addAttributes([
                .font: UIFont.systemFont(ofSize: 23, weight: .bold),
                .foregroundColor: EndConfirmationStyle.countForeground,
                .shadow: audienceCountShadow(),
            ], range: NSRange(range, in: text))
        }
        return result
    }

    private func audienceCountShadow() -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = LiveTheme.Color.brandBlue.withAlphaComponent(0.45)
        shadow.shadowBlurRadius = 14
        shadow.shadowOffset = .zero
        return shadow
    }

    @objc private func confirmEnd() {
        isHidden = true
        onConfirmEnd?()
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum EndConfirmationStyle {
    static let cancelBackground: UIColor = UIColor.white.withAlphaComponent(0.1)
    static let endBackground: UIColor = UIColor(red: 0.769, green: 0.267, blue: 0.314, alpha: 1)
    static let buttonForeground: UIColor = UIColor.white.withAlphaComponent(0.94)
    static let messageForeground: UIColor = UIColor.white.withAlphaComponent(0.76)
    static let countForeground: UIColor = UIColor(red: 0.557, green: 0.812, blue: 1, alpha: 1)
}

private enum PusherEndConfirmationViewTypography {
    static let buttonFont: UIFont = UIFont.systemFont(ofSize: 15)
}
