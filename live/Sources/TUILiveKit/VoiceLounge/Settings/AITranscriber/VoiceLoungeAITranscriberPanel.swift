import AtomicXCore
import SnapKit
import UIKit

final class VoiceLoungeAITranscriberPanel: BottomSheetView {
    struct State: Equatable {
        var isEnabled: Bool
        var showOriginal: Bool
        var scale: VoiceLoungeTranscriberScale
        var language: TranslationLanguage
        var saveAsDefault: Bool
    }

    var onStateChanged: ((State) -> Void)?

    private var state: State = State(
        isEnabled: false, showOriginal: false, scale: .standard, language: .english, saveAsDefault: false)
    private var skin: VoiceLoungeSkin = .defaultSkin

    private let card = UIView()
    private let enableRow = SwitchRow()
    private let originalRow = SwitchRow()
    private let scaleRow = SegmentRow()
    private let languageRow = ValueRow()
    private let defaultCheck = DefaultCheckRow()

    private lazy var languagePanel: VoiceLoungeTranscriberLanguagePanel = {
        let panel = VoiceLoungeTranscriberLanguagePanel()
        panel.onSelect = { [weak self] language in
            guard let self else { return }
            self.state.language = language
            self.languageRow.setValue(VoiceLoungeTranscriberPanelCopy.languageDisplayName(language))
            self.emit()
        }
        return panel
    }()

    override var sheetHeight: CGFloat { 440 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupActions()
    }

    func show(initial: State, skin: VoiceLoungeSkin) {
        self.state = initial
        self.skin = skin
        enableRow.setSwitchOn(initial.isEnabled, animated: false)
        enableRow.setTint(skin.mid)
        originalRow.setSwitchOn(initial.showOriginal, animated: false)
        originalRow.setTint(skin.mid)
        scaleRow.applySkin(skin)
        scaleRow.setSelectedIndex(VoiceLoungeTranscriberScale.allCases.firstIndex(of: initial.scale) ?? 1)
        languageRow.setValue(VoiceLoungeTranscriberPanelCopy.languageDisplayName(initial.language))
        defaultCheck.applySkin(skin)
        defaultCheck.setChecked(initial.saveAsDefault)
        updateInteractability()
        present()
    }

    override func dismiss() {
        if languagePanel.isPresented { languagePanel.dismiss() }
        super.dismiss()
    }

    private func setupViews() {
        contentView.addSubview(card)
        card.addSubview(enableRow)
        card.addSubview(originalRow)
        card.addSubview(scaleRow)
        card.addSubview(languageRow)
        contentView.addSubview(defaultCheck)
    }

    private func setupConstraints() {
        card.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(66)
        }
        enableRow.snp.makeConstraints { make in make.leading.trailing.top.equalToSuperview() }
        originalRow.snp.makeConstraints { make in
            make.top.equalTo(enableRow.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }
        scaleRow.snp.makeConstraints { make in
            make.top.equalTo(originalRow.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }
        languageRow.snp.makeConstraints { make in
            make.top.equalTo(scaleRow.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        defaultCheck.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.greaterThanOrEqualTo(card.snp.bottom).offset(10)
            make.bottom.equalTo(contentView.safeAreaLayoutGuide.snp.bottom).inset(SheetBottomStyle.inset)
        }
    }

    private func setupStyles() {
        sheetTitle = LiveKitResources.localizedString("tuilivekit.voiceroom.caption.title")
        card.backgroundColor = VoiceLoungeColor.card
        card.layer.cornerRadius = 16
        enableRow.configure(
            title: LiveKitResources.localizedString("tuilivekit.voiceroom.caption.title"),
            subtitle: LiveKitResources.localizedString("tuilivekit.voiceroom.caption.subtitle"))
        originalRow.configure(
            title: LiveKitResources.localizedString("tuilivekit.voiceroom.caption.show_source"),
            subtitle: LiveKitResources.localizedString("tuilivekit.voiceroom.caption.show_source_subtitle"))
        scaleRow.configure(
            title: LiveKitResources.localizedString("tuilivekit.voiceroom.caption.font_scale"),
            segments: [
                LiveKitResources.localizedString("tuilivekit.voiceroom.caption.font_small"),
                LiveKitResources.localizedString("tuilivekit.voiceroom.caption.font_standard"),
                LiveKitResources.localizedString("tuilivekit.voiceroom.caption.font_large"),
            ])
        languageRow.configure(title: LiveKitResources.localizedString("tuilivekit.voiceroom.caption.target_language"))
    }

    private func setupActions() {
        enableRow.onToggle = { [weak self] on in
            guard let self else { return }
            self.state.isEnabled = on
            self.updateInteractability()
            self.emit()
        }
        originalRow.onToggle = { [weak self] on in
            guard let self else { return }
            self.state.showOriginal = on
            self.emit()
        }
        scaleRow.onSelect = { [weak self] index in
            guard let self else { return }
            if let scale = VoiceLoungeTranscriberScale.allCases[safe: index] {
                self.state.scale = scale
                self.emit()
            }
        }
        languageRow.onTap = { [weak self] in
            guard let self else { return }
            self.languagePanel.show(selected: self.state.language, skin: self.skin)
        }
        defaultCheck.onToggle = { [weak self] checked in
            guard let self else { return }
            self.state.saveAsDefault = checked
            self.emit()
        }
    }

    private func updateInteractability() {
        let alpha: CGFloat = state.isEnabled ? 1 : 0.4
        originalRow.contentAlpha = alpha
        scaleRow.contentAlpha = alpha
        languageRow.contentAlpha = alpha
    }

    private func emit() { onStateChanged?(state) }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window else { return }
        if languagePanel.superview !== window {
            languagePanel.removeFromSuperview()
            window.addSubview(languagePanel)
            languagePanel.snp.remakeConstraints { make in make.edges.equalToSuperview() }
        }
    }
}

private final class SwitchRow: UIView {
    var onToggle: ((Bool) -> Void)?

