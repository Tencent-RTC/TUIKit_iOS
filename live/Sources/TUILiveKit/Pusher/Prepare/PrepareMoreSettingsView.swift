import UIKit
import SnapKit

final class PrepareMoreSettingsView: PusherMoreSettingsSheet {
    weak var actionHandler: PusherSettingsActionHandling?

    private let mirrorItem = PusherSettingsItemView(
        title: LiveKitResources.localizedString("tuilivekit.pusher.mirror"), assetName: "livekit_settings_mirror")
    private let audioEffectItem = PusherSettingsItemView(
        title: LiveKitResources.localizedString("tuilivekit.pusher.audio_effects"),
        assetName: "livekit_settings_audio_effect")
    private var settings = PusherSettingsState()

    override var mainSheetHeight: CGFloat { 191 + 84 * (panelScale - 1) }
    override var mainSheetTitle: String? { LiveKitResources.localizedString("tuilivekit.pusher.settings.more") }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    override func updateMainLayout(scale: CGFloat) {
        [mirrorItem, audioEffectItem].forEach { $0.updatePanelLayout(scale: scale) }
        mainContentView.snp.updateConstraints { $0.height.equalTo(84 * scale) }
    }

    func bind(_ settings: PusherSettingsState) {
        self.settings = settings
        mirrorItem.setIcon(
            assetName: settings.isMirrorEnabled ? "livekit_settings_mirror_on" : "livekit_settings_mirror_off")
        audioEffectView.bindCaptureVolume(settings.captureVolume)
    }

    func show() {
        showPage(false, animated: false)
        present()
    }

    /// The panel always reopens on its main page.
    override func sheetDidDismiss() { showPage(false, animated: false) }

    private func configureUI() {

        let mainStack = UIStackView(arrangedSubviews: [mirrorItem, audioEffectItem])
        mainStack.axis = .horizontal
        mainStack.distribution = .fillEqually
        mainContentView.addSubview(mainStack)

        mirrorItem.addTarget(self, action: #selector(toggleMirror), for: .touchUpInside)
        audioEffectItem.addTarget(self, action: #selector(showAudioEffect), for: .touchUpInside)

        audioEffectView.onSetCaptureVolume = { [weak self] volume in self?.actionHandler?.setCaptureVolume(volume) }

        mainContentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(75)
            make.height.equalTo(84)
        }
        mainStack.snp.makeConstraints { make in make.edges.equalToSuperview() }
        showPage(false, animated: false)
    }

    @objc private func toggleMirror() { actionHandler?.toggleMirror() }

    @objc private func showAudioEffect() {
        audioEffectView.bindCaptureVolume(settings.captureVolume)
        showPage(true, animated: true)
    }
}
