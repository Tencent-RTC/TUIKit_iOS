import AtomicXCore
import Combine
import SnapKit
import TXLiteAVSDK_Professional
import UIKit

@MainActor final class VoiceLoungeVoiceTuner {
    static let shared = VoiceLoungeVoiceTuner()

    private(set) var isCustom = false
    private(set) var customPoint = CGPoint.zero
    private var lastPitch: Double?
    private var lastFormant: Double?

    private init() {}

    func applyCustom(_ point: CGPoint) {
        isCustom = true
        customPoint = point
        send(pitch: Double(point.x), formant: -Double(point.y), force: false)
    }

    func clearCustom() {
        guard isCustom || lastPitch != nil || lastFormant != nil else { return }
        isCustom = false
        send(pitch: 0, formant: 0, force: false)
    }

    func reapply() {
        let point = isCustom ? customPoint : .zero
        send(pitch: Double(point.x), formant: -Double(point.y), force: true)
    }

    func reset() {
        isCustom = false
        customPoint = .zero
        send(pitch: 0, formant: 0, force: true)
        lastPitch = nil
        lastFormant = nil
    }

    private func send(pitch: Double, formant: Double, force: Bool) {
        let pitch = Self.normalize(pitch)
        let formant = Self.normalize(formant)
        if force || lastPitch != pitch {
            lastPitch = pitch
            TRTCCloud.sharedInstance().getAudioEffectManager().setVoicePitch(pitch)
        }
        if force || lastFormant != formant {
            lastFormant = formant
            Self.setFormant(formant)
        }
    }

    private static func normalize(_ value: Double) -> Double { (min(1, max(-1, value)) * 100).rounded() / 100 }

    private static func setFormant(_ value: Double) {
        let payload: [String: Any] = ["api": "setAudioFormant", "params": ["formantRatio": value]]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
            let json = String(data: data, encoding: .utf8)
        else { return }
        TRTCCloud.sharedInstance().callExperimentalAPI(json)
    }
}

final class VoiceLoungeAudioEffectView: UIView {
    var onSetCaptureVolume: ((Int) -> Void)?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let earMonitorSwitch = UISwitch()
    private let earMonitorVolumeRow = EffectVolumeRow(title: .earMonitorVolume)
    private let voiceVolumeRow = EffectVolumeRow(title: .voiceVolume)
    private let reverbStrip = EffectCardStrip(options: EffectOption<AudioReverbType>.reverbs)
    private let voiceStrip = EffectCardStrip(options: EffectOption<VoiceChoice>.voices)
    private let formantPad = FormantPadView()

    private var isActive = false
    private var subscription: AnyCancellable?
    private let tuner = VoiceLoungeVoiceTuner.shared

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupBindings()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bindCaptureVolume(_ value: Int) { voiceVolumeRow.setValue(value) }

    func setActive(_ active: Bool) {
        isActive = active
        updateSubscription()
        if active { scrollView.setContentOffset(.zero, animated: false) }
    }

    func applySkin(_ skin: VoiceLoungeSkin) {
        earMonitorSwitch.onTintColor = skin.mid
        [earMonitorVolumeRow, voiceVolumeRow].forEach { $0.applySkin(skin) }
        reverbStrip.applySkin(skin)
        voiceStrip.applySkin(skin)
        formantPad.applySkin(skin)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { isActive = false }
        updateSubscription()
    }

