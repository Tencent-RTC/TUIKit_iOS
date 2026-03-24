import UIKit
import SnapKit
import Combine
import AtomicXCore

/**
 * Audio effect settings panel component
 *
 * APIs involved:
 * - AudioEffectStore.shared - get the audio effect management singleton
 * - AudioEffectStore.setAudioChangerType(type:) - set the voice changer effect
 * - AudioEffectStore.setAudioReverbType(type:) - set the reverb effect
 * - AudioEffectStore.setVoiceEarMonitorEnable(enable:) - toggle in-ear monitoring
 * - AudioEffectStore.setVoiceEarMonitorVolume(volume:) - set the in-ear monitoring volume
 * - AudioEffectStore.reset() - reset all audio effect settings
 * - AudioEffectStore.state - audio effect state subscription (AudioEffectState)
 *
 * Features:
 * - voice changer selection (horizontally scrollable tags)
 * - reverb selection (horizontally scrollable tags)
 * - in-ear monitoring switch and volume adjustment
 * - one-tap reset
 */
class AudioEffectSettingView: UIView {

    // MARK: - Properties

    private var cancellables = Set<AnyCancellable>()

    /// voice changer configuration list
    private let changerTypes: [(type: AudioChangerType, name: String)] = [
        (.none, "interactive.audioEffect.changer.none".localized),
        (.child, "interactive.audioEffect.changer.child".localized),
        (.littleGirl, "interactive.audioEffect.changer.littleGirl".localized),
        (.man, "interactive.audioEffect.changer.man".localized),
        (.ethereal, "interactive.audioEffect.changer.ethereal".localized),
    ]

    /// reverb configuration list
    private let reverbTypes: [(type: AudioReverbType, name: String)] = [
        (.none, "interactive.audioEffect.reverb.none".localized),
        (.ktv, "interactive.audioEffect.reverb.ktv".localized),
        (.smallRoom, "interactive.audioEffect.reverb.smallRoom".localized),
        (.auditorium, "interactive.audioEffect.reverb.auditorium".localized),
        (.metallic, "interactive.audioEffect.reverb.metallic".localized),
    ]

    private var selectedChangerIndex: Int = 0
    private var selectedReverbIndex: Int = 0

    // MARK: - UI Components

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        return sv
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        return stack
    }()

    /// voice changer selection
    private lazy var changerSection = createTagSection(
        titleKey: "interactive.audioEffect.changer.title",
        tags: changerTypes.map { $0.name },
        selectedIndex: selectedChangerIndex,
        onSelect: { [weak self] index in
            self?.selectedChangerIndex = index
            AudioEffectStore.shared.setAudioChangerType(type: self?.changerTypes[index].type ?? .none)
        }
    )

    /// reverb selection
    private lazy var reverbSection = createTagSection(
        titleKey: "interactive.audioEffect.reverb.title",
        tags: reverbTypes.map { $0.name },
        selectedIndex: selectedReverbIndex,
        onSelect: { [weak self] index in
            self?.selectedReverbIndex = index
            AudioEffectStore.shared.setAudioReverbType(type: self?.reverbTypes[index].type ?? .none)
        }
    )

    /// in-ear monitoring switch
    private let earMonitorSwitch = SettingToggleRow(
        icon: "headphones",
        titleKey: "interactive.audioEffect.earMonitor"
    )

    /// in-ear monitoring volume
    private let earMonitorVolumeRow = AudioSliderRow(
        icon: "speaker.wave.2.fill",
        titleKey: "interactive.audioEffect.earMonitorVolume",
        minValue: 0,
        maxValue: 100
    )

    /// reset button
    private let resetButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("interactive.audioEffect.reset".localized, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15)
        button.tintColor = .systemRed
        return button
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupBindings()
        setupActions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        addSubview(scrollView)
        scrollView.addSubview(stackView)

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView)
        }

        let rows: [UIView] = [
            changerSection,
            createSeparator(),
            reverbSection,
            createSeparator(),
            earMonitorSwitch,
            createSeparator(),
            earMonitorVolumeRow,
            createSeparator(),
            createResetContainer()
        ]

        rows.forEach { stackView.addArrangedSubview($0) }
    }

    private func setupBindings() {
        AudioEffectStore.shared.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateUI(with: state)
            }
            .store(in: &cancellables)
    }

    private func setupActions() {
        // in-ear monitoring switch
        earMonitorSwitch.onToggle = { isOn in
            AudioEffectStore.shared.setVoiceEarMonitorEnable(enable: isOn)
        }

        // in-ear monitoring volume
        earMonitorVolumeRow.onValueChanged = { value in
            AudioEffectStore.shared.setVoiceEarMonitorVolume(volume: Int(value))
        }

        // Reset
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
    }

    // MARK: - State Update

    private func updateUI(with state: AudioEffectState) {
        earMonitorSwitch.setOn(state.isEarMonitorOpened)
        earMonitorVolumeRow.setValue(Float(state.earMonitorVolume))

        // Synchronize the selected states of the voice changer and reverb settings
        if let changerIndex = changerTypes.firstIndex(where: { $0.type == state.audioChangerType }) {
            selectedChangerIndex = changerIndex
            changerSection.updateSelection(changerIndex)
        }
        if let reverbIndex = reverbTypes.firstIndex(where: { $0.type == state.audioReverbType }) {
            selectedReverbIndex = reverbIndex
            reverbSection.updateSelection(reverbIndex)
        }
    }

    // MARK: - Actions

    @objc private func resetTapped() {
        AudioEffectStore.shared.reset()
    }

    // MARK: - Helpers

    private func createSeparator() -> UIView {
        let container = UIView()
        let line = UIView()
        line.backgroundColor = .separator
        container.addSubview(line)
        line.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.top.bottom.equalToSuperview()
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
        return container
    }

    private func createResetContainer() -> UIView {
        let container = UIView()
        container.addSubview(resetButton)
        resetButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.top.equalToSuperview().offset(12)
            make.bottom.equalToSuperview().offset(-12)
        }
        return container
    }

    private func createTagSection(
        titleKey: String,
        tags: [String],
        selectedIndex: Int,
        onSelect: @escaping (Int) -> Void
    ) -> TagSelectionSection {
        return TagSelectionSection(
            titleKey: titleKey,
            tags: tags,
            selectedIndex: selectedIndex,
            onSelect: onSelect
        )
    }
}

