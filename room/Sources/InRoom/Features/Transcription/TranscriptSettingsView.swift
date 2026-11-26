import UIKit
import SnapKit
import Combine
import AtomicXCore

final class TranscriptSettingsView: UIView {

    var onBack: (() -> Void)?

    private let roomID: String
    private let titleLabel = UILabel()
    private let mainContent = UIStackView()
    private let languageContent = UIView()
    private let languageList = UIStackView()
    private let sourceValueLabel = UILabel()
    private let translationSwitch = UISwitch()
    private var sourceLanguage = SourceLanguage.english
    private var languageRows: [(language: SourceLanguage, label: UILabel, check: UIImageView)] = []
    private var storeCancellables = Set<AnyCancellable>()

    init(roomID: String) {
        self.roomID = roomID
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        subscribe()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func prepareForReuse() {
        storeCancellables.removeAll()
    }

    private func setupViews() {
        titleLabel.text = RoomKitResources.localizedString("roomkit_caption_settings_native")
        let header = UIStackView(arrangedSubviews: [titleLabel])
        header.layoutMargins = UIEdgeInsets(top: 4, left: 16, bottom: 10, right: 16)
        header.isLayoutMarginsRelativeArrangement = true

        let sourceRow = makeRow(
            title: RoomKitResources.localizedString("roomkit_caption_source_language"),
            accessory: sourceValueLabel,
            action: #selector(showLanguages)
        )
        let translationRow = makeRow(
            title: RoomKitResources.localizedString("roomkit_caption_bilingual"),
            accessory: translationSwitch,
            action: nil
        )
        [sourceRow, divider(), translationRow].forEach(mainContent.addArrangedSubview)
        mainContent.axis = .vertical
        mainContent.layoutMargins = UIEdgeInsets(top: 0, left: 14, bottom: 10, right: 14)
        mainContent.isLayoutMarginsRelativeArrangement = true

        let backRow = UIControl()
        let backImage = UIImageView(image: RoomKitResources.image(named:"roomkit_icon_back")?.withRenderingMode(.alwaysTemplate))
        let backTitle = UILabel()
        backTitle.text = RoomKitResources.localizedString("roomkit_caption_source_language")
        backTitle.textColor = .roomKitFgPrimary
        backTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        backRow.addSubview(backImage)
        backRow.addSubview(backTitle)
        backImage.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(2)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(13)
        }
        backTitle.snp.makeConstraints {
            $0.leading.equalTo(backImage.snp.trailing).offset(6)
            $0.centerY.equalToSuperview()
        }
        backRow.snp.makeConstraints { $0.height.equalTo(36) }
        backRow.addTarget(self, action: #selector(showMain), for: .touchUpInside)

        let languages = UIStackView(arrangedSubviews: [backRow, divider()])
        languages.axis = .vertical
        languages.spacing = 2
        languages.layoutMargins = UIEdgeInsets(top: 0, left: 14, bottom: 10, right: 14)
        languages.isLayoutMarginsRelativeArrangement = true
        for language in [SourceLanguage.chinese, .english, .japanese, .korean] {
            let label = UILabel()
            label.font = .systemFont(ofSize: 13)
            let check = UIImageView(image: RoomKitResources.image(named:"roomkit_icon_check")?.withRenderingMode(.alwaysTemplate))
            check.tintColor = .roomKitAccent
            let row = UIControl()
            row.addSubview(label)
            row.addSubview(check)
            label.snp.makeConstraints {
                $0.leading.equalToSuperview().offset(2)
                $0.centerY.equalToSuperview()
                $0.trailing.lessThanOrEqualTo(check.snp.leading).offset(-8)
            }
            check.snp.makeConstraints {
                $0.trailing.equalToSuperview().offset(-2)
                $0.centerY.equalToSuperview()
                $0.size.equalTo(13)
            }
            row.snp.makeConstraints { $0.height.equalTo(40) }
            row.tag = languageRows.count
            row.addTarget(self, action: #selector(selectLanguage(_:)), for: .touchUpInside)
            languageRows.append((language, label, check))
            languages.addArrangedSubview(row)
        }
        languageContent.addSubview(languages)
        languages.snp.makeConstraints { $0.edges.equalToSuperview() }

        let root = UIStackView(arrangedSubviews: [header, mainContent, languageContent])
        root.axis = .vertical
        addSubview(root)
        root.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.lessThanOrEqualToSuperview()
        }
    }

    private func setupConstraints() {
        translationSwitch.setContentHuggingPriority(.required, for: .horizontal)
        sourceValueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func setupStyles() {
        backgroundColor = .roomKitBgSurface
        titleLabel.textColor = .roomKitFgPrimary
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        sourceValueLabel.textColor = .roomKitFgSecondary
        sourceValueLabel.font = .systemFont(ofSize: 13)
        translationSwitch.onTintColor = .roomKitAccent
        languageContent.isHidden = true
    }

    private func setupBindings() {
        translationSwitch.addTarget(self, action: #selector(updateTranslationEnabled), for: .valueChanged)
    }

    private func subscribe() {
        let state = AITranscriberStore.create(roomID: roomID).state
        state.subscribe(StatePublisherSelector(keyPath: \TranscriberState.selfLanguage))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] language in
                self?.sourceLanguage = language
                self?.updateLanguages()
            }
            .store(in: &storeCancellables)
        state.subscribe(StatePublisherSelector(keyPath: \TranscriberState.transcriptionConfig))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] config in
                self?.translationSwitch.setOn(config.enableTranslation, animated: true)
            }
            .store(in: &storeCancellables)
    }

    private func makeRow(title: String, accessory: UIView, action: Selector?) -> UIView {
        let row = UIControl()
        let label = UILabel()
        label.text = title
        label.textColor = .roomKitFgPrimary
        label.font = .systemFont(ofSize: 13)
        row.addSubview(label)
        row.addSubview(accessory)
        label.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(2)
            $0.centerY.equalToSuperview()
            $0.trailing.lessThanOrEqualTo(accessory.snp.leading).offset(-8)
        }
        accessory.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-2)
            $0.centerY.equalToSuperview()
        }
        row.snp.makeConstraints { $0.height.equalTo(48) }
        if let action {
            row.addTarget(self, action: action, for: .touchUpInside)
        }
        return row
    }

    private func divider() -> UIView {
        let view = UIView()
        view.backgroundColor = .roomKitBorder
        view.snp.makeConstraints { $0.height.equalTo(1) }
        return view
    }

    private func updateLanguages() {
        sourceValueLabel.text = languageLabel(sourceLanguage)
        for row in languageRows {
            let selected = row.language == sourceLanguage
            row.label.text = languageLabel(row.language)
            row.label.textColor = selected ? .roomKitAccent : .roomKitFgPrimary
            row.label.font = .systemFont(ofSize: 13, weight: selected ? .semibold : .regular)
            row.check.isHidden = !selected
        }
    }

    private func languageLabel(_ language: SourceLanguage) -> String {
        switch language {
        case .chinese: return RoomKitResources.localizedString("roomkit_caption_language_zh")
        case .japanese: return RoomKitResources.localizedString("roomkit_caption_language_ja")
        case .korean: return RoomKitResources.localizedString("roomkit_caption_language_ko")
        default: return RoomKitResources.localizedString("roomkit_caption_language_en")
        }
    }

    @objc private func showLanguages() {
        mainContent.isHidden = true
        languageContent.isHidden = false
    }

    @objc private func showMain() {
        mainContent.isHidden = false
        languageContent.isHidden = true
    }

    @objc private func selectLanguage(_ sender: UIControl) {
        let language = languageRows[sender.tag].language
        sourceLanguage = language
        updateLanguages()
        let config = AITranscriberStore.create(roomID: roomID).state.value.transcriptionConfig
        AITranscriberStore.create(roomID: roomID).updateTranscription(myLanguage: language, config: config) { [weak self] result in
            if case .failure(let error) = result {
                ErrorLocalized.showError(code: error.code, message: error.message)
                return
            }
            DispatchQueue.main.async {
                self?.showMain()
            }
        }
    }

    @objc private func updateTranslationEnabled() {
        let config = TranscriptionConfig(enableTranslation: translationSwitch.isOn)
        AITranscriberStore.create(roomID: roomID).updateTranscription(myLanguage: sourceLanguage, config: config) { result in
            if case .failure(let error) = result {
                ErrorLocalized.showError(code: error.code, message: error.message)
            }
        }
    }
}
