//
//  ProfileController.swift
//  mine
//

import UIKit
import AtomicX
import ImSDK_Plus
import Login
import SnapKit
import TUICore
import Toast_Swift

class ProfileController: UIViewController {
    
    var profileData: [[ProfileInfoModel]] = []
    
    private lazy var isRTCApp: Bool = {
        #if RTCUBE_OVERSEAS
        return true
        #else
        return false
        #endif
    }()
    
    var profile: V2TIMUserFullInfo?
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero)
        table.isScrollEnabled = false
        table.dataSource = self
        table.delegate = self
        table.backgroundColor = UIColor.clear
        table.showsVerticalScrollIndicator = false
        table.separatorColor = .clear
        table.register(ProfileTableViewCell.self,
                       forCellReuseIdentifier: ProfileTableViewCell.cellReuseIdentifier)
        return table
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = MineLocalize("Demo.TRTC.Portal.Mine.profileDetail")
        let backBtn = UIButton(type: .custom)
        backBtn.setImage(UIImage(named: "mine_back"), for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        let item = UIBarButtonItem(customView: backBtn)
        item.tintColor = UIColor.black
        navigationItem.leftBarButtonItem = item
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        
        guard let userid = V2TIMManager.sharedInstance()?.getLoginUser() else { return }
        V2TIMManager.sharedInstance().getUsersInfo([userid]) { [weak self] infoList in
            guard let self = self else { return }
            self.profile = infoList?.first ?? profile
            self.configData()
        } fail: { _, _ in }
        
        configData()
        constructViewHierarchy()
        activateConstraints()
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension ProfileController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return profileData.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let rowData = profileData[section]
        return rowData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseID = ProfileTableViewCell.cellReuseIdentifier
        let rowData = profileData[indexPath.section]
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseID, for: indexPath) as! ProfileTableViewCell
        cell.selectionStyle = .none
        cell.config(with: rowData[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let rowData = profileData[indexPath.section]
        let model = rowData[indexPath.row]
        return model.cellHeight
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 8.0
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let rowData = profileData[indexPath.section]
        let model = rowData[indexPath.row]
        model.selectHandler?()
    }
}

// MARK: - Data

extension ProfileController {
    func configData() {
        profileData = [
            [
                ProfileInfoModel(
                    title: MineLocalize("Demo.TRTC.Portal.Mine.profilePhoto"),
                    imageName: profile?.faceURL,
                    cellHeight: navigationFullHeight(),
                    selectHandler: { [weak self] in
                        self?.didSelectChangeHead()
                    }
                ),
            ],
            [
                ProfileInfoModel(
                    title: MineLocalize("Demo.TRTC.Portal.Mine.profileName"),
                    detail: profile?.showName(),
                    cellHeight: 58.0,
                    selectHandler: { [weak self] in
                        self?.didSelectChangeNick()
                    }
                ),
                ProfileInfoModel(
                    title: MineLocalize("Demo.TRTC.Portal.Mine.profileAccount"),
                    detail: profile?.userID,
                    cellHeight: 58.0
                ),
            ],
        ]
        
        let rtcubeData = [
            ProfileInfoModel(
                title: MineLocalize("Demo.TRTC.Portal.Mine.profileSignature"),
                detail: profile?.selfSignature,
                cellHeight: 58.0,
                selectHandler: { [weak self] in
                    self?.didSelectChangeSignature()
                }
            ),
            ProfileInfoModel(
                title: MineLocalize("Demo.TRTC.Portal.Mine.profileGender"),
                detail: profile?.showGender(),
                cellHeight: 58.0,
                selectHandler: { [weak self] in
                    self?.didSelectChangeGender()
                }
            ),
            ProfileInfoModel(
                title: MineLocalize("Demo.TRTC.Portal.Mine.profileBirth"),
                detail: birthString(with: profile?.birthday),
                cellHeight: 58.0,
                selectHandler: { [weak self] in
                    self?.didSelectChangeBirth()
                }
            ),
        ]
        if !isRTCApp {
            profileData.append(rtcubeData)
        }
        tableView.reloadData()
    }
}

// MARK: - View Hierarchy

extension ProfileController {
    func constructViewHierarchy() {
        view.addSubview(tableView)
    }
    