// MARK: - TagSelectionSection

/// Tag selection section component - title + horizontally scrollable tag buttons
class TagSelectionSection: UIView {

    private var selectedIndex: Int
    private let onSelect: (Int) -> Void
    private var tagButtons: [UIButton] = []

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        return sv
    }()

    private let tagStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        return stack
    }()

    init(titleKey: String, tags: [String], selectedIndex: Int, onSelect: @escaping (Int) -> Void) {
        self.selectedIndex = selectedIndex
        self.onSelect = onSelect
        super.init(frame: .zero)

        titleLabel.text = titleKey.localized
        setupUI(tags: tags)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI(tags: [String]) {
        addSubview(titleLabel)
        addSubview(scrollView)
        scrollView.addSubview(tagStack)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(12)
        }

        scrollView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-12)
            make.height.equalTo(34)
        }

        tagStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
            make.height.equalTo(scrollView)
        }

        // Create tag buttons
        for (index, tag) in tags.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(tag, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13)
            button.layer.cornerRadius = 15
            button.layer.borderWidth = 1
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
            button.tag = index
            button.addTarget(self, action: #selector(tagTapped(_:)), for: .touchUpInside)

            updateButtonStyle(button, isSelected: index == selectedIndex)
            tagButtons.append(button)
            tagStack.addArrangedSubview(button)
        }
    }

    @objc private func tagTapped(_ sender: UIButton) {
        let index = sender.tag
        selectedIndex = index
        updateAllButtonStyles()
        onSelect(index)
    }

    func updateSelection(_ index: Int) {
        selectedIndex = index
        updateAllButtonStyles()
    }

    private func updateAllButtonStyles() {
        for (i, button) in tagButtons.enumerated() {
            updateButtonStyle(button, isSelected: i == selectedIndex)
        }
    }

    private func updateButtonStyle(_ button: UIButton, isSelected: Bool) {
        if isSelected {
            button.backgroundColor = .systemBlue
            button.setTitleColor(.white, for: .normal)
            button.layer.borderColor = UIColor.systemBlue.cgColor
        } else {
            button.backgroundColor = .clear
            button.setTitleColor(.label, for: .normal)
            button.layer.borderColor = UIColor.separator.cgColor
        }
    }
}

// MARK: - AudioSliderRow

/// Audio slider row component - icon and title on the left, slider and value below
class AudioSliderRow: UIView {

    var onValueChanged: ((Float) -> Void)?

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .label
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        return label
    }()

    private let slider: UISlider = {
        let slider = UISlider()
        slider.tintColor = .systemBlue
        return slider
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()

    init(icon: String, titleKey: String, minValue: Float, maxValue: Float) {
        super.init(frame: .zero)
        iconView.image = UIImage(systemName: icon)
        titleLabel.text = titleKey.localized
        slider.minimumValue = minValue
        slider.maximumValue = maxValue
        setupUI()
        setupActions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(slider)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(14)
            make.width.height.equalTo(24)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(16)
            make.centerY.equalTo(iconView)
        }

        valueLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalTo(iconView)
            make.width.equalTo(36)
        }

        slider.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-14)
        }
    }

    private func setupActions() {
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
    }

    @objc private func sliderChanged() {
        let value = slider.value.rounded()
        valueLabel.text = "\(Int(value))"
        onValueChanged?(value)
    }

    func setValue(_ value: Float) {
        guard slider.value != value else { return }
        slider.value = value
        valueLabel.text = "\(Int(value))"
    }
}