    private let titleLabel = LiveText.voiceLounge(.itemTitle, tone: .primary, emphasized: true)
    private let subtitleLabel = LiveText.voiceLounge(.caption, tone: .tertiary)
    private let toggle = UISwitch()

    override init(frame: CGRect) {
        super.init(frame: frame)
        subtitleLabel.numberOfLines = 0
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(toggle)
        titleLabel.bumpFont()
        subtitleLabel.bumpFont()
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(12)
            make.trailing.lessThanOrEqualTo(toggle.snp.leading).offset(-10)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.trailing.lessThanOrEqualTo(toggle.snp.leading).offset(-10)
            make.bottom.equalToSuperview().inset(12)
        }
        toggle.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
        toggle.addTarget(self, action: #selector(handleToggle), for: .valueChanged)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }

    func setSwitchOn(_ on: Bool, animated: Bool) { toggle.setOn(on, animated: animated) }

    func setTint(_ color: UIColor) { toggle.onTintColor = color }

    var contentAlpha: CGFloat = 1 {
        didSet {
            titleLabel.alpha = contentAlpha
            subtitleLabel.alpha = contentAlpha
        }
    }

    @objc private func handleToggle() { onToggle?(toggle.isOn) }
}

private final class SegmentRow: UIView {
    var onSelect: ((Int) -> Void)?

    private let titleLabel = LiveText.voiceLounge(.itemTitle, tone: .primary, emphasized: true)
    private let track = UIView()
    private var chips: [UIButton] = []
    private var selectedIndex: Int = -1
    private var skinColor: UIColor = VoiceLoungeSkin.defaultSkin.mid

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(titleLabel)
        addSubview(track)
        titleLabel.bumpFont()
        track.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        track.layer.cornerRadius = 8
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview().offset(14)
            make.bottom.lessThanOrEqualToSuperview().inset(14)
        }
        track.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.height.equalTo(32)
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, segments: [String]) {
        titleLabel.text = title
        chips.forEach { $0.removeFromSuperview() }
        chips = []
        var previous: UIButton?
        for (index, label) in segments.enumerated() {
            let chip = UIButton(type: .custom)
            chip.setTitle(label, for: .normal)
            chip.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .medium)
            chip.setTitleColor(.white, for: .normal)
            chip.layer.cornerRadius = 6
            chip.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
            chip.tag = index
            chip.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
            track.addSubview(chip)
            chip.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview().inset(2)
                if let previous {
                    make.leading.equalTo(previous.snp.trailing).offset(2)
                } else {
                    make.leading.equalToSuperview().offset(2)
                }
                if index == segments.count - 1 { make.trailing.equalToSuperview().inset(2) }
            }
            chips.append(chip)
            previous = chip
        }
    }

    func setSelectedIndex(_ index: Int) {
        guard selectedIndex != index else { return }
        selectedIndex = index
        for (i, chip) in chips.enumerated() {
            let isSelected = i == index
            chip.backgroundColor = isSelected ? skinColor : .clear
            chip.setTitleColor(isSelected ? .white : UIColor.white.withAlphaComponent(0.78), for: .normal)
        }
    }

    func applySkin(_ skin: VoiceLoungeSkin) {
        skinColor = skin.mid
        if selectedIndex >= 0 {
            let i = selectedIndex
            selectedIndex = -1
            setSelectedIndex(i)
        }
    }

    var contentAlpha: CGFloat = 1 {
        didSet {
            titleLabel.alpha = contentAlpha
            track.alpha = contentAlpha
        }
    }

    @objc private func handleTap(_ sender: UIButton) {
        setSelectedIndex(sender.tag)
        onSelect?(sender.tag)
    }
}

