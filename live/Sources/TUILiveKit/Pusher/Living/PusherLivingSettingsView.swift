import UIKit
import SnapKit

final class PusherLivingSettingsView: PusherMoreSettingsSheet {
    weak var settingsActionHandler: PusherSettingsActionHandling?
    var onToggleMute: (() -> Void)?
    var onPause: (() -> Void)?
    var onShowBeauty: (() -> Void)?
    var onShowComment: (() -> Void)?

    private let muteItem = PusherSettingsItemView(
        title: LiveKitResources.localizedString("tuilivekit.pusher.living.mute"),
        assetName: "livekit_living_setting_mic_on", iconSize: CGSize(width: 44, height: 44))
    private let mirrorItem = PusherSettingsItemView(
        title: LiveKitResources.localizedString("tuilivekit.pusher.mirror"), assetName: "livekit_living_setting_mirror",
        iconSize: CGSize(width: 21, height: 22))
    private var renderedSettings: PusherSettingsState?
    private var pendingDismissAction: (() -> Void)?

    private var mainRows: [(stack: UIStackView, top: CGFloat)] = []
    private var sectionTitles: [(label: LiveText, top: CGFloat)] = []

    override var mainSheetHeight: CGFloat { 385 * panelScale }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    override func updateMainLayout(scale: CGFloat) {
        for row in mainRows {
            row.stack.arrangedSubviews.compactMap { $0 as? PusherSettingsItemView }.forEach {
                $0.updatePanelLayout(scale: scale)
            }
            row.stack.snp.updateConstraints {
                $0.top.equalToSuperview().offset(row.top * scale)
                $0.height.equalTo(84 * scale)
            }
        }
        for title in sectionTitles {
            title.label.snp.updateConstraints { $0.top.equalToSuperview().offset(title.top * scale) }
        }
        mainContentView.snp.updateConstraints { $0.height.equalTo(mainSheetHeight) }
    }

    func bind(_ settings: PusherSettingsState) {
        guard renderedSettings != settings else { return }
        let previous = renderedSettings
        renderedSettings = settings
        if previous?.isMuted != settings.isMuted {
            muteItem.setTitle(
                LiveKitResources.localizedString(
                    settings.isMuted ? "tuilivekit.pusher.living.unmute" : "tuilivekit.pusher.living.mute"))
            muteItem.setIcon(
                assetName: settings.isMuted ? "livekit_living_setting_mic_off" : "livekit_living_setting_mic_on")
        }
        if previous?.isMirrorEnabled != settings.isMirrorEnabled {
            mirrorItem.setIcon(
                assetName: settings.isMirrorEnabled ? "livekit_settings_mirror_on" : "livekit_settings_mirror_off")
        }
        if previous?.captureVolume != settings.captureVolume {
            audioEffectView.bindCaptureVolume(settings.captureVolume)
        }
    }

    func show() {
        showPage(false, animated: false)
        present()
    }

    func cancelPendingAction() { pendingDismissAction = nil }

    private func configureUI() {
        configureMainPage()

        audioEffectView.onSetCaptureVolume = { [weak self] in self?.settingsActionHandler?.setCaptureVolume($0) }

        mainContentView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(mainSheetHeight)
        }
        showPage(false, animated: false)
    }

    private func configureMainPage() {
        let pause = PusherSettingsItemView(
            title: LiveKitResources.localizedString("tuilivekit.pusher.living.pause"),
            assetName: "livekit_living_setting_pause", iconSize: CGSize(width: 17, height: 17))
        installRow([pause, muteItem, UIView(), UIView(), UIView()], top: 30)
        let beauty = PusherSettingsItemView(
            title: LiveKitResources.localizedString("tuilivekit.pusher.beautify"),
            assetName: "livekit_living_setting_beauty", iconSize: CGSize(width: 18.05, height: 16.3))
        let audio = PusherSettingsItemView(
            title: LiveKitResources.localizedString("tuilivekit.pusher.audio_effects"),
            assetName: "livekit_living_setting_audio", iconSize: CGSize(width: 18.1, height: 18.6))
        installSection(
            "tuilivekit.pusher.living.basic_settings", titleTop: 121, rowTop: 148,
            items: [beauty, mirrorItem, audio, UIView(), UIView()])
        let comment = PusherSettingsItemView(
            title: LiveKitResources.localizedString("tuilivekit.pusher.living.comment"),
            assetName: "livekit_living_setting_comment", iconSize: CGSize(width: 19, height: 16))
        installSection(
            "tuilivekit.pusher.living.interaction", titleTop: 239, rowTop: 266,
            items: [comment, UIView(), UIView(), UIView(), UIView()])

        muteItem.addAction(UIAction { [weak self] _ in self?.onToggleMute?() }, for: .touchUpInside)
        pause.addAction(UIAction { [weak self] _ in self?.animateDismiss { self?.onPause?() } }, for: .touchUpInside)
        beauty.addAction(
            UIAction { [weak self] _ in self?.animateDismiss { self?.onShowBeauty?() } }, for: .touchUpInside)
        mirrorItem.addAction(
            UIAction { [weak self] _ in self?.settingsActionHandler?.toggleMirror() }, for: .touchUpInside)
        audio.addAction(UIAction { [weak self] _ in self?.showPage(true, animated: true) }, for: .touchUpInside)
        comment.addAction(
            UIAction { [weak self] _ in self?.animateDismiss { self?.onShowComment?() } }, for: .touchUpInside)

    }

    private func installRow(_ views: [UIView], top: CGFloat) {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        mainContentView.addSubview(stack)
        mainRows.append((stack, top))
        stack.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.top.equalToSuperview().offset(top)
            $0.height.equalTo(84)
        }
    }

    private func installSection(_ titleKey: String, titleTop: CGFloat, rowTop: CGFloat, items: [UIView]) {
        let title = LiveText(.caption, text: LiveKitResources.localizedString(titleKey), tone: .tertiary)
        mainContentView.addSubview(title)
        sectionTitles.append((title, titleTop))
        title.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(20)
            $0.top.equalToSuperview().offset(titleTop)
            $0.height.equalTo(15)
        }
        installRow(items, top: rowTop)
    }

    /// The panel always reopens on its main page. Pending follow-up actions run
    /// after the dismiss animation so the next panel does not overlap this one.
    override func sheetDidDismiss() {
        showPage(false, animated: false)
        let pending = pendingDismissAction
        pendingDismissAction = nil
        pending?()
    }

    private func animateDismiss(completion: (() -> Void)?) {
        pendingDismissAction = completion
        dismiss()
    }
}
