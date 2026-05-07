//
//  PrivacyAuthDetailViewController.swift
//  privacy
//

import UIKit
import AtomicX

private let kBeautyAuthStatusKey = "beautyAuthStatus"

// MARK: - PrivacyAuthDetailViewController

final class PrivacyAuthDetailViewController: UITableViewController {
    
    private let authType: PrivacyAuthType
    private let config: PrivacyConfig
    
    // MARK: - Header View
    
    private lazy var headerView: UIView = {
        let width = UIScreen.main.bounds.width
        let container = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 220))
        container.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        
        let titleLabel = UILabel()
        titleLabel.font = ThemeStore.shared.typographyTokens.Bold20
        titleLabel.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        titleLabel.text = localizedTitle
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let descLabel = UILabel()
        descLabel.font = ThemeStore.shared.typographyTokens.Regular14
        descLabel.textColor = ThemeStore.shared.colorTokens.textColorSecondary
        descLabel.numberOfLines = 0
        descLabel.text = localizedDescription
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(descLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
        ])
        
        return container
    }()
    
    // MARK: - Init
    
    init(authType: PrivacyAuthType, config: PrivacyConfig) {
        self.authType = authType
        self.config = config
        super.init(style: .grouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        tableView.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        tableView.separatorStyle = .singleLine
        tableView.tableHeaderView = headerView
        configureNavigation()
    }
    
    // MARK: - Navigation
    
    private func configureNavigation() {
        title = localizedTitle
        navigationController?.navigationBar.titleTextAttributes = [
            .font: ThemeStore.shared.typographyTokens.Medium18,
            .foregroundColor: UIColor.black
        ]
        
        let backBtn = UIButton(type: .custom)
        backBtn.setImage(UIImage(named: "privacy_back"), for: .normal)
        backBtn.addTarget(self, action: #selector(backAction), for: .touchUpInside)
        backBtn.sizeToFit()
        let backItem = UIBarButtonItem(customView: backBtn)
        backItem.tintColor = .black
        navigationItem.leftBarButtonItem = backItem
    }
    
    @objc private func backAction() {
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Localized Helpers
    
    private var localizedTitle: String {
        return PrivacyLocalize("Privacy.SystemAuth.\(authType.rawValue)")
    }
    
    private var localizedDescription: String {
        if authType == .beauty {
            return PrivacyLocalize("Privacy.AuthDetail.beautyDesc")
        }
        let keyMap: [PrivacyAuthType: String] = [
            .camera: "NSCameraUsageDescription",
            .microphone: "NSMicrophoneUsageDescription",
            .photos: "NSPhotoLibraryUsageDescription",
        ]
        guard let plistKey = keyMap[authType] else { return "" }
        let desc = Bundle.main.localizedString(forKey: plistKey, value: "", table: "InfoPlist")
        if !desc.isEmpty && desc != plistKey {
            return desc
        }
        return (Bundle.main.infoDictionary?[plistKey] as? String) ?? ""
    }
    
    // MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if authType == .beauty {
            return makeBeautySwitchCell()
        } else {
            return makeSystemSettingCell()
        }
    }
    
    private func makeSystemSettingCell() -> UITableViewCell {
        let cellID = "SettingCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID)
            ?? UITableViewCell(style: .default, reuseIdentifier: cellID)
        cell.selectionStyle = .none
        cell.accessoryType = .disclosureIndicator
        cell.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        cell.textLabel?.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        cell.textLabel?.font = ThemeStore.shared.typographyTokens.Regular16
        let format = PrivacyLocalize("Privacy.AuthDetail.manage")
        cell.textLabel?.text = String(format: format, localizedTitle)
        return cell
    }
    
    private func makeBeautySwitchCell() -> UITableViewCell {
        let cellID = "SwitchCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID)
            ?? UITableViewCell(style: .default, reuseIdentifier: cellID)
        cell.selectionStyle = .none
        cell.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        cell.textLabel?.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        cell.textLabel?.font = ThemeStore.shared.typographyTokens.Regular16
        let format = PrivacyLocalize("Privacy.AuthDetail.manage")
        cell.textLabel?.text = String(format: format, localizedTitle)
        
        cell.accessoryView = nil
        
        let authSwitch = UISwitch()
        let rawValue = UserDefaults.standard.integer(forKey: kBeautyAuthStatusKey)
        authSwitch.isOn = (rawValue == BeautyAuthStatus.allow.rawValue)
        authSwitch.addTarget(self, action: #selector(beautySwitchChanged(_:)), for: .valueChanged)
        cell.accessoryView = authSwitch
        
        return cell
    }
    
    @objc private func beautySwitchChanged(_ sender: UISwitch) {
        let status: BeautyAuthStatus = sender.isOn ? .allow : .deny
        UserDefaults.standard.set(status.rawValue, forKey: kBeautyAuthStatusKey)
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 49.0
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if authType != .beauty {
            openSystemSettings()
        }
    }
    
    // MARK: - System Settings
    
    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
