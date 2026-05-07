//
//  PrivacyMyInfoViewController.swift
//  privacy
//

import UIKit
import AtomicX
import Kingfisher
import SnapKit

// MARK: - PrivacyMyInfoViewController

final class PrivacyMyInfoViewController: UITableViewController {
    
    private let config: PrivacyConfig
    private var infoItems: [String] = []
    
    // MARK: - Copy Tip
    
    private lazy var tipLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .black
        label.layer.cornerRadius = ThemeStore.shared.borderRadius.radius4
        label.layer.masksToBounds = true
        label.text = PrivacyLocalize("Privacy.MyInfo.copySuccess")
        label.textColor = .white
        label.textAlignment = .center
        label.font = ThemeStore.shared.typographyTokens.Regular14
        label.alpha = 0
        return label
    }()
    
    // MARK: - Init
    
    init(config: PrivacyConfig) {
        self.config = config
        super.init(style: .plain)
        self.infoItems = config.infoList
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
        tableView.register(PrivacyMyInfoCell.self, forCellReuseIdentifier: PrivacyMyInfoCell.reuseID)
        configureNavigation()
        
        view.addSubview(tipLabel)
        tipLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(150)
            make.height.equalTo(30)
        }
    }
    
    // MARK: - Navigation
    
    private func configureNavigation() {
        title = PrivacyLocalize("Privacy.PersonalAuth.info")
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
        return infoItems.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: PrivacyMyInfoCell.reuseID,
            for: indexPath
        ) as? PrivacyMyInfoCell else {
            return UITableViewCell()
        }
        
        let key = infoItems[indexPath.row]
        let title = PrivacyLocalize("Privacy.SystemAuth.\(key)")
        let noneText = PrivacyLocalize("Privacy.DataCollection.none")
        
        if key == "avatar" {
            cell.configure(title: title, value: nil, avatarURL: config.userAvatar)
        } else {
            var text = ""
            switch key {
            case "name": text = config.userName
            case "id": text = config.userID
            case "phone": text = config.phone
            case "email": text = config.email
            default: break
            }
            if text.isEmpty { text = noneText }
            cell.configure(title: title, value: text, avatarURL: nil)
        }
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let key = infoItems[indexPath.row]
        return key == "avatar" ? 74.0 : 49.0
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let key = infoItems[indexPath.row]
        guard key != "avatar" else { return }
        
        var text = ""
        switch key {
        case "name": text = config.userName
        case "id": text = config.userID
        case "phone": text = config.phone
        case "email": text = config.email
        default: break
        }
        copyText(text)
    }
    
    // MARK: - Copy
    
    private func copyText(_ text: String) {
        guard !text.isEmpty else { return }
        UIPasteboard.general.string = text
        showCopyTip()
    }
    
    private func showCopyTip() {
        tipLabel.layer.removeAllAnimations()
        UIView.animateKeyframes(withDuration: 2.0, delay: 0, options: .layoutSubviews) { [weak self] in
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.25) {
                self?.tipLabel.alpha = 1.0
            }
            UIView.addKeyframe(withRelativeStartTime: 0.75, relativeDuration: 0.25) {
                self?.tipLabel.alpha = 0.0
            }
        } completion: { [weak self] _ in
            self?.tipLabel.alpha = 0.0
        }
    }
}

// MARK: - PrivacyMyInfoCell

private final class PrivacyMyInfoCell: UITableViewCell {
    
    static let reuseID = "PrivacyMyInfoCell"
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeStore.shared.typographyTokens.Regular16
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
        iv.layer.cornerRadius = 22
        iv.clipsToBounds = true
        iv.isHidden = true
        return iv
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        contentView.addSubview(avatarImageView)
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.lessThanOrEqualTo(120)
        }
        
        valueLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8)
        }
        
        avatarImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(44)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(title: String, value: String?, avatarURL: String?) {
        titleLabel.text = title
        
        if let avatarURL = avatarURL, let url = URL(string: avatarURL) {
            avatarImageView.isHidden = false
            avatarImageView.kf.setImage(with: url)
            valueLabel.isHidden = true
        } else {
            avatarImageView.isHidden = true
            valueLabel.isHidden = false
            valueLabel.text = value
        }
    }
}
