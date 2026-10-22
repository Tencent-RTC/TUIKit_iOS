import UIKit
import SnapKit
import AtomicXCore

final class RoomSettingsOptionsView: UIView {

    enum Mode {
        case resolution
        case language
    }

    weak var routerContext: RouterContext?

    private let mode: Mode
    private var rows: [RoomSettingsRow] = []

    private let navBar = RoomNavigationBar()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let section = RoomSettingsSection()

    init(mode: Mode) {
        self.mode = mode
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        configureMode()
    }

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
        contentView.addSubview(section)
        scrollView.addSubview(contentView)
        addSubview(scrollView)
        addSubview(navBar)
    }

    private func setupConstraints() {
        navBar.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(safeAreaLayoutGuide.snp.top).offset(52)
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
        section.snp.makeConstraints {
            $0.top.equalToSuperview().offset(12)
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.bottom.equalToSuperview().offset(-16)
        }
    }

    private func setupStyles() {
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        navBar.navigationTitle = title
        applyTheme()
    }

    private func setupBindings() {
        navBar.onBack = { [weak self] in
            self?.routerContext?.pop(animated: true)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(handleLanguageChanged),
                                               name: RoomKitResources.languageDidChangeNotification, object: nil)
    }

    private func configureMode() {
        for (index, option) in options.enumerated() {
            let row = RoomSettingsRow(style: .option)
            row.title = option.title
            row.isChecked = option.isSelected
            row.onTap = { [weak self] in
                self?.select(at: index)
            }
            rows.append(row)
            section.addRow(row)
        }
    }

    private var title: String {
        switch mode {
        case .resolution: return .settingsResolution
        case .language: return .settingsLanguage
        }
    }

    private var options: [(title: String, isSelected: Bool, apply: () -> Void)] {
        switch mode {
        case .resolution:
            let current = DeviceStore.shared.state.value.localVideoQuality
            let qualities: [VideoQuality] = [.quality1080P, .quality720P, .quality540P, .quality360P]
            return qualities.map { quality in
                (quality.displayName, quality == current, { DeviceStore.shared.updateVideoQuality(quality) })
            }
        case .language:
            let current = RoomKitResources.language
            let languages: [RoomKitResources.Language] = [.simplifiedChinese, .english]
            return languages.map { language in
                (language.displayName, language == current, { RoomKitResources.setLanguage(language) })
            }
        }
    }

    private func applyTheme() {
        backgroundColor = UIColor.roomKitBgCanvas
    }

    private func select(at index: Int) {
        guard rows.indices.contains(index) else { return }
        section.isUserInteractionEnabled = false
        if !rows[index].isChecked {
            options[index].apply()
        }
        for (rowIndex, row) in rows.enumerated() {
            row.isChecked = rowIndex == index
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.routerContext?.pop(animated: true)
        }
    }

    @objc private func handleLanguageChanged() {
        navBar.navigationTitle = title
    }
}

extension String {
    fileprivate static var settingsResolution: String { RoomKitResources.localizedString("roomkit.settings.resolution") }
    fileprivate static var settingsLanguage: String { RoomKitResources.localizedString("roomkit.settings.language") }
}


extension VideoQuality {

    var displayName: String {
        switch self {
        case .quality1080P: return .settingsQuality1080P
        case .quality720P: return .settingsQuality720P
        case .quality540P: return .settingsQuality540P
        case .quality360P: return .settingsQuality360P
        @unknown default: return .settingsQuality720P
        }
    }
}

extension RoomKitResources.Language {

    var displayName: String {
        switch self {
        case .simplifiedChinese: return .settingsLanguageZhHans
        case .english: return .settingsLanguageEn
        }
    }
}

extension String {
    fileprivate static var settingsQuality1080P: String { RoomKitResources.localizedString("roomkit.settings.quality_1080p") }
    fileprivate static var settingsQuality720P: String { RoomKitResources.localizedString("roomkit.settings.quality_720p") }
    fileprivate static var settingsQuality540P: String { RoomKitResources.localizedString("roomkit.settings.quality_540p") }
    fileprivate static var settingsQuality360P: String { RoomKitResources.localizedString("roomkit.settings.quality_360p") }
    fileprivate static var settingsLanguageZhHans: String { RoomKitResources.localizedString("roomkit.settings.language_zh_hans") }
    fileprivate static var settingsLanguageEn: String { RoomKitResources.localizedString("roomkit.settings.language_en") }
}
