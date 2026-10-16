import UIKit
import SnapKit

final class PusherLivingSettingsView: BottomSheetView {
    weak var settingsActionHandler: PusherSettingsActionHandling?
    var onToggleMute: (() -> Void)?
    var onPause: (() -> Void)?
    var onShowBeauty: (() -> Void)?
    var onShowComment: (() -> Void)?
    var onShowBackgroundMusic: (() -> Void)?
    var onFlipCamera: (() -> Void)?

    private enum Page {
        case main
        case audioEffect

        var title: String? {
            switch self {
            case .main: return nil
            case .audioEffect: return LiveKitResources.localizedString("tuilivekit.pusher.audio_effects")
            }
        }

        var height: CGFloat {
            switch self {
            case .main: return 385
            case .audioEffect: return 466
            }
        }
    }

    private let mainContentView = UIView()
    private let audioEffectView = AudioEffectView()
    private let muteItem = PusherSettingsItemView(title: LiveKitResources.localizedString("tuilivekit.pusher.living.mute"), assetName: "livekit_living_setting_mic_on", iconSize: CGSize(width: 44, height: 44))
    private let mirrorItem = PusherSettingsItemView(title: LiveKitResources.localizedString("tuilivekit.pusher.mirror"), assetName: "livekit_living_setting_mirror", iconSize: CGSize(width: 21, height: 22))
    private var renderedSettings: PusherSettingsState?
    private var page: Page = .main
    private var pendingDismissAction: (() -> Void)?

    override var sheetHeight: CGFloat { page.height }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    func bind(_ settings: PusherSettingsState) {
        guard renderedSettings != settings else { return }
        let previous = renderedSettings
        renderedSettings = settings
        if previous?.isMuted != settings.isMuted {
            muteItem.setTitle(LiveKitResources.localizedString(
                settings.isMuted ? "tuilivekit.pusher.living.unmute" : "tuilivekit.pusher.living.mute"
            ))
            muteItem.setIcon(assetName: settings.isMuted ? "livekit_living_setting_mic_off" : "livekit_living_setting_mic_on")
        }
        if previous?.isMirrorEnabled != settings.isMirrorEnabled {
            mirrorItem.setIcon(assetName: settings.isMirrorEnabled ? "livekit_settings_mirror_on" : "livekit_settings_mirror_off")
        }
        if previous?.captureVolume != settings.captureVolume {
            audioEffectView.bindCaptureVolume(settings.captureVolume)
        }
    }

    func show() {
        showPage(.main, animated: false)
        present()
    }

    func cancelPendingAction() {
        pendingDismissAction = nil
    }

    override func sheetWillPresent() {
        audioEffectView.setActive(page == .audioEffect)
    }

    override func sheetWillDismiss() {
        audioEffectView.setActive(false)
    }

    private func configureUI() {
        contentView.addSubview(mainContentView)
        configureMainPage()

        audioEffectView.onSetCaptureVolume = { [weak self] in self?.settingsActionHandler?.setCaptureVolume($0) }
        contentView.addSubview(audioEffectView)

        mainContentView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(Page.main.height)
        }
        audioEffectView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(60)
            make.height.equalTo(372)
        }
        showPage(.main, animated: false)
    }

    private func configureMainPage() {
        let pause = PusherSettingsItemView(title: LiveKitResources.localizedString("tuilivekit.pusher.living.pause"), assetName: "livekit_living_setting_pause", iconSize: CGSize(width: 17, height: 17))
        installRow([pause, muteItem, UIView(), UIView(), UIView()], top: 30)
        let beauty = PusherSettingsItemView(title: LiveKitResources.localizedString("tuilivekit.pusher.beautify"), assetName: "livekit_living_setting_beauty", iconSize: CGSize(width: 18.05, height: 16.3))
        let flip = PusherSettingsItemView(title: LiveKitResources.localizedString("tuilivekit.pusher.flip_camera"), assetName: "livekit_living_setting_flip", iconSize: CGSize(width: 21, height: 18.5))
        let audio = PusherSettingsItemView(title: LiveKitResources.localizedString("tuilivekit.pusher.audio_effects"), assetName: "livekit_living_setting_audio", iconSize: CGSize(width: 18.1, height: 18.6))
        installSection("tuilivekit.pusher.living.basic_settings", titleTop: 121, rowTop: 148, items: [beauty, mirrorItem, flip, audio, UIView()])
        let music = PusherSettingsItemView(title: LiveKitResources.localizedString("tuilivekit.pusher.living.music"), assetName: "livekit_living_setting_music", iconSize: CGSize(width: 14.93, height: 17.63))
        let comment = PusherSettingsItemView(title: LiveKitResources.localizedString("tuilivekit.pusher.living.comment"), assetName: "livekit_living_setting_comment", iconSize: CGSize(width: 19, height: 16))
        installSection("tuilivekit.pusher.living.interaction", titleTop: 239, rowTop: 266, items: [music, comment, UIView(), UIView(), UIView()])

        muteItem.addAction(UIAction { [weak self] _ in self?.onToggleMute?() }, for: .touchUpInside)
        pause.addAction(UIAction { [weak self] _ in
            self?.animateDismiss { self?.onPause?() }
        }, for: .touchUpInside)
        beauty.addAction(UIAction { [weak self] _ in
            self?.animateDismiss { self?.onShowBeauty?() }
        }, for: .touchUpInside)
        mirrorItem.addAction(UIAction { [weak self] _ in self?.settingsActionHandler?.toggleMirror() }, for: .touchUpInside)
        flip.addAction(UIAction { [weak self] _ in self?.onFlipCamera?() }, for: .touchUpInside)
        audio.addAction(UIAction { [weak self] _ in self?.showPage(.audioEffect, animated: true) }, for: .touchUpInside)
        comment.addAction(UIAction { [weak self] _ in
            self?.animateDismiss { self?.onShowComment?() }
        }, for: .touchUpInside)
        music.addAction(UIAction { [weak self] _ in
            self?.animateDismiss { self?.onShowBackgroundMusic?() }
        }, for: .touchUpInside)

    }

    private func showPage(_ page: Page, animated: Bool) {
        self.page = page
        sheetTitle = page.title
        mainContentView.isHidden = page != .main
        audioEffectView.isHidden = page != .audioEffect
        audioEffectView.setActive(page == .audioEffect && !isHidden)
        updateSheetHeight(animated: animated)
    }

    private func installRow(_ views: [UIView], top: CGFloat) {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        mainContentView.addSubview(stack)
        stack.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.top.equalToSuperview().offset(top)
            $0.height.equalTo(84)
        }
    }

    private func installSection(_ titleKey: String, titleTop: CGFloat, rowTop: CGFloat, items: [UIView]) {
        let title = LiveText(.caption, text: LiveKitResources.localizedString(titleKey), tone: .tertiary)
        mainContentView.addSubview(title)
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
        showPage(.main, animated: false)
        let pending = pendingDismissAction
        pendingDismissAction = nil
        pending?()
    }

    private func animateDismiss(completion: (() -> Void)?) {
        pendingDismissAction = completion
        dismiss()
    }
}
