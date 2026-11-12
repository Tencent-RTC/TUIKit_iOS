import Combine
import SnapKit
import UIKit

final class TranscriptionSettingsSheet: UIView {

    var onPickLanguage: (() -> Void)?
    var onClose: (() -> Void)?

    private let enableSwitch = UISwitch()
    private let originalSwitch = UISwitch()
    private let sizeSegment = LightSegmentedControl()
    private let targetValueLabel = UILabel()
    private let setDefaultTick = UILabel()
    private let setDefaultButton = UIButton(type: .custom)
    private var cancellables = Set<AnyCancellable>()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        reload()
        CallKitConfig.shared.transcriptionChanged
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.reload() }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        let header = LightSheetHeader(title: CallKitResources.text("callkit.cc.title"))
        header.onClose = { [weak self] in self?.onClose?() }
        addSubview(header)
        header.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        let enableRow = Self.makeSwitchRow(title: CallKitResources.text("callkit.cc.title"),
                                           subtitle: CallKitResources.text("callkit.cc.enable_sub"),
                                           toggle: enableSwitch)
        let originalRow = Self.makeSwitchRow(title: CallKitResources.text("callkit.cc.show_original"),
                                             subtitle: CallKitResources.text("callkit.cc.show_original_sub"),
                                             toggle: originalSwitch)
        enableSwitch.addTarget(self, action: #selector(handleEnableChange), for: .valueChanged)
        originalSwitch.addTarget(self, action: #selector(handleOriginalChange), for: .valueChanged)
        [enableSwitch, originalSwitch].forEach {
            $0.onTintColor = CallKitTheme.brand
            $0.backgroundColor = CallKitTheme.switchOff
            $0.layer.cornerRadius = 16
        }

        sizeSegment.items = Self.sizeLabels
        sizeSegment.onSelect = { [weak self] index in self?.handleSizeChange(index) }
        sizeSegment.snp.makeConstraints { make in
            make.size.equalTo(CGSize(width: 170, height: 32))
        }

        let sizeTitle = UILabel()
        sizeTitle.text = CallKitResources.text("callkit.cc.font_size")
        sizeTitle.font = .systemFont(ofSize: 15)
        sizeTitle.textColor = CallKitTheme.sheetText

        let sizeRow = UIStackView(arrangedSubviews: [sizeTitle, sizeSegment])
        sizeRow.alignment = .center
        sizeRow.spacing = 12
        sizeSegment.setContentHuggingPriority(.required, for: .horizontal)

        let targetLanguageRow = makeTargetLanguageRow()
        let setDefaultRow = makeSetDefaultRow()

        let column = UIStackView(arrangedSubviews: [enableRow, originalRow, sizeRow, targetLanguageRow, setDefaultRow])
        column.axis = .vertical
        column.isLayoutMarginsRelativeArrangement = true
        column.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16)
        addSubview(column)
        column.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-8)
        }
        sizeRow.snp.makeConstraints { make in make.height.equalTo(60) }
        setDefaultRow.snp.makeConstraints { make in make.height.equalTo(44) }
    }

    private func makeSetDefaultRow() -> UIView {
        setDefaultTick.text = "\u{2713}"
        setDefaultTick.font = .systemFont(ofSize: 11, weight: .bold)
        setDefaultTick.textAlignment = .center
        setDefaultTick.layer.cornerRadius = 8
        setDefaultTick.layer.masksToBounds = true
        setDefaultTick.snp.makeConstraints { make in
            make.size.equalTo(16)
        }

        let textLabel = UILabel()
        textLabel.text = CallKitResources.text("callkit.cc.set_default")
        textLabel.font = .systemFont(ofSize: 12)
        textLabel.textColor = CallKitTheme.sheetText3

        let content = UIStackView(arrangedSubviews: [setDefaultTick, textLabel])
        content.alignment = .center
        content.spacing = 8
        content.isUserInteractionEnabled = false

        setDefaultButton.backgroundColor = .clear
        setDefaultButton.addSubview(content)
        setDefaultButton.addAction(UIAction { _ in
            CallKitConfig.shared.updateCcPresetEnabled(!CallKitConfig.shared.ccPresetEnabled)
        }, for: .touchUpInside)
        content.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
        return setDefaultButton
    }

    private static func makeSwitchRow(title: String, subtitle: String, toggle: UISwitch) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15)
        titleLabel.textColor = CallKitTheme.sheetText

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = CallKitTheme.sheetText4
        subtitleLabel.numberOfLines = 0

        let textColumn = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textColumn.axis = .vertical
        textColumn.spacing = 3
        textColumn.isUserInteractionEnabled = false

        let row = UIStackView(arrangedSubviews: [textColumn, toggle])
        row.alignment = .center
        row.spacing = 12
        row.snp.makeConstraints { make in make.height.equalTo(62) }
        toggle.setContentHuggingPriority(.required, for: .horizontal)
        return row
    }

    private func makeTargetLanguageRow() -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = CallKitResources.text("callkit.cc.target_language")
        titleLabel.font = .systemFont(ofSize: 15)
        titleLabel.textColor = CallKitTheme.sheetText

        targetValueLabel.font = .systemFont(ofSize: 15)
        targetValueLabel.textColor = CallKitTheme.sheetText2
        targetValueLabel.lineBreakMode = .byTruncatingTail

        let chevron = UIImageView(image: CallKitResources.image(named: "callkit_icon_chevron")?.withRenderingMode(.alwaysTemplate))
        chevron.tintColor = CallKitTheme.sheetText2
        chevron.contentMode = .scaleAspectFit
        chevron.snp.makeConstraints { make in
            make.size.equalTo(CGSize(width: 5, height: 9))
        }

        let valueGroup = UIStackView(arrangedSubviews: [targetValueLabel, chevron])
        valueGroup.alignment = .center
        valueGroup.spacing = 5

        let rowStack = UIStackView(arrangedSubviews: [titleLabel, valueGroup])
        rowStack.alignment = .center
        rowStack.distribution = .equalSpacing
        rowStack.spacing = 12
        rowStack.isUserInteractionEnabled = false

        let row = UIControl()
        row.addSubview(rowStack)
        rowStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        row.snp.makeConstraints { make in
            make.height.equalTo(60)
        }
        row.addAction(UIAction { [weak self] _ in self?.onPickLanguage?() }, for: .touchUpInside)
        return row
    }

    private func reload() {
        let config = CallKitConfig.shared
        enableSwitch.setOn(config.enableAITranscriber, animated: false)
        originalSwitch.setOn(config.showOriginalTranscript, animated: false)
        sizeSegment.selectedIndex = CallKitConfig.TranscriptFontSize.allCases.firstIndex(of: config.transcriptFontSize) ?? 1
        targetValueLabel.text = Self.languageLabel(config.transcriptionTargetLanguage)
        if config.ccPresetEnabled {
            setDefaultTick.backgroundColor = CallKitTheme.brand
            setDefaultTick.textColor = .white
            setDefaultTick.layer.borderWidth = 0
            setDefaultTick.layer.borderColor = UIColor.clear.cgColor
        } else {
            setDefaultTick.backgroundColor = .clear
            setDefaultTick.textColor = .clear
            setDefaultTick.layer.borderWidth = 1.5
            setDefaultTick.layer.borderColor = CallKitTheme.sheetText4.cgColor
        }
    }

    static func languageLabel(_ code: String) -> String {
        let keys = [
            "auto": "callkit.cc.lang_auto",
            "zh": "callkit.cc.lang_zh",
            "en": "callkit.cc.lang_en",
            "ar": "callkit.cc.lang_ar",
            "ja": "callkit.cc.lang_ja",
        ]
        guard let key = keys[code] else { return code }
        return CallKitResources.text(key)
    }

    @objc private func handleEnableChange() {
        CallKitConfig.shared.updateAITranscriber(enableSwitch.isOn)
    }

    @objc private func handleOriginalChange() {
        CallKitConfig.shared.updateShowOriginalTranscript(originalSwitch.isOn)
    }

    private static let sizeLabels = [CallKitResources.text("callkit.cc.size_sm"),
                                     CallKitResources.text("callkit.cc.size_md"),
                                     CallKitResources.text("callkit.cc.size_lg")]

    private func handleSizeChange(_ index: Int) {
        let sizes = CallKitConfig.TranscriptFontSize.allCases
        guard sizes.indices.contains(index) else { return }
        CallKitConfig.shared.updateTranscriptFontSize(sizes[index])
        CallKitToast.show(String(format: CallKitResources.text("callkit.cc.size_changed"), Self.sizeLabels[index]))
    }
}

