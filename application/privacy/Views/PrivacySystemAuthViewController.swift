//
//  PrivacySystemAuthViewController.swift
//  privacy
//

import UIKit
import AtomicX
import AVFoundation
import Photos
import UserNotifications

// MARK: - Auth Type

enum PrivacyAuthType: String {
    case camera
    case microphone
    case photos
    case apns
    case beauty
}

// MARK: - Beauty Auth Status

enum BeautyAuthStatus: Int {
    case notDetermined = 0
    case allow = 1
    case deny = 2
}

private let kBeautyAuthStatusKey = "beautyAuthStatus"

// MARK: - PrivacySystemAuthViewController

final class PrivacySystemAuthViewController: UITableViewController {
    
    private let config: PrivacyConfig
    private var authItems: [String] = []
    private var notificationStatusText: String = ""
    
    // MARK: - Init
    
    init(config: PrivacyConfig) {
        self.config = config
        super.init(style: .plain)
        self.authItems = config.authList
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        tableView.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        tableView.separatorStyle = .none
        configureNavigation()
        configureFooter()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshAuthStatus()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Navigation
    
    private func configureNavigation() {
        title = PrivacyLocalize("Privacy.PersonalAuth.systemAuth")
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
    
    private func configureFooter() {
        let screenWidth = UIScreen.main.bounds.width
        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: 40))
        footerView.backgroundColor = .clear
        
        let settingBtn = UIButton(type: .system)
        settingBtn.frame = CGRect(x: screenWidth / 2 - 100, y: 0, width: 200, height: 40)
        settingBtn.setTitle(PrivacyLocalize("Privacy.SystemAuth.goToSettings"), for: .normal)
        settingBtn.addTarget(self, action: #selector(openSystemSettings), for: .touchUpInside)
        footerView.addSubview(settingBtn)
        
        tableView.tableFooterView = footerView
    }
    
    // MARK: - Actions
    
    @objc private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    @objc private func appDidBecomeActive() {
        refreshAuthStatus()
    }
    
    // MARK: - Refresh
    
    private func refreshAuthStatus() {
        tableView.reloadData()
        checkNotificationStatus()
    }
    
    private func checkNotificationStatus() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            switch settings.authorizationStatus {
            case .authorized:
                self.notificationStatusText = PrivacyLocalize("Privacy.SystemAuth.allow")
            case .denied:
                self.notificationStatusText = PrivacyLocalize("Privacy.SystemAuth.deny")
            default:
                self.notificationStatusText = PrivacyLocalize("Privacy.SystemAuth.unauthorized")
            }
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    // MARK: - Auth Status Text
    
    private func authStatusText(for type: PrivacyAuthType) -> String {
        switch type {
        case .camera:
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized: return PrivacyLocalize("Privacy.SystemAuth.allow")
            case .notDetermined: return PrivacyLocalize("Privacy.SystemAuth.unauthorized")
            default: return PrivacyLocalize("Privacy.SystemAuth.deny")
            }
            
        case .microphone:
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            switch status {
            case .authorized: return PrivacyLocalize("Privacy.SystemAuth.allow")
            case .notDetermined: return PrivacyLocalize("Privacy.SystemAuth.unauthorized")
            default: return PrivacyLocalize("Privacy.SystemAuth.deny")
            }
            
        case .photos:
            let status = PHPhotoLibrary.authorizationStatus()
            switch status {
            case .authorized: return PrivacyLocalize("Privacy.SystemAuth.allow")
            case .notDetermined: return PrivacyLocalize("Privacy.SystemAuth.unauthorized")
            default: return PrivacyLocalize("Privacy.SystemAuth.deny")
            }
            
        case .apns:
            return notificationStatusText.isEmpty
                ? PrivacyLocalize("Privacy.SystemAuth.unauthorized")
                : notificationStatusText
            
        case .beauty:
            let rawValue = UserDefaults.standard.integer(forKey: kBeautyAuthStatusKey)
            let status = BeautyAuthStatus(rawValue: rawValue) ?? .notDetermined
            switch status {
            case .allow: return PrivacyLocalize("Privacy.SystemAuth.allow")
            case .notDetermined: return PrivacyLocalize("Privacy.SystemAuth.unauthorized")
            case .deny: return PrivacyLocalize("Privacy.SystemAuth.deny")
            }
        }
    }
    
    private func localizedTitle(for key: String) -> String {
        return PrivacyLocalize("Privacy.SystemAuth.\(key)")
    }
    
    // MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return authItems.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellID = "SystemAuthCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID)
            ?? UITableViewCell(style: .value1, reuseIdentifier: cellID)
        cell.selectionStyle = .none
        cell.accessoryType = .disclosureIndicator
        cell.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        cell.textLabel?.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        cell.textLabel?.font = ThemeStore.shared.typographyTokens.Regular16
        cell.detailTextLabel?.textColor = .gray
        cell.detailTextLabel?.font = ThemeStore.shared.typographyTokens.Regular14
        
        let key = authItems[indexPath.row]
        cell.textLabel?.text = localizedTitle(for: key)
        
        if let authType = PrivacyAuthType(rawValue: key) {
            cell.detailTextLabel?.text = authStatusText(for: authType)
        }
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 49.0
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let key = authItems[indexPath.row]
        guard let authType = PrivacyAuthType(rawValue: key) else { return }
        
        if authType == .apns {
            openSystemSettings()
        } else {
            let vc = PrivacyAuthDetailViewController(authType: authType, config: config)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
