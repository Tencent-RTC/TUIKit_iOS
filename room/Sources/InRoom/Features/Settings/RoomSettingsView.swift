import UIKit
import SnapKit
import Combine
import AtomicXCore

public final class RoomSettingsView: UIView {
    public enum Mode {
        case `default`
    }

    public weak var routerContext: RouterContext?

    private let mode: Mode
    private var cancellableSet = Set<AnyCancellable>()

    private let navBar = UIView()
    private let navBarContent = UIView()
    private let navBackButton = UIButton(type: .custom)
    private let navBackIcon = UIImageView()
    private let navTitleLabel = UILabel()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let videoGroupLabel = UILabel()
    private let videoSection = RoomSettingsSection()
    private let mirrorRow = RoomSettingsRow(style: .toggle)
    private let resolutionRow = RoomSettingsRow(style: .navigation)
    private let generalGroupLabel = UILabel()
    private let generalSection = RoomSettingsSection()

    private static let pushDuration: TimeInterval = 0.25

    public init(mode: Mode) {
        self.mode = mode
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    public convenience init() {
        self.init(mode: .default)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyTheme()
            refreshValues()
        }
    }

    private func setupViews() {
        videoSection.addRow(mirrorRow)
        videoSection.addRow(resolutionRow)
        generalGroupLabel.isHidden = true
        generalSection.isHidden = true

        [videoGroupLabel, videoSection, generalGroupLabel, generalSection].forEach { contentView.addSubview($0) }
        scrollView.addSubview(contentView)
        addSubview(scrollView)
        addSubview(navBar)
        navBar.addSubview(navBarContent)
        navBackButton.addSubview(navBackIcon)
        navBarContent.addSubview(navBackButton)
        navBarContent.addSubview(navTitleLabel)
        navBackButton.addTarget(self, action: #selector(handleNavBarBack), for: .touchUpInside)
        navBackButton.addTarget(self, action: #selector(handleNavBarBackHighlight), for: [.touchDown, .touchDragEnter])
        navBackButton.addTarget(self, action: #selector(handleNavBarBackUnhighlight),
                                for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }

    private func setupConstraints() {
        navBar.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(safeAreaLayoutGuide.snp.top).offset(52)
        }
        navBarContent.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(52)
        }
        navBackButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(8)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(40)
        }
        navBackIcon.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(22)
        }
        navTitleLabel.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.greaterThanOrEqualToSuperview().offset(72)
            $0.trailing.lessThanOrEqualToSuperview().offset(-72)
        }
        scrollView.snp.makeConstraints {
            $0.top.equalTo(navBar.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(safeAreaLayoutGuide)
        }
        contentView.snp.makeConstraints {
            $0.edges.equalTo(scrollView.contentLayoutGuide)
            $0.width.equalTo(scrollView.frameLayoutGuide)
        }

        videoGroupLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(16)
            $0.leading.trailing.equalToSuperview().inset(32)
        }
        videoSection.snp.makeConstraints {
            $0.top.equalTo(videoGroupLabel.snp.bottom).offset(8)
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.bottom.equalToSuperview().offset(-16)
        }
        generalGroupLabel.snp.makeConstraints {
            $0.top.equalTo(videoSection.snp.bottom).offset(20)
            $0.leading.trailing.equalToSuperview().inset(32)
        }
        generalSection.snp.makeConstraints {
            $0.top.equalTo(generalGroupLabel.snp.bottom).offset(8)
            $0.leading.trailing.equalToSuperview().inset(16)
        }
    }

    private func setupStyles() {
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        for label in [videoGroupLabel, generalGroupLabel] {
            label.font = .systemFont(ofSize: 11, weight: .medium)
        }

        applyTexts()
        applyTheme()
    }

    private func setupBindings() {
        mirrorRow.onToggle = { isOn in
            DeviceStore.shared.switchMirror(mirrorType: isOn ? .enable : .disable)
        }
        resolutionRow.onTap = { [weak self] in
            self?.pushOptions(.resolution)
        }

        DeviceStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \DeviceState.localVideoQuality))
            .receive(on: RunLoop.main)
            .sink { [weak self] quality in
                self?.resolutionRow.value = quality.displayName
            }
            .store(in: &cancellableSet)

        Publishers.CombineLatest(
            DeviceStore.shared.state.subscribe(StatePublisherSelector(keyPath: \DeviceState.isFrontCamera)),
            DeviceStore.shared.state.subscribe(StatePublisherSelector(keyPath: \DeviceState.localMirrorType))
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] isFrontCamera, mirrorType in
            self?.applyMirror(isFrontCamera: isFrontCamera, mirrorType: mirrorType)
        }
        .store(in: &cancellableSet)

        NotificationCenter.default.addObserver(self, selector: #selector(handleLanguageChanged),
                                               name: RoomKitResources.languageDidChangeNotification, object: nil)
    }

    private func applyTheme() {
        backgroundColor = UIColor.roomKitBgCanvas
        for label in [videoGroupLabel, generalGroupLabel] {
            label.textColor = UIColor.roomKitFgTertiary
        }
    }

    private func applyTexts() {

        navBar.backgroundColor = UIColor.roomKitBgSurface
        navBackButton.layer.cornerRadius = 20
        navBackIcon.isUserInteractionEnabled = false
        navBackIcon.image = RoomKitResources.image(named: "roomkit_icon_back")
        navBackButton.accessibilityLabel = RoomKitResources.localizedString("roomkit.common.back")
        navTitleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        navTitleLabel.textAlignment = .center
        navTitleLabel.textColor = UIColor.roomKitFgPrimary
        navTitleLabel.text = .settingsTitle
        videoGroupLabel.text = .settingsGroupVideo
        generalGroupLabel.text = .settingsGroupGeneral
        mirrorRow.title = .settingsMirror
        mirrorRow.desc = .settingsMirrorDesc
        resolutionRow.title = .settingsResolution
        refreshValues()
    }

    private func refreshValues() {
        resolutionRow.value = DeviceStore.shared.state.value.localVideoQuality.displayName
    }

    private func applyMirror(isFrontCamera: Bool, mirrorType: MirrorType) {
        mirrorRow.isToggleEnabled = isFrontCamera
        mirrorRow.isOn = isFrontCamera && mirrorType != .disable
    }

    private var optionsView: RoomSettingsOptionsView?

    private func pushOptions(_ mode: RoomSettingsOptionsView.Mode) {
        guard optionsView == nil else { return }
        let options = RoomSettingsOptionsView(mode: mode)
        options.onBack = { [weak self] in self?.popOptions() }
        addSubview(options)
        options.snp.makeConstraints { $0.edges.equalToSuperview() }
        layoutIfNeeded()
        optionsView = options

        options.transform = CGAffineTransform(translationX: bounds.width, y: 0)
        UIView.animate(withDuration: Self.pushDuration, delay: 0, options: [.curveEaseOut]) {
            options.transform = .identity
        }
    }

    private func popOptions() {
        guard let options = optionsView else { return }
        optionsView = nil
        UIView.animate(withDuration: Self.pushDuration, delay: 0, options: [.curveEaseIn], animations: {
            options.transform = CGAffineTransform(translationX: self.bounds.width, y: 0)
        }, completion: { _ in
            options.removeFromSuperview()
        })
    }
}

