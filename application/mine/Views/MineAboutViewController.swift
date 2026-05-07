//
//  MineAboutViewController.swift
//  mine
//

import UIKit
import AtomicX
import SnapKit
import TXLiteAVSDK_Professional

class MineAboutViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        
        self.title = MineLocalize("Demo.TRTC.Portal.Mine.about")
        navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.black,
            NSAttributedString.Key.font: ThemeStore.shared.typographyTokens.Bold18
        ]
        
        let backBtn = UIButton(type: .custom)
        backBtn.setImage(UIImage(named: "main_mine_about_back"), for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        backBtn.sizeToFit()
        let item = UIBarButtonItem(customView: backBtn)
        item.tintColor = .black
        navigationItem.leftBarButtonItem = item
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    @objc func backBtnClick() {
        navigationController?.popViewController(animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
        tableView.register(MineAboutTableViewCell.self, forCellReuseIdentifier: "MineAboutTableViewCell")
        tableView.register(MineAboutDetailCell.self, forCellReuseIdentifier: "MineAboutDetailCell")
        return tableView
    }()
    
    lazy var dataSource: [MineAboutModel] = {
        var res: [MineAboutModel] = []
        let sdkVersion = TRTCCloud.getSDKVersion()
        let sdk = MineAboutModel(title: MineLocalize("Demo.TRTC.Portal.sdkversion"), value: sdkVersion)
        res.append(sdk)
        
        let version = Self.appVersionWithBuild
        let storeVersion = MineAboutModel(title: MineLocalize("Demo.TRTC.Portal.appversion"), value: version)
        res.append(storeVersion)
        
        let resign = MineAboutModel(title: MineLocalize("Demo.TRTC.Portal.resignaccount"), type: .resign)
        res.append(resign)
        
        return res
    }()
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available(iOS 13.0, *) {
            return .darkContent
        } else {
            return .default
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    // MARK: - Version Helper
    
    private static var appVersionWithBuild: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version)(\(build))"
    }
}

// MARK: - UITableViewDataSource

extension MineAboutViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = dataSource[indexPath.row]
        switch model.type {
        case .normal:
            let cell = tableView.dequeueReusableCell(withIdentifier: "MineAboutTableViewCell", for: indexPath)
            if let scell = cell as? MineAboutTableViewCell {
                scell.titleLabel.text = model.title
                scell.descLabel.text = model.value
            }
            return cell
        case .resign:
            let cell = tableView.dequeueReusableCell(withIdentifier: "MineAboutDetailCell", for: indexPath)
            if let scell = cell as? MineAboutDetailCell {
                scell.titleLabel.text = model.title
            }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
    }
}

// MARK: - UITableViewDelegate

extension MineAboutViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let model = dataSource[indexPath.row]
        if model.type == .resign {
            let vc = MineAboutResignViewController()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

// MARK: - Models & Cells

enum MineAboutCellType {
    case normal
    case resign
}

class MineAboutModel: NSObject {
    let title: String
    let value: String
    let type: MineAboutCellType
    init(title: String, value: String = "", type: MineAboutCellType = .normal) {
        self.title = title
        self.value = value
        self.type = type
        super.init()
    }
}

class MineAboutDetailCell: UITableViewCell {
    lazy var titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Regular16
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        return label
    }()
    lazy var lineView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.strokeColorSecondary
        return view
    }()
    lazy var detailImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "main_mine_detail"))
        return imageView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailImageView)
        contentView.addSubview(lineView)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
        }
        detailImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
        }
        lineView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
    }
}

class MineAboutTableViewCell: UITableViewCell {
    lazy var titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Regular16
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        return label
    }()
    lazy var descLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Regular16
        label.textColor = ThemeStore.shared.colorTokens.textColorSecondary
        return label
    }()
    lazy var lineView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.strokeColorSecondary
        return view
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        contentView.addSubview(titleLabel)
        contentView.addSubview(descLabel)
        contentView.addSubview(lineView)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
        }
        descLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
        }
        lineView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(descLabel)
            make.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
    }
}
