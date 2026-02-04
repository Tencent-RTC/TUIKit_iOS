//
//  TranscriberSettingsViewController.swift
//  AtomicX
//
//  Created on 2026/1/19.
//

import UIKit
import SnapKit
import AtomicXCore

final class TranscriberSettingsViewController: UIViewController {
    
    private enum SettingRow: Int, CaseIterable {
        case sourceLanguage
        case translationLanguage
        case bilingual
        
        var isSelectable: Bool { self != .bilingual }
    }
    
    private static let tableViewHeight: CGFloat = 164.0
    
    var onSettingsChanged: (() -> Void)?
    
    private lazy var navigationBar: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        return view
    }()
    
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.tintColor = .black
        button.addTarget(self, action: #selector(onBackButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = .settingsTitle
        label.textColor = .black
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        return label
    }()
    
    private lazy var sectionTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(0x727A8A)
        label.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        label.text = .sectionRecognition
        return label
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .white
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = false
        tableView.layer.cornerRadius = 12
        tableView.clipsToBounds = true
        tableView.register(SettingCell.self, forCellReuseIdentifier: SettingCell.reuseIdentifier)
        tableView.register(SettingSwitchCell.self, forCellReuseIdentifier: SettingSwitchCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        return tableView
    }()
    
    static func show(
        from viewController: UIViewController,
        onSettingsChanged: (() -> Void)?
    ) {
        let settingsVC = TranscriberSettingsViewController()
        settingsVC.onSettingsChanged = onSettingsChanged
        settingsVC.modalPresentationStyle = .fullScreen
        viewController.present(settingsVC, animated: true)
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        constructViewHierarchy()
        activateConstraints()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }
    
    private func constructViewHierarchy() {
        view.backgroundColor = UIColor(0xF2F2F7)
        
        view.addSubview(navigationBar)
        navigationBar.addSubview(backButton)
        navigationBar.addSubview(titleLabel)
        view.addSubview(sectionTitleLabel)
        view.addSubview(tableView)
    }
    
    private func activateConstraints() {
        navigationBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(CallConstants.statusBar_Height + 44)
        }
        
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.bottom.equalToSuperview().offset(-8)
            make.size.equalTo(44)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(backButton)
        }
        
        sectionTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(sectionTitleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(12)
            make.height.equalTo(Self.tableViewHeight)
        }
    }
    
    // MARK: - Actions
    @objc private func onBackButtonTapped() {
        updateTranscriberConfig()
        onSettingsChanged?()
        dismiss(animated: true)
    }
    
    private func showLanguagePicker(for row: SettingRow) {
        guard row.isSelectable else { return }
        let config = TranscriberSettings.config
        let pickerVC: LanguagePickerViewController
        switch row {
        case .sourceLanguage:
            pickerVC = LanguagePickerViewController.newInstanceForSource(selectedValue: config.sourceLanguage.rawValue)
        case .translationLanguage:
            pickerVC = LanguagePickerViewController.newInstanceForTranslation(selectedValue:
                                                                                config.translationLanguages.first?.rawValue ?? "")
        case .bilingual:
            return
        }
        pickerVC.delegate = self
        present(pickerVC, animated: true)
    }
    
    private func updateTranscriberConfig() {
        AITranscriberStore.shared.updateRealtimeTranscriber(config: TranscriberSettings.config, completion: nil)
    }
}

extension TranscriberSettingsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        SettingRow.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let row = SettingRow(rawValue: indexPath.row) else { return UITableViewCell() }
        let isLastRow = indexPath.row == SettingRow.allCases.count - 1
        let config = TranscriberSettings.config
        
        switch row {
        case .sourceLanguage:
            return dequeueSettingCell(tableView, indexPath: indexPath,
                                      title: .sourceLanguage,
                                      value: LanguageProvider.getSourceLanguageDisplayName(config.sourceLanguage),
                                      showSeparator: !isLastRow)
        case .translationLanguage:
            return dequeueSettingCell(tableView, indexPath: indexPath,
                                      title: .translationLanguage,
                                      value: LanguageProvider.getTranslationLanguageDisplayName(config.translationLanguages.first),
                                      showSeparator: !isLastRow)
        case .bilingual:
            return dequeueSwitchCell(tableView, indexPath: indexPath,
                                     title: .bilingualSubtitle,
                                     isOn: TranscriberSettings.isBilingualEnabled,
                                     showSeparator: !isLastRow) {
                TranscriberSettings.isBilingualEnabled = $0
            }
        }
    }
    
    private func dequeueSettingCell(_ tableView: UITableView, indexPath: IndexPath,
                                    title: String, value: String, showSeparator: Bool) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingCell.reuseIdentifier,
                                                       for: indexPath) as? SettingCell else {
            return UITableViewCell()
        }
        cell.configure(title: title, value: value, showSeparator: showSeparator)
        return cell
    }
    
    private func dequeueSwitchCell(_ tableView: UITableView, indexPath: IndexPath,
                                   title: String, isOn: Bool, showSeparator: Bool,
                                   onChanged: @escaping (Bool) -> Void) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingSwitchCell.reuseIdentifier,
                                                       for: indexPath) as? SettingSwitchCell else {
            return UITableViewCell()
        }
        cell.configure(title: title, isOn: isOn, showSeparator: showSeparator, onChanged: onChanged)
        return cell
    }
}