extension RoomSettingsView {

    @objc private func handleLanguageChanged() {
        applyTexts()
    }
}

final class RoomSettingsRow: UIControl {

    enum Style {
        case toggle
        case navigation
        case option
    }

    var onToggle: ((Bool) -> Void)?
    var onTap: (() -> Void)?

    var title: String? {
        didSet { titleLabel.attributedText = attributedText(title, fontSize: 15, color: UIColor.roomKitFgPrimary) }
    }

    var desc: String? {
        didSet {
            descLabel.attributedText = attributedText(desc, fontSize: 11, color: UIColor.roomKitFgTertiary)
            descLabel.isHidden = desc?.isEmpty ?? true
        }
    }

    var value: String? {
        didSet { valueLabel.text = value }
    }

    var isOn: Bool {
        get { toggle.isOn }
        set { toggle.isOn = newValue }
    }

    var isChecked = false {
        didSet { checkIcon.isHidden = !isChecked }
    }

    var isToggleEnabled = true {
        didSet {
            toggle.isEnabled = isToggleEnabled
            alpha = isToggleEnabled ? 1 : 0.45
        }
    }

    var showsSeparator = false {
        didSet { separator.isHidden = !showsSeparator }
    }

    override var isHighlighted: Bool {
        didSet { applyBackground() }
    }

    private let style: Style

    private let contentStack = UIStackView()
    private let textStack = UIStackView()
    private let titleLabel = UILabel()
    private let descLabel = UILabel()
    private let valueLabel = UILabel()
    private let arrowIcon = UIImageView()
    private let checkIcon = UIImageView()
    private let toggle = UISwitch()
    private let separator = UIView()

