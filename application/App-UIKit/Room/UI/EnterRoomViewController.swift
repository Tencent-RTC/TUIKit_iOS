//
//  TUIRoomViewController.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/20.
//

import SnapKit
import UIKit
import TUIRoomKit
import TUICore
import RTCRoomEngine

class RoomViewController: UIViewController {
    weak var rootView: EnterRoomView?
    private var fieldText: String = ""
    private(set) var inputViewItems: [ListCellItemModel] = []
    private(set) var switchViewItems: [ListCellItemModel] = []
    private let currentUserName: String = TUILogin.getNickName() ?? ""
    private let currentUserId: String = TUILogin.getUserID() ?? ""
    private var roomId: String = ""
    private var enableLocalAudio: Bool = true
    private var enableLocalVideo: Bool = true
    private var isSoundOnSpeaker: Bool = true
    
    let backButton: UIButton = {
        let button = UIButton(type: .custom)
        let normalIcon = UIImage(named: "room_back_white")
        button.setImage(normalIcon, for: .normal)
        button.setTitleColor(UIColor(0xD1D9EC), for: .normal)
        return button
    }()
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
        createItems()
        backButton.addTarget(self, action: #selector(backButtonClick(sender:)), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        let rootView = EnterRoomView()
        rootView.rootViewController = self
        view = rootView
        self.rootView = rootView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        ConferenceSession.sharedInstance.addObserver(observer: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    @objc func backButtonClick(sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    
    deinit {
//        ConferenceSession.sharedInstance.removeObserver(observer: self)
        debugPrint("deinit \(self)")
    }
}

extension RoomViewController {
    private func createItems() {
        let enterRoomIdItem = ListCellItemModel()
        enterRoomIdItem.titleText = .roomNumText
        enterRoomIdItem.fieldEnable = true
        enterRoomIdItem.hasFieldView = true
        enterRoomIdItem.fieldPlaceholderText = .placeholderTipsText
        enterRoomIdItem.action = { [weak self] sender in
            guard let self = self, let view = sender as? UITextField else { return }
            self.fieldText = view.text ?? ""
        }
        inputViewItems.append(enterRoomIdItem)
        
        let userNameItem = ListCellItemModel()
        userNameItem.titleText = .userNameText
        userNameItem.messageText = currentUserName
        userNameItem.hasDownLineView = false
        inputViewItems.append(userNameItem)
        
        let openMicItem = ListCellItemModel()
        openMicItem.titleText = .openMicText
        openMicItem.hasSwitch = true
        openMicItem.isSwitchOn = enableLocalAudio
        openMicItem.action = {[weak self] sender in
            guard let self = self, let view = sender as? UISwitch else { return }
            self.enableLocalAudio = view.isOn
        }
        switchViewItems.append(openMicItem)
        
        let openSpeakerItem = ListCellItemModel()
        openSpeakerItem.titleText = .openSpeakerText
        openSpeakerItem.hasSwitch = true
        openSpeakerItem.isSwitchOn = true
        openSpeakerItem.action = {[weak self] sender in
            guard let self = self, let view = sender as? UISwitch else { return }
            self.isSoundOnSpeaker = view.isOn
        }
        switchViewItems.append(openSpeakerItem)
        
        let openCameraItem = ListCellItemModel()
        openCameraItem.titleText = .openCameraText
        openCameraItem.hasSwitch = true
        openCameraItem.isSwitchOn = enableLocalVideo
        openCameraItem.hasDownLineView = false
        openCameraItem.action = {[weak self] sender in
            guard let self = self, let view = sender as? UISwitch else { return }
            self.enableLocalVideo = view.isOn
        }
        switchViewItems.append(openCameraItem)
    }
    
    func enterButtonClick(sender: UIButton) {
        if fieldText.count <= 0 {
            view.showAtomicToast(text: .enterRoomIdErrorToast)
            return
        }
        let roomIDStr = fieldText
            .replacingOccurrences(of: " ",
                                  with: "",
                                  options: .literal,
                                  range: nil)
        if roomIDStr.count <= 0 {
            view.showAtomicToast(text: .enterRoomIdErrorToast)
            return
        }
        roomId = roomIDStr
        joinConference(roomId: roomId)
    }
    
    private func joinConference(roomId: String) {
//        let vc =  ConferenceMainViewController()
//        let params = JoinConferenceParams(roomId: roomId)
//        params.isOpenMicrophone = enableLocalAudio
//        params.isOpenCamera = enableLocalVideo
//        params.isOpenSpeaker = isSoundOnSpeaker
//        vc.setJoinConferenceParams(params: params)
//        navigationController?.pushViewController(vc, animated: true)
    }
    
}

//extension RoomViewController: ConferenceObserver {
//    func onConferenceJoined(roomInfo: TUIRoomInfo, error: TUIError, message: String) {
//        guard error != .success else { return }
//        navigationController?.popViewController(animated: true)
//        guard !message.isEmpty else { return }
//        SceneDelegate.getCurrentWindow()?.showAtomicToast(message, duration: 1, position:TUICSToastPositionCenter)
//    }
//    
//    func onConferenceFinished(roomInfo: TUIRoomInfo, reason: ConferenceFinishedReason) {
//        debugPrint("onConferenceFinished")
//    }
//    
//    func onConferenceExited(roomInfo: TUIRoomInfo, reason: ConferenceExitedReason) {
//        debugPrint("onConferenceExited")
//    }
//}

private extension String {
    static var enterRoomIdErrorToast: String {
        ("Enter a valid room ID.").localized
    }
    static var placeholderTipsText: String {
        ("Enter a room ID").localized
    }
    static var userNameText: String {
        ("Your Name").localized
    }
    static var roomNumText: String {
        ("Room ID").localized
    }
    static var openCameraText: String {
        ("Video").localized
    }
    static var openMicText: String {
        ("Mic").localized
    }
    static var openSpeakerText: String {
        ("Speaker").localized
    }
}
