//
//  LanguageSelectViewController.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/18.
//

import UIKit
import TUICore

protocol LanguageSelectViewControllerDelegate: NSObjectProtocol {
    func onSelectLanguage(cellModel: LanguageSelectCellModel) -> Void
}

class LanguageSelectViewController: UIViewController {
    
    weak var delegate: LanguageSelectViewControllerDelegate?
    private var dataSource: [LanguageSelectCellModel] = []
    
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
        return tableView
    }()
    
    private func configData() -> () {
        self.dataSource = [
            LanguageSelectCellModel(languageID: "zh-Hans", languageName: "简体中文", selected: false),
            LanguageSelectCellModel(languageID: "en", languageName: "English", selected: false),
        ]
        
        let languageID = TUIGlobalization.getPreferredLanguage()
        
        for (index, model) in self.dataSource.enumerated() where languageID == model.languageID {
            self.dataSource[index].selected = true
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        self.title = "Change Language".localized
        configData()
        setupNavigationBackButton()
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }

    private func constructViewHierarchy() {
        view.addSubview(tableView)
    }
    
    private func activateConstraints() {
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
    
    private func bindInteraction() {
        tableView.register(LanguageSelectCell.self, forCellReuseIdentifier: "LanguageSelectCell")
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    private func setupNavigationBackButton() -> () {
        let backBtn = UIButton(type: .custom)
        backBtn.setImage(UIImage(named: "back"), for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        backBtn.sizeToFit()
        let item = UIBarButtonItem(customView: backBtn)
        item.tintColor = .black
        navigationItem.leftBarButtonItem = item
    }
    
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    @objc private func backBtnClick() {
        navigationController?.popViewController(animated: true)
    }
}

extension LanguageSelectViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = dataSource[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "LanguageSelectCell", for: indexPath)
        if let cell = cell as? LanguageSelectCell {
            cell.nameLabel.text = model.languageName
            cell.chooseIconView.isHidden = !model.selected
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
    }
}

extension LanguageSelectViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellModel = self.dataSource[indexPath.row]
        TUIGlobalization.setPreferredLanguage(cellModel.languageID)
        self.dataSource[indexPath.row].selected = true
        for (index, model) in self.dataSource.enumerated() {
            if (index != indexPath.row && model.selected) {
                self.dataSource[index].selected = false
            }
        }
        tableView.reloadData()
        self.delegate?.onSelectLanguage(cellModel: cellModel)
    }
    
}
