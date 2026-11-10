import SnapKit
import UIKit

class PusherMoreSettingsSheet: BottomSheetView {
    let mainContentView = UIView()
    let audioEffectView = AudioEffectView()
    private var showsAudio = false
    private(set) var panelScale: CGFloat = 1
    var mainSheetHeight: CGFloat { 0 }
    var mainSheetTitle: String? { nil }
    override var sheetHeight: CGFloat { showsAudio ? 466 : mainSheetHeight }

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(mainContentView)
        contentView.addSubview(audioEffectView)
        audioEffectView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.top.equalToSuperview().offset(60)
            $0.height.equalTo(372)
        }
    }

    final override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        let scale = LiveLayoutScale.factor(for: bounds.width, widthRange: 375...440, scaleRange: 1...(52.0 / 44.0))
        guard panelScale != scale else { return }
        panelScale = scale
        updateMainLayout(scale: scale)
        updateSheetHeight(animated: false)
    }

    /// Subclasses update their main-page constraints after the shared scale changes.
    func updateMainLayout(scale: CGFloat) {}

    func showPage(_ showsAudio: Bool, animated: Bool) {
        self.showsAudio = showsAudio
        sheetTitle = showsAudio ? LiveKitResources.localizedString("tuilivekit.pusher.audio_effects") : mainSheetTitle
        mainContentView.isHidden = showsAudio
        audioEffectView.isHidden = !showsAudio
        audioEffectView.setActive(showsAudio && !isHidden)
        updateSheetHeight(animated: animated)
    }

    override func sheetWillPresent() { audioEffectView.setActive(showsAudio) }
    override func sheetWillDismiss() { audioEffectView.setActive(false) }
}

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
    private let panelIconSize: CGSize
    private var panelScale: CGFloat = 1
    private var prepareScale: CGFloat = 1

    override var isSelected: Bool { didSet { updateSelection() } }

    init(
        title: String, assetName: String, iconSize: CGSize = CGSize(width: 22, height: 22),
        showsIconBackground: Bool = true, style: Style = .panel
    ) {
        let isPrepare = style == .prepare
        let isSoundOption = style == .soundOption
        self.style = style
        panelIconSize = iconSize
        titleLabel = LiveText(
            .control, tone: isPrepare ? .primary : .secondary, alignment: .center, emphasized: isPrepare)
        super.init(frame: .zero)
        iconBackground.backgroundColor =
            isPrepare
            ? UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 0.5)
            : showsIconBackground ? UIColor.white.withAlphaComponent(isSoundOption ? 0.045 : 0.08) : .clear
        iconBackground.layer.cornerRadius = isSoundOption ? 14 : isPrepare ? 27 : 22
        iconBackground.layer.borderWidth = isPrepare || isSoundOption ? 1 : 0
        iconBackground.layer.borderColor = UIColor.white.withAlphaComponent(isSoundOption ? 0.14 : 0.1).cgColor
        iconBackground.isUserInteractionEnabled = false
        addSubview(iconBackground)

        if isSoundOption {
            selectedGradient.colors = [
                PusherSettingsSelectionStyle.selectedTop.cgColor, PusherSettingsSelectionStyle.selectedBottom.cgColor,
            ]
            selectedGradient.startPoint = CGPoint(x: 0.5, y: 0)
            selectedGradient.endPoint = CGPoint(x: 0.5, y: 1)
            selectedGradient.cornerRadius = 14
            iconBackground.layer.insertSublayer(selectedGradient, at: 0)
        }

        iconView.image = LiveKitResources.image(named: assetName)
        iconView.contentMode = .scaleAspectFit
        iconBackground.addSubview(iconView)

        if isPrepare { titleLabel.font = .systemFont(ofSize: 12, weight: .semibold) }
        titleLabel.text = title
        titleLabel.numberOfLines = style == .panel ? 2 : 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75
        addSubview(titleLabel)

        if isPrepare {
            snp.makeConstraints { $0.size.equalTo(CGSize(width: 76, height: 80)) }
        } else if isSoundOption {
            snp.makeConstraints { $0.height.equalTo(64) }
        }
        iconBackground.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(isPrepare || isSoundOption ? 0 : 4)
            make.centerX.equalToSuperview()
            make.size.equalTo(isPrepare ? 54 : isSoundOption ? 48 : 44)
        }
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(isSoundOption ? 25 : isPrepare ? CGSize(width: 27, height: 27) : iconSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(iconBackground.snp.bottom).offset(isSoundOption ? 2 : 8)
            make.height.equalTo(isPrepare ? 18 : isSoundOption ? 14 : 28)
        }
        updateSelection()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updatePrepareLayout(scale: CGFloat) {
        guard style == .prepare, prepareScale != scale else { return }
        prepareScale = scale
        titleLabel.font = .systemFont(ofSize: 12 * scale, weight: .semibold)
        iconBackground.layer.cornerRadius = 27 * scale
        snp.updateConstraints { $0.size.equalTo(CGSize(width: 76 * scale, height: 80 * scale)) }
        iconBackground.snp.updateConstraints { $0.size.equalTo(54 * scale) }
        iconView.snp.updateConstraints { $0.size.equalTo(CGSize(width: 27 * scale, height: 27 * scale)) }
        titleLabel.snp.updateConstraints { make in
            make.top.equalTo(iconBackground.snp.bottom).offset(8 * scale)
            make.height.equalTo(18 * scale)
        }
    }

    func updatePanelLayout(scale: CGFloat) {
        guard style == .panel, panelScale != scale else { return }
        panelScale = scale
        titleLabel.font = .systemFont(ofSize: min(12, 11 * scale))
        iconBackground.layer.cornerRadius = 22 * scale
        iconBackground.snp.updateConstraints { make in
            make.top.equalToSuperview().offset(4 * scale)
            make.size.equalTo(44 * scale)
        }
        iconView.snp.updateConstraints {
            $0.size.equalTo(CGSize(width: panelIconSize.width * scale, height: panelIconSize.height * scale))
        }
        titleLabel.snp.updateConstraints { make in
            make.top.equalTo(iconBackground.snp.bottom).offset(8 * scale)
            make.height.equalTo(28 * scale)
        }
    }

    func setTitle(_ title: String) { titleLabel.text = title }

    func setIcon(assetName: String) { iconView.image = LiveKitResources.image(named: assetName) }

    override func layoutSubviews() {
        super.layoutSubviews()
        selectedGradient.frame = iconBackground.bounds
    }

    private func updateSelection() {
        guard style == .soundOption else { return }
        selectedGradient.isHidden = !isSelected
        iconBackground.backgroundColor = isSelected ? .clear : PusherSettingsSelectionStyle.idleBackground
        iconBackground.layer.borderColor =
            (isSelected ? LiveTheme.Color.brandBlue : PusherSettingsSelectionStyle.idleBorder).cgColor
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