    private func updateSubscription() {
        guard isActive, window != nil else {
            subscription?.cancel()
            subscription = nil
            return
        }
        guard subscription == nil else { return }
        subscription = AudioEffectStore.shared.state.subscribe().receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.render()
        }
        render()
    }

    private func render() {
        let state = AudioEffectStore.shared.state.value
        earMonitorSwitch.setOn(state.isEarMonitorOpened, animated: false)
        earMonitorVolumeRow.setValue(state.earMonitorVolume)
        reverbStrip.setSelected(state.audioReverbType)
        let voice = tuner.isCustom ? VoiceChoice.custom : VoiceChoice.preset(state.audioChangerType)
        voiceStrip.setSelected(voice)
        formantPad.place(voice.formantPoint(custom: tuner.customPoint), isIdle: voice == .preset(.none), animated: true)
    }

    private func setupViews() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        addSubview(scrollView)
        contentStack.axis = .vertical
        scrollView.addSubview(contentStack)

        let card = makeSettingsCard()
        let reverbTitle = makeSectionTitle(.reverb)
        let voiceTitle = makeSectionTitle(.voiceChanger)
        let hintLabel = UILabel()
        hintLabel.text = .formantHint
        hintLabel.font = .systemFont(ofSize: VoiceLoungeFont.size(11))
        hintLabel.textColor = EffectStyle.ink3
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0
        let cardItem = Self.inset(card)
        let padItem = Self.inset(formantPad)
        let items = [
            cardItem, Self.inset(reverbTitle), reverbStrip, Self.inset(voiceTitle), voiceStrip, padItem,
            Self.inset(hintLabel),
        ]
        items.forEach(contentStack.addArrangedSubview)
        contentStack.setCustomSpacing(12, after: cardItem)
        contentStack.setCustomSpacing(4, after: reverbStrip)
        contentStack.setCustomSpacing(4, after: voiceStrip)
        contentStack.setCustomSpacing(6, after: padItem)

        scrollView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        contentStack.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.bottom.equalToSuperview().inset(12)
            make.leading.trailing.equalTo(self)
        }
        reverbStrip.contentInsetX = EffectStyle.horizontalInset
        voiceStrip.contentInsetX = EffectStyle.horizontalInset
        [reverbStrip, voiceStrip].forEach { strip in
            strip.snp.makeConstraints { make in make.height.equalTo(EffectStyle.cardSize + 8) }
        }
        formantPad.snp.makeConstraints { make in make.height.equalTo(150) }
        [reverbTitle, voiceTitle].forEach { $0.snp.makeConstraints { make in make.height.equalTo(22) } }
    }

    private static func inset(_ view: UIView) -> UIView {
        let container = UIView()
        container.addSubview(view)
        view.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(EffectStyle.horizontalInset)
        }
        return container
    }

    private func makeSettingsCard() -> UIView {
        let card = UIView()
        card.backgroundColor = EffectStyle.cardBackground
        card.layer.cornerRadius = 12
        card.layer.borderWidth = 1
        card.layer.borderColor = EffectStyle.line.cgColor

        let earMonitorRow = UIView()
        let earMonitorLabel = EffectVolumeRow.makeLabel(.earMonitor)
        earMonitorSwitch.transform = CGAffineTransform(scaleX: 0.78, y: 0.78)
        earMonitorRow.addSubview(earMonitorLabel)
        earMonitorRow.addSubview(earMonitorSwitch)
        earMonitorLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        earMonitorSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(5)
            make.centerY.equalToSuperview()
        }

        let rows = [earMonitorRow, earMonitorVolumeRow, voiceVolumeRow]
        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        card.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 2, left: 12, bottom: 2, right: 12))
        }
        rows.enumerated().forEach { index, row in
            row.snp.makeConstraints { make in make.height.equalTo(EffectStyle.rowHeight) }
            guard index > 0 else { return }
            let separator = UIView()
            separator.backgroundColor = EffectStyle.line
            row.addSubview(separator)
            separator.snp.makeConstraints { make in
                make.leading.trailing.top.equalToSuperview()
                make.height.equalTo(1)
            }
        }
        return card
    }

    private func makeSectionTitle(_ text: String) -> UIView {
        let container = UIView()
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: VoiceLoungeFont.size(11))
        label.textColor = EffectStyle.ink3
        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(2)
            make.bottom.equalToSuperview().inset(5)
        }
        return container
    }

    private func setupBindings() {
        earMonitorSwitch.addTarget(self, action: #selector(earMonitorChanged), for: .valueChanged)
        earMonitorVolumeRow.onValueChanged = { [weak self] value in
            guard self?.subscription != nil else { return }
            AudioEffectStore.shared.setVoiceEarMonitorVolume(volume: min(100, max(0, value)))
        }
        voiceVolumeRow.onValueChanged = { [weak self] value in self?.onSetCaptureVolume?(value) }
        reverbStrip.onSelect = { [weak self] reverb in
            guard self?.subscription != nil else { return }
            AudioEffectStore.shared.setAudioReverbType(type: reverb)
        }
        voiceStrip.onSelect = { [weak self] voice in self?.selectVoice(voice) }
        formantPad.onDrag = { [weak self] point in self?.dragFormant(to: point) }
        formantPad.onReset = { [weak self] in self?.selectVoice(.preset(.none)) }
    }

    private func selectVoice(_ voice: VoiceChoice) {
        guard subscription != nil else { return }
        switch voice {
        case .preset(let type):
            tuner.clearCustom()
            AudioEffectStore.shared.setAudioChangerType(type: type)
        case .custom:
            AudioEffectStore.shared.setAudioChangerType(type: .none)
            tuner.applyCustom(tuner.customPoint)
        }
        render()
    }

    private func dragFormant(to point: CGPoint) {
        guard subscription != nil else { return }
        if !tuner.isCustom {
            AudioEffectStore.shared.setAudioChangerType(type: .none)
            voiceStrip.setSelected(VoiceChoice.custom)
        }
        tuner.applyCustom(point)
        formantPad.place(point, isIdle: false, animated: false)
    }
}