final class LightSegmentedControl: UIView {

    var items: [String] = [] {
        didSet { rebuild() }
    }

    var onSelect: ((Int) -> Void)?

    var selectedIndex = 0 {
        didSet { refreshSelection() }
    }

    private let stack = UIStackView()
    private var buttons: [UIButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = CallKitTheme.sheetGrey
        layer.cornerRadius = 9
        stack.distribution = .fillEqually
        stack.spacing = 2
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttons = items.enumerated().map { index, title in
            let button = UIButton(type: .custom)
            button.setTitle(title, for: .normal)
            button.setTitleColor(CallKitTheme.sheetText2, for: .normal)
            button.setTitleColor(CallKitTheme.brand, for: .selected)
            button.layer.cornerRadius = 7
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowRadius = 1.5
            button.layer.shadowOffset = CGSize(width: 0, height: 1)
            button.tag = index
            button.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            return button
        }
        refreshSelection()
    }

    private func refreshSelection() {
        for (index, button) in buttons.enumerated() {
            let selected = index == selectedIndex
            button.isSelected = selected
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: selected ? .semibold : .regular)
            button.backgroundColor = selected ? .white : .clear
            button.layer.shadowOpacity = selected ? 0.08 : 0
        }
    }

    @objc private func handleTap(_ sender: UIButton) {
        selectedIndex = sender.tag
        onSelect?(sender.tag)
    }
}

