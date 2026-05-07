//
//  LanguageSelectViewController.swift
//  language
//

import UIKit
import AtomicX

class LanguageSelectViewController: UIViewController {
    
    var onLanguageChanged: ((String) -> Void)?
    
    private var dataSource: [LanguageCellModel] = []
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
        tableView.register(LanguageSelectCell.self, forCellReuseIdentifier: LanguageSelectCell.reuseID)
        return tableView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        title = MainLocalize("Demo.TRTC.Language.switchLanguage")
        configData()
        setupNavigationBar()
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
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
    
    // MARK: - Private
    
    private func configData() {
        dataSource = [
            LanguageCellModel(languageID: "zh-Hans", languageName: "简体中文"),
            LanguageCellModel(languageID: "en", languageName: "English"),
        ]
        
        let currentLanguageID = LanguageEntry.shared.currentLanguageID
        for (index, model) in dataSource.enumerated() where currentLanguageID == model.languageID {
            dataSource[index].selected = true
        }
    }
    
    private func setupNavigationBar() {
        let backBtn = UIButton(type: .custom)
        backBtn.setImage(UIImage(named: "main_mine_about_back"), for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        backBtn.sizeToFit()
        let item = UIBarButtonItem(customView: backBtn)
        item.tintColor = .black
        navigationItem.leftBarButtonItem = item
    }
    
    @objc private func backBtnClick() {
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - UITableViewDataSource

extension LanguageSelectViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = dataSource[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: LanguageSelectCell.reuseID, for: indexPath)
        if let cell = cell as? LanguageSelectCell {
            cell.update(model: model)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
    }
}

// MARK: - UITableViewDelegate

extension LanguageSelectViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedModel = dataSource[indexPath.row]
        
        for i in 0..<dataSource.count {
            dataSource[i].selected = (i == indexPath.row)
        }
        tableView.reloadData()
        
        LanguageEntry.shared.currentLanguageID = selectedModel.languageID
        
        onLanguageChanged?(selectedModel.languageID)
    }
}

// MARK: - Model

struct LanguageCellModel {
    let languageID: String
    let languageName: String
    var selected: Bool = false
}

// MARK: - Cell

class LanguageSelectCell: UITableViewCell {
    
    static let reuseID = "LanguageSelectCell"
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Regular16
        label.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        return label
    }()
    
    private lazy var checkmarkView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = createCheckmarkImage()
        return imageView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.addSubview(nameLabel)
        contentView.addSubview(checkmarkView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let contentBounds = contentView.bounds
        nameLabel.frame = CGRect(x: 20, y: 0, width: contentBounds.width - 60, height: contentBounds.height)
        checkmarkView.frame = CGRect(x: contentBounds.width - 40, y: (contentBounds.height - 20) / 2, width: 20, height: 20)
    }
    
    func update(model: LanguageCellModel) {
        nameLabel.text = model.languageName
        checkmarkView.isHidden = !model.selected
    }
    
    private func createCheckmarkImage() -> UIImage? {
        let size = CGSize(width: 20, height: 20)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        let checkColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        context.setStrokeColor(checkColor.cgColor)
        context.setLineWidth(2.5)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 3, y: 10))
        path.addLine(to: CGPoint(x: 8, y: 15))
        path.addLine(to: CGPoint(x: 17, y: 4))
        context.addPath(path.cgPath)
        context.strokePath()
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
