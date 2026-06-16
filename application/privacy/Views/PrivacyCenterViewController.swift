//
//  PrivacyCenterViewController.swift
//  privacy
//
//  隐私管理中心 — 主列表页面
//  对标 v1 LiteAVPrivacyViewController
//

import UIKit
import AtomicX
import SafariServices

// MARK: - Menu Item

/// 隐私中心菜单项类型
private enum PrivacyMenuItem {
    /// 个人信息与权限（跳转 PersonalAuth 页面）
    case personalAuth
    /// 系统权限（海外版，直接跳转 SystemAuth 页面）
    case systemPermissions
    /// 个人信息查看（跳转 DataCollection 页面）
    case dataCollection
    /// 个人信息收集清单（URL）
    case dataCollectionList(url: String)
    /// 第三方信息共享清单（URL）
    case thirdShare(url: String)
    /// 隐私政策摘要（URL）
    case privacySummary(url: String)
    /// 隐私保护指引（URL）
    case privacyAgreement(url: String)
    /// 服务条款（URL）
    case termsOfService(url: String)
    /// 用户协议（URL）
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
    
    /// 海外版菜单：System Permissions / Personal Information / Privacy Policy
    private func buildOverseasMenuItems() {
        // 1. System Permissions（直接跳转系统权限页面）
        if config.personalAuth != nil, !config.authList.isEmpty {
            let title = PrivacyLocalize("privacy_system_auth")
            menuItems.append((title, .systemPermissions))
        }
        
        // 2. Personal Information（跳转个人信息查看页面）
        if !config.dataCollectionList.isEmpty {
            let title = PrivacyLocalize("privacy_data_collection")
            menuItems.append((title, .dataCollection))
        }
        
        // 3. Privacy Policy（URL）
        let privacyURL = config.privacyURL
        if !privacyURL.isEmpty {
            let title = PrivacyLocalize("privacy_agreement")
            menuItems.append((title, .privacyAgreement(url: privacyURL)))
        }
    }
    
    /// 国内版菜单：完整列表
    private func buildDomesticMenuItems() {
        // 1. 个人信息与权限
        if config.personalAuth != nil {
            let title = PrivacyLocalize("privacy_personal_auth")
            menuItems.append((title, .personalAuth))
        }
        
        // 2. 个人信息查看
        if !config.dataCollectionList.isEmpty {
            let title = PrivacyLocalize("privacy_data_collection")
            menuItems.append((title, .dataCollection))
        }
        
        // 3. 个人信息收集清单（URL）
        let dataCollectionURL = config.dataCollectionURL
        if !dataCollectionURL.isEmpty {
            let title = PrivacyLocalize("privacy_data_collection_list")
            menuItems.append((title, .dataCollectionList(url: dataCollectionURL)))
        }
        
        // 4. 第三方信息共享清单（URL）
        let thirdShareURL = config.thirdShareURL
        if !thirdShareURL.isEmpty {
            let title = PrivacyLocalize("privacy_third_share")
            menuItems.append((title, .thirdShare(url: thirdShareURL)))
        }
        
        // 5. 隐私政策摘要（URL）
        let privacySummaryURL = config.privacySummaryURL
        if !privacySummaryURL.isEmpty {
            let title = PrivacyLocalize("privacy_policy_summary")
            menuItems.append((title, .privacySummary(url: privacySummaryURL)))
        }
        
        // 6. 隐私保护指引（URL）
        let privacyURL = config.privacyURL
        if !privacyURL.isEmpty {
            let title = PrivacyLocalize("privacy_agreement")
            menuItems.append((title, .privacyAgreement(url: privacyURL)))
        }
        
        // 7. 服务条款（URL）
        let serviceURL = config.serviceURL
        if !serviceURL.isEmpty {
            let title = PrivacyLocalize("privacy_terms_of_service")
            menuItems.append((title, .termsOfService(url: serviceURL)))
        }
        
        // 8. 用户协议（URL）
        let agreementURL = config.agreementURL
        if !agreementURL.isEmpty {
            let title = PrivacyLocalize("privacy_user_agreement")
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
        title = PrivacyLocalize("privacy_title")
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