extension VoiceLoungeAudioEffectView {
    @objc private func earMonitorChanged() {
        guard subscription != nil else { return }
        AudioEffectStore.shared.setVoiceEarMonitorEnable(enable: earMonitorSwitch.isOn)
    }
}

private enum VoiceChoice: Equatable {
    case preset(AudioChangerType)
    case custom

    func formantPoint(custom: CGPoint) -> CGPoint {
        switch self {
        case .custom: return custom
        case .preset(let type):
            switch type {
            case .child: return CGPoint(x: 0.55, y: 0.35)
            case .littleGirl: return CGPoint(x: 0.75, y: 0.65)
            case .man: return CGPoint(x: -0.55, y: -0.5)
            case .ethereal: return CGPoint(x: 0.25, y: 0.8)
            default: return .zero
            }
        }
    }
}

private struct EffectOption<Value> {
    let value: Value
    let titleKey: String
    let imageName: String

    var title: String { LiveKitResources.localizedString(titleKey) }
}

extension EffectOption where Value == AudioReverbType {
    static var reverbs: [EffectOption<AudioReverbType>] {
        [
            EffectOption(value: .none, titleKey: "tuilivekit.pusher.settings.reverb.none", imageName: "r_none"),
            EffectOption(value: .ktv, titleKey: "tuilivekit.pusher.settings.reverb.ktv", imageName: "r_ktv"),
            EffectOption(value: .metallic, titleKey: "tuilivekit.pusher.settings.reverb.metal", imageName: "r_metal"),
            EffectOption(value: .deep, titleKey: "tuilivekit.pusher.settings.reverb.deep", imageName: "r_deep"),
            EffectOption(value: .loud, titleKey: "tuilivekit.pusher.settings.reverb.bright", imageName: "r_loud"),
        ]
    }
}

extension EffectOption where Value == VoiceChoice {
    static var voices: [EffectOption<VoiceChoice>] {
        [
            EffectOption(
                value: .preset(.none), titleKey: "tuilivekit.pusher.settings.voice.original", imageName: "v_none"),
            EffectOption(value: .custom, titleKey: "tuilivekit.voiceroom.audio.voice_custom", imageName: "v_custom"),
            EffectOption(
                value: .preset(.child), titleKey: "tuilivekit.pusher.settings.voice.child", imageName: "v_kid"),
            EffectOption(
                value: .preset(.littleGirl), titleKey: "tuilivekit.pusher.settings.voice.loli", imageName: "v_loli"),
            EffectOption(
                value: .preset(.man), titleKey: "tuilivekit.pusher.settings.voice.uncle", imageName: "v_uncle"),
            EffectOption(
                value: .preset(.ethereal), titleKey: "tuilivekit.pusher.settings.voice.spirit", imageName: "v_ethereal"),
        ]
    }
}

private final class EffectCardStrip<Value: Equatable>: UIView {
    var onSelect: ((Value) -> Void)?

    var contentInsetX: CGFloat = 0 {
        didSet { stack.snp.updateConstraints { make in make.leading.trailing.equalToSuperview().inset(contentInsetX) } }
    }

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var cards: [(Value, EffectCard)] = []

