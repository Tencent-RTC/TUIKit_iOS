//
//  TRTCCallingContactView.swift
//  main
//

import UIKit
import Foundation
import Toast_Swift
import TUICallKit_Swift
import RTCRoomEngine
import ImSDK_Plus
import TUICore
import AtomicXCore
import Login
import AtomicX

enum TRTCCallingUserRemoveReason: UInt32 {
    case leave = 0
    case reject
    case noresp
    case busy
}

public class TRTCCallingContactView: UIView {
    var selectedFinished: (([UserModel]) -> Void)? = nil
    var gotoGuideVCHandler: () -> Void = {}
    var btnType: CallingSelectUserButtonType = .call
    var callType: CallMediaType = .audio

    var shouldShowSearchResult: Bool = false {
        didSet {
            if oldValue != shouldShowSearchResult {
                selectTable.reloadData()
            }
        }
    }

    var searchResult: UserModel? = nil

    private let callingGuideView: CallingDetaiGuideView = {
        let view = CallingDetaiGuideView(frame: .zero)
        view.isHidden = false
        return view
    }()

    let searchContainerView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        view.layer.cornerRadius = ThemeStore.shared.borderRadius.radius20
        return view
    }()

    lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundImage = UIImage()
        searchBar.placeholder = CallingLocalize("Demo.TRTC.calling.searchID")
        searchBar.barTintColor = UIColor.clear
        searchBar.backgroundColor = UIColor.clear
        searchBar.returnKeyType = .search

        if LoginManager.shared.currentUser?.isMoa() == true {
            searchBar.keyboardType = .default
        } else {
            searchBar.keyboardType = .phonePad
        }

        searchBar.layer.cornerRadius = 0
        return searchBar
    }()

    lazy var searchBtn: UIButton = {
        let done = UIButton(type: .custom)
        done.setTitle(CallingLocalize("Demo.TRTC.calling.searching"), for: .normal)
        done.setTitleColor(ThemeStore.shared.colorTokens.buttonColorPrimaryDefault, for: .normal)
        done.titleLabel?.font = ThemeStore.shared.typographyTokens.Bold14
        done.clipsToBounds = true
        done.layer.cornerRadius = ThemeStore.shared.borderRadius.radius20
        return done
    }()

    lazy var userInfoMarkView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.textColorTertiary
        view.layer.cornerRadius = 1.5
        view.isHidden = true
        return view
    }()

    let userInfoLabel: UILabel = {
        let label = UILabel(frame: .zero)
        let copyStr = CallingLocalize("Demo.TRTC.calling.contactCopy")
        let str = CallingLocalize("Demo.TRTC.calling.yourID") + " "
            + (LoginManager.shared.getCurrentUser()?.userId ?? "") + "  "
            + copyStr
        let font = ThemeStore.shared.typographyTokens.Regular12
        let fontAttr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ThemeStore.shared.colorTokens.textColorPrimary]
        let contentAttrStr = NSMutableAttributedString(string: str, attributes: fontAttr)
        let newColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault
        let newColorAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: newColor]
        contentAttrStr.addAttributes(newColorAttributes,
                                     range: NSRange(location: str.count - copyStr.count,
                                                    length: copyStr.count))
        label.isUserInteractionEnabled = true
        label.attributedText = contentAttrStr
        return label
    }()

    lazy var selectTable: UITableView = {
        let table = UITableView(frame: CGRect.zero, style: .plain)
        table.tableFooterView = UIView(frame: .zero)
        table.backgroundColor = UIColor.clear
        table.register(CallingSelectUserTableViewCell.classForCoder(), forCellReuseIdentifier: "CallingSelectUserTableViewCell")
        table.delegate = self
        table.dataSource = self
        return table
    }()

    let kUserBorder: CGFloat = 44.0
    let kUserSpacing: CGFloat = 2
    let kUserPanelLeftSpacing: CGFloat = 28

    lazy var noSearchImageView: UIImageView = {
        let imageView = UIImageView(image: AppAssemblyBundle.image(named: "noSearchMembers"))
        imageView.isUserInteractionEnabled = false
        return imageView
    }()

    lazy var noMembersTip: UILabel = {
        let label = UILabel()
        label.text = CallingLocalize("Demo.TRTC.calling.searchandcall")
        label.numberOfLines = 2
        label.textAlignment = NSTextAlignment.center
        label.textColor = ThemeStore.shared.colorTokens.textColorDisable
        return label
    }()

    public init(frame: CGRect = .zero, type: CallingSelectUserButtonType, selectHandle: @escaping ([UserModel]) -> Void) {
        super.init(frame: frame)
        btnType = type
        selectedFinished = selectHandle
        backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        setupUI()
        registerButtonTouchEvents()
        hiddenNoMembersImg(isHidden: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        debugPrint("deinit \(self)")
        NotificationCenter.default.removeObserver(self)
    }

    var lastNetworkQualityCallTime: Date?
}

