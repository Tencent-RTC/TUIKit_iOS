import AtomicXCore
import SnapKit
import UIKit

/// User preferences are independent of SDK state and shared by both camera entry points.
struct BeautyPreferences: Codable {
    var isEnabled = true
    var smoothLevel: Float = 0
    var whitenessLevel: Float = 0
    var ruddyLevel: Float = 0

    static var currentKey: String? {
        guard let userID = LoginStore.shared.state.value.loginUserInfo?.userID,
              !userID.isEmpty else { return nil }
        return "TUILiveKit.beauty.v1.\(LoginStore.shared.sdkAppID).\(userID)"
    }

    static func load(for key: String?) -> BeautyPreferences {
        guard let key, let data = UserDefaults.standard.data(forKey: key),
              var settings = try? JSONDecoder().decode(Self.self, from: data) else {
            return Self()
        }
        settings.smoothLevel = validated(settings.smoothLevel)
        settings.whitenessLevel = validated(settings.whitenessLevel)
        settings.ruddyLevel = validated(settings.ruddyLevel)
        return settings
    }

    func save(for key: String?) {
        guard let key, let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func restore() {
        load(for: currentKey).apply()
    }

    func apply() {
        BaseBeautyStore.shared.setSmoothLevel(smoothLevel: isEnabled ? smoothLevel : 0)
        BaseBeautyStore.shared.setWhitenessLevel(whitenessLevel: isEnabled ? whitenessLevel : 0)
        BaseBeautyStore.shared.setRuddyLevel(ruddyLevel: isEnabled ? ruddyLevel : 0)
    }

    private static func validated(_ value: Float) -> Float {
        value.isFinite ? min(9, max(0, value)) : 0
    }
}

/// Shared beauty sheet. SDK readback never overwrites the user's saved choices.
final class BeautyPanel: BottomSheetView {
    private enum Kind: CaseIterable {
        case smooth
        case whiteness
        case ruddy

        var title: String {
            switch self {
            case .smooth: return LiveKitResources.localizedString("tuilivekit.pusher.beauty.smooth")
            case .whiteness: return LiveKitResources.localizedString("tuilivekit.pusher.beauty.whiteness")
            case .ruddy: return LiveKitResources.localizedString("tuilivekit.pusher.beauty.ruddy")
            }
        }

        var assetName: String {
            switch self {
            case .smooth: return "livekit_beauty_smooth"
            case .whiteness: return "livekit_beauty_whiteness"
            case .ruddy: return "livekit_beauty_ruddy"
            }
        }
    }

    private let beautySwitch = UISwitch()
    private let typeLabel = LiveText(.caption, tone: .secondary)
    private let valueLabel = LiveText(.caption, alignment: .right, emphasized: true)
    private let slider = LiveSlider(range: 0 ... 9)
    private var buttons: [(Kind, BeautyOptionControl)] = []
    private var selectedKind: Kind = .smooth
    private var settings = BeautyPreferences()
    private var preferencesKey: String?
    private var isActive = false

