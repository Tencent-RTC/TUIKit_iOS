//
//  PrivacyDataCollectionViewController.swift
//  privacy
//

import UIKit
import AtomicX
import Kingfisher
import TUICore

// MARK: - PrivacyDataCollectionViewController

final class PrivacyDataCollectionViewController: UITableViewController {
    
    private let config: PrivacyConfig
    private var dataSource: [[String: Any]] = []
    
    // MARK: - Header View
    
    private lazy var headerView: UIView = {
        let width = UIScreen.main.bounds.width
        let container = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 160))
        container.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        
        let titleLabel = UILabel()
        titleLabel.font = ThemeStore.shared.typographyTokens.Bold20
        titleLabel.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        titleLabel.text = PrivacyLocalize("Privacy.Center.dataCollection")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let descLabel = UILabel()
        descLabel.font = ThemeStore.shared.typographyTokens.Regular14
        descLabel.textColor = ThemeStore.shared.colorTokens.textColorSecondary
        descLabel.numberOfLines = 0
        let format = PrivacyLocalize("Privacy.DataCollection.desc")
        descLabel.text = String(format: format, appName)
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
    
    init(config: PrivacyConfig) {
        self.config = config
        super.init(style: .plain)
        self.dataSource = config.dataCollectionList
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        tableView.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.separatorStyle = .none
        tableView.tableHeaderView = headerView
        tableView.register(PrivacyDataCollectionCell.self, forCellReuseIdentifier: PrivacyDataCollectionCell.reuseID)
        configureNavigation()
    }
    
    // MARK: - Navigation
    
    private func configureNavigation() {
        title = PrivacyLocalize("Privacy.Center.dataCollection")
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
    
    // MARK: - Helpers
    
    private var appName: String {
        let name = Bundle.main.localizedString(forKey: "CFBundleDisplayName", value: nil, table: "InfoPlist")
        if !name.isEmpty && name != "CFBundleDisplayName" {
            return name
        }
        return Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? ""
    }
    
    private func isEnglish() -> Bool {
        return TUIGlobalization.getPreferredLanguage()?.hasPrefix("en") ?? false
    }
    
    // MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: PrivacyDataCollectionCell.reuseID,
            for: indexPath
        ) as? PrivacyDataCollectionCell else {
            return UITableViewCell()
        }
        
        let info = dataSource[indexPath.row]
        let type = info["type"] as? String ?? ""
        var desc = info["desc"] as? String ?? ""
        if isEnglish(), let descEn = info["desc_en"] as? String {
            desc = descEn
        }
        
        let title = PrivacyLocalize("Privacy.SystemAuth.\(type)")
        let noneText = PrivacyLocalize("Privacy.DataCollection.none")
        
        if type == "avatar" {
            cell.configure(
                title: title,
                valueText: nil,
                purposeText: desc,
                avatarURL: config.userAvatar
            )
        } else {
            var text: String = ""
            switch type {
            case "name": text = config.userName
            case "id": text = config.userID
            case "phone": text = config.phone
            case "email": text = config.email
            default: break
            }
            if text.isEmpty { text = noneText }
            cell.configure(
                title: title,
                valueText: text,
                purposeText: desc,
                avatarURL: nil
            )
        }
        return cell
    }
}

// MARK: - PrivacyDataCollectionCell

private final class PrivacyDataCollectionCell: UITableViewCell {
    
    static let reuseID = "PrivacyDataCollectionCell"
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeStore.shared.typographyTokens.Medium16
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        return label
    }()
    
    let valueLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeStore.shared.typographyTokens.Regular14
        label.textColor = .gray
        return label
    }()
    
    let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = ThemeStore.shared.borderRadius.radius20
        iv.clipsToBounds = true
        iv.isHidden = true
        return iv
    }()
    
    let purposeTextLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeStore.shared.typographyTokens.Regular14
        label.textColor = ThemeStore.shared.colorTokens.textColorTertiary
        label.numberOfLines = 0
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel, avatarImageView, purposeTextLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            avatarImageView.widthAnchor.constraint(equalToConstant: 40),
            avatarImageView.heightAnchor.constraint(equalToConstant: 40),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(title: String, valueText: String?, purposeText: String, avatarURL: String?) {
        titleLabel.text = title
        
        if let avatarURL = avatarURL, let url = URL(string: avatarURL) {
            avatarImageView.isHidden = false
            avatarImageView.kf.setImage(with: url)
            valueLabel.isHidden = true
        } else {
            avatarImageView.isHidden = true
            valueLabel.isHidden = false
            valueLabel.text = valueText
        }
        
        purposeTextLabel.text = purposeText
    }
}
