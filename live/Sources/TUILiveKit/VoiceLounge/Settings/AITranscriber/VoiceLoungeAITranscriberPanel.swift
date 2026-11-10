import SnapKit
import UIKit

final class VoiceLoungeAITranscriberPanel: BottomSheetView {
    var onToggle: ((Bool) -> Void)?

    private let card = UIView()
    private let titleLabel = LiveText.voiceLounge(.action, tone: .primary)
    private let subtitleLabel = LiveText.voiceLounge(.caption, tone: .tertiary)
    private let toggleSwitch = UISwitch()
    private var skin = VoiceLoungeSkin.defaultSkin

    override var sheetHeight: CGFloat { 200 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    func show(isOn: Bool, skin: VoiceLoungeSkin) {
        toggleSwitch.isOn = isOn
        self.skin = skin
        toggleSwitch.onTintColor = skin.mid
        present()
    }

    private func setupViews() {
        contentView.addSubview(card)
        card.addSubview(titleLabel)
        card.addSubview(subtitleLabel)
        card.addSubview(toggleSwitch)
    }

    private func setupConstraints() {
        card.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(66)
            make.height.equalTo(80)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualTo(toggleSwitch.snp.leading).offset(-10)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.trailing.lessThanOrEqualTo(toggleSwitch.snp.leading).offset(-10)
        }
        toggleSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
    }

    private func setupStyles() {
        sheetTitle = .title
        card.backgroundColor = VoiceLoungeColor.overlayHair
        card.layer.cornerRadius = 16
        titleLabel.text = .title
        titleLabel.isUserInteractionEnabled = false
        subtitleLabel.text = .subtitle
        subtitleLabel.numberOfLines = 0
        subtitleLabel.isUserInteractionEnabled = false
    }

    private func setupBindings() { toggleSwitch.addTarget(self, action: #selector(handleToggle), for: .valueChanged) }
}

extension VoiceLoungeAITranscriberPanel { @objc private func handleToggle() { onToggle?(toggleSwitch.isOn) } }

private extension String {
    static var subtitle: String { LiveKitResources.localizedString("tuilivekit.voiceroom.caption.subtitle") }
    static var title: String { LiveKitResources.localizedString("tuilivekit.voiceroom.caption.title") }
}
