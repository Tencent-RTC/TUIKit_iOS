import AtomicXCore
import SnapKit
import UIKit

final class VoiceLoungePrepareView: UIView {
    var onExit: (() -> Void)?
    var onStart: ((VoiceLoungeConfig) -> Void)?

    private let backgroundView = VoiceLoungeBackgroundView()
    private let backgroundDimView = UIView()
    private let exitButton = UIControl()
    private let exitIconView = UIImageView()
    private let infoEditorView = VoiceLoungeInfoEditorView()
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

    func bind(_ input: VoiceLoungeConfig) {
        self.input = input
        applyDefaultLayout()
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

    func deactivate() { infoEditorView.endRoomNameEditing() }

    private func setupViews() {
        addSubview(backgroundView)
        addSubview(backgroundDimView)
        exitButton.addSubview(exitIconView)
        addSubview(exitButton)
        addSubview(infoEditorView)
        [backgroundAction, moreAction].forEach(actionsStack.addArrangedSubview)
        addSubview(actionsStack)
        addSubview(startButton)
        addSubview(themePanel)
        addSubview(morePanel)
        addSubview(layoutPanel)
        addSubview(transcriberPanel)
        addSubview(audioEffectsPanel)
        addSubview(topicPanel)
    }

    private func setupConstraints() {
        backgroundView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        backgroundDimView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        exitButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(9)
            make.size.equalTo(34)
        }
        exitIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(21)
        }
        infoEditorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(exitButton.snp.bottom).offset(42)
            make.bottom.lessThanOrEqualTo(actionsStack.snp.top).offset(-24)
        }
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
    }

    private func setupStyles() {
        backgroundDimView.backgroundColor = PrepareStyle.backgroundDim
        backgroundDimView.isUserInteractionEnabled = false

        exitIconView.image = LiveKitResources.image(named: "livekit_voiceprepare_close")
        exitIconView.contentMode = .scaleAspectFit
        exitIconView.isUserInteractionEnabled = false
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

        layoutPanel.onConfirm = { [weak self] layout, setAsDefault in
            guard let self else { return }
            input.seatLayout = layout
            saveDefaultLayout(setAsDefault ? layout : nil)
            render()
        }
        transcriberPanel.onToggle = { [weak self] isOn in
            guard let self else { return }
            input.isTranscriberEnabled = isOn
        }
        audioEffectsPanel.onSetCaptureVolume = { [weak self] volume in self?.captureVolume = volume }
    }

    var defaultLayoutKey: String? {
        guard let userID = LoginStore.shared.state.value.loginUserInfo?.userID, !userID.isEmpty else { return nil }
        return "TUILiveKit.voiceLounge.defaultLayout.v1.\(LoginStore.shared.sdkAppID).\(userID).voice"
    }

    private func applyDefaultLayout() {
        guard let key = defaultLayoutKey, let raw = UserDefaults.standard.string(forKey: key),
            let saved = VoiceLoungeSeatLayout(rawValue: raw)
        else { return }
        input.seatLayout = saved
    }

    private func saveDefaultLayout(_ layout: VoiceLoungeSeatLayout?) {
        guard let key = defaultLayoutKey else { return }
        if let layout {
            UserDefaults.standard.set(layout.rawValue, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func presentLayoutPanel() {
        layoutPanel.show(selected: input.seatLayout, setAsDefault: true, skin: input.skin)
    }

    private func presentTranscriberPanel() { transcriberPanel.show(isOn: input.isTranscriberEnabled, skin: input.skin) }

    private func presentAudioPanel() { audioEffectsPanel.show(captureVolume: captureVolume) }

    private func render() {
        backgroundView.show(input.background)
        startButton.applySkin(input.skin)
        startButton.setTitle(.startVoice)
        infoEditorView.bind(input, hostName: hostName, avatarURL: hostAvatarURL)
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
    private let iconBackground = UIView()
    private let iconView = UIImageView()
    private let titleLabel = LiveText.voiceLounge(.control, tone: .secondary, alignment: .center, emphasized: true)

    override var isSelected: Bool { didSet { updateSelection() } }

    var selectedBorderColor: UIColor = VoiceLoungeColor.prepareMid { didSet { updateSelection() } }

    init(title: String, assetName: String) {
        super.init(frame: .zero)
        iconBackground.backgroundColor = VoiceLoungeColor.prepareIconBackground
        iconBackground.layer.cornerRadius = 24
        iconBackground.layer.borderWidth = 1
        iconBackground.layer.borderColor = VoiceLoungeColor.prepareIconBorder.cgColor
        iconBackground.isUserInteractionEnabled = false
        addSubview(iconBackground)

        iconView.image = LiveKitResources.image(named: assetName)
        iconView.contentMode = .scaleAspectFit
        iconBackground.addSubview(iconView)

        titleLabel.text = title
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        snp.makeConstraints { $0.width.equalTo(48) }
        iconBackground.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.size.equalTo(48)
        }
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(22)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconBackground.snp.bottom).offset(7)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(15)
            make.bottom.equalToSuperview()
        }
        updateSelection()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func updateSelection() {
        iconBackground.layer.borderColor =
            (isSelected ? selectedBorderColor : VoiceLoungeColor.prepareIconBorder).cgColor
        titleLabel.tone = isSelected ? .primary : .secondary
    }
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
