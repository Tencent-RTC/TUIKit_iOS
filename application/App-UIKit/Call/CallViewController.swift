//
//  CallViewController.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/8.
//

import Foundation
import UIKit
import RTCRoomEngine

#if canImport(TUICallKit_Swift)
import TUICallKit_Swift
#elseif canImport(TUICallKit)
import TUICallKit
#endif

class CallViewController: UIViewController, UITextFieldDelegate {
    private var callType: TUICallMediaType = .audio
    
    private let line1View: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor(hex: "EEEEEE")
        return view
    }()
    private let groupIdContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor.white
        view.isHidden = true
        return view
    }()
    private let groupIdTextLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.black
        label.text = ("Group ID").localized
        return label
    }()
    private let groupIdTextField: UITextField = {
        let textField = UITextField(frame: .zero)
        textField.backgroundColor = UIColor.clear
        textField.font = UIFont(name: "PingFangSC-Regular", size: 16)
        textField.textColor = UIColor(hex: "333333")
        textField.attributedPlaceholder = NSAttributedString(string: ("InputGroupId").localized)
        textField.textAlignment = .right
        textField.keyboardType = .asciiCapable
        return textField
    }()
    private let userIdContentView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor.white
        return view
    }()
    private let userIdTextLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.black
        label.text = ("User ID".localized)
        return label
    }()
    private let calledUserIdTextField: UITextField = {
        let textField = UITextField(frame: .zero)
        textField.backgroundColor = UIColor.clear
        textField.font = UIFont(name: "PingFangSC-Regular", size: 16)
        textField.textColor = UIColor(hex: "333333")
        textField.attributedPlaceholder = NSAttributedString(string:("InputUserIds").localized)
        textField.textAlignment = .right
        textField.keyboardType = .asciiCapable
        return textField
    }()
    
    weak var currentTextField: UITextField?
    
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
    private let callSettingsLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.blue
        label.text = "\(("CallSettings").localized)  >"
        label.isUserInteractionEnabled = true
        return label
    }()
    
    private let optionalParamLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.blue
        label.text = "\(("OptionalParameters").localized)  >"
        label.isUserInteractionEnabled = true
        return label
    }()
    
    private let joinInGroupLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.blue
        label.text = ("JoinGroupCall").localized
        label.isUserInteractionEnabled = true
        return label
    }()
    private let callButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitleColor(.white, for: .normal)
        btn.setTitle(("App_Call").localized, for: .normal)
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    private func setupNavigationBar() {
        navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.black
        ]
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)
    }
    
    private func constructViewHierarchy() {
        view.addSubview(line1View)
        
        view.addSubview(userIdContentView)
        userIdContentView.addSubview(calledUserIdTextField)
        userIdContentView.addSubview(userIdTextLabel)

        view.addSubview(mediaTypeContentView)
        mediaTypeContentView.addSubview(typeLabel)
        mediaTypeContentView.addSubview(videoButton)
        mediaTypeContentView.addSubview(voiceButton)

        view.addSubview(line2View)
        view.addSubview(optionalParamLabel)
        view.addSubview(groupIdContentView)
        groupIdContentView.addSubview(groupIdTextLabel)
        groupIdContentView.addSubview(groupIdTextField)
        
        view.addSubview(callSettingsLabel)
        view.addSubview(callButton)
    }
    
    private func activateConstraints() {
        line1View.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(100.scale375Height())
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(10.scale375Height())
        }
        
        userIdContentView.snp.makeConstraints { make in
            make.top.equalTo(line1View.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(50.scale375Height())
        }
        userIdTextLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(20.scale375Width())
            make.width.equalTo(80.scale375Width())
        }
        calledUserIdTextField.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(userIdTextLabel.snp.trailing).offset(20.scale375Width())
            make.trailing.equalToSuperview().offset(-20.scale375Width())
        }

        mediaTypeContentView.snp.makeConstraints { make in
            make.top.equalTo(userIdContentView.snp.bottom).offset(20)
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

        line2View.snp.makeConstraints { make in
            make.top.equalTo(mediaTypeContentView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(10.scale375Height())
        }

        optionalParamLabel.snp.makeConstraints { make in
            make.top.equalTo(line2View.snp.bottom).offset(10.scale375Height())
            make.leading.equalToSuperview().offset(20.scale375Width())
            make.trailing.equalToSuperview()
            make.height.equalTo(30.scale375Height())
        }
        
        groupIdContentView.snp.makeConstraints { make in
            make.top.equalTo(optionalParamLabel.snp.bottom)
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
        
        callSettingsLabel.snp.makeConstraints { make in
            make.top.equalTo(optionalParamLabel.snp.bottom).offset(100.scale375Height())
            make.centerX.equalToSuperview()
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
        backButton.addTarget(self, action: #selector(backButtonClick), for: .touchUpInside)
        callButton.addTarget(self, action: #selector(callButtonClick), for: .touchUpInside)
        
        let optionalParamLabelTapGesture = UITapGestureRecognizer(target: self, action: #selector(callSettingsLabelClick))
        optionalParamLabel.addGestureRecognizer(optionalParamLabelTapGesture)
        
        let callSettingsLabelTapGesture = UITapGestureRecognizer(target: self, action: #selector(settingButtonClick))
        callSettingsLabel.addGestureRecognizer(callSettingsLabelTapGesture)
        
        let joinInGroupLabelTapGesture = UITapGestureRecognizer(target: self, action: #selector(joinInGroupClick))
        joinInGroupLabel.addGestureRecognizer(joinInGroupLabelTapGesture)
                
        calledUserIdTextField.delegate = self
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        super.touchesBegan(touches, with: event)
        
        if let current = currentTextField {
            current.resignFirstResponder()
            currentTextField = nil
        }
    }
    
    @objc private func callSettingsLabelClick() {
        if groupIdContentView.isHidden {
            groupIdContentView.isHidden = false
            optionalParamLabel.text = "\(("OptionalParameters").localized)  v"
        } else {
            groupIdContentView.isHidden = true
            optionalParamLabel.text = "\(("OptionalParameters").localized)  >"
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
        guard let userIdArray = calledUserIdTextField.text else { return }
        guard let groupId = groupIdTextField.text else { return }
        
        if userIdArray.isEmpty {
            return
        }
        let userIds = userIdArray.components(separatedBy: ",")
        
        let params = TUICallParams()
        params.timeout = Int32(SettingsConfig.share.timeout)
        params.userData = SettingsConfig.share.userData
        params.offlinePushInfo = SettingsConfig.share.pushInfo
        
        let roomId = TUIRoomId()
        roomId.intRoomId = SettingsConfig.share.intRoomId
        roomId.strRoomId = SettingsConfig.share.strRoomId
        params.roomId = roomId
        
        if !groupId.isEmpty {
            params.chatGroupId = groupId
        }
        
        TUICallKit.createInstance().calls(userIdList: userIds, callMediaType: callType, params: params){
            
        } fail: { code, message in
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
    
    @objc private func joinInGroupClick() {
        let joinInGroupVC = JoinGroupCallViewController()
        joinInGroupVC.title = ("JoinGroupCall").localized
        joinInGroupVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(joinInGroupVC, animated: true)
    }
}

extension CallViewController {
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