    init(style: Style) {
        self.style = style
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyTheme()
        }
    }

    private func setupViews() {
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(descLabel)
        contentStack.addArrangedSubview(textStack)
        switch style {
        case .toggle:
            contentStack.addArrangedSubview(toggle)
        case .navigation:
            contentStack.addArrangedSubview(valueLabel)
            contentStack.addArrangedSubview(arrowIcon)
        case .option:
            contentStack.addArrangedSubview(checkIcon)
        }
        addSubview(contentStack)
        addSubview(separator)
    }

    private func setupConstraints() {
        snp.makeConstraints { $0.height.greaterThanOrEqualTo(56) }
        contentStack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16))
        }
        separator.snp.makeConstraints {
            $0.top.trailing.equalToSuperview()
            $0.leading.equalToSuperview().offset(16)
            $0.height.equalTo(0.5)
        }
        switch style {
        case .toggle:
            break
        case .navigation:
            arrowIcon.snp.makeConstraints { $0.size.equalTo(16) }
        case .option:
            checkIcon.snp.makeConstraints { $0.size.equalTo(20) }
        }
    }

    private func setupStyles() {
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = 12
        contentStack.isUserInteractionEnabled = style == .toggle

        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        titleLabel.font = .systemFont(ofSize: 15)
        titleLabel.numberOfLines = 0

        descLabel.font = .systemFont(ofSize: 11)
        descLabel.numberOfLines = 0
        descLabel.isHidden = true

        valueLabel.font = .systemFont(ofSize: 15)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        arrowIcon.image = RoomKitResources.image(named: "roomkit_icon_chevron_right_tertiary")
        checkIcon.image = RoomKitResources.image(named: "roomkit_icon_check_accent")
        checkIcon.isHidden = true

        toggle.applyRoomKitStyle()
        toggle.setContentHuggingPriority(.required, for: .horizontal)
        toggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        separator.isHidden = true
        separator.isUserInteractionEnabled = false

        applyTheme()
    }

    private func setupBindings() {
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        toggle.addTarget(self, action: #selector(handleToggleChanged), for: .valueChanged)
    }

    private func applyTheme() {
        titleLabel.attributedText = attributedText(title, fontSize: 15, color: UIColor.roomKitFgPrimary)
        descLabel.attributedText = attributedText(desc, fontSize: 11, color: UIColor.roomKitFgTertiary)
        valueLabel.textColor = UIColor.roomKitFgSecondary
        separator.backgroundColor = UIColor.roomKitBorder
        applyBackground()
    }

    private func attributedText(_ text: String?, fontSize: CGFloat, color: UIColor) -> NSAttributedString? {
        guard let text else { return nil }
        let lineHeight = fontSize * 1.4
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        return NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ])
    }

    private func applyBackground() {
        let showsPress = isHighlighted && style != .toggle
        backgroundColor = showsPress ? UIColor.roomKitBgPress : .clear
    }
}

extension RoomSettingsRow {

    @objc private func handleTap() {
        onTap?()
    }

    @objc private func handleToggleChanged() {
        onToggle?(toggle.isOn)
    }
}

final class RoomSettingsSection: UIView {

    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyTheme()
        }
    }

    private func setupViews() {
        addSubview(stack)
    }

    private func setupConstraints() {
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    private func setupStyles() {
        layer.cornerRadius = 12
        layer.masksToBounds = true
        stack.axis = .vertical
        applyTheme()
    }

    private func applyTheme() {
        backgroundColor = UIColor.roomKitBgSurface
    }
}

extension RoomSettingsSection {

    func addRow(_ row: RoomSettingsRow) {
        row.showsSeparator = !stack.arrangedSubviews.isEmpty
        stack.addArrangedSubview(row)
    }
}

extension String {
    fileprivate static var settingsTitle: String { RoomKitResources.localizedString("roomkit.settings.title") }
    fileprivate static var settingsGroupVideo: String { RoomKitResources.localizedString("roomkit.settings.group_video") }
    fileprivate static var settingsGroupGeneral: String { RoomKitResources.localizedString("roomkit.settings.group_general") }
    fileprivate static var settingsMirror: String { RoomKitResources.localizedString("roomkit.settings.mirror") }
    fileprivate static var settingsMirrorDesc: String { RoomKitResources.localizedString("roomkit.settings.mirror_desc") }
    fileprivate static var settingsResolution: String { RoomKitResources.localizedString("roomkit.settings.resolution") }
}

extension RoomSettingsView {

    @objc private func handleNavBarBack() {
        routerContext?.pop(animated: true)
    }

    @objc private func handleNavBarBackHighlight() {
        navBackButton.alpha = 0.72
    }

    @objc private func handleNavBarBackUnhighlight() {
        navBackButton.alpha = 1
    }
}