private final class ValueRow: UIControl {
    var onTap: (() -> Void)?

    private let titleLabel = LiveText.voiceLounge(.itemTitle, tone: .primary, emphasized: true)
    private let valueLabel = LiveText.voiceLounge(.itemTitle, tone: .secondary)
    private let chevron = UILabel()

    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.7 : 1 } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.isUserInteractionEnabled = false
        valueLabel.isUserInteractionEnabled = false
        titleLabel.bumpFont()
        valueLabel.bumpFont()
        chevron.text = "›"
        chevron.textColor = UIColor.white.withAlphaComponent(0.6)
        chevron.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        chevron.isUserInteractionEnabled = false
        addSubview(titleLabel)
        addSubview(chevron)
        addSubview(valueLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(16)
            make.bottom.equalToSuperview().inset(16)
        }
        chevron.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
        valueLabel.snp.makeConstraints { make in
            make.trailing.equalTo(chevron.snp.leading).offset(-6)
            make.centerY.equalToSuperview()
        }
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String) { titleLabel.text = title }
    func setValue(_ text: String) { valueLabel.text = text }

    var contentAlpha: CGFloat = 1 {
        didSet {
            titleLabel.alpha = contentAlpha
            valueLabel.alpha = contentAlpha
            chevron.alpha = contentAlpha
        }
    }

    @objc private func handleTap() { onTap?() }
}

private final class DefaultCheckRow: UIControl {
    var onToggle: ((Bool) -> Void)?

    private let box = UIView()
    private let check = CAShapeLayer()
    private let label = LiveText.voiceLounge(.caption, tone: .secondary)
    private var skinColor: UIColor = VoiceLoungeSkin.defaultSkin.mid
    private var checked: Bool = false

    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.7 : 1 } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.text = LiveKitResources.localizedString("tuilivekit.voiceroom.caption.default_hint")
        label.bumpFont()
        label.isUserInteractionEnabled = false
        box.isUserInteractionEnabled = false
        box.layer.cornerRadius = 8
        box.layer.borderWidth = 1
        check.fillColor = UIColor.clear.cgColor
        check.strokeColor = UIColor.white.cgColor
        check.lineWidth = 1.5
        check.lineCap = .round
        check.lineJoin = .round
        check.isHidden = true
        box.layer.addSublayer(check)
        addSubview(box)
        addSubview(label)
        box.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.size.equalTo(16)
        }
        label.snp.makeConstraints { make in
            make.leading.equalTo(box.snp.trailing).offset(8)
            make.centerY.equalTo(box)
            make.trailing.equalToSuperview()
        }
        renderBox()
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        check.frame = box.bounds
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 4, y: 8))
        path.addLine(to: CGPoint(x: 7, y: 11))
        path.addLine(to: CGPoint(x: 12, y: 5))
        check.path = path.cgPath
    }

    func applySkin(_ skin: VoiceLoungeSkin) {
        skinColor = skin.mid
        renderBox()
    }

    func setChecked(_ value: Bool) {
        guard checked != value else { return }
        checked = value
        renderBox()
    }

    private func renderBox() {
        box.backgroundColor = checked ? skinColor : .clear
        box.layer.borderColor = (checked ? skinColor : UIColor.white.withAlphaComponent(0.35)).cgColor
        check.isHidden = !checked
    }

    @objc private func handleTap() {
        checked.toggle()
        renderBox()
        onToggle?(checked)
    }
}

