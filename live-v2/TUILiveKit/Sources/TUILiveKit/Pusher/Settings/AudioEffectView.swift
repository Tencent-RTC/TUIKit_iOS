import AtomicXCore
import Combine
import UIKit
import SnapKit

private enum PusherAudioChangerSetting: Equatable {
    case original
    case child
    case loli
    case uncle
    case spirit
}

private enum PusherAudioReverbSetting: Equatable {
    case none
    case ktv
    case metal
    case deep
    case bright
}

final class AudioEffectView: UIView {
    var onSetCaptureVolume: ((Int) -> Void)?

    private var isActive = false
    private var subscription: AnyCancellable?
    private var subscriptionID: UUID?

    private let earMonitorSwitch = UISwitch()
    private let earMonitorVolume = SettingsVolumeView(title: LiveKitResources.localizedString("tuilivekit.pusher.settings.ear_monitor_volume"))
    private let captureVolume = SettingsVolumeView(title: LiveKitResources.localizedString("tuilivekit.pusher.settings.capture_volume"))
    private let changerSection = SoundOptionSection<PusherAudioChangerSetting>(
        title: LiveKitResources.localizedString("tuilivekit.pusher.settings.voice_changer"),
        options: [
            (.original, "tuilivekit.pusher.settings.voice.original", "livekit_voice_original"),
            (.child, "tuilivekit.pusher.settings.voice.child", "livekit_voice_child"),
            (.loli, "tuilivekit.pusher.settings.voice.loli", "livekit_voice_loli"),
            (.uncle, "tuilivekit.pusher.settings.voice.uncle", "livekit_voice_uncle"),
            (.spirit, "tuilivekit.pusher.settings.voice.spirit", "livekit_voice_spirit"),
        ]
    )
    private let reverbSection = SoundOptionSection<PusherAudioReverbSetting>(
        title: LiveKitResources.localizedString("tuilivekit.pusher.settings.reverb"),
        options: [
            (.none, "tuilivekit.pusher.settings.reverb.none", "livekit_reverb_none"),
            (.ktv, "tuilivekit.pusher.settings.reverb.ktv", "livekit_reverb_ktv"),
            (.metal, "tuilivekit.pusher.settings.reverb.metal", "livekit_reverb_metal"),
            (.deep, "tuilivekit.pusher.settings.reverb.deep", "livekit_reverb_deep"),
            (.bright, "tuilivekit.pusher.settings.reverb.bright", "livekit_reverb_bright"),
        ]
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func resetForNewSession() {
        AudioEffectStore.shared.setVoiceEarMonitorEnable(enable: false)
        AudioEffectStore.shared.setVoiceEarMonitorVolume(volume: 100)
        AudioEffectStore.shared.setAudioChangerType(type: .none)
        AudioEffectStore.shared.setAudioReverbType(type: .none)
    }

    func bindCaptureVolume(_ value: Int) {
        captureVolume.setValue(value)
    }

    func setActive(_ active: Bool) {
        isActive = active
        updateSubscription()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { isActive = false }
        updateSubscription()
    }

    private func updateSubscription() {
        guard isActive, window != nil else {
            subscriptionID = nil
            subscription?.cancel()
            subscription = nil
            return
        }
        guard subscription == nil else { return }
        let id = UUID()
        subscriptionID = id
        subscription = AudioEffectStore.shared.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.subscriptionID == id else { return }
                self.updateAudioEffects()
            }
        updateAudioEffects()
    }

    private func updateAudioEffects() {
        let audioState = AudioEffectStore.shared.state.value
        let changer: PusherAudioChangerSetting
        switch audioState.audioChangerType {
        case .none: changer = .original
        case .child: changer = .child
        case .littleGirl: changer = .loli
        case .man: changer = .uncle
        case .ethereal: changer = .spirit
        default: changer = .original
        }
        let reverb: PusherAudioReverbSetting
        switch audioState.audioReverbType {
        case .none: reverb = .none
        case .ktv: reverb = .ktv
        case .metallic: reverb = .metal
        case .deep: reverb = .deep
        case .loud: reverb = .bright
        default: reverb = .none
        }
        earMonitorSwitch.setOn(audioState.isEarMonitorOpened, animated: false)
        earMonitorVolume.setValue(audioState.earMonitorVolume)
        changerSection.setSelected(changer)
        reverbSection.setSelected(reverb)
    }