    init(options: [EffectOption<Value>]) {
        super.init(frame: .zero)
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.clipsToBounds = false
        clipsToBounds = true
        addSubview(scrollView)
        stack.axis = .horizontal
        stack.spacing = 7
        scrollView.addSubview(stack)
        scrollView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        stack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(3)
            make.leading.trailing.equalToSuperview().inset(0)
            make.bottom.equalToSuperview()
        }
        cards = options.map { option in
            let card = EffectCard(title: option.title, imageName: option.imageName)
            card.addAction(
                UIAction { [weak self] _ in
                    self?.setSelected(option.value)
                    self?.onSelect?(option.value)
                }, for: .touchUpInside)
            stack.addArrangedSubview(card)
            return (option.value, card)
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSelected(_ value: Value) { cards.forEach { $0.1.isSelected = $0.0 == value } }

    func applySkin(_ skin: VoiceLoungeSkin) { cards.forEach { $0.1.applySkin(skin) } }
}

private final class EffectCard: UIControl {
    private let imageView = UIImageView()
    private let labelBackground = CAGradientLayer()
    private let titleLabel = UILabel()
    private let checkView = UIImageView()
    private let clipView = UIView()
    private var skin = VoiceLoungeSkin.defaultSkin

    override var isSelected: Bool { didSet { updateSelection() } }
    override var isHighlighted: Bool {
        didSet { transform = isHighlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity }
    }

    init(title: String, imageName: String) {
        super.init(frame: .zero)
        clipView.layer.cornerRadius = 10
        clipView.clipsToBounds = true
        clipView.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        clipView.isUserInteractionEnabled = false
        addSubview(clipView)

        imageView.image = LiveKitResources.image(named: "livekit_voicefx_\(imageName)")
        imageView.contentMode = .scaleAspectFill
        clipView.addSubview(imageView)

        labelBackground.colors = [
            UIColor.black.withAlphaComponent(0).cgColor, UIColor.black.withAlphaComponent(0.55).cgColor,
            UIColor.black.withAlphaComponent(0.88).cgColor,
        ]
        labelBackground.locations = [0, 0.45, 1]
        clipView.layer.addSublayer(labelBackground)

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: VoiceLoungeFont.size(10), weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOpacity = 0.8
        titleLabel.layer.shadowRadius = 1.5
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        clipView.addSubview(titleLabel)

        checkView.image = Self.checkImage
        checkView.isHidden = true
        checkView.isUserInteractionEnabled = false
        addSubview(checkView)

        layer.cornerRadius = 10
        layer.shadowOffset = .zero
        layer.shadowRadius = 7
        accessibilityLabel = title
        accessibilityTraits = .button

        snp.makeConstraints { make in make.size.equalTo(EffectStyle.cardSize) }
        clipView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        imageView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(2)
            make.bottom.equalToSuperview().inset(4)
        }
        checkView.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(4)
            make.size.equalTo(12)
        }
        updateSelection()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func applySkin(_ skin: VoiceLoungeSkin) {
        self.skin = skin
        updateSelection()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let labelHeight: CGFloat = 26
        labelBackground.frame = CGRect(x: 0, y: bounds.height - labelHeight, width: bounds.width, height: labelHeight)
    }

    private func updateSelection() {
        layer.borderWidth = isSelected ? 2 : 1
        layer.borderColor = (isSelected ? skin.mid : UIColor.white.withAlphaComponent(0.08)).cgColor
        layer.shadowColor = skin.mid.cgColor
        layer.shadowOpacity = isSelected ? 0.55 : 0
        checkView.isHidden = !isSelected
        checkView.backgroundColor = skin.mid
        checkView.layer.cornerRadius = 6
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }

    private static let checkImage: UIImage = {
        UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { _ in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 3.7, y: 6))
            path.addLine(to: CGPoint(x: 5.3, y: 7.7))
            path.addLine(to: CGPoint(x: 8.3, y: 4.3))
            path.lineWidth = 1.2
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            UIColor.white.setStroke()
            path.stroke()
        }
    }()
}

private final class FormantPadView: UIView {
    var onDrag: ((CGPoint) -> Void)?
    var onReset: (() -> Void)?