final class LanguagePickerSheet: UIView {

    var onFinish: (() -> Void)?

    private let current = CallKitConfig.shared.transcriptionTargetLanguage
    private lazy var picked = current
    private var rowViews: [String: (label: UILabel, check: UILabel)] = [:]
    private let header = LightSheetHeader(title: CallKitResources.text("callkit.cc.target_language"))
    private let languageCodes = ["zh", "en", "ar", "ja"]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        refreshSelection()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        header.onAction = { [weak self] in self?.handleActionTap() }
        addSubview(header)
        header.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        let list = UIStackView()
        list.axis = .vertical
        for (index, code) in languageCodes.enumerated() {
            if index > 0 {
                let divider = UIView()
                divider.backgroundColor = CallKitTheme.sheetLine
                list.addArrangedSubview(divider)
                divider.snp.makeConstraints { make in
                    make.height.equalTo(1)
                }
            }
            list.addArrangedSubview(makeRow(code: code))
        }
        addSubview(list)
        list.snp.makeConstraints { make in
            make.top.equalTo(header.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-8)
        }
    }

    private func makeRow(code: String) -> UIControl {
        let row = UIControl()
        let label = UILabel()
        label.text = TranscriptionSettingsSheet.languageLabel(code)

        let check = CallKitCheckLabel(tint: CallKitTheme.brand)

        rowViews[code] = (label, check)

        let rowStack = UIStackView(arrangedSubviews: [label, check])
        rowStack.alignment = .center
        rowStack.isUserInteractionEnabled = false
        row.addSubview(rowStack)
        rowStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
        row.snp.makeConstraints { make in
            make.height.equalTo(52)
        }
        row.addAction(UIAction { [weak self] _ in self?.pick(code) }, for: .touchUpInside)
        return row
    }

    private func pick(_ code: String) {
        guard picked != code else { return }
        picked = code
        refreshSelection()
    }

    private func refreshSelection() {
        for (code, views) in rowViews {
            let selected = code == picked
            views.label.textColor = selected ? CallKitTheme.brand : CallKitTheme.sheetText
            views.label.font = .systemFont(ofSize: 15, weight: selected ? .semibold : .regular)
            views.check.isHidden = !selected
        }
        let isCancel = picked == current
        header.setActionTitle(CallKitResources.text(isCancel ? "callkit.common.cancel" : "callkit.common.confirm"),
                              isCancel: isCancel)
    }

    private func handleActionTap() {
        if picked != current {
            CallKitConfig.shared.updateTranscriptionTargetLanguage(picked)
            let label = TranscriptionSettingsSheet.languageLabel(picked)
            CallKitToast.show(String(format: CallKitResources.text("callkit.cc.target_changed"), label))
        }
        onFinish?()
    }
}