final class VoiceLoungeTranscriberLanguagePanel: BottomSheetView {
    var onSelect: ((TranslationLanguage) -> Void)?
    private var selected: TranslationLanguage = .english
    private var skin: VoiceLoungeSkin = .defaultSkin
    private let stack = UIStackView()

    override var sheetHeight: CGFloat {
        66 + CGFloat(VoiceLoungeTranscriberPanelCopy.supportedLanguages.count) * 52 + SheetBottomStyle.inset
            + safeAreaInsets.bottom
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        sheetTitle = LiveKitResources.localizedString("tuilivekit.voiceroom.caption.target_language")
        stack.axis = .vertical
        contentView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().offset(66)
            make.bottom.equalTo(contentView.safeAreaLayoutGuide.snp.bottom).inset(SheetBottomStyle.inset)
        }
        for language in VoiceLoungeTranscriberPanelCopy.supportedLanguages {
            stack.addArrangedSubview(makeRow(language: language))
        }
    }

    func show(selected: TranslationLanguage, skin: VoiceLoungeSkin) {
        self.selected = selected
        self.skin = skin
        refreshSelection()
        present()
    }

    private func makeRow(language: TranslationLanguage) -> UIView {
        let row = UIControl()
        row.tag = VoiceLoungeTranscriberPanelCopy.supportedLanguages.firstIndex(of: language) ?? 0
        row.addTarget(self, action: #selector(handleRow(_:)), for: .touchUpInside)
        let title = LiveText.voiceLounge(.itemTitle, tone: .primary)
        title.text = VoiceLoungeTranscriberPanelCopy.languageDisplayName(language)
        title.isUserInteractionEnabled = false
        let tick = UILabel()
        tick.text = "✓"
        tick.textColor = skin.mid
        tick.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        tick.isHidden = true
        tick.isUserInteractionEnabled = false
        row.addSubview(title)
        row.addSubview(tick)
        title.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        tick.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        row.snp.makeConstraints { make in make.height.equalTo(52) }
        return row
    }

    private func refreshSelection() {
        let selectedIndex = VoiceLoungeTranscriberPanelCopy.supportedLanguages.firstIndex(of: selected) ?? 0
        for (index, row) in stack.arrangedSubviews.enumerated() {
            guard let tick = row.subviews.last as? UILabel else { continue }
            tick.isHidden = index != selectedIndex
            tick.textColor = skin.mid
        }
    }

    @objc private func handleRow(_ sender: UIControl) {
        let language = VoiceLoungeTranscriberPanelCopy.supportedLanguages[sender.tag]
        guard selected != language else {
            dismiss()
            return
        }
        selected = language
        refreshSelection()
        onSelect?(language)
        dismiss()
    }
}

enum VoiceLoungeTranscriberPanelCopy {
    static let supportedLanguages: [TranslationLanguage] = [
        .english, .chinese, .japanese, .korean, .spanish, .french, .german, .russian,
    ]

    static func languageDisplayName(_ language: TranslationLanguage) -> String {
        switch language {
        case .chinese: return LiveKitResources.localizedString("tuilivekit.voiceroom.caption.lang_chinese")
        case .english: return LiveKitResources.localizedString("tuilivekit.voiceroom.caption.lang_english")
        case .japanese: return LiveKitResources.localizedString("tuilivekit.voiceroom.caption.lang_japanese")
        case .korean: return LiveKitResources.localizedString("tuilivekit.voiceroom.caption.lang_korean")
        case .spanish: return LiveKitResources.localizedString("tuilivekit.voiceroom.caption.lang_spanish")
        case .french: return LiveKitResources.localizedString("tuilivekit.voiceroom.caption.lang_french")
        case .german: return LiveKitResources.localizedString("tuilivekit.voiceroom.caption.lang_german")
        case .russian: return LiveKitResources.localizedString("tuilivekit.voiceroom.caption.lang_russian")
        default: return LiveKitResources.localizedString("tuilivekit.voiceroom.caption.lang_english")
        }
    }
}

private extension Array { subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil } }

private extension UILabel { func bumpFont() { font = font.withSize(font.pointSize + 1) } }