    func activateConstraints() {
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

// MARK: - Profile Edit Actions

extension ProfileController {
    
    @objc func didSelectChangeNick() {
        var viewType = UpdateInfoViewType.hasInput
        if isRTCApp {
            viewType = .noInput
        } else {
            viewType = .hasInput
        }
        let view = ProfileUpdateInfoView(viewType: viewType, oldInfo: profile?.showName())
        view.show(in: self)
        view.submitClosure = { [weak self] newName in
            guard let self = self else { return }
            let info = V2TIMUserFullInfo()
            info.nickName = newName
            V2TIMManager.sharedInstance().setSelfInfo(info: info) { [weak self] in
                guard let self = self else { return }
                self.profile?.nickName = newName
                self.view.makeToast(MineLocalize("Demo.TRTC.Portal.Mine.profileUpdateSucc"))
                self.configData()
            } fail: { code, err in
                self.view.makeToast(MineLocalize("Demo.TRTC.Portal.Mine.profileUpdateFailed"))
                AppLogger.App.warn("updateUserInfoWithUserModel:\(code)==\(String(describing: err))")
            }
        }
    }
    
    @objc func didSelectChangeHead() {
        let avatarVC = AvatarPickerViewController()
        avatarVC.currentAvatarURL = self.profile?.faceURL
        avatarVC.onConfirm = { [weak self] urlString in
            guard let self = self else { return }
            let info = V2TIMUserFullInfo()
            info.faceURL = urlString
            V2TIMManager.sharedInstance().setSelfInfo(info: info) {
                LoginManager.shared.getCurrentUser()?.avatar = urlString
                self.profile?.faceURL = urlString
                self.configData()
            } fail: { code, err in
                self.view.makeToast(MineLocalize("Demo.TRTC.Portal.Mine.profileUpdateFailed"))
                AppLogger.App.warn("updateUserInfoWithUserModel:\(code)==\(String(describing: err))")
            }
        }
        self.navigationController?.pushViewController(avatarVC, animated: true)
    }
    
    @objc func didSelectChangeSignature() {
        let viewType = UpdateInfoViewType.hasInput
        let view = ProfileUpdateInfoView(viewType: viewType, oldInfo: self.profile?.selfSignature)
        view.show(in: self)
        view.submitClosure = { [weak self] newSignature in
            guard let self = self else { return }
            let info = V2TIMUserFullInfo()
            info.selfSignature = newSignature
            V2TIMManager.sharedInstance().setSelfInfo(info: info) { [weak self] in
                guard let self = self else { return }
                self.profile?.selfSignature = newSignature
                self.view.makeToast(MineLocalize("Demo.TRTC.Portal.Mine.profileUpdateSucc"))
                self.configData()
            } fail: { code, err in
                self.view.makeToast(MineLocalize("Demo.TRTC.Portal.Mine.profileUpdateFailed"))
                AppLogger.App.warn("updateUserInfoWithUserModel:\(code)==\(String(describing: err))")
            }
        }
    }
    
    @objc func didSelectChangeGender() {
        let alertController = UIAlertController(
            title: MineLocalize("Demo.TRTC.Portal.Mine.profileEditGender"),
            message: nil,
            preferredStyle: .actionSheet
        )
        let selectMaleAction = UIAlertAction(
            title: MineLocalize("Demo.TRTC.Portal.Mine.profileMaleGender"),
            style: .default
        ) { [weak self] _ in
            self?.setProfile(withGender: .GENDER_MALE)
        }
        let selectFemaleAction = UIAlertAction(
            title: MineLocalize("Demo.TRTC.Portal.Mine.profileFemaleGender"),
            style: .default
        ) { [weak self] _ in
            self?.setProfile(withGender: .GENDER_FEMALE)
        }
        let cancelAction = UIAlertAction(
            title: MineLocalize("Demo.TRTC.Portal.Mine.cancel"),
            style: .cancel
        )
        alertController.addAction(selectMaleAction)
        alertController.addAction(selectFemaleAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
    
    private func setProfile(withGender gender: V2TIMGender) {
        let info = V2TIMUserFullInfo()
        info.gender = gender
        V2TIMManager.sharedInstance().setSelfInfo(info: info) {
            self.profile?.gender = info.gender
            self.configData()
        } fail: { code, message in
            self.view.makeToast(MineLocalize("Demo.TRTC.Portal.Mine.profileUpdateFailed"))
            AppLogger.App.warn("updateUserInfoWithUserModel:\(code)==\(String(describing: message))")
        }
    }
    
    @objc func didSelectChangeBirth() {
        let datePicker = ProfileDatePickerView(
            withProfile: profile,
            frame: CGRect(x: 0, y: 0, width: ScreenWidth, height: ScreenHeight)
        )
        datePicker.confirmClosure = { [weak self] dateStr in
            guard let self = self else { return }
            guard let birthday = UInt32(dateStr) else { return }
            let info = V2TIMUserFullInfo()
            info.birthday = birthday
            V2TIMManager.sharedInstance()?.setSelfInfo(info: info, succ: {
                self.profile?.birthday = birthday
                self.configData()
            }, fail: nil)
        }
        datePicker.hideClosure = {
            datePicker.removeFromSuperview()
        }
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            window.addSubview(datePicker)
        }
    }
}

// MARK: - Navigation

extension ProfileController {
    @objc func backBtnClick() {
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - Birthday Formatter

extension ProfileController {
    func birthString(with birthNum: UInt32?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        guard let birthday = birthNum else {
            let date = Date()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }
        if let date = formatter.date(from: String(birthday)) {
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        } else {
            let date = Date()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }
    }
}