    private static let edgeRatio: CGFloat = 0.08
    private let dotsLayer = CAShapeLayer()
    private let horizontalAxis = UIView()
    private let verticalAxis = UIView()
    private let glowLayer = CAGradientLayer()
    private let knobView = UIView()
    private let knobGradient = CAGradientLayer()
    private let readoutView = UIView()
    private let pitchValueLabel = UILabel()
    private let formantValueLabel = UILabel()
    private var point = CGPoint.zero
    private var isIdle = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.25)
        layer.cornerRadius = 14
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        clipsToBounds = true

        dotsLayer.fillColor = UIColor.white.withAlphaComponent(0.18).cgColor
        layer.addSublayer(dotsLayer)
        [horizontalAxis, verticalAxis].forEach { axis in
            axis.backgroundColor = UIColor.white.withAlphaComponent(0.12)
            axis.isUserInteractionEnabled = false
            addSubview(axis)
        }
        addTag(.padLow) { make in
            make.leading.equalToSuperview().offset(8)
            make.bottom.equalTo(self.snp.centerY).offset(-4)
        }
        addTag(.padHigh) { make in
            make.trailing.equalToSuperview().inset(8)
            make.bottom.equalTo(self.snp.centerY).offset(-4)
        }
        addTag(.padBright) { make in
            make.leading.equalTo(self.snp.centerX).offset(6)
            make.top.equalToSuperview().offset(6)
        }
        addTag(.padThick) { make in
            make.leading.equalTo(self.snp.centerX).offset(6)
            make.bottom.equalToSuperview().inset(6)
        }

        glowLayer.type = .radial
        glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowLayer.endPoint = CGPoint(x: 1, y: 1)
        glowLayer.locations = [0, 0.65]
        glowLayer.bounds = CGRect(x: 0, y: 0, width: 120, height: 120)
        layer.addSublayer(glowLayer)

        knobView.bounds = CGRect(x: 0, y: 0, width: 26, height: 26)
        knobView.layer.cornerRadius = 13
        knobView.layer.borderWidth = 4
        knobView.layer.shadowColor = UIColor.black.cgColor
        knobView.layer.shadowOpacity = 0.4
        knobView.layer.shadowOffset = CGSize(width: 0, height: 4)
        knobView.layer.shadowRadius = 5
        knobGradient.type = .radial
        knobGradient.startPoint = CGPoint(x: 0.35, y: 0.3)
        knobGradient.endPoint = CGPoint(x: 1.2, y: 1.2)
        knobGradient.frame = CGRect(x: 4, y: 4, width: 18, height: 18)
        knobGradient.cornerRadius = 9
        knobView.layer.addSublayer(knobGradient)
        addSubview(knobView)

        setupReadout()
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
        tap.require(toFail: doubleTap)
        applySkin(.defaultSkin)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func applySkin(_ skin: VoiceLoungeSkin) {
        glowLayer.colors = [skin.mid.withAlphaComponent(0.28).cgColor, skin.mid.withAlphaComponent(0).cgColor]
        [pitchValueLabel, formantValueLabel].forEach { $0.textColor = skin.textStrong }
        tintSkin = skin
        updateKnobStyle()
    }

    func place(_ point: CGPoint, isIdle: Bool, animated: Bool) {
        self.point = point
        self.isIdle = isIdle
        pitchValueLabel.text = Self.format(point.x)
        formantValueLabel.text = Self.format(point.y)
        updateKnobStyle()
        let apply = { self.layoutKnob() }
        if animated, window != nil { UIView.animate(withDuration: 0.25, animations: apply) } else { apply() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        horizontalAxis.frame = CGRect(x: 20, y: bounds.midY, width: bounds.width - 40, height: 1)
        verticalAxis.frame = CGRect(x: bounds.midX, y: 16, width: 1, height: bounds.height - 32)
        dotsLayer.frame = bounds
        dotsLayer.path = dotsPath().cgPath
        layoutKnob()
    }

    private var tintSkin = VoiceLoungeSkin.defaultSkin

    private func updateKnobStyle() {
        let colors = isIdle ? PadStyle.idleKnob : [PadStyle.activeKnobHighlight, tintSkin.mid.blendedForKnob]
        knobGradient.colors = colors.map(\.cgColor)
        let ring = isIdle ? UIColor.white.withAlphaComponent(0.08) : tintSkin.mid.withAlphaComponent(0.25)
        knobView.layer.borderColor = ring.cgColor
        glowLayer.opacity = isIdle ? 0 : 1
    }

    private func layoutKnob() {
        let center = position(for: point)
        knobView.center = center
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glowLayer.position = center
        CATransaction.commit()
    }

    private func position(for point: CGPoint) -> CGPoint {
        let span = 1 - Self.edgeRatio * 2
        let x = (Self.edgeRatio + (point.x + 1) / 2 * span) * bounds.width
        let y = (Self.edgeRatio + (1 - point.y) / 2 * span) * bounds.height
        return CGPoint(x: x, y: y)
    }

    private func value(at location: CGPoint) -> CGPoint {
        guard bounds.width > 0, bounds.height > 0 else { return .zero }
        let span = 1 - Self.edgeRatio * 2
        var x = ((location.x / bounds.width) - Self.edgeRatio) / span * 2 - 1
        var y = 1 - ((location.y / bounds.height) - Self.edgeRatio) / span * 2
        x = min(1, max(-1, x))
        y = min(1, max(-1, y))
        if abs(x) < 0.06 { x = 0 }
        if abs(y) < 0.06 { y = 0 }
        return CGPoint(x: x, y: y)
    }

    private func dotsPath() -> UIBezierPath {
        let path = UIBezierPath()
        let rect = bounds.insetBy(dx: 20, dy: 16)
        guard rect.width > 0, rect.height > 0 else { return path }
        for column in 0...4 {
            for row in 0...2 {
                let center = CGPoint(
                    x: rect.minX + rect.width * CGFloat(column) / 4, y: rect.minY + rect.height * CGFloat(row) / 2)
                path.append(UIBezierPath(ovalIn: CGRect(x: center.x - 1.2, y: center.y - 1.2, width: 2.4, height: 2.4)))
            }
        }
        return path
    }

    private func setupReadout() {
        readoutView.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        readoutView.layer.cornerRadius = 8
        readoutView.isUserInteractionEnabled = false
        addSubview(readoutView)
        let pitchTitle = Self.makeReadoutLabel(.pitch)
        let formantTitle = Self.makeReadoutLabel(.formant)
        [pitchValueLabel, formantValueLabel].forEach { label in
            label.font = .monospacedDigitSystemFont(ofSize: VoiceLoungeFont.size(10.5), weight: .semibold)
            label.text = Self.format(0)
        }
        [pitchTitle, pitchValueLabel, formantTitle, formantValueLabel].forEach(readoutView.addSubview)
        readoutView.snp.makeConstraints { make in make.top.trailing.equalToSuperview().inset(8) }
        pitchTitle.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.top.equalToSuperview().offset(4)
        }
        formantTitle.snp.makeConstraints { make in
            make.leading.equalTo(pitchTitle)
            make.top.equalTo(pitchTitle.snp.bottom).offset(1)
            make.bottom.equalToSuperview().inset(4)
        }
        pitchValueLabel.snp.makeConstraints { make in
            make.firstBaseline.equalTo(pitchTitle)
            make.leading.greaterThanOrEqualTo(pitchTitle.snp.trailing).offset(4)
            make.leading.greaterThanOrEqualTo(formantTitle.snp.trailing).offset(4)
            make.trailing.equalToSuperview().inset(8)
        }
        formantValueLabel.snp.makeConstraints { make in
            make.firstBaseline.equalTo(formantTitle)
            make.leading.equalTo(pitchValueLabel)
            make.trailing.equalToSuperview().inset(8)
        }
    }

    private func addTag(_ text: String, constraints: (ConstraintMaker) -> Void) {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: VoiceLoungeFont.size(10))
        label.textColor = UIColor.white.withAlphaComponent(0.4)
        label.isUserInteractionEnabled = false
        addSubview(label)
        label.snp.makeConstraints(constraints)
    }

    private static func makeReadoutLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: VoiceLoungeFont.size(10.5))
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        return label
    }

    private static func format(_ value: CGFloat) -> String {
        (value > 0 ? "+" : "") + String(format: "%.2f", Double(value))
    }
}

