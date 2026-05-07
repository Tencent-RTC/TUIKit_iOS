//
//  TRTCGroupCallingContactViewController.swift
//  main
//

import UIKit
import Foundation
import Toast_Swift
import TUICallKit_Swift
import RTCRoomEngine
import ImSDK_Plus
import AtomicXCore
import Login
import AtomicX

enum GroupCallingUserRemoveReason: UInt32 {
    case leave = 0
    case reject
    case noresp
    case busy
}

public class TRTCGroupCallingContactViewController: UIViewController {
    var selectedFinished: (([UserModel]) -> Void)? = nil
    var addedUserModel: [UserModel] = []
    var callType: CallMediaType = .audio

    let addedTableTitle: UILabel = {
        let label = UILabel(frame: .zero)
        label.text = CallingLocalize("Demo.TRTC.calling.addedUser")
        label.font = ThemeStore.shared.typographyTokens.Regular16
        label.textColor = UIColor.black
        label.textAlignment = .left
        return label
    }()

    lazy var addedTable: UITableView = {
        let table = UITableView(frame: CGRect.zero, style: .plain)
        table.tableFooterView = UIView(frame: .zero)
        table.backgroundColor = UIColor.clear
        table.register(CallingSelectUserTableViewCell.classForCoder(), forCellReuseIdentifier: "CallingSelectUserTableViewCell")
        table.delegate = self
        table.dataSource = self
        return table
    }()

    lazy var noMembersTip: UILabel = {
        let label = UILabel()
        label.text = CallingLocalize("Demo.TRTC.calling.tips")
        label.numberOfLines = 2
        label.textAlignment = NSTextAlignment.center
        label.textColor = ThemeStore.shared.colorTokens.textColorDisable
        return label
    }()

    lazy var callingContactView: TRTCCallingContactView = {
        let callingContactView = TRTCCallingContactView(frame: .zero, type: .add) { [weak self] users in
            guard let self = self else { return }
            self.adduser(users: users)
        }
        return callingContactView
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        let backBtn = UIButton(type: .custom)
        backBtn.setImage(AppAssemblyBundle.image(named: "calling_back"), for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        let item = UIBarButtonItem(customView: backBtn)
        item.tintColor = UIColor.black
        navigationItem.leftBarButtonItem = item

        let callBtn = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 30))
        callBtn.setTitle(CallingLocalize("Demo.TRTC.calling.done"), for: .normal)
        callBtn.setTitleColor(UIColor.black, for: .normal)
        callBtn.titleLabel?.font = ThemeStore.shared.typographyTokens.Regular16
        callBtn.addTarget(self, action: #selector(showCallVC), for: .touchUpInside)
        let rightItem = UIBarButtonItem(customView: callBtn)
        rightItem.tintColor = UIColor.black
        navigationItem.rightBarButtonItem = rightItem
        setupUI()
    }

    @objc func backBtnClick() {
        navigationController?.popViewController(animated: true)
    }

    @objc func showCallVC() {
        var userIds: [String] = []
        for item in addedUserModel { userIds.append(item.userId) }
        guard userIds.count > 0 else {
            self.view.makeToast(CallingLocalize("Demo.TRTC.calling.tips"))
            return
        }
        TUICallKit.createInstance().calls(userIdList: userIds, mediaType: callType, params: nil, completion: nil)
    }

    deinit { debugPrint("deinit \(self)") }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        hiddenNoMembersImg(isHidden: false)
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    var lastNetworkQualityCallTime: Date?
}

extension TRTCGroupCallingContactViewController {
    func setupUI() {
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        ToastManager.shared.position = .bottom
        hiddenNoMembersImg(isHidden: false)
        addedTable.reloadData()
    }

    func constructViewHierarchy() {
        view.addSubview(addedTableTitle)
        view.addSubview(addedTable)
        view.addSubview(noMembersTip)
        view.addSubview(callingContactView)
    }

    func activateConstraints() {
        addedTableTitle.snp.makeConstraints { make in
            make.topMargin.equalTo(view).offset(20)
            make.leading.equalTo(view).offset(20)
            make.trailing.equalTo(-20)
            make.height.equalTo(20)
        }
        addedTable.snp.makeConstraints { make in
            make.top.equalTo(addedTableTitle.snp.bottom).offset(10)
            make.leading.trailing.equalTo(view)
            make.height.equalTo(200)
        }
        noMembersTip.snp.makeConstraints { make in
            make.top.equalTo(addedTable.bounds.size.height / 3.0)
            make.leading.equalTo(addedTable.bounds.size.width * 154.0 / 375)
            make.trailing.equalTo(-addedTable.bounds.size.width * 154.0 / 375)
            make.height.equalTo(addedTable.bounds.size.width * 67.0 / 375)
        }
        callingContactView.snp.makeConstraints { make in
            make.top.equalTo(addedTable.snp.bottom)
            make.left.right.equalTo(view)
            make.bottomMargin.equalTo(view)
        }
    }

    func bindInteraction() {
        selectedFinished = { [weak self] users in
            guard let self = self else { return }
            self.deleteAddedUser(users: users)
        }
    }

    func deleteAddedUser(users: [UserModel]) {
        guard users.count > 0 else { return }
        if let waitingDeleteUser = users.first {
            if let deleteIndex = addedUserModel.firstIndex(where: { $0.userId == waitingDeleteUser.userId }) {
                addedUserModel.remove(at: deleteIndex)
                addedTable.reloadData()
            }
        }
    }

    func adduser(users: [UserModel]) {
        guard users.count > 0 else { return }
        guard addedUserModel.count < 8 else {
            self.view.makeToast(CallingLocalize("Demo.TRTC.calling.numExceed"))
            return
        }
        var addedFlag = false
        if let waitingAddUser = users.first {
            for _ in addedUserModel.filter({ $0.userId == waitingAddUser.userId }) {
                addedFlag = true
            }
            guard addedFlag == false else { return }
            addedUserModel.append(waitingAddUser)
            addedTable.reloadData()
        }
    }

    @objc func hiddenNoMembersImg(isHidden: Bool) {
        noMembersTip.isHidden = isHidden
    }
}

extension TRTCGroupCallingContactViewController: UITableViewDelegate, UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return addedUserModel.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CallingSelectUserTableViewCell") as! CallingSelectUserTableViewCell
        cell.selectionStyle = .none
        let userModel = addedUserModel[indexPath.row]
        cell.config(model: userModel, type: .delete, selected: false) { [weak self] in
            guard let self = self else { return }
            if let finish = self.selectedFinished {
                finish([userModel])
            }
        }
        return cell
    }

    public func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        view.tintColor = UIColor.clear
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.textColor = UIColor.white
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
}
