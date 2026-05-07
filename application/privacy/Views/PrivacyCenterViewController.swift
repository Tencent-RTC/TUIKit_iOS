//
//  PrivacyCenterViewController.swift
//  privacy
//

import UIKit
import AtomicX
import SafariServices

// MARK: - Menu Item

private enum PrivacyMenuItem {
    case personalAuth
    case systemPermissions
    case dataCollection
    case dataCollectionList(url: String)
    case thirdShare(url: String)
    case privacySummary(url: String)
    case privacyAgreement(url: String)
    case termsOfService(url: String)
    case userAgreement(url: String)
}

// MARK: - PrivacyCenterViewController

final class PrivacyCenterViewController: UITableViewController {
    
    private let config: PrivacyConfig
    private var menuItems: [(title: String, item: PrivacyMenuItem)] = []
    
    // MARK: - Init
    
    init(config: PrivacyConfig) {
        self.config = config
        super.init(style: .plain)
        buildMenuItems()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Build Data Source
    
    private func buildMenuItems() {
        if isTencentRTCApp {
            buildOverseasMenuItems()
        } else {
            buildDomesticMenuItems()
        }
    }
    
    private func buildOverseasMenuItems() {
        if config.personalAuth != nil, !config.authList.isEmpty {
            let title = PrivacyLocalize("Privacy.PersonalAuth.systemAuth")
            menuItems.append((title, .systemPermissions))
        }
        
        if !config.dataCollectionList.isEmpty {
            let title = PrivacyLocalize("Privacy.Center.dataCollection")
            menuItems.append((title, .dataCollection))
        }
        
        // 3. Privacy Policy（URL）
        let privacyURL = config.privacyURL
        if !privacyURL.isEmpty {
            let title = PrivacyLocalize("Privacy.Center.privacyAgreement")
            menuItems.append((title, .privacyAgreement(url: privacyURL)))
        }
    }
    
    private func buildDomesticMenuItems() {
        if config.personalAuth != nil {
            let title = PrivacyLocalize("Privacy.Center.personalAuth")
            menuItems.append((title, .personalAuth))
        }
        
        if !config.dataCollectionList.isEmpty {
            let title = PrivacyLocalize("Privacy.Center.dataCollection")
            menuItems.append((title, .dataCollection))
        }
        
        let dataCollectionURL = config.dataCollectionURL
        if !dataCollectionURL.isEmpty {
            let title = PrivacyLocalize("Privacy.Center.dataCollectionList")
            menuItems.append((title, .dataCollectionList(url: dataCollectionURL)))
        }
        
        let thirdShareURL = config.thirdShareURL
        if !thirdShareURL.isEmpty {
            let title = PrivacyLocalize("Privacy.Center.thirdShare")
            menuItems.append((title, .thirdShare(url: thirdShareURL)))
        }
        
        let privacySummaryURL = config.privacySummaryURL
        if !privacySummaryURL.isEmpty {
            let title = PrivacyLocalize("Privacy.Center.privacySummary")
            menuItems.append((title, .privacySummary(url: privacySummaryURL)))
        }
        
        let privacyURL = config.privacyURL
        if !privacyURL.isEmpty {
            let title = PrivacyLocalize("Privacy.Center.privacyAgreement")
            menuItems.append((title, .privacyAgreement(url: privacyURL)))
        }
        
        let serviceURL = config.serviceURL
        if !serviceURL.isEmpty {
            let title = PrivacyLocalize("Privacy.Center.termsOfService")
            menuItems.append((title, .termsOfService(url: serviceURL)))
        }
        
        let agreementURL = config.agreementURL
        if !agreementURL.isEmpty {
            let title = PrivacyLocalize("Privacy.Center.userAgreement")
            menuItems.append((title, .userAgreement(url: agreementURL)))
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        tableView.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        tableView.tableFooterView = UIView()
        configureNavigation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    // MARK: - Navigation
    
    private func configureNavigation() {
        title = PrivacyLocalize("Privacy.Center.title")
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
    
    // MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menuItems.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellID = "PrivacyCenterCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID)
            ?? UITableViewCell(style: .default, reuseIdentifier: cellID)
        cell.selectionStyle = .none
        cell.accessoryType = .disclosureIndicator
        cell.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        cell.textLabel?.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        cell.textLabel?.font = ThemeStore.shared.typographyTokens.Regular16
        cell.textLabel?.text = menuItems[indexPath.row].title
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 49.0
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = menuItems[indexPath.row].item
        switch item {
        case .personalAuth:
            let vc = PrivacyPersonalAuthViewController(config: config)
            navigationController?.pushViewController(vc, animated: true)
            
        case .systemPermissions:
            let vc = PrivacySystemAuthViewController(config: config)
            navigationController?.pushViewController(vc, animated: true)
            
        case .dataCollection:
            let vc = PrivacyDataCollectionViewController(config: config)
            navigationController?.pushViewController(vc, animated: true)
            
        case .dataCollectionList(let url),
             .thirdShare(let url),
             .privacySummary(let url),
             .privacyAgreement(let url),
             .termsOfService(let url),
             .userAgreement(let url):
            openURL(url, title: menuItems[indexPath.row].title)
        }
    }
    
    // MARK: - Open URL
    
    private func openURL(_ urlString: String, title: String) {
        guard let url = URL(string: urlString) else { return }
        let safari = SFSafariViewController(url: url)
        safari.title = title
        present(safari, animated: true)
    }
    
    // MARK: - Status Bar
    
    override var prefersStatusBarHidden: Bool { false }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available(iOS 13.0, *) {
            return .darkContent
        }
        return .default
    }
}