extension TRTCCallingContactView {

    func setupUI() {
        constructViewHierarchy()
        activateConstraints()
        setupUIStyle()
        hiddenNoMembersImg(isHidden: false)
        selectTable.reloadData()
        bindInteraction()
    }

    func constructViewHierarchy() {
        addSubview(searchContainerView)
        searchContainerView.addSubview(searchBar)
        searchContainerView.addSubview(searchBtn)
        addSubview(userInfoMarkView)
        addSubview(userInfoLabel)
        addSubview(selectTable)
        selectTable.isHidden = true
        addSubview(noSearchImageView)
        addSubview(noMembersTip)
        addSubview(callingGuideView)
    }

    func activateConstraints() {
        searchContainerView.snp.makeConstraints { make in
            if #available(iOS 11.0, *) {
                make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(20)
            } else {
                make.top.equalToSuperview().offset(20)
            }
            make.leading.equalTo(20)
            make.trailing.equalTo(-20)
            make.height.equalTo(40)
        }
        searchBar.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview()
            make.trailing.equalTo(searchBtn.snp.leading)
        }
        searchBtn.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.trailing.equalToSuperview().offset(-16)
            make.width.equalTo(60)
        }
        userInfoMarkView.snp.makeConstraints { make in
            make.centerY.equalTo(userInfoLabel)
            make.leading.equalTo(20)
            make.size.equalTo(CGSize(width: 3, height: 12))
        }
        userInfoLabel.snp.makeConstraints { make in
            make.top.equalTo(searchContainerView.snp.bottom).offset(20)
            make.leading.equalTo(userInfoMarkView).offset(8)
            make.trailing.equalTo(-20)
            make.height.equalTo(20)
        }
        selectTable.snp.makeConstraints { make in
            make.top.equalTo(userInfoLabel.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview()
            make.bottomMargin.equalToSuperview()
        }
        noSearchImageView.snp.makeConstraints { make in
            make.top.equalTo(self.bounds.size.height / 3.0)
            make.leading.equalTo(self.bounds.size.width * 154.0 / 375)
            make.trailing.equalTo(-self.bounds.size.width * 154.0 / 375)
            make.height.equalTo(self.bounds.size.width * 67.0 / 375)
        }
        noMembersTip.snp.makeConstraints { make in
            make.top.equalTo(noSearchImageView.snp.bottom)
            make.width.equalTo(self.bounds.size.width)
            make.height.equalTo(60)
        }
        callingGuideView.snp.makeConstraints { make in
            make.top.equalTo(userInfoLabel.snp.bottom).offset(102)
            make.centerX.equalToSuperview()
            make.height.equalTo(201)
            make.width.equalTo(184)
        }
    }

    func bindInteraction() {
        callingGuideView.guideButtonClickHandler = { [weak self] in
            guard let self = self else { return }
            self.gotoGuideVCHandler()
        }
        let tap = UITapGestureRecognizer(target: self, action: #selector(copyUserIDClicked))
        userInfoLabel.isUserInteractionEnabled = true
        userInfoLabel.addGestureRecognizer(tap)
    }

    func setupUIStyle() {
        let textfield = searchBar.searchTextField
        textfield.layer.cornerRadius = 0
        textfield.layer.masksToBounds = true
        textfield.textColor = UIColor.black
        textfield.font = ThemeStore.shared.typographyTokens.Regular14
        textfield.backgroundColor = UIColor.clear
        textfield.borderStyle = .none
        textfield.leftViewMode = .always
        textfield.adjustsFontSizeToFitWidth = true
        textfield.minimumFontSize = 10
        ToastManager.shared.position = .bottom
    }

    func showCallVC(users: [String]) {
        TUICallKit.createInstance().calls(userIdList: users, mediaType: callType, params: nil, completion: nil)
    }

    @objc func hiddenNoMembersImg(isHidden: Bool) {
        selectTable.isHidden = !isHidden
        noSearchImageView.isHidden = isHidden
        noMembersTip.isHidden = isHidden
    }
}

