//
//  LanguagePickerViewController.swift
//  AtomicX
//
//  Created on 2026/1/19.
//

import UIKit
import SnapKit

protocol LanguagePickerDelegate: AnyObject {
    func languagePickerDidSelect(value: String, isSourceLanguage: Bool)
}

final class LanguagePickerViewController: UIViewController {
    
    weak var delegate: LanguagePickerDelegate?
    private var languages: [(value: String, displayName: String)] = []
    private var selectedValue: String?
    private var titleText = ""
    private var isSourceLanguage = false
    
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
        label.textColor = .black
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        return label
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = UIColor(0xF2F2F7)
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.register(LanguageCell.self, forCellReuseIdentifier: LanguageCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        return tableView
    }()
    
    static func newInstanceForSource(selectedValue: String?) -> LanguagePickerViewController {
        let vc = LanguagePickerViewController()
        vc.configure(
            selectedValue: selectedValue,
            titleKey: "ai_transcriber_select_source_language",
            languages: LanguageProvider.getSourceLanguageList(),
            isSourceLanguage: true
        )
        return vc
    }
    
    static func newInstanceForTranslation(selectedValue: String?) -> LanguagePickerViewController {
        let vc = LanguagePickerViewController()
        vc.configure(
            selectedValue: selectedValue,
            titleKey: "ai_transcriber_select_translation_language",
            languages: LanguageProvider.getTranslationLanguageList(),
            isSourceLanguage: false
        )
        return vc
    }
    
    private func configure(selectedValue: String?, titleKey: String, languages: [(value: String, displayName: String)], isSourceLanguage: Bool) {
        self.selectedValue = selectedValue
        self.titleText = CallKitBundle.localizedString(forKey: titleKey)
        self.languages = languages
        self.isSourceLanguage = isSourceLanguage
        modalPresentationStyle = .fullScreen
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        constructViewHierarchy()
        activateConstraints()
        titleLabel.text = titleText
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollToSelectedItem()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }
    
    private func constructViewHierarchy() {
        view.backgroundColor = UIColor(0xF2F2F7)
        
        view.addSubview(navigationBar)
        navigationBar.addSubview(backButton)
        navigationBar.addSubview(titleLabel)
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
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    private func scrollToSelectedItem() {
        guard let selectedValue,
              let index = languages.firstIndex(where: { $0.value == selectedValue }) else { return }
        tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: false)
    }
    
    @objc private func onBackButtonTapped() {
        dismiss(animated: true)
    }
}

extension LanguagePickerViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        languages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: LanguageCell.reuseIdentifier,
                                                       for: indexPath) as? LanguageCell else {
            return UITableViewCell()
        }
        let language = languages[indexPath.row]
        let isLastRow = indexPath.row == languages.count - 1
        cell.configure(
            displayName: language.displayName,
            isSelected: language.value == selectedValue,
            showSeparator: !isLastRow
        )
        return cell
    }
}

extension LanguagePickerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        delegate?.languagePickerDidSelect(value: languages[indexPath.row].value, isSourceLanguage: isSourceLanguage)
        dismiss(animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        56
    }
}

private final class LanguageCell: UITableViewCell {
    static let reuseIdentifier = "LanguageCell"
    
    private let languageLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Regular", size: 16) ?? .systemFont(ofSize: 16)
        return label
    }()
    
    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(0xE5E5E5)
        return view
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(0xF2F2F7)
        selectionStyle = .none
        constructViewHierarchy()
        activateConstraints()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func constructViewHierarchy() {
        contentView.addSubview(languageLabel)
        contentView.addSubview(separatorView)
    }
    
    private func activateConstraints() {
        languageLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
        
        separatorView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }
    }
    
    func configure(displayName: String, isSelected: Bool, showSeparator: Bool = true) {
        languageLabel.text = displayName
        languageLabel.textColor = isSelected ? UIColor(0x007AFF) : UIColor(0x000000, alpha: 0.9)
        separatorView.isHidden = !showSeparator
    }
}
