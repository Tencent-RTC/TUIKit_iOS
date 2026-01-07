//
//  RoomBottomBarView.swift
//  TUIRoomKit
//
//  Created on 2025/11/21.
//  Copyright © 2025 Tencent. All rights reserved.
//

import AtomicXCore
import Combine

protocol RoomBottomBarViewDelegate: AnyObject {
    func onMembersButtonTapped()
    func onMicrophoneButtonTapped()
    func onCameraButtonTapped()
//    func onMoreButtonTapped()
}

// MARK: - RoomBottomBarView Component
class RoomBottomBarView: UIView, BaseView {
    // MARK: - BaseView Properties
    weak var routerContext: RouterContext?
    
    // MARK: - Properties
    weak var delegate: RoomBottomBarViewDelegate?
    
    private let deviceStore: DeviceStore = DeviceStore.shared
    private let roomStore: RoomStore = RoomStore.shared
    private lazy var participantStore: RoomParticipantStore = {
        RoomParticipantStore.create(roomID: roomID)
    }()
    
    private var isAllCameraDisabled: Bool = false
    private var isAllMicrophoneDisabled: Bool = false
    private let roomID: String
    private var cancellableSet = Set<AnyCancellable>()
    
    // MARK: - UI Components
    private lazy var buttonStackView: UIStackView = {
        let stackView = UIStackView()
        buttons.forEach { _ in
            let containerView = UIView()
            containerView.layer.cornerRadius = 10
            containerView.backgroundColor = RoomColors.g2
            stackView.addArrangedSubview(containerView)
        }
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        return stackView
    }()
    
    private lazy var membersButton: RoomIconButton = {
        let button = RoomIconButton()
        button.setIcon(ResourceLoader.loadImage("room_members"))
        button.setTitle(.members.localizedReplace("0"))
        button.setIconPosition(.top, spacing: RoomSpacing.extraSmall)
        button.setTitleColor(.white)
        button.setTitleFont(RoomFonts.pingFangSCFont(size: 10, weight: .regular))
        return button
    }()
    
    private lazy var microphoneButton: RoomIconButton = {
        let button = RoomIconButton()
        button.setIcon(ResourceLoader.loadImage("room_mic_on_big"))
        button.setTitle(.mute)
        button.setIconPosition(.top, spacing: RoomSpacing.extraSmall)
        button.setTitleColor(.white)
        button.setTitleFont(RoomFonts.pingFangSCFont(size: 10, weight: .regular))
        return button
    }()
    
    private lazy var cameraButton: RoomIconButton = {
        let button = RoomIconButton()
        button.setIcon(ResourceLoader.loadImage("camera_open"))
        button.setTitle(.startVideo)
        button.setTitleColor(.white)
        button.setTitleFont(RoomFonts.pingFangSCFont(size: 10, weight: .regular))
        button.setIconPosition(.top, spacing: RoomSpacing.extraSmall)
        return button
    }()
    
//    private lazy var moreButton: RoomIconButton = {
//        let button = RoomIconButton()
//        button.setIcon(ResourceLoader.loadImage("room_more"))
//        button.setTitle("Expansion".localized)
//        button.setIconPosition(.top, spacing: RoomSpacing.extraSmall)
//        button.setTitleColor(.white)
//        button.setTitleFont(RoomFonts.pingFangSCFont(size: 10, weight: .regular))
//        return button
//    }()
    
    private lazy var buttons: [RoomIconButton] = {[membersButton, microphoneButton, cameraButton]}()
    