    private func configureUI() {
        let earMonitorCard = makeCard()
        addSubview(earMonitorCard)

        let earMonitorTitle = LiveText(.body, text: LiveKitResources.localizedString("tuilivekit.pusher.settings.ear_monitor"), emphasized: true)
        earMonitorCard.addSubview(earMonitorTitle)

        earMonitorSwitch.onTintColor = AudioEffectStyle.earMonitorOn
        earMonitorSwitch.transform = CGAffineTransform(scaleX: 0.81, y: 0.81)
        earMonitorSwitch.addTarget(self, action: #selector(earMonitorChanged), for: .valueChanged)
        earMonitorCard.addSubview(earMonitorSwitch)

        earMonitorCard.addSubview(earMonitorVolume)
        earMonitorVolume.onValueChanged = { [weak self] value in
            guard let self, self.subscription != nil else { return }
            AudioEffectStore.shared.setVoiceEarMonitorVolume(volume: min(100, max(0, value)))
        }

        let sectionTitle = LiveText(.sectionTitle, text: LiveKitResources.localizedString("tuilivekit.pusher.settings.audio"), tone: .tertiary)
        addSubview(sectionTitle)

        let captureCard = makeCard()
        addSubview(captureCard)

        captureCard.addSubview(captureVolume)
        captureVolume.onValueChanged = { [weak self] value in
            self?.onSetCaptureVolume?(value)
        }

        [changerSection, reverbSection].forEach(addSubview)
        changerSection.onSelect = { [weak self] in self?.setAudioChanger($0) }
        reverbSection.onSelect = { [weak self] in self?.setAudioReverb($0) }

        earMonitorCard.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.height.equalTo(96)
        }
        earMonitorTitle.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview()
            make.height.equalTo(48)
        }
        earMonitorSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(10)
            make.centerY.equalTo(earMonitorCard.snp.top).offset(24)
        }
        earMonitorVolume.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(48)
        }
        sectionTitle.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalTo(earMonitorCard.snp.bottom).offset(12)
            make.height.equalTo(15)
        }
        captureCard.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(sectionTitle.snp.bottom).offset(7)
            make.height.equalTo(46)
        }
        captureVolume.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        changerSection.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(188)
            make.height.equalTo(86)
        }
        reverbSection.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(286)
            make.height.equalTo(86)
        }
    }

    private func makeCard() -> UIView {
        let view = UIView()
        view.backgroundColor = PusherSettingsSelectionStyle.idleBackground
        view.layer.cornerRadius = 14
        view.layer.borderWidth = 1
        view.layer.borderColor = PusherSettingsSelectionStyle.idleBorder.cgColor
        return view
    }

    @objc private func earMonitorChanged() {
        guard subscription != nil else { return }
        AudioEffectStore.shared.setVoiceEarMonitorEnable(enable: earMonitorSwitch.isOn)
    }

    private func setAudioChanger(_ changer: PusherAudioChangerSetting) {
        guard subscription != nil else { return }
        let sdkChanger: AudioChangerType
        switch changer {
        case .original: sdkChanger = .none
        case .child: sdkChanger = .child
        case .loli: sdkChanger = .littleGirl
        case .uncle: sdkChanger = .man
        case .spirit: sdkChanger = .ethereal
        }
        AudioEffectStore.shared.setAudioChangerType(type: sdkChanger)
    }

    private func setAudioReverb(_ reverb: PusherAudioReverbSetting) {
        guard subscription != nil else { return }
        let sdkReverb: AudioReverbType
        switch reverb {
        case .none: sdkReverb = .none
        case .ktv: sdkReverb = .ktv
        case .metal: sdkReverb = .metallic
        case .deep: sdkReverb = .deep
        case .bright: sdkReverb = .loud
        }
        AudioEffectStore.shared.setAudioReverbType(type: sdkReverb)
    }
}

private final class SoundOptionSection<Value: Equatable>: UIView {
    var onSelect: ((Value) -> Void)?
    private var options: [(Value, PusherSettingsItemView)] = []

    init(title: String, options: [(Value, String, String)]) {
        super.init(frame: .zero)
        let titleLabel = LiveText(.sectionTitle, text: title, tone: .tertiary)
        let row = UIStackView()
        row.alignment = .top
        row.distribution = .fillEqually
        addSubview(titleLabel)
        addSubview(row)
        options.forEach { value, titleKey, assetName in
            let option = PusherSettingsItemView(
                title: LiveKitResources.localizedString(titleKey),
                assetName: assetName,
                style: .soundOption
            )
            option.addAction(UIAction { [weak self] _ in
                self?.setSelected(value)
                self?.onSelect?(value)
            }, for: .touchUpInside)
            self.options.append((value, option))
            row.addArrangedSubview(option)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.height.equalTo(15)
        }
        row.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(64)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSelected(_ selectedValue: Value) {
        options.forEach { value, view in view.isSelected = value == selectedValue }
    }
}

private final class SettingsVolumeView: UIView {
    var onValueChanged: ((Int) -> Void)?

    private let valueLabel = LiveText(.action, tone: .secondary, alignment: .right)
    private let slider = LiveSlider(range: 0 ... 100)

    init(title: String) {
        super.init(frame: .zero)

        let titleLabel = LiveText(.itemTitle, tone: .secondary)
        titleLabel.text = title
        titleLabel.numberOfLines = 2
        addSubview(titleLabel)

        addSubview(valueLabel)

        slider.onValueChanged = { [weak self] value in self?.valueChanged(Int(value)) }
        addSubview(slider)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(valueLabel.snp.leading).offset(-8)
        }
        valueLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(slider.snp.leading).offset(-10)
            make.width.equalTo(30)
        }
        slider.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(176)
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setValue(_ value: Int) {
        valueLabel.text = String(value)
        slider.value = Float(value)
    }

    private func valueChanged(_ value: Int) {
        valueLabel.text = String(value)
        onValueChanged?(value)
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum AudioEffectStyle {
    static let earMonitorOn: UIColor = UIColor(red: 0.18, green: 0.52, blue: 0.95, alpha: 1)
}
