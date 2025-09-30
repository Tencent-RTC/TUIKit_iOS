//
//  JoinGroupCallViewController.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/13.
//

import Foundation
import UIKit
import RTCRoomEngine

#if canImport(TUICallKit_Swift)
import TUICallKit_Swift
#elseif canImport(TUICallKit)
import TUICallKit
#endif

class JoinGroupCallViewController: UIViewController, UITextFieldDelegate {
    private var callType: TUICallMediaType = .audio
    private var isIntRoom = true
    private let line1View: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor(hex: "EEEEEE")
        return view
    }()
    
    private let groupIdContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor.white
        return view
    }()
    private let groupIdTextLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.black
        label.text = SettingsConfig.share.is1VN ? "输入 CallID: " : ("GroupId").localized
        return label
    }()
    private let groupIdTextField: UITextField = {
        let textField = UITextField(frame: .zero)
        textField.backgroundColor = UIColor.clear
        textField.font = UIFont(name: "PingFangSC-Regular", size: 16)
        textField.textColor = UIColor(hex: "333333")
        textField.attributedPlaceholder = NSAttributedString(string: SettingsConfig.share.is1VN ? "请输入 CallID" : ("InputGroupId").localized)
        textField.textAlignment = .right
        textField.keyboardType = .asciiCapable
        return textField
    }()
    private let roomIdContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor.white
        return view
    }()
    private let roomTypeData = [("RoomIdInt").localized, ("RoomIdString").localized]
    private var roomTypeIndex = 0
    private lazy var roomIdButton: SwiftDropMenuListView = {
        let menu = SwiftDropMenuListView(frame: CGRect.zero)
        let titleStr: String = roomTypeData[roomTypeIndex]
        menu.setTitle(titleStr, for: .normal)
        menu.setTitleColor(.black, for: .normal)
        menu.titleLabel?.font = UIFont(name: "PingFangSC-Medium", size: 16)
        menu.backgroundColor = UIColor.clear
        menu.translatesAutoresizingMaskIntoConstraints = false
        return menu
    }()
    private let roomIdTextField: UITextField = {
        let textField = UITextField(frame: .zero)
        textField.backgroundColor = UIColor.clear
        textField.font = UIFont(name: "PingFangSC-Regular", size: 16)
        textField.textColor = UIColor(hex: "333333")
        textField.attributedPlaceholder = NSAttributedString(string: ("InputRoomId").localized)
        textField.textAlignment = .right
        return textField
    }()
    
    private var currentTextField: UITextField?
    
    private let line2View: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor(hex: "EEEEEE")
        return view
    }()
    
    private let mediaTypeContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor.white
        return view
    }()
    private let typeLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.black
        label.text = ("MediaType").localized
        return label
    }()
    private let videoButton: RadioButton = {
        let button = RadioButton(frame: CGRect.zero)
        button.titleText = ("Video Call").localized
        button.titleSize = 16
        return button
    }()
    private let voiceButton: RadioButton = {
        let button = RadioButton(frame: CGRect.zero)
        button.titleText = ("Audio Call").localized
        button.isSelected = true
        button.titleSize = 16
        return button
    }()
    private lazy var buttons: [RadioButton] = {
        let buttons = [videoButton, voiceButton]
        return buttons
    }()
    private let callButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitleColor(.white, for: .normal)
        btn.setTitle(("Call").localized, for: .normal)
        btn.adjustsImageWhenHighlighted = false
        btn.setBackgroundImage(UIColor(hex: "006EFF")?.trans2Image(), for: .normal)
        btn.titleLabel?.font = UIFont(name: "PingFangSC-Medium", size: 20)
        btn.layer.shadowColor = UIColor(hex: "006EFF")?.cgColor ?? UIColor.blue.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 6)
        btn.layer.shadowRadius = 16
        btn.layer.shadowOpacity = 0.4
        btn.layer.masksToBounds = true
        btn.layer.cornerRadius = 10
        return btn
    }()
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(named: "back"), for: .normal)
        button.tintColor = .black
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        setupNavigationBar()
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }
    
    private func setupNavigationBar() {
        navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.black
        ]
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)
        navigationController?.navigationBar.isHidden = false
    }
    
    private func constructViewHierarchy() {
        view.addSubview(line1View)
        view.addSubview(groupIdContentView)
        groupIdContentView.addSubview(groupIdTextLabel)
        groupIdContentView.addSubview(groupIdTextField)
        
        if (!SettingsConfig.share.is1VN) {
            view.addSubview(roomIdContentView)
            roomIdContentView.addSubview(roomIdTextField)
            roomIdContentView.addSubview(roomIdButton)
            view.addSubview(line2View)
            view.addSubview(mediaTypeContentView)
            mediaTypeContentView.addSubview(typeLabel)
            mediaTypeContentView.addSubview(videoButton)
            mediaTypeContentView.addSubview(voiceButton)
        }
        view.addSubview(callButton)
    }
    
    private func activateConstraints() {
        line1View.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(100.scale375Height())
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(10.scale375Height())
        }
        groupIdContentView.snp.makeConstraints { make in
            make.top.equalTo(line1View.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(50.scale375Height())
        }
        groupIdTextLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(20.scale375Width())
        }
        groupIdTextField.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(groupIdTextLabel.snp.trailing).offset(20.scale375Width())
            make.trailing.equalToSuperview().offset(-20.scale375Width())
        }
        if (!SettingsConfig.share.is1VN) {
            roomIdContentView.snp.makeConstraints { make in
                make.top.equalTo(groupIdTextField.snp.bottom)
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(50.scale375Height())
            }
            roomIdButton.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.equalToSuperview().offset(20.scale375Width())
            }
            roomIdTextField.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.equalTo(roomIdButton.snp.trailing).offset(20.scale375Width())
                make.trailing.equalToSuperview().offset(-20.scale375Width())
            }
            line2View.snp.makeConstraints { make in
                make.top.equalTo(groupIdTextField.snp.bottom).offset(60.scale375Height())
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(10.scale375Height())
            }
            mediaTypeContentView.snp.makeConstraints { make in
                make.top.equalTo(line2View.snp.bottom).offset(20.scale375Height())
                make.leading.trailing.equalToSuperview()
                make.width.equalToSuperview()
                make.height.equalTo(30.scale375Height())
            }
            typeLabel.snp.makeConstraints { make in
                make.top.equalToSuperview()
                make.leading.equalToSuperview().offset(20.scale375Width())
            }
            videoButton.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.equalTo(typeLabel.snp.trailing).offset(40.scale375Width())
            }
            voiceButton.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.equalTo(videoButton.snp.trailing).offset(80.scale375Width())
            }
        }
        callButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-60.scale375Height())
            make.height.equalTo(60.scale375Height())
            make.width.equalToSuperview().offset(-40.scale375Width())
        }
    }
    
    private func bindInteraction() {
        videoButton.addTarget(self, action: #selector(radioButtonTapped), for: .touchUpInside)
        voiceButton.addTarget(self, action: #selector(radioButtonTapped), for: .touchUpInside)
        callButton.addTarget(self, action: #selector(callButtonClick), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(backButtonClick), for: .touchUpInside)
        groupIdTextField.delegate = self
        roomIdButton.delegate = self
        roomIdButton.dataSource = self
        roomIdTextField.delegate = self
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        if let current = currentTextField {
            current.resignFirstResponder()
            currentTextField = nil
        }
    }
    
    @objc private func radioButtonTapped(_ sender: RadioButton) {
        buttons.forEach({ $0.isSelected = false})
        sender.isSelected = true
        if sender == videoButton {
            callType = .video
        } else {
            callType = .audio
        }
    }
    
    @objc private func callButtonClick() {
        guard let roomIdString = roomIdTextField.text else { return }
        guard let groupId = groupIdTextField.text else { return }
        
        if (!SettingsConfig.share.is1VN) {
            if roomIdString.isEmpty || groupId.isEmpty {
                return
            }
        }
        
        let roomId = TUIRoomId()
        if roomTypeIndex == 0 {
            roomId.intRoomId = UInt32(roomIdString) ?? 0
        } else {
            roomId.strRoomId = roomIdString
        }
        
        if (SettingsConfig.share.is1VN) {
            TUICallKit.createInstance().join(callId: groupId)
        } else {
            TUICallKit.createInstance().joinInGroupCall(roomId: roomId, groupId: groupId, callMediaType: callType)
        }
    }
    
    @objc private func backButtonClick() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func settingButtonClick() {
        let settingVC = SettingsViewController()
        settingVC.title = ("CallSettings").localized
        settingVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(settingVC, animated: true)
    }
}

extension JoinGroupCallViewController {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if let last = currentTextField {
            last.resignFirstResponder()
        }
        currentTextField = textField
        textField.becomeFirstResponder()
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
        currentTextField = nil
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension JoinGroupCallViewController: SwiftDropMenuListViewDataSource, SwiftDropMenuListViewDelegate {
    func numberOfItems(in menu: SwiftDropMenuListView) -> Int {
        return roomTypeData.count
    }
    
    func dropMenu(_ menu: SwiftDropMenuListView, titleForItemAt index: Int) -> String {
        return roomTypeData[index]
    }
    
    func heightOfRow(in menu: SwiftDropMenuListView) -> CGFloat {
        return 30
    }
    
    func numberOfColumns(in menu: SwiftDropMenuListView) -> Int {
        return 1
    }
    
    func dropMenu(_ menu: SwiftDropMenuListView, didSelectItem: String?, atIndex index: Int) {
        roomTypeIndex = index
        if index == 0 {
            roomIdButton.setTitle(("RoomIdInt").localized + " >", for: .normal)
        } else {
            roomIdButton.setTitle(("RoomIdString").localized + " >", for: .normal)
        }
        
    }
}
