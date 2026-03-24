import UIKit
import SnapKit
import Combine
import AtomicXCore

/**
 * Beauty settings panel component
 *
 * APIs involved:
 * - BaseBeautyStore.shared - get the beauty management singleton
 * - BaseBeautyStore.setSmoothLevel(smoothLevel:) - set the smoothness level [0-9]
 * - BaseBeautyStore.setWhitenessLevel(whitenessLevel:) - set the whiteness level [0-9]
 * - BaseBeautyStore.setRuddyLevel(ruddyLevel:) - set the ruddy level [0-9]
 * - BaseBeautyStore.reset() - reset all beauty parameters
 * - BaseBeautyStore.state - beauty state subscription (BaseBeautyState)
 *
 * Features:
 * - Three sliders separately control smoothness, whiteness, and ruddy levels
 * - real-time preview of beauty effects
 * - one-tap reset of all beauty parameters
 */
class BeautySettingView: UIView {

    // MARK: - Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI Components

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        return sv
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }()

    /// smoothness slider
    private let smoothRow = BeautySliderRow(
        icon: "face.dashed",
        titleKey: "interactive.beauty.smooth",
        maxValue: 9
    )

    /// whiteness slider
    private let whitenessRow = BeautySliderRow(
        icon: "sun.max.fill",
        titleKey: "interactive.beauty.whiteness",
        maxValue: 9
    )

    /// ruddy slider
    private let ruddyRow = BeautySliderRow(
        icon: "drop.fill",
        titleKey: "interactive.beauty.ruddy",
        maxValue: 9
    )

    /// reset button
    private let resetButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("interactive.beauty.reset".localized, for: .normal)
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
            smoothRow,
            createSeparator(),
            whitenessRow,
            createSeparator(),
            ruddyRow,
            createSeparator(),
            createResetContainer()
        ]

        rows.forEach { stackView.addArrangedSubview($0) }
    }

    private func setupBindings() {
        // Subscribe to beauty state changes
        BaseBeautyStore.shared.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.smoothRow.setValue(state.smoothLevel)
                self?.whitenessRow.setValue(state.whitenessLevel)
                self?.ruddyRow.setValue(state.ruddyLevel)
            }
            .store(in: &cancellables)
    }

    private func setupActions() {
        // smoothness adjustment
        smoothRow.onValueChanged = { value in
            BaseBeautyStore.shared.setSmoothLevel(smoothLevel: value)
        }

        // whiteness adjustment
        whitenessRow.onValueChanged = { value in
            BaseBeautyStore.shared.setWhitenessLevel(whitenessLevel: value)
        }

        // ruddy adjustment
        ruddyRow.onValueChanged = { value in
            BaseBeautyStore.shared.setRuddyLevel(ruddyLevel: value)
        }

        // Reset
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc private func resetTapped() {
        BaseBeautyStore.shared.reset()
    }

    // MARK: - Helpers

    private func createSeparator() -> UIView {
        let container = UIView()
        let line = UIView()
        line.backgroundColor = .separator
        container.addSubview(line)
        line.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(56)
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
}

// MARK: - BeautySliderRow

/// Beauty slider row component - icon and title on the left, slider and value on the right
class BeautySliderRow: UIView {

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
        slider.minimumValue = 0
        slider.tintColor = .systemPink
        return slider
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()

    init(icon: String, titleKey: String, maxValue: Float) {
        super.init(frame: .zero)
        iconView.image = UIImage(systemName: icon)
        titleLabel.text = titleKey.localized
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
            make.width.equalTo(30)
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
        let roundedValue = slider.value.rounded()
        valueLabel.text = "\(Int(roundedValue))"
        onValueChanged?(roundedValue)
    }

    func setValue(_ value: Float) {
        guard slider.value != value else { return }
        slider.value = value
        valueLabel.text = "\(Int(value))"
    }
}
