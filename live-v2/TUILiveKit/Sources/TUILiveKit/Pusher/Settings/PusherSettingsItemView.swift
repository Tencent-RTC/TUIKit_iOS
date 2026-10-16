import SnapKit
import UIKit

final class PusherSettingsItemView: UIControl {
    enum Style: Equatable {
        case prepare
        case panel
        case soundOption
    }

    private let iconBackground = UIView()
    private let iconView = UIImageView()
    private let titleLabel: LiveText
    private let selectedGradient = CAGradientLayer()
    private let style: Style

    override var isSelected: Bool {
        didSet { updateSelection() }
    }

    init(
        title: String,
        assetName: String,
        iconSize: CGSize = CGSize(width: 22, height: 22),
        showsIconBackground: Bool = true,
        style: Style = .panel
    ) {
        let isPrepare = style == .prepare
        let isSoundOption = style == .soundOption
        self.style = style
        titleLabel = LiveText(
            .control,
            tone: isPrepare ? .primary : .secondary,
            alignment: .center,
            emphasized: isPrepare
        )
        super.init(frame: .zero)
        iconBackground.backgroundColor = isPrepare
            ? UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 0.5)
            : showsIconBackground ? UIColor.white.withAlphaComponent(isSoundOption ? 0.045 : 0.08) : .clear
        iconBackground.layer.cornerRadius = isSoundOption ? 14 : isPrepare ? 24 : 22
        iconBackground.layer.borderWidth = isPrepare || isSoundOption ? 1 : 0
        iconBackground.layer.borderColor = UIColor.white.withAlphaComponent(isSoundOption ? 0.14 : 0.1).cgColor
        iconBackground.isUserInteractionEnabled = false
        addSubview(iconBackground)

        if isSoundOption {
            selectedGradient.colors = [
                PusherSettingsSelectionStyle.selectedTop.cgColor,
                PusherSettingsSelectionStyle.selectedBottom.cgColor,
            ]
            selectedGradient.startPoint = CGPoint(x: 0.5, y: 0)
            selectedGradient.endPoint = CGPoint(x: 0.5, y: 1)
            selectedGradient.cornerRadius = 14
            iconBackground.layer.insertSublayer(selectedGradient, at: 0)
        }

        iconView.image = LiveKitResources.image(named: assetName)
        iconView.contentMode = .scaleAspectFit
        iconBackground.addSubview(iconView)

        titleLabel.text = title
        titleLabel.numberOfLines = style == .panel ? 2 : 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75
        addSubview(titleLabel)

        if isPrepare {
            snp.makeConstraints { $0.size.equalTo(CGSize(width: 68, height: 71)) }
        } else if isSoundOption {
            snp.makeConstraints { $0.height.equalTo(64) }
        }
        iconBackground.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(isPrepare || isSoundOption ? 0 : 4)
            make.centerX.equalToSuperview()
            make.size.equalTo(isPrepare || isSoundOption ? 48 : 44)
        }
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(isSoundOption ? 25 : isPrepare ? CGSize(width: 24, height: 24) : iconSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(iconBackground.snp.bottom).offset(isSoundOption ? 2 : isPrepare ? 7 : 8)
            make.height.equalTo(isPrepare ? 16 : isSoundOption ? 14 : 28)
        }
        updateSelection()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTitle(_ title: String) {
        titleLabel.text = title
    }

    func setIcon(assetName: String) {
        iconView.image = LiveKitResources.image(named: assetName)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        selectedGradient.frame = iconBackground.bounds
    }

    private func updateSelection() {
        guard style == .soundOption else { return }
        selectedGradient.isHidden = !isSelected
        iconBackground.backgroundColor = isSelected ? .clear : PusherSettingsSelectionStyle.idleBackground
        iconBackground.layer.borderColor = (isSelected
            ? LiveTheme.Color.brandBlue
            : PusherSettingsSelectionStyle.idleBorder).cgColor
        titleLabel.tone = isSelected ? .primary : .secondary
        titleLabel.isEmphasized = isSelected
    }
}

enum PusherSettingsSelectionStyle {
    static let selectedTop: UIColor = LiveTheme.Color.brandBlue.withAlphaComponent(0.42)
    static let selectedBottom: UIColor = LiveTheme.Color.brandDeepBlue.withAlphaComponent(0.26)
    static let idleBackground: UIColor = UIColor.white.withAlphaComponent(0.045)
    static let idleBorder: UIColor = UIColor.white.withAlphaComponent(0.14)
}
