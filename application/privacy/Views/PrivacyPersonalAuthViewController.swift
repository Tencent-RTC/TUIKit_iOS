//
//  PrivacyPersonalAuthViewController.swift
//  privacy
//

import UIKit
import AtomicX

final class PrivacyPersonalAuthViewController: UITableViewController {
    
    private let config: PrivacyConfig
    
    private var dataSource: [(title: String, data: [String])] = []
    
    // MARK: - Init
    
    init(config: PrivacyConfig) {
        self.config = config
        super.init(style: .plain)
        buildDataSource()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Build Data
    
    private func buildDataSource() {
        let authList = config.authList
        if !authList.isEmpty {
            let title = PrivacyLocalize("Privacy.PersonalAuth.systemAuth")
            dataSource.append((title, authList))
        }
        let infoList = config.infoList
        if !infoList.isEmpty {
            let title = PrivacyLocalize("Privacy.PersonalAuth.info")
            dataSource.append((title, infoList))
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        tableView.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        tableView.separatorStyle = .none
        configureNavigation()
    }
    
    // MARK: - Navigation
    
    private func configureNavigation() {
        title = PrivacyLocalize("Privacy.Center.personalAuth")
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
        return dataSource.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellID = "PersonalAuthCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID)
            ?? UITableViewCell(style: .default, reuseIdentifier: cellID)
        cell.selectionStyle = .none
        cell.accessoryType = .disclosureIndicator
        cell.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        cell.textLabel?.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        cell.textLabel?.font = ThemeStore.shared.typographyTokens.Regular16
        cell.textLabel?.text = dataSource[indexPath.row].title
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 49.0
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = dataSource[indexPath.row]
        let systemAuthTitle = PrivacyLocalize("Privacy.PersonalAuth.systemAuth")
        let infoTitle = PrivacyLocalize("Privacy.PersonalAuth.info")
        
        if item.title == systemAuthTitle {
            let vc = PrivacySystemAuthViewController(config: config)
            navigationController?.pushViewController(vc, animated: true)
        } else if item.title == infoTitle {
            let vc = PrivacyMyInfoViewController(config: config)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
