//
//  RoomJoinView.swift
//  TUIRoomKit
//
//  Created on 2025/11/13.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import AtomicXCore
import Combine

public class RoomJoinView: UIView, BaseView {
    
    // MARK: - Properties
    public weak var routerContext: RouterContext?
    private var cancellableSet = Set<AnyCancellable>()
    private var connectConfig: ConnectConfig = ConnectConfig()
    
    // MARK: - UI Components
    private lazy var backButtonContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        return view
    }()
    
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(ResourceLoader.loadImage("back_arrow"), for: .normal)
        button.isUserInteractionEnabled = false
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = .joinRoom
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        label.textColor = RoomColors.g2
        return label
    }()
    
    private lazy var roomIdCardView: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.cardBackground
        view.layer.cornerRadius = RoomCornerRadius.large
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var roomIDLabel: UILabel = {
        let label = UILabel()
        label.text = .roomID
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        label.textColor = RoomColors.g3
        return label
    }()
    
    private lazy var roomIDTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = .enterRoomID
        textField.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        textField.textColor = RoomColors.g2
        textField.keyboardType = .numberPad
       
        if let placeholder = textField.placeholder {
            textField.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [
                    .foregroundColor: RoomColors.g6,
                    .font: RoomFonts.pingFangSCFont(size: 16, weight: .medium)
                ]
            )
        }
        
        return textField
    }()
    
    private lazy var formCardView: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.cardBackground
        view.layer.cornerRadius = RoomCornerRadius.large
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var yourNameLabel: UILabel = {
        let label = UILabel()
        label.text = .yourName
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        label.textColor = RoomColors.g3
        return label
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        label.textColor = RoomColors.g2
        return label
    }()
    
    private lazy var microphoneLabel: UILabel = {
        let label = UILabel()
        label.text = .enableAudio
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        label.textColor = RoomColors.g3
        return label
    }()
    
    private lazy var microphoneSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.onTintColor = RoomColors.brandBlue
        return toggle
    }()
    
    private lazy var speakerLabel: UILabel = {
        let label = UILabel()
        label.text = .enableSpeaker
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        label.textColor = RoomColors.g3
        return label
    }()
    
    private lazy var speakerSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.onTintColor = RoomColors.brandBlue
        return toggle
    }()
    
    private lazy var cameraLabel: UILabel = {
        let label = UILabel()
        label.text = .enableVideo
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        label.textColor = RoomColors.g3
        return label
    }()
    
    private lazy var cameraSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.onTintColor = RoomColors.brandBlue
        return toggle
    }()
    
    private lazy var dividerLine1: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g8
        return view
    }()
    
    private lazy var dividerLine2: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g8
        return view
    }()
    
    private lazy var dividerLine3: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g8
        return view
    }()
    
    private lazy var joinRoomButton: UIButton = {
        let button = UIButton(type: .custom)
        button.layer.cornerRadius = 10
        button.clipsToBounds = true
        button.backgroundColor = RoomColors.brandBlue
        button.setTitle(.joinRoom, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 16, weight: .semibold)
        return button
    }()
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        setupStoreObservers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - BaseView Implementation
    public func setupViews() {
        addSubview(backButtonContainerView)
        backButtonContainerView.addSubview(backButton)
        backButtonContainerView.addSubview(titleLabel)
        addSubview(roomIdCardView)
        addSubview(formCardView)
        
        roomIdCardView.addSubview(roomIDLabel)
        roomIdCardView.addSubview(roomIDTextField)
        roomIdCardView.addSubview(dividerLine1)
        roomIdCardView.addSubview(yourNameLabel)
        roomIdCardView.addSubview(nameLabel)
        
        formCardView.addSubview(microphoneLabel)
        formCardView.addSubview(microphoneSwitch)
        formCardView.addSubview(dividerLine2)
        formCardView.addSubview(speakerLabel)
        formCardView.addSubview(speakerSwitch)
        formCardView.addSubview(dividerLine3)
        formCardView.addSubview(cameraLabel)
        formCardView.addSubview(cameraSwitch)
        
        addSubview(joinRoomButton)
    }
    
    public func setupConstraints() {
        backButtonContainerView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.right.equalTo(titleLabel.snp.right).offset(20)
            make.height.equalTo(60)
        }
        
        backButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.top.equalToSuperview().offset(22)
            make.width.height.equalTo(16)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(backButton.snp.right).offset(12)
            make.centerY.equalTo(backButton)
        }
        
        roomIdCardView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.right.equalToSuperview().offset(-12)
            make.top.equalTo(titleLabel.snp.bottom).offset(42)
            make.height.equalTo(109)
        }
        
        roomIDLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(21)
            make.height.equalTo(20)
            make.width.equalTo(90)
        }
        
        roomIDTextField.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.left.equalTo(roomIDLabel.snp.right).offset(20)
            make.centerY.equalTo(roomIDLabel)
            make.height.equalTo(20)
        }
        
        dividerLine1.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.height.equalTo(1)
        }
        
        yourNameLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.top.equalTo(dividerLine1.snp.bottom).offset(18)
            make.height.equalTo(20)
            make.width.equalTo(90)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.left.equalTo(roomIDLabel.snp.right).offset(20)
            make.centerY.equalTo(yourNameLabel)
            make.height.equalTo(20)
        }
        
        formCardView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.right.equalToSuperview().offset(-12)
            make.top.equalTo(roomIdCardView.snp.bottom).offset(20)
            make.height.equalTo(166)
        }
        
        microphoneLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(18)
            make.height.equalTo(20)
        }
        
        microphoneSwitch.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalTo(microphoneLabel)
        }
        
        dividerLine2.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.top.equalTo(microphoneLabel.snp.bottom).offset(18)
            make.height.equalTo(1)
        }
        
        speakerLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.top.equalTo(dividerLine2.snp.bottom).offset(18)
            make.height.equalTo(20)
        }
        
        speakerSwitch.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalTo(speakerLabel)
        }
        
        dividerLine3.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.top.equalTo(speakerLabel.snp.bottom).offset(18)
            make.height.equalTo(1)
        }
        
        cameraLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.top.equalTo(dividerLine3.snp.bottom).offset(18)
            make.height.equalTo(20)
        }
        
        cameraSwitch.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalTo(cameraLabel)
        }
        
        joinRoomButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(formCardView.snp.bottom).offset(48)
            make.size.equalTo(CGSize(width: 200, height: 52))
        }
    }
    
    public func setupStyles() {
        backgroundColor = RoomColors.themeBackground
        microphoneSwitch.isOn = connectConfig.autoEnableMicrophone
        speakerSwitch.isOn = connectConfig.autoEnableSpeaker
        cameraSwitch.isOn = connectConfig.autoEnableCamera
    }
    
    public func setupBindings() {
        let backTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackButtonTapped))
        backButtonContainerView.addGestureRecognizer(backTapGesture)
        
        let dismissKeyboardGesture = UITapGestureRecognizer(target: self, action: #selector(handleDismissKeyboard))
        dismissKeyboardGesture.cancelsTouchesInView = false
        addGestureRecognizer(dismissKeyboardGesture)
        
        joinRoomButton.addTarget(self, action: #selector(handleJoinRoomButtonTapped), for: .touchUpInside)
        microphoneSwitch.addTarget(self, action: #selector(handleMicrophoneSwitchChanged(sender:)), for: .valueChanged)
        speakerSwitch.addTarget(self, action: #selector(handleSpeakerSwitchChanged(sender:)), for: .valueChanged)
        cameraSwitch.addTarget(self, action: #selector(handleCameraSwitchChanged(sender:)), for: .valueChanged)
        
        roomIDTextField.delegate = self
    }
    
    // MARK: - Store Observers
    
    private func setupStoreObservers() {
        LoginStore.shared.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo))
            .receive(on: RunLoop.main)
            .sink { [weak self] loginUser in
                guard let self = self, let loginUser = loginUser else { return }
                nameLabel.text = loginUser.nickname ?? loginUser.userID
            }
            .store(in: &cancellableSet)
    }
}

// MARK: - Actions
extension RoomJoinView {
    @objc private func handleBackButtonTapped() {
        routerContext?.pop(animated: true)
    }
    
    @objc private func handleDismissKeyboard() {
        endEditing(true)
    }
    
    @objc private func handleMicrophoneSwitchChanged(sender: UISwitch) {
        connectConfig.autoEnableMicrophone = sender.isOn
    }
    
    @objc private func handleSpeakerSwitchChanged(sender: UISwitch) {
        connectConfig.autoEnableSpeaker = sender.isOn
    }
    
    @objc private func handleCameraSwitchChanged(sender: UISwitch) {
        connectConfig.autoEnableCamera = sender.isOn
    }
    
    @objc private func handleJoinRoomButtonTapped() {
        guard let roomID = roomIDTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !roomID.isEmpty else {
            showToast(.inputNotEmpty)
            return
        }
        
        let mainViewController = RoomMainViewController(roomID: roomID,
                                                        behavior: .join,
                                                        config: connectConfig)
        routerContext?.push(mainViewController, animated: true)
        roomIDTextField.resignFirstResponder()
    }
}

// MARK: - UITextFieldDelegate

extension RoomJoinView: UITextFieldDelegate {
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

fileprivate extension String {
    static let joinRoom = "roomkit_join_room".localized
    static let roomID = "roomkit_room_id".localized
    static let enterRoomID = "roomkit_enter_room_id".localized
    static let yourName = "roomkit_your_name".localized
    static let enableAudio = "roomkit_enable_audio".localized
    static let enableSpeaker = "roomkit_enable_speaker".localized
    static let enableVideo = "roomkit_enable_video".localized
    static let inputNotEmpty = "roomkit_input_can_not_empty".localized
}