extension TranscriberSettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        Self.tableViewHeight / CGFloat(SettingRow.allCases.count)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let row = SettingRow(rawValue: indexPath.row), row.isSelectable else { return }
        showLanguagePicker(for: row)
    }
}

extension TranscriberSettingsViewController: LanguagePickerDelegate {
    func languagePickerDidSelect(value: String, isSourceLanguage: Bool) {
        let config = TranscriberSettings.config
        let rowToReload: SettingRow
        
        if isSourceLanguage {
            guard let sourceLanguage = LanguageProvider.findSourceLanguage(value) else { return }
            TranscriberSettings.config = TranscriberConfig(
                sourceLanguage: sourceLanguage,
                translationLanguages: config.translationLanguages
            )
            rowToReload = .sourceLanguage
        } else {
            let languages: [TranslationLanguage] = value.isEmpty ? [] : LanguageProvider.findTranslationLanguage(value).map { [$0] } ?? []
            TranscriberSettings.config = TranscriberConfig(
                sourceLanguage: config.sourceLanguage,
                translationLanguages: languages
            )
            rowToReload = .translationLanguage
        }
        
        tableView.reloadRows(at: [IndexPath(row: rowToReload.rawValue, section: 0)], with: .none)
    }
}

// MARK: - SettingCell
private final class SettingCell: UITableViewCell {
    static let reuseIdentifier = "SettingCell"
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(0x000000, alpha: 0.9)
        label.font = UIFont(name: "PingFangSC-Regular", size: 16) ?? .systemFont(ofSize: 16)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.textColor = .gray
        label.font = .systemFont(ofSize: 16)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    private let arrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "chevron.right")
        imageView.tintColor = .lightGray
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(0xE5E5E5)
        return view
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .white
        selectionStyle = .none
        constructViewHierarchy()
        activateConstraints()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func constructViewHierarchy() {
        [titleLabel, valueLabel, arrowImageView, separatorView].forEach { contentView.addSubview($0) }
    }
    
    private func activateConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
        }
        
        arrowImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 16, height: 16))
        }
        
        valueLabel.snp.makeConstraints { make in
            make.trailing.equalTo(arrowImageView.snp.leading).offset(-6)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(20)
        }
        
        separatorView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }
    }
    
    func configure(title: String, value: String, showSeparator: Bool) {
        titleLabel.text = title
        valueLabel.text = value
        separatorView.isHidden = !showSeparator
    }
}

// MARK: - SettingSwitchCell
private final class SettingSwitchCell: UITableViewCell {
    static let reuseIdentifier = "SettingSwitchCell"
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(0x000000, alpha: 0.9)
        label.font = UIFont(name: "PingFangSC-Regular", size: 16) ?? .systemFont(ofSize: 16)
        return label
    }()
    
    private let switchControl: UISwitch = {
        let control = UISwitch()
        control.onTintColor = UIColor(0x007AFF)
        return control
    }()
    
    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(0xE5E5E5)
        return view
    }()
    
    private var onSwitchChanged: ((Bool) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .white
        selectionStyle = .none
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func constructViewHierarchy() {
        [titleLabel, switchControl, separatorView].forEach { contentView.addSubview($0) }
    }
    
    private func activateConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
        }
        
        switchControl.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
        
        separatorView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }
    }
    
    private func bindInteraction() {
        switchControl.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
    }
    
    func configure(title: String, isOn: Bool, showSeparator: Bool, onChanged: @escaping (Bool) -> Void) {
        titleLabel.text = title
        switchControl.isOn = isOn
        separatorView.isHidden = !showSeparator
        onSwitchChanged = onChanged
    }
    
    @objc private func switchValueChanged() {
        onSwitchChanged?(switchControl.isOn)
    }
}

fileprivate extension String {
    static let settingsTitle = CallKitBundle.localizedString(forKey: "ai_transcriber_settings_title")
    static let sectionRecognition = CallKitBundle.localizedString(forKey: "ai_transcriber_section_recognition")
    static let sourceLanguage = CallKitBundle.localizedString(forKey: "ai_transcriber_source_language")
    static let translationLanguage = CallKitBundle.localizedString(forKey: "ai_transcriber_translation_language")
    static let bilingualSubtitle = CallKitBundle.localizedString(forKey: "ai_transcriber_bilingual_subtitle")
}