extension FormantPadView {
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .began || gesture.state == .changed else { return }
        onDrag?(value(at: gesture.location(in: self)))
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) { onDrag?(value(at: gesture.location(in: self))) }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard knobView.frame.insetBy(dx: -10, dy: -10).contains(gesture.location(in: self)) else {
            onDrag?(value(at: gesture.location(in: self)))
            return
        }
        onReset?()
    }
}

private final class EffectVolumeRow: UIView {
    var onValueChanged: ((Int) -> Void)?

    private let valueLabel = UILabel()
    private let slider = LiveSlider(range: 0...100)

    init(title: String) {
        super.init(frame: .zero)
        let titleLabel = Self.makeLabel(title)
        valueLabel.font = .monospacedDigitSystemFont(ofSize: VoiceLoungeFont.size(12), weight: .regular)
        valueLabel.textColor = EffectStyle.ink2
        valueLabel.textAlignment = .right
        slider.onValueChanged = { [weak self] value in
            self?.valueLabel.text = String(Int(value))
            self?.onValueChanged?(Int(value))
        }
        [titleLabel, valueLabel, slider].forEach(addSubview)
        titleLabel.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(valueLabel.snp.leading).offset(-10)
        }
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        slider.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.width.equalTo(EffectStyle.sliderWidth).priority(.high)
        }
        valueLabel.snp.makeConstraints { make in
            make.trailing.equalTo(slider.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
            make.width.equalTo(30)
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func makeLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: VoiceLoungeFont.size(12.5))
        label.textColor = .white
        return label
    }

    func setValue(_ value: Int) {
        UIView.performWithoutAnimation {
            valueLabel.text = String(value)
            slider.setValue(Float(value), animated: false)
            layoutIfNeeded()
        }
    }

    func applySkin(_ skin: VoiceLoungeSkin) { slider.minimumTrackTintColor = skin.mid }
}

