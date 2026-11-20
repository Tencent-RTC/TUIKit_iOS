import AtomicXCore
import SnapKit
import UIKit

final class VoiceLoungePrepareView: UIView {
    var onExit: (() -> Void)?
    var onStart: ((VoiceLoungeConfig) -> Void)?

    var accessoryView: UIView? {
        didSet {
            guard oldValue !== accessoryView else { return }
            oldValue?.removeFromSuperview()
            infoEditorTopConstraint?.update(
                offset: accessoryView == nil ? PrepareStyle.headerTop : PrepareStyle.accessoryHeaderTop)
            guard let accessoryView else { return }
            insertSubview(accessoryView, belowSubview: themePanel)
            accessoryView.snp.makeConstraints { make in
                make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(4)
                make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(60)
                make.height.equalTo(48)
            }
        }
    }

    var title: String {
        get { infoEditorView.roomName }
        set {
            infoEditorView.setRoomName(newValue)
            input.roomName = infoEditorView.roomName
        }
    }

    private let backgroundView = VoiceLoungeBackgroundView()
    private let backgroundDimView = UIView()
    private let exitButton = UIButton(type: .custom)
    private let infoEditorView = VoiceLoungeInfoEditorView()
    private var infoEditorTopConstraint: Constraint?
    private let heroView = VoiceLoungeHostHeroView()
    private let seatPreviewView = VoiceLoungeSeatPreviewView()
    private let actionsStack = UIStackView()
    private let backgroundAction = PrepareToolButton(
        title: .actionBackground, assetName: "livekit_voiceprepare_background")
    private let moreAction = PrepareToolButton(title: .more, assetName: "livekit_voiceprepare_more")
    private let startButton = StartLiveButton()
    private let themePanel = VoiceLoungeThemeSelectPanel()
    private let morePanel = VoiceLoungePrepareMorePanel()
    private let layoutPanel = VoiceLoungeSeatLayoutPanel()
    private let transcriberPanel = VoiceLoungeAITranscriberPanel()
    private let audioEffectsPanel = VoiceLoungeAudioEffectPanel()
    private let topicPanel = VoiceLoungeTopicPanel()
    private let coverPickerView = PusherCoverPickerView()
    private var captureVolume: Int = 100

    private var input = VoiceLoungeConfig()
    private var hostName = ""
    private var hostAvatarURL = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        render()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isHidden: Bool { didSet { heroView.setActive(!isHidden) } }

    func bind(_ input: VoiceLoungeConfig) {
        self.input = input
        applyDefaultLayout()
        applyPersistedTranscriberDefaults()
        render()
    }

    func updateHost(avatarURL: String, name: String) {
        let previousDefault = VoiceLoungeConfig.defaultRoomName(hostName: hostName)
        if input.roomName.isEmpty || input.roomName == previousDefault { input.roomName = "" }
        hostAvatarURL = avatarURL
        hostName = name
        applyDefaultLayout()
        render()
    }

    private func applyPersistedTranscriberDefaults() {
        guard let defaults = VoiceLoungeTranscriberDefaults.current else { return }
        input.isTranscriberEnabled = defaults.isEnabled
        input.transcriberShowOriginal = defaults.showOriginal
        input.transcriberScale = defaults.scale
        input.transcriberLanguage = defaults.language
    }

    func deactivate() { infoEditorView.endRoomNameEditing() }

    private func setupViews() {
        addSubview(backgroundView)
        addSubview(backgroundDimView)
        addSubview(seatPreviewView)
        addSubview(heroView)
        addSubview(infoEditorView)
        addSubview(exitButton)
        [backgroundAction, moreAction].forEach(actionsStack.addArrangedSubview)
        addSubview(actionsStack)
        addSubview(startButton)
        addSubview(themePanel)
        addSubview(morePanel)
        addSubview(layoutPanel)
        addSubview(transcriberPanel)
        addSubview(audioEffectsPanel)
        addSubview(topicPanel)
        addSubview(coverPickerView)
    }