    override var sheetHeight: CGFloat { 220 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        sheetTitle = LiveKitResources.localizedString("tuilivekit.pusher.beauty")
        configureUI()
        updateEnabledAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sheetWillPresent() {
        preferencesKey = BeautyPreferences.currentKey
        settings = BeautyPreferences.load(for: preferencesKey)
        settings.apply()
        select(.smooth)
        updateEnabledAppearance()
        isActive = true
    }

    override func sheetWillDismiss() {
        isActive = false
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { isActive = false }
    }

    private var canEdit: Bool {
        isActive && window != nil && preferencesKey == BeautyPreferences.currentKey
    }

    private func setEnabled(_ enabled: Bool) {
        guard canEdit, settings.isEnabled != enabled else { return }
        settings.isEnabled = enabled
        settings.save(for: preferencesKey)
        settings.apply()
        updateEnabledAppearance()
    }

    private func updateEnabledAppearance() {
        beautySwitch.setOn(settings.isEnabled, animated: false)
        slider.isEnabled = settings.isEnabled
        slider.alpha = settings.isEnabled ? 1 : 0.4
        updateSlider()
    }

    private func configureUI() {
        let controls = UIView()
        contentView.addSubview(controls)
        controls.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.equalToSuperview().offset(68)
            make.height.equalTo(112)
        }
        controls.addSubview(typeLabel)

        controls.addSubview(valueLabel)

        slider.onValueChanged = { [weak self] value in self?.setBeautyLevel(value) }
        controls.addSubview(slider)

        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        controls.addSubview(row)

        let switchItem = UIView()
        row.addArrangedSubview(switchItem)
        let switchTitle = LiveText(.control, text: LiveKitResources.localizedString("tuilivekit.pusher.beauty"), tone: .secondary, alignment: .center)
        switchItem.addSubview(switchTitle)
        beautySwitch.onTintColor = UIColor(red: 0.18, green: 0.52, blue: 0.95, alpha: 1)
        beautySwitch.transform = CGAffineTransform(scaleX: 0.81, y: 0.81)
        beautySwitch.accessibilityLabel = switchTitle.text
        beautySwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.setEnabled(self.beautySwitch.isOn)
        }, for: .valueChanged)
        switchItem.addSubview(beautySwitch)
        beautySwitch.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(switchItem.snp.top).offset(26)
        }
        switchTitle.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(56)
            make.height.equalTo(14)
        }

        Kind.allCases.forEach { kind in
            let button = BeautyOptionControl(
                title: kind.title,
                assetName: kind.assetName
            )
            button.addAction(UIAction { [weak self] _ in self?.select(kind) }, for: .touchUpInside)
            buttons.append((kind, button))
            row.addArrangedSubview(button)
        }

        typeLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4)
            make.top.equalToSuperview()
            make.width.greaterThanOrEqualTo(34)
            make.height.equalTo(32)
        }
        slider.snp.makeConstraints { make in
            make.leading.equalTo(typeLabel.snp.trailing).offset(8)
            make.trailing.equalTo(valueLabel.snp.leading).offset(-8)
            make.centerY.equalTo(typeLabel)
        }
        valueLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-4)
            make.centerY.equalTo(typeLabel)
            make.width.equalTo(22)
        }
        row.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(40)
            make.height.equalTo(73)
        }
        select(.smooth)
    }

    private func select(_ kind: Kind) {
        selectedKind = kind
        buttons.forEach { value, button in
            button.isSelected = value == kind
        }
        updateSlider()
    }

    private func updateSlider() {
        switch selectedKind {
        case .smooth:
            configureSlider(title: Kind.smooth.title, value: settings.smoothLevel)
        case .whiteness:
            configureSlider(title: Kind.whiteness.title, value: settings.whitenessLevel)
        case .ruddy:
            configureSlider(title: Kind.ruddy.title, value: settings.ruddyLevel)
        }
    }

    private func configureSlider(title: String, value: Float) {
        typeLabel.text = title
        slider.isHidden = false
        slider.value = value
        valueLabel.text = String(Int(value.rounded()))
    }

    private func setBeautyLevel(_ value: Float) {
        guard canEdit, settings.isEnabled, value.isFinite else { return }
        let value = min(9, max(0, value))
        switch selectedKind {
        case .smooth: settings.smoothLevel = value
        case .whiteness: settings.whitenessLevel = value
        case .ruddy: settings.ruddyLevel = value
        }
        settings.save(for: preferencesKey)
        settings.apply()
        updateSlider()
    }
}

private final class BeautyOptionControl: UIControl {
    private let iconBackground = UIView()
    private let iconView = UIImageView()
    private let titleLabel = LiveText(.control, tone: .secondary, alignment: .center)

    override var isSelected: Bool {
        didSet { updateAppearance() }
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.iconBackground.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.94, y: 0.94)
                    : .identity
            }
        }
    }

    init(title: String, assetName: String) {
        super.init(frame: .zero)

        accessibilityLabel = title

        iconBackground.layer.cornerRadius = BeautyStyle.iconRadius
        iconBackground.layer.borderWidth = 1
        iconBackground.isUserInteractionEnabled = false
        addSubview(iconBackground)

        iconView.image = LiveKitResources.image(named: assetName)?.withRenderingMode(.alwaysTemplate)
        iconView.contentMode = .scaleAspectFit
        iconBackground.addSubview(iconView)

        titleLabel.text = title
        addSubview(titleLabel)

        iconBackground.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.centerX.equalToSuperview()
            make.size.equalTo(44)
        }
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(24)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(56)
            make.height.equalTo(14)
        }

        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateAppearance() {
        iconBackground.backgroundColor = isSelected
            ? BeautyStyle.selectedFill
            : BeautyStyle.idleFill
        iconBackground.layer.borderColor = (isSelected
            ? BeautyStyle.accent
            : BeautyStyle.idleBorder).cgColor
        iconView.tintColor = isSelected ? .white : BeautyStyle.idleForeground
        titleLabel.tone = isSelected ? .primary : .secondary
    }
}

private enum BeautyStyle {
    static let selectedFill: UIColor = UIColor(red: 0.18, green: 0.48, blue: 0.92, alpha: 0.32)
    static let accent: UIColor = UIColor(red: 0.31, green: 0.64, blue: 1, alpha: 1)
    static let idleFill: UIColor = UIColor.white.withAlphaComponent(0.08)
    static let idleBorder: UIColor = UIColor.white.withAlphaComponent(0.12)
    static let idleForeground: UIColor = UIColor.white.withAlphaComponent(0.82)
}

// Styles owned by this component or feature. Values preserve the existing design.
extension BeautyStyle {
    static let iconRadius: CGFloat = 22
}