private extension UIColor {
    var blendedForKnob: UIColor {
        var (red, green, blue, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return UIColor(red: red * 0.8 + 0.2, green: green * 0.8 + 0.2, blue: blue * 0.8 + 0.2, alpha: 1)
    }
}

private enum PadStyle {
    static let idleKnob = [
        UIColor(red: 0.914, green: 0.925, blue: 0.949, alpha: 1),
        UIColor(red: 0.604, green: 0.631, blue: 0.682, alpha: 1),
    ]
    static let activeKnobHighlight = UIColor(red: 0.835, green: 0.894, blue: 1, alpha: 1)
}

private enum EffectStyle {
    static let horizontalInset: CGFloat = 16
    static let rowHeight: CGFloat = 44
    static let cardSize: CGFloat = 56
    static let sliderWidth: CGFloat = 180
    static let cardBackground = UIColor(red: 22 / 255, green: 23 / 255, blue: 31 / 255, alpha: 1)
    static let line = UIColor.white.withAlphaComponent(0.08)
    static let ink2 = UIColor.white.withAlphaComponent(0.72)
    static let ink3 = UIColor.white.withAlphaComponent(0.45)
}

private extension String {
    static var earMonitor: String { LiveKitResources.localizedString("tuilivekit.pusher.settings.ear_monitor") }
    static var earMonitorVolume: String {
        LiveKitResources.localizedString("tuilivekit.pusher.settings.ear_monitor_volume")
    }
    static var voiceVolume: String { LiveKitResources.localizedString("tuilivekit.voiceroom.audio.voice_volume") }
    static var reverb: String { LiveKitResources.localizedString("tuilivekit.pusher.settings.reverb") }
    static var voiceChanger: String { LiveKitResources.localizedString("tuilivekit.pusher.settings.voice_changer") }
    static var formantHint: String { LiveKitResources.localizedString("tuilivekit.voiceroom.audio.formant_hint") }
    static var pitch: String { LiveKitResources.localizedString("tuilivekit.voiceroom.audio.pitch") }
    static var formant: String { LiveKitResources.localizedString("tuilivekit.voiceroom.audio.formant") }
    static var padLow: String { LiveKitResources.localizedString("tuilivekit.voiceroom.audio.pad_low") }
    static var padHigh: String { LiveKitResources.localizedString("tuilivekit.voiceroom.audio.pad_high") }
    static var padBright: String { LiveKitResources.localizedString("tuilivekit.voiceroom.audio.pad_bright") }
    static var padThick: String { LiveKitResources.localizedString("tuilivekit.voiceroom.audio.pad_thick") }
}