    private func setupConstraints() {
        backgroundView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        backgroundDimView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        exitButton.snp.makeConstraints { make in
            make.leading.equalTo(safeAreaLayoutGuide.snp.leading).offset(LivePrepareHeaderStyle.closeButtonLeading)
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(LivePrepareHeaderStyle.closeButtonTop)
            make.size.equalTo(LivePrepareHeaderStyle.closeButtonSize)
        }
        infoEditorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            infoEditorTopConstraint =
                make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(PrepareStyle.headerTop).constraint
        }
        applyHeroConstraints(for: input.seatLayout)
        applySeatPreviewConstraints(for: input.seatLayout)
        actionsStack.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(20)
            make.trailing.lessThanOrEqualToSuperview().inset(20)
            make.bottom.equalTo(startButton.snp.top).offset(-41)
        }
        startButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-7)
            make.height.equalTo(52)
        }
        themePanel.snp.makeConstraints { make in make.edges.equalToSuperview() }
        morePanel.snp.makeConstraints { make in make.edges.equalToSuperview() }
        layoutPanel.snp.makeConstraints { make in make.edges.equalToSuperview() }
        transcriberPanel.snp.makeConstraints { make in make.edges.equalToSuperview() }
        audioEffectsPanel.snp.makeConstraints { make in make.edges.equalToSuperview() }
        topicPanel.snp.makeConstraints { make in make.edges.equalToSuperview() }
        coverPickerView.snp.makeConstraints { make in make.edges.equalToSuperview() }
    }

    private func setupStyles() {
        backgroundDimView.backgroundColor = PrepareStyle.backgroundDim
        backgroundDimView.isUserInteractionEnabled = false

        exitButton.setImage(LiveKitResources.image(named: LivePrepareHeaderStyle.closeImageName), for: .normal)
        exitButton.imageView?.contentMode = .scaleAspectFit
        exitButton.backgroundColor = .clear
        exitButton.accessibilityLabel = .close

        actionsStack.axis = .horizontal
        actionsStack.spacing = PrepareStyle.actionSpacing
        actionsStack.alignment = .top
    }

    private func setupBindings() {
        exitButton.addTarget(self, action: #selector(exit), for: .touchUpInside)
        backgroundAction.addTarget(self, action: #selector(showBackground), for: .touchUpInside)
        moreAction.addTarget(self, action: #selector(showMoreSettings), for: .touchUpInside)
        startButton.addTarget(self, action: #selector(start), for: .touchUpInside)

        infoEditorView.onRoomNameChanged = { [weak self] name in self?.input.roomName = name }
        infoEditorView.onChangeCover = { [weak self] in
            guard let self else { return }
            infoEditorView.endRoomNameEditing()
            coverPickerView.bind(selectedURL: input.coverURL)
            coverPickerView.present()
        }
        coverPickerView.onSelect = { [weak self] coverURL in
            guard let self else { return }
            input.coverURL = coverURL
            render()
        }
        infoEditorView.onSelectTopic = { [weak self] in
            guard let self else { return }
            infoEditorView.endRoomNameEditing()
            topicPanel.show(current: input.topic, skin: input.skin)
        }
        topicPanel.onConfirm = { [weak self] topic in
            guard let self else { return }
            input.topic = topic
            render()
        }
        themePanel.onSelect = { [weak self] backgroundID in
            guard let self, let background = VoiceLoungeBackground.background(id: backgroundID) else { return }
            input.background = background
            render()
        }
        themePanel.onSelectSkin = { [weak self] skinID in
            guard let self, let skin = VoiceLoungeSkin.skin(id: skinID) else { return }
            input.skin = skin
            render()
        }
        morePanel.onLayout = { [weak self] in self?.presentLayoutPanel() }
        morePanel.onTranscriber = { [weak self] in self?.presentTranscriberPanel() }
        morePanel.onAudio = { [weak self] in self?.presentAudioPanel() }

        layoutPanel.onConfirm = { [weak self] layout in
            guard let self else { return }
            input.seatLayout = layout
            render()
        }
        transcriberPanel.onStateChanged = { [weak self] state in
            guard let self else { return }
            self.input.isTranscriberEnabled = state.isEnabled
            self.input.transcriberShowOriginal = state.showOriginal
            self.input.transcriberScale = state.scale
            self.input.transcriberLanguage = state.language
            if state.saveAsDefault {
                VoiceLoungeTranscriberDefaults.current = VoiceLoungeTranscriberDefaults(
                    isEnabled: state.isEnabled, showOriginal: state.showOriginal, scale: state.scale,
                    language: state.language)
            }
        }
        audioEffectsPanel.onSetCaptureVolume = { [weak self] volume in self?.captureVolume = volume }
    }

    private func applyDefaultLayout() {
        guard let saved = VoiceLoungeSeatLayout.savedDefault else { return }
        input.seatLayout = saved
    }

    private func applyHeroConstraints(for layout: VoiceLoungeSeatLayout) {
        heroView.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            if layout == .oneV8x {
                make.centerY.equalTo(seatPreviewView)
                make.top.greaterThanOrEqualTo(infoEditorView.snp.bottom).offset(PrepareStyle.heroMinimumGap)
            } else {
                make.top.equalTo(infoEditorView.snp.top).offset(PrepareStyle.heroOffset).priority(.high)
                make.top.greaterThanOrEqualTo(infoEditorView.snp.bottom).offset(PrepareStyle.heroMinimumGap)
            }
        }
    }

    private func applySeatPreviewConstraints(for layout: VoiceLoungeSeatLayout) {
        seatPreviewView.snp.remakeConstraints { make in
            switch layout {
            case .oneV8x:
                make.leading.greaterThanOrEqualTo(heroView.snp.centerX).offset(32)
                make.trailing.equalToSuperview().inset(24)
                make.top.equalTo(infoEditorView.snp.bottom).offset(PrepareStyle.seatPreviewMinimumGap)
                make.bottom.lessThanOrEqualTo(actionsStack.snp.top).offset(-PrepareStyle.seatPreviewMinimumGap)
                    .priority(999)
            case .duo:
                make.centerX.equalToSuperview()
                make.top.equalTo(heroView.snp.bottom).offset(PrepareStyle.seatPreviewGap)
                make.size.equalTo(0)
            default:
                make.centerX.equalToSuperview()
                make.top.equalTo(heroView.snp.bottom).offset(PrepareStyle.seatPreviewGap).priority(.medium)
                make.top.greaterThanOrEqualTo(heroView.snp.bottom).offset(PrepareStyle.seatPreviewMinimumGap)
                make.bottom.lessThanOrEqualTo(actionsStack.snp.top).offset(-PrepareStyle.seatPreviewMinimumGap)
                    .priority(999)
            }
        }
    }

    private func presentLayoutPanel() {
        layoutPanel.show(selected: input.seatLayout, setAsDefault: true, skin: input.skin)
    }

    private func presentTranscriberPanel() {
        let hasDefaults = VoiceLoungeTranscriberDefaults.current != nil
        let state = VoiceLoungeAITranscriberPanel.State(
            isEnabled: input.isTranscriberEnabled, showOriginal: input.transcriberShowOriginal,
            scale: input.transcriberScale, language: input.transcriberLanguage, saveAsDefault: hasDefaults)
        transcriberPanel.show(initial: state, skin: input.skin)
    }

    private func presentAudioPanel() { audioEffectsPanel.show(captureVolume: captureVolume) }

    private func render() {
        backgroundView.show(input.background)
        startButton.applySkin(input.skin)
        startButton.setTitle(.startVoice)
        infoEditorView.bind(input, hostName: hostName)
        heroView.bind(hostName: hostName, avatarURL: hostAvatarURL, skin: input.skin)
        heroView.applyLayout(input.seatLayout)
        seatPreviewView.isHidden = input.seatLayout == .duo
        seatPreviewView.applyLayout(input.seatLayout)
        applyHeroConstraints(for: input.seatLayout)
        applySeatPreviewConstraints(for: input.seatLayout)
        audioEffectsPanel.applySkin(input.skin)
    }
}

extension VoiceLoungePrepareView {
    @objc private func exit() {
        infoEditorView.endRoomNameEditing()
        onExit?()
    }

    @objc private func start() {
        infoEditorView.endRoomNameEditing()
        input.roomName = infoEditorView.roomName
        onStart?(input)
    }

    @objc private func showBackground() {
        infoEditorView.endRoomNameEditing()
        themePanel.bind(selectedID: input.background.id, skinID: input.skin.id)
        themePanel.present()
    }

    @objc private func showMoreSettings() {
        infoEditorView.endRoomNameEditing()
        morePanel.present()
    }
}

private final class PrepareToolButton: UIControl {
    private let iconView = UIImageView()
    private let titleLabel = LiveText.voiceLounge(.control, tone: .secondary, alignment: .center, emphasized: true)

    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.6 : 1 } }

    init(title: String, assetName: String) {
        super.init(frame: .zero)
        iconView.image = LiveKitResources.image(named: assetName)?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = PrepareStyle.actionIconTint
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        addSubview(iconView)

        titleLabel.text = title
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(PrepareStyle.actionIconBox)
            make.width.lessThanOrEqualTo(PrepareStyle.actionLabelMaxWidth)
        }
        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset((PrepareStyle.actionIconBox - PrepareStyle.actionIconSize) / 2)
            make.centerX.equalToSuperview()
            make.size.equalTo(PrepareStyle.actionIconSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(PrepareStyle.actionIconBox + 7)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class StartLiveButton: UIControl {
    private let borderGradientLayer = CAGradientLayer()
    private let innerGradientLayer = CAGradientLayer()
    private let dotView = UIView()
    private let titleLabel = LiveText.voiceLounge(.dialogTitle, alignment: .center)
    private let contentStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        borderGradientLayer.colors = [VoiceLoungeColor.prepareDeep.cgColor, VoiceLoungeColor.prepareMid.cgColor]
        borderGradientLayer.startPoint = CGPoint(x: 0, y: 1)
        borderGradientLayer.endPoint = CGPoint(x: 1, y: 0)

        innerGradientLayer.colors = [
            VoiceLoungeColor.prepareDeep.cgColor, VoiceLoungeColor.prepareMid.cgColor,
            VoiceLoungeColor.prepareLight.cgColor,
        ]
        innerGradientLayer.locations = [0, 0.55, 1]
        innerGradientLayer.startPoint = CGPoint(x: 0, y: 1)
        innerGradientLayer.endPoint = CGPoint(x: 1, y: 0)

        layer.insertSublayer(borderGradientLayer, at: 0)
        layer.insertSublayer(innerGradientLayer, above: borderGradientLayer)
        layer.shadowColor = VoiceLoungeColor.prepareDeep.cgColor
        layer.shadowOpacity = 0.4
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 14
        clipsToBounds = false

        dotView.backgroundColor = .white
        dotView.layer.cornerRadius = 4
        dotView.layer.shadowColor = UIColor.white.cgColor
        dotView.layer.shadowOpacity = 0.85
        dotView.layer.shadowOffset = .zero
        dotView.layer.shadowRadius = 4
        dotView.snp.makeConstraints { $0.size.equalTo(8) }

        contentStack.axis = .horizontal
        contentStack.spacing = 8
        contentStack.alignment = .center
        contentStack.isUserInteractionEnabled = false
        contentStack.addArrangedSubview(dotView)
        contentStack.addArrangedSubview(titleLabel)
        addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().inset(16)
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setTitle(_ title: String) { titleLabel.text = title }

    func applySkin(_ skin: VoiceLoungeSkin) {
        borderGradientLayer.colors = [skin.deep.cgColor, skin.mid.cgColor]
        innerGradientLayer.colors = [skin.deep.cgColor, skin.mid.cgColor, skin.light.cgColor]
        layer.shadowColor = skin.deep.cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = bounds.height / 2
        borderGradientLayer.frame = bounds
        borderGradientLayer.cornerRadius = radius
        innerGradientLayer.frame = bounds.insetBy(dx: 1, dy: 1)
        innerGradientLayer.cornerRadius = max(0, (bounds.height - 2) / 2)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
    }
}

private enum PrepareStyle {
    static let actionSpacing: CGFloat = 30
    static let actionIconBox: CGFloat = 30
    static let actionIconSize: CGFloat = 26
    static let actionLabelMaxWidth: CGFloat = 72
    static let actionIconTint = UIColor.white.withAlphaComponent(0.92)
    static let headerTop: CGFloat = 49
    static let accessoryHeaderTop: CGFloat = 85
    static let heroOffset: CGFloat = 210
    static let heroMinimumGap: CGFloat = 36
    static let seatPreviewGap: CGFloat = 20
    static let seatPreviewMinimumGap: CGFloat = 16
    static let backgroundDim = UIColor(red: 0.051, green: 0.055, blue: 0.078, alpha: 0.42)
}

private extension String {
    static var actionBackground: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.prepare.action_background")
    }
    static var close: String { LiveKitResources.localizedString("tuilivekit.common.close") }
    static var more: String { LiveKitResources.localizedString("tuilivekit.common.more") }
    static var startVoice: String { LiveKitResources.localizedString("tuilivekit.voiceroom.prepare.start_voice") }
}
