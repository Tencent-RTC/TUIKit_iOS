//
//  RoomCreateView.swift
//  TUIRoomKit
//
//  Created on 2025/11/12.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import AtomicXCore
import Combine

public class RoomCreateView: UIView, BaseView {
    
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
        label.text = .createRoom
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        label.textColor = RoomColors.g2
        return label
    }()
    
    private lazy var roomTypeCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var formCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 12
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
        toggle.onTintColor = RoomColors.b1
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
        toggle.onTintColor = RoomColors.b1
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
        toggle.onTintColor = RoomColors.b1
        toggle.layer.cornerRadius = toggle.frame.height / 2
        return toggle
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
    
    private lazy var createRoomButton: UIButton = {
        let button = UIButton(type: .custom)
        button.layer.cornerRadius = 10
        button.clipsToBounds = true
        button.backgroundColor = RoomColors.brandBlue
        button.setTitle(.createRoom, for: .normal)
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
        // Add subviews
        addSubview(backButtonContainerView)
        backButtonContainerView.addSubview(backButton)
        backButtonContainerView.addSubview(titleLabel)
        
        addSubview(roomTypeCardView)
        addSubview(formCardView)
        
        // Room type card content
        roomTypeCardView.addSubview(yourNameLabel)
        roomTypeCardView.addSubview(nameLabel)
        
        // Form card content
        formCardView.addSubview(microphoneLabel)
        formCardView.addSubview(microphoneSwitch)
        formCardView.addSubview(dividerLine2)
        formCardView.addSubview(speakerLabel)
        formCardView.addSubview(speakerSwitch)
        formCardView.addSubview(dividerLine3)
        formCardView.addSubview(cameraLabel)
        formCardView.addSubview(cameraSwitch)
        
        addSubview(createRoomButton)
    }
    
    public func setupConstraints() {
        // Back button container - expand click area
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
        
        roomTypeCardView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.right.equalToSuperview().offset(-12)
            make.top.equalTo(titleLabel.snp.bottom).offset(42)
            make.height.equalTo(54)
        }
        
        yourNameLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.height.equalTo(20)
            make.width.equalTo(90)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.left.equalTo(yourNameLabel.snp.right).offset(20)
            make.centerY.equalTo(yourNameLabel)
            make.height.equalTo(20)
        }
        
        formCardView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.right.equalToSuperview().offset(-12)
            make.top.equalTo(roomTypeCardView.snp.bottom).offset(RoomSpacing.standard)
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
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.top.equalTo(microphoneLabel.snp.bottom).offset(18)
            make.height.equalTo(1)
        }
        
        speakerLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.top.equalTo(dividerLine2.snp.bottom).offset(18)
        }
        
        speakerSwitch.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalTo(speakerLabel)
        }
        
        dividerLine3.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.top.equalTo(speakerLabel.snp.bottom).offset(18)
            make.height.equalTo(1)
        }
        
        cameraLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.top.equalTo(dividerLine3.snp.bottom).offset(18)
        }
        
        cameraSwitch.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalTo(cameraLabel)
        }
        
        createRoomButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(formCardView.snp.bottom).offset(48)
            make.height.equalTo(52)
            make.leading.trailing.equalToSuperview().inset(88)
        }
    }
    
    public func setupStyles() {
        backgroundColor = RoomColors.g8
        microphoneSwitch.isOn = connectConfig.autoEnableMicrophone
        speakerSwitch.isOn = connectConfig.autoEnableSpeaker
        cameraSwitch.isOn = connectConfig.autoEnableCamera
    }
    
    public func setupBindings() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackButtonTapped))
        backButtonContainerView.addGestureRecognizer(tapGesture)
        
        createRoomButton.addTarget(self, action: #selector(handleCreateRoomButtonTapped), for: .touchUpInside)
        microphoneSwitch.addTarget(self, action: #selector(handleMicrophoneSwitchChanged(sender:)), for: .valueChanged)
        speakerSwitch.addTarget(self, action: #selector(handleSpeakerSwitchChanged(sender:)), for: .valueChanged)
        cameraSwitch.addTarget(self, action: #selector(handleCameraSwitchChanged(sender:)), for: .valueChanged)
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
extension RoomCreateView {
    
    @objc private func handleBackButtonTapped() {
        routerContext?.pop(animated: true)
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
    
    @objc private func handleCreateRoomButtonTapped() {
        guard let name = nameLabel.text else { return }
        let roomID = getRandomRoomId(numberOfDigits: 6)
        var options = CreateRoomOptions()
        options.roomName = .roomName.localizedReplace(name)
        let mainViewController = RoomMainViewController(roomID: roomID,
                                                        behavior: .create(options: options),
                                                        config: connectConfig)
        routerContext?.push(mainViewController, animated: true)
    }
    
    private func getRandomRoomId(numberOfDigits: Int) -> String {
        var numberOfDigit = numberOfDigits > 0 ? numberOfDigits : 1
        numberOfDigit = numberOfDigit < 10 ? numberOfDigit : 9
        let minNumber = Int(truncating: NSDecimalNumber(decimal: pow(10, numberOfDigit - 1)))
        let maxNumber = Int(truncating: NSDecimalNumber(decimal: pow(10, numberOfDigit))) - 1
        let randomNumber = arc4random_uniform(UInt32(maxNumber - minNumber)) + UInt32(minNumber)
        return String(randomNumber)
    }
}

fileprivate extension String {
    static let createRoom = "roomkit_create_room".localized
    static let yourName = "roomkit_your_name".localized
    static let enableAudio = "roomkit_enable_audio".localized
    static let enableSpeaker = "roomkit_enable_speaker".localized
    static let enableVideo = "roomkit_enable_video".localized
    static let roomName = "roomkit_user_room"
}
