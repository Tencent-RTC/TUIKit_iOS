//
//  MineSettingsViewController.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/12.
//

import UIKit
import SnapKit
import RTCCommon
import TUICore
import TIMCommon
import TUIContact

class MineSettingsViewController: UIViewController{
    
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
        return tableView
    }()
    
    private let backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "mine_goback"), for: .normal)
        button.tintColor = .black
        button.sizeToFit()
        return button
    }()
    
    private let dataSource: [MineSettingsModel] = {
        var res : [MineSettingsModel] = []
        let avatar = MineSettingsModel(title: ("Avatar").localized)
        res.append(avatar)
        
        let nickName = MineSettingsModel(title: ("Nickname").localized)
        res.append(nickName)
        
        let language = MineSettingsModel(title: ("Language").localized)
        res.append(language)
        
        return res
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupNavigationBar()
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        tableView.reloadData()
    }
    
    private func setupNavigationBar() {
        self.title = ("Settings").localized
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor : UIColor.black,
            .font: UIFont(name: "PingFangSC-Semibold", size: 18) ?? UIFont.systemFont(ofSize: 18)
        ]
        let item = UIBarButtonItem(customView: backButton)
        navigationItem.leftBarButtonItem = item
    }
    
    private func constructViewHierarchy() {
        view.addSubview(tableView)
    }

    private func activateConstraints() {
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func bindInteraction() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MineSettingsTableViewCell.self, forCellReuseIdentifier: "MineSettingsTableViewCell")
        backButton.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
    }
    
    @objc private func backBtnClick() {
        navigationController?.popViewController(animated: true)
    }
    
    var currentUserInfo: V2TIMUserFullInfo?
    @objc func didSelectChangeHead() {
        let avatarVC = TUISelectAvatarController()
        avatarVC.selectAvatarType = .userAvatar
        avatarVC.profilFaceURL = TUILogin.getFaceUrl() ?? ""
        self.navigationController?.pushViewController(avatarVC, animated: true)
        avatarVC.selectCallBack = { [weak self] urlString in
            guard let self = self, let userID = TUILogin.getUserID() else { return }
            let info = V2TIMUserFullInfo()
            info.faceURL = urlString
            V2TIMManager.sharedInstance().setSelfInfo(info: info) {
                V2TIMManager.sharedInstance().getUsersInfo([userID]) { userInfos in
                    self.currentUserInfo = userInfos?.first
                    self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
                } fail: { _,_  in
                    self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
                }
            } fail: { code, err in
                self.view.makeToast(("profileUpdateFailed").localized)
            }
        }
    }
    
    @objc func didSelectChangeNick() {
        let view = ProfileUpdateInfoView(oldInfo: TUILogin.getNickName())
        view.show(in: self)
        view.submitClosure = { [weak self] newName in
            guard let self = self, let userID = TUILogin.getUserID() else { return }
            let info = V2TIMUserFullInfo()
            info.nickName = newName
            V2TIMManager.sharedInstance().setSelfInfo(info: info) {
                V2TIMManager.sharedInstance().getUsersInfo([userID]) { userInfos in
                    self.currentUserInfo = userInfos?.first
                    self.tableView.reloadRows(at: [IndexPath(row: 1, section: 0)], with: .none)
                } fail: { _,_ in
                    self.tableView.reloadRows(at: [IndexPath(row: 1, section: 0)], with: .none)
                }
            } fail: { code, err in
                self.view.makeToast(("profileUpdateFailed").localized)
                debugPrint("updateUserInfoWithUserModel:\(code)==\(String(describing: err))")
            }
        }
    }
    
    @objc func didSelectChangeLanguage() {
        let vc = LanguageSelectViewController()
        vc.delegate = self
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension MineSettingsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = dataSource[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "MineSettingsTableViewCell", for: indexPath)
        if let scell = cell as? MineSettingsTableViewCell {
            scell.titleLabel.text = model.title
            if indexPath.row == 0 {
                scell.avatarImageView.isHidden = false
                scell.nicknameLabel.isHidden = true
                let faceUrl = currentUserInfo?.faceURL ?? TUILogin.getFaceUrl() ?? ""
                if let avatarUrl = URL(string: faceUrl), !faceUrl.isEmpty {
                    scell.avatarImageView.kf.setImage(with: avatarUrl, placeholder: UIImage(named: "default_avatar"))
                } else {
                    scell.avatarImageView.image = UIImage(named: "default_avatar")
                }
            } else if indexPath.row == 1 { 
                scell.avatarImageView.isHidden = true
                scell.nicknameLabel.isHidden = false
                let nick = currentUserInfo?.nickName ?? TUILogin.getNickName()
                scell.nicknameLabel.text = (nick ?? "").isEmpty ? "No nickname".localized : nick
            } else {
                scell.avatarImageView.isHidden = true
                scell.nicknameLabel.isHidden = true
            }
        }
        return cell
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
    }
}
extension MineSettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            didSelectChangeHead()
        } else if indexPath.row == 1 {
            didSelectChangeNick()
        } else if indexPath.row == 2 {
            didSelectChangeLanguage() 
        }
    }
}

extension MineSettingsViewController: LanguageSelectViewControllerDelegate {
    func onSelectLanguage(cellModel: LanguageSelectCellModel) {
        DispatchQueue.main.async {
            guard let appDelegate = ApplicationUtils.shared.appDelegate as? AppDelegate else{ return}
            appDelegate.showMainViewController()
        }
    }
}
