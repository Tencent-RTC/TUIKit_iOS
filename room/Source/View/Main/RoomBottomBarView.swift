//
//  RoomBottomBarView.swift
//  TUIRoomKit
//
//  Created on 2025/11/21.
//  Copyright © 2025 Tencent. All rights reserved.
//

import AtomicXCore
import Combine

public protocol RoomBottomBarViewDelegate: AnyObject {
    func onMembersButtonTapped()
    func onMicrophoneButtonTapped()
    func onCameraButtonTapped()
}

let buttonItemSizeForStandard: CGFloat = 52
let buttonItemSizeForWebinar: CGFloat = 40

// MARK: - RoomBottomBarView Component
public class RoomBottomBarView: UIView, BaseView {
    // MARK: - BaseView Properties
    public weak var routerContext: RouterContext?
    
    // MARK: - Properties
    public weak var delegate: RoomBottomBarViewDelegate?
    
    private let deviceStore: DeviceStore = DeviceStore.shared
    private let roomStore: RoomStore = RoomStore.shared
    private lazy var participantStore: RoomParticipantStore = {
        RoomParticipantStore.create(roomID: roomID)
    }()
    
    private var isAllCameraDisabled: Bool = false
    private var isAllMicrophoneDisabled: Bool = false
    private let roomID: String
    private let roomType: RoomType
    private var cancellableSet = Set<AnyCancellable>()
    
    // MARK: - UI Components
    private lazy var buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = roomType == .standard ? .center : .trailing
        stackView.spacing = roomType == .standard ? 10 : 8
        return stackView
    }()
    
    private lazy var membersButton: RoomIconButton = {
        let button = RoomIconButton()
        button.setIcon(ResourceLoader.loadImage("room_members"))
        button.setTitle(roomType == .standard ? .members.localizedReplace("0") : .member)
        button.setIconPosition(.top, spacing: RoomSpacing.extraSmall)
        button.setTitleColor(.white)
        button.setIconSize(roomType == .standard ? CGSize(width: 24, height: 24) : CGSize(width: 20, height: 20))
        button.setTitleFont(RoomFonts.pingFangSCFont(size: roomType == .standard ? 10 : 8, weight: .regular))
        button.layer.cornerRadius = 8
        button.backgroundColor = RoomColors.g2
        return button
    }()
    
    private lazy var microphoneButton: RoomIconButton = {
        let button = RoomIconButton()
        button.setIcon(ResourceLoader.loadImage("room_mic_on_big"))
        button.setTitle(.mute)
        button.setIconPosition(.top, spacing: RoomSpacing.extraSmall)
        button.setTitleColor(.white)
        button.setIconSize(roomType == .standard ? CGSize(width: 24, height: 24) : CGSize(width: 20, height: 20))
        button.setTitleFont(RoomFonts.pingFangSCFont(size: roomType == .standard ? 10 : 8, weight: .regular))
        button.layer.cornerRadius = 8
        button.backgroundColor = RoomColors.g2
        return button
    }()
    
    private lazy var cameraButton: RoomIconButton = {
        let button = RoomIconButton()
        button.setIcon(ResourceLoader.loadImage("camera_open"))
        button.setTitle(.startVideo)
        button.setTitleColor(.white)
        button.setIconSize(roomType == .standard ? CGSize(width: 24, height: 24) : CGSize(width: 20, height: 20))
        button.setTitleFont(RoomFonts.pingFangSCFont(size: roomType == .standard ? 10 : 8, weight: .regular))
        button.setIconPosition(.top, spacing: RoomSpacing.extraSmall)
        button.layer.cornerRadius = roomType == .standard ? 10 : 8
        button.backgroundColor = RoomColors.g2
        return button
    }()
    
    private lazy var buttonsForStandard: [RoomIconButton] = {[membersButton, microphoneButton, cameraButton]}()
    private lazy var buttonsForWebinar: [RoomIconButton] = {[microphoneButton, membersButton]}()
    
    // MARK: - Initialization
    public init(roomID: String, roomType: RoomType) {
        self.roomID = roomID
        self.roomType = roomType
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
    public func setupViews() {
        addSubview(buttonStackView)
        if roomType == .standard {
            buttonsForStandard.forEach { [weak self] button in
                guard let self = self else { return }
                buttonStackView.addArrangedSubview(button)
            }
        } else {
            buttonsForWebinar.forEach { [weak self] button in
                guard let self = self else { return }
                buttonStackView.addArrangedSubview(button)
            }
        }
    }
    
    public func setupConstraints() {
        buttonStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        if roomType == .standard {
            buttonsForStandard.forEach { button in
                button.snp.makeConstraints { make in
                    make.size.equalTo(CGSize(width: buttonItemSizeForStandard, height: buttonItemSizeForStandard))
                }
            }
        } else {
            buttonsForWebinar.forEach { button in
                button.snp.makeConstraints { make in
                    make.size.equalTo(CGSize(width: buttonItemSizeForWebinar, height: buttonItemSizeForWebinar))
                }
            }
        }
    }
    
    public func setupStyles() {}
    
    public func setupBindings() {
        membersButton.addTarget(self, action: #selector(membersButtonTapped), for: .touchUpInside)
        microphoneButton.addTarget(self, action: #selector(microphoneButtonTapped), for: .touchUpInside)
        if roomType == .standard {
            cameraButton.addTarget(self, action: #selector(cameraButtonTapped), for: .touchUpInside)
        }
        
        participantStore.state.subscribe(StatePublisherSelector(keyPath: \.participantList))
            .receive(on: RunLoop.main)
            .sink { [weak self] participantList in
                guard let self = self else { return }
                guard roomType == .webinar else { return }
                let userIDList = participantList.map { $0.userID }
                if userIDList.contains(LoginStore.shared.state.value.loginUserInfo?.userID ?? "") {
                    microphoneButton.isHidden = false
                } else {
                    microphoneButton.isHidden = true
                }
            }
            .store(in: &cancellableSet)
        
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
                    if roomType == .standard {
                        membersButton.setTitle(.members.localizedReplace("\(participantCount)"))
                    }
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
}

fileprivate extension String {
    static let members = "roomkit_member_count"
    static let mute = "roomkit_mute".localized
    static let unmute = "roomkit_unmute".localized
    static let stopVideo = "roomkit_stop_video".localized
    static let startVideo = "roomkit_start_video".localized
    static let member = "roomkit_member".localized
}
