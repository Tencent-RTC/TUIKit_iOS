//
//  StandardRoomBottomBarView.swift
//  AFNetworking
//
//  Created by adamsfliu on 2026/4/1.
//

import AtomicXCore
import Combine

public protocol StandardRoomBottomBarViewDelegate: AnyObject {
    func onMembersButtonTapped(bottomBar: StandardRoomBottomBarView)
}

public class StandardRoomBottomBarView: UIView, BaseView {

    // MARK: - BaseView Properties
    public weak var routerContext: RouterContext?
    
    // MARK: - Properties
    public weak var delegate: StandardRoomBottomBarViewDelegate?
    
    private let roomStore: RoomStore = RoomStore.shared
    private lazy var participantStore: RoomParticipantStore = {
        RoomParticipantStore.create(roomID: roomID)
    }()
    
    private let deviceOperator: DeviceOperator = DeviceOperator()
    private var isAllCameraDisabled: Bool = false
    private var isAllMicrophoneDisabled: Bool = false
    private let roomID: String
    private var cancellableSet = Set<AnyCancellable>()
    
    // MARK: - UI Components
    private lazy var buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.alignment = .center
        stackView.spacing = 25
        return stackView
    }()
    
    private lazy var membersButton: RoomIconButton = {
        return makeIconButton(title: .members.localizedReplace("0"), imageName: "room_members")
    }()
    
    private lazy var microphoneButton: RoomIconButton = {
        return makeIconButton(title: .mute, imageName: "room_mic_on_big")
    }()
    
    private lazy var cameraButton: RoomIconButton = {
        return makeIconButton(title: .startVideo, imageName: "camera_open")
    }()
    
    private lazy var buttons: [RoomIconButton] = {
        [membersButton, microphoneButton, cameraButton]
    }()
    
    // MARK: - Initialization
    public init(roomID: String) {
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
    public func setupViews() {
        addSubview(buttonStackView)
        buttons.forEach { [weak self] button in
            guard let self = self else { return }
            buttonStackView.addArrangedSubview(button)
        }
    }
    
    public func setupConstraints() {
        buttonStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        buttons.forEach { button in
            button.snp.makeConstraints { make in
                make.size.equalTo(CGSize(width: 52, height: 52))
            }
        }
    }
    
    public func setupStyles() {}
    
    public func setupBindings() {
        membersButton.addTarget(self, action: #selector(membersButtonTapped), for: .touchUpInside)
        microphoneButton.addTarget(self, action: #selector(microphoneButtonTapped), for: .touchUpInside)
        cameraButton.addTarget(self, action: #selector(cameraButtonTapped), for: .touchUpInside)
        
        participantStore.state.subscribe(StatePublisherSelector(keyPath: \.participantList))
            .receive(on: RunLoop.main)
            .sink { [weak self] participantList in
                guard let self = self else { return }
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
    
    private func makeIconButton(title: String,imageName: String) -> RoomIconButton {
        let button = RoomIconButton()
        button.setIcon(ResourceLoader.loadImage(imageName))
        button.setTitle(title)
        button.setTitleColor(.white)
        button.setIconSize(CGSize(width: 24, height: 24))
        button.setTitleFont(RoomFonts.pingFangSCFont(size: 10, weight: .regular))
        button.setIconPosition(.top, spacing: RoomSpacing.extraSmall)
        button.layer.cornerRadius = 8
        button.backgroundColor = RoomColors.g2
        return button
    }
}

// MARK: - Actions
extension StandardRoomBottomBarView {
    @objc private func membersButtonTapped() {
        delegate?.onMembersButtonTapped(bottomBar: self)
    }
    
    @objc private func microphoneButtonTapped() {
        guard let localParticipant = participantStore.state.value.localParticipant else { return }
        if localParticipant.microphoneStatus == .on {
            deviceOperator.muteMicrophone(participantStore: participantStore)
        } else {
            Task { @MainActor in
                do {
                    try await deviceOperator.openLocalMicrophone()
                    try await deviceOperator.unmuteMicrophone(participantStore: participantStore)
                } catch let error as ErrorInfo {
                    if error.code == RoomError.openMicrophoneNeedPermissionFromAdmin.rawValue {
                        showAtomicToast(text: InternalError(code: error.code, message: error.message).localizedMessage, style: .warning)
                    } else {
                        showAtomicToast(text: InternalError(code: error.code, message: error.message).localizedMessage, style: .error)
                    }
                }
            }
        }
    }
    
    @objc private func cameraButtonTapped() {
        guard let localParticipant = participantStore.state.value.localParticipant else { return }
        if localParticipant.cameraStatus == .on {
            deviceOperator.closeLocalCamera()
        } else {
            Task { @MainActor in
                do {
                    try await deviceOperator.openLocalCamera()
                } catch let error as ErrorInfo {
                    if error.code == RoomError.openCameraNeedPermissionFromAdmin.rawValue {
                        showAtomicToast(text: InternalError(code: error.code, message: error.message).localizedMessage, style: .warning)
                    } else {
                        showAtomicToast(text: InternalError(code: error.code, message: error.message).localizedMessage, style: .error)
                    }
                }
            }
        }
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