extension TRTCCallingContactView: UITextFieldDelegate, UISearchBarDelegate {

    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        hiddenNoMembersImg(isHidden: false)
    }

    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        if let input = searchBar.text, input.count > 0 {
            searchUser(input: input)
        }
    }

    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchBar.text == nil || searchBar.text?.count ?? 0 == 0 {
            shouldShowSearchResult = false
            hiddenNoMembersImg(isHidden: false)
        }

        if (searchBar.text?.count ?? 0) > 11 {
            searchBar.text = (searchBar.text as NSString?)?.substring(to: 11)
        }
    }

    public func searchUser(input: String) {
        if LoginManager.shared.getCurrentUser() != nil &&
            UserOverdueLogicManager.sharedManager().userOverdueState == .alreadyLogged
        {
#if RTCUBE_LAB
            V2TIMManager.sharedInstance()?.getUsersInfo([input], succ: { [weak self] infos in
                guard let self = self else { return }
                if let info = infos?.first {
                    let userModel = UserModel(userId: info.userID ?? "",
                                              name: info.nickName ?? "",
                                              avatar: info.faceURL ?? "")
                    self.searchResult = userModel
                    if self.searchResult != nil {
                        self.shouldShowSearchResult = true
                        self.selectTable.reloadData()
                        self.hiddenNoMembersImg(isHidden: true)
                        self.callingGuideView.isHidden = true
                    }
                }
            }, fail: { code, err in
                self.searchResult = nil
                self.callingGuideView.isHidden = false
                self.makeToast(err)
                if UserOverdueLogicManager.sharedManager().userOverdueState == .notLogin {
                    self.makeToast(CallingLocalize("Demo.TRTC.Portal.Main.LoginFailed"))
                }
            })
#else
            let param = ["searchUserId": input]
            LoginNetworkManager.userQueryUserId(param: param, resultCallback: { [weak self] code, errorMessage, result in
                guard let self = self else { return }
                if code == kAppLoginServiceSuccessCode {
                    guard let model = result["jsonModel"] as? HttpJsonModel else {
                        return
                    }
                    if let bsUser = model.searchUserModel {
                        self.searchResult = UserModel(userId: bsUser.userId,
                                                      name: bsUser.name,
                                                      avatar: bsUser.avatar)
                    }
                    if self.searchResult != nil {
                        self.shouldShowSearchResult = true
                        self.selectTable.reloadData()
                        self.hiddenNoMembersImg(isHidden: true)
                        self.callingGuideView.isHidden = true
                    }
                } else {
                    self.searchResult = nil
                    self.callingGuideView.isHidden = false
                    self.makeToast(errorMessage)
                    if UserOverdueLogicManager.sharedManager().userOverdueState == .notLogin {
                        self.makeToast(CallingLocalize("Demo.TRTC.Portal.Main.LoginFailed"))
                    }
                }
            })
#endif
        }
    }
}

extension TRTCCallingContactView: UITableViewDelegate, UITableViewDataSource {

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if shouldShowSearchResult {
            return 1
        }
        return 0
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CallingSelectUserTableViewCell") as! CallingSelectUserTableViewCell
        cell.selectionStyle = .none
        if shouldShowSearchResult {
            if let userModel = searchResult {
                cell.config(model: userModel, type: btnType, selected: false) { [weak self] in
                    guard let self = self else { return }
                    if userModel.userId == V2TIMManager.sharedInstance()?.getLoginUser() {
                        self.makeToast(CallingLocalize("Demo.TRTC.calling.cantinviteself"))
                        return
                    }
                    if let finish = self.selectedFinished {
                        finish([userModel])
                    }
                }
            } else {
                debugPrint("not search result")
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

extension TRTCCallingContactView {

    private func registerButtonTouchEvents() {
        searchBtn.addTarget(self, action: #selector(searchBtnTouchEvent(sender:)), for: .touchUpInside)
    }

    @objc private func searchBtnTouchEvent(sender: UIButton) {
        self.searchBar.resignFirstResponder()
        if let input = self.searchBar.text, input.count > 0 {
            self.searchUser(input: input)
        }
    }

    @objc private func copyUserIDClicked() {
        if let stringToCopy = LoginManager.shared.getCurrentUser()?.userId {
            UIPasteboard.general.string = stringToCopy
            self.makeToast(CallingLocalize("Demo.TRTC.calling.guideCopySucess"))
        } else {
            self.makeToast(CallingLocalize("Demo.TRTC.calling.IDCopyFailed"))
        }
    }
}