    // MARK: - Initialization
    init(roomID: String) {
        self.roomID = roomID
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    func setupViews() {
        addSubview(buttonStackView)
        buttonStackView.subviews.enumerated().forEach { index, view in
            let button = buttons[index]
            view.addSubview(button)
        }
    }
    
    func setupConstraints() {
        buttonStackView.snp.makeConstraints { make in
            make.width.equalTo(200)
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        buttonStackView.subviews.enumerated().forEach { index, view in
            view.snp.makeConstraints { make in
                make.size.equalTo(CGSize(width: 52, height: 52))
            }
            
            let button = buttons[index]
            button.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.equalTo(52)
            }
        }
    }
    
    func setupStyles() {
        
    }
    
    func setupBindings() {
        membersButton.addTarget(self, action: #selector(membersButtonTapped), for: .touchUpInside)
        microphoneButton.addTarget(self, action: #selector(microphoneButtonTapped), for: .touchUpInside)
        cameraButton.addTarget(self, action: #selector(cameraButtonTapped), for: .touchUpInside)
//        moreButton.addTarget(self, action: #selector(moreButtonTapped(sender:)), for: .touchUpInside)
        
        participantStore.state.subscribe(StatePublisherSelector(keyPath: \.localParticipant))
            .combineLatest(roomStore.state.subscribe(StatePublisherSelector(keyPath: \.currentRoom)))
            .receive(on: RunLoop.main)
            .sink { [weak self] localParticipant, currentRoom in
                guard let self = self else { return }
                
                if let currentRoom = currentRoom {
                    isAllCameraDisabled = currentRoom.isAllCameraDisabled
                    isAllMicrophoneDisabled = currentRoom.isAllMicrophoneDisabled
                }
                
                if let localParticipant = localParticipant {
                    updateCameraStatus(participant: localParticipant)
                    updateMicrophoneStatus(participant: localParticipant)
                }
            }
            .store(in: &cancellableSet)
        
        roomStore.state.subscribe(StatePublisherSelector(keyPath: \.currentRoom?.participantCount))
            .receive(on: RunLoop.main)
            .sink { [weak self] participantCount in
                guard let self = self else { return }
                if let participantCount = participantCount {
                    membersButton.setTitle(.members.localizedReplace("\(participantCount)"))
                }
            }
            .store(in: &cancellableSet)
    }
    
    private func updateMicrophoneStatus(participant: RoomParticipant) {
        switch participant.microphoneStatus {
        case .on:
            microphoneButton.setIcon(ResourceLoader.loadImage("room_mic_on_big"))
            microphoneButton.setTitle(.mute)
            microphoneButton.alpha = 1.0
        case .off:
            microphoneButton.setIcon(ResourceLoader.loadImage("room_mic_off_red"))
            microphoneButton.setTitle(.unmute)
            if participant.role == .generalUser {
                microphoneButton.alpha = isAllMicrophoneDisabled ? 0.5 : 1.0
            } else {
                microphoneButton.alpha = 1.0
            }
        }
    }
    
    private func updateCameraStatus(participant: RoomParticipant) {
        switch participant.cameraStatus {
        case .on:
            cameraButton.setIcon(ResourceLoader.loadImage("camera_open"))
            cameraButton.setTitle(.stopVideo)
            cameraButton.alpha = 1.0
        case .off:
            cameraButton.setIcon(ResourceLoader.loadImage("camera_close"))
            cameraButton.setTitle(.startVideo)
            if participant.role == .generalUser {
                cameraButton.alpha =  isAllCameraDisabled ? 0.5 : 1.0
            } else {
                cameraButton.alpha = 1.0
            }
        }
    }
}

// MARK: - Actions
extension RoomBottomBarView {
    @objc private func membersButtonTapped() {
        delegate?.onMembersButtonTapped()
    }
    
    @objc private func microphoneButtonTapped() {
        delegate?.onMicrophoneButtonTapped()
    }
    
    @objc private func cameraButtonTapped() {
        delegate?.onCameraButtonTapped()
    }
    
//    @objc private func moreButtonTapped() {
//        delegate?.onMoreButtonTapped()
//    }
}

fileprivate extension String {
    static let members = "Members(xxx)"
    static let mute = "Mute".localized
    static let unmute = "Unmute".localized
    static let stopVideo = "Stop video".localized
    static let startVideo = "Start video".localized
}
