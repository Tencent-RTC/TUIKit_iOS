//
//  StandardRoomBottomBarView.swift
//  AFNetworking
//
//  Created by adamsfliu on 2026/4/1.
//

import AtomicXCore
import Combine
import AtomicX

public protocol StandardRoomBottomBarViewDelegate: AnyObject {
    func onMembersButtonTapped(bottomBar: StandardRoomBottomBarView)
    func onAIToolsButtonTapped()
    func onShowToast(message: String, style: ToastStyle)
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
    
    private lazy var screenShareButton: RoomIconButton = {
        return makeIconButton(title: .startScreenShare, imageName: "room_start_screen_share")
    }()
    
    private lazy var aiToolsButton: RoomIconButton = {
        return makeIconButton(title: .aiTools, imageName: "room_ai_tools")
    }()
    
    private lazy var buttons: [RoomIconButton] = {
        [membersButton, microphoneButton, cameraButton, screenShareButton, aiToolsButton]
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
        screenShareButton.addTarget(self, action: #selector(screenShareButtonTapped), for: .touchUpInside)
        aiToolsButton.addTarget(self, action: #selector(aiToolsButtonTapped), for: .touchUpInside)
        
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
        
        Publishers.CombineLatest3(
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.localParticipant))
                .map { $0?.screenShareStatus ?? .off }
                .removeDuplicates(),
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.localParticipant))
                .map { $0?.role ?? .generalUser }
                .removeDuplicates(),
            roomStore.state.subscribe(StatePublisherSelector(keyPath: \.currentRoom))
                .map { $0?.isAllScreenShareDisabled ?? false }
                .removeDuplicates()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] screenShareStatus, userRole, isAllScreenShareDisabled in
            guard let self = self else { return }
            updateScreenShareStatus(screenStatus: screenShareStatus,
                                    userRole: userRole,
                                    isAllScreenShareDisabled: isAllScreenShareDisabled)
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
    
    private func updateScreenShareStatus(screenStatus: DeviceStatus, userRole: ParticipantRole, isAllScreenShareDisabled: Bool) {
        RoomKitLog.info("updateScreenShareStatus screenStatus: \(screenStatus), userRole: \(userRole), isAllScreenShareDisabled: \(isAllScreenShareDisabled)")
        screenShareButton.isHidden = false
        if isAllScreenShareDisabled && userRole == .generalUser {
            screenShareButton.alpha = 0.5
            return
        }
        
        screenShareButton.alpha = 1
        switch screenStatus {
        case .on:
            screenShareButton.setIcon(ResourceLoader.loadImage("room_stop_screen_share"))
        case .off:
            screenShareButton.setIcon(ResourceLoader.loadImage("room_start_screen_share"))
        }
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
                        delegate?.onShowToast(message: InternalError(code: error.code, message: error.message).localizedMessage, style: .warning)
                    } else {
                        delegate?.onShowToast(message: InternalError(code: error.code, message: error.message).localizedMessage, style: .error)
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
                        delegate?.onShowToast(message: InternalError(code: error.code, message: error.message).localizedMessage, style: .warning)
                    } else {
                        delegate?.onShowToast(message: InternalError(code: error.code, message: error.message).localizedMessage, style: .error)
                    }
                }
            }
        }
    }
    
    @objc private func screenShareButtonTapped(sender: UIButton) {
        guard let localParticipant = participantStore.state.value.localParticipant else { return }
        guard let isAllScreenShareDisabled = roomStore.state.value.currentRoom?.isAllScreenShareDisabled else { return }
        if isAllScreenShareDisabled && localParticipant.role == .generalUser {
            delegate?.onShowToast(message: .notAllowedToScreenShare, style: .warning)
            return
        }
        
        RoomKitLog.info("screenShareButtonTapped screenStatus:\(localParticipant.screenShareStatus)")
        if localParticipant.screenShareStatus == .on {
            RoomKitLog.info("screenShareButtonTapped: screen share is ON, show stop alert")
            showStopScreenShareAlert()
            return
        }
        
        let localUserID = localParticipant.userID
        if let sharingUser = participantStore.state.value.participantWithScreen, sharingUser.userID != localUserID {
            RoomKitLog.info("screenShareButtonTapped: another user \(sharingUser.userID) is sharing the screen")
            delegate?.onShowToast(message: .anotherIsSharing, style: .warning)
            return
        }
        
        requestScreenShareTip { [weak self] in
            guard let self = self else { return }
            deviceOperator.launchScreenShareBroadcast()
        }
    }
    
    private func requestScreenShareTip(onApproved: @escaping () -> Void) {
        let bannedFeatureIds = UserDefaults.standard.stringArray(forKey: "rtcube_module_permission.bannedFeatureIds") ?? []
        if bannedFeatureIds.contains("screen_share") {
            RoomKitLog.info("requestScreenShareTip: screen share is banned by backend")
            showScreenShareForbiddenAlertView()
            return
        }
        showScreenShareTipAlertView(onApproved: onApproved)
    }
    
    private func showScreenShareForbiddenAlertView() {
        let cancelButtonConfig = AlertButtonConfig(text: .cancel, type: .grey, isBold: false) { view in
            view.dismiss()
        }
        
        let contactButtonConfig = AlertButtonConfig(text: .contactUs, type: .blue, isBold: false) { [weak self] view in
            guard let self = self else { return }
            self.openContactURL()
            view.dismiss()
        }
        
        let config = AlertViewConfig(title: .tips,
                                     content: .unableToSharedScreen,
                                     cancelButton: cancelButtonConfig,
                                     confirmButton: contactButtonConfig)
        AtomicAlertView(config: config).show()
    }
    
    private func showScreenShareTipAlertView(onApproved: @escaping () -> Void) {
        let cancelButtonConfig = AlertButtonConfig(text: .cancel, type: .grey, isBold: false) { view in
            view.dismiss()
        }
        
        let continueButtonConfig = AlertButtonConfig(text: .privacyScreenShareTipContinue, type: .blue, isBold: false) { view in
            onApproved()
            view.dismiss()
        }
        
        let config = AlertViewConfig(title: .privacyScreenShareTipTitle,
                                     content: .privacyScreenShareTipContent,
                                     cancelButton: cancelButtonConfig,
                                     confirmButton: continueButtonConfig)
        AtomicAlertView(config: config).show()
    }
    
    private func openContactURL() {
        guard let url = URL(string: "https://im.cloud.tencent.com/s/cWSPGIIM62CC/cFUPGIIM62CF") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    @objc private func aiToolsButtonTapped() {
        delegate?.onAIToolsButtonTapped()
    }
    
    private func showStopScreenShareAlert() {
        let cancelButtonConfig = AlertButtonConfig(text: .cancel, type: .grey, isBold: false) { view in
            view.dismiss()
        }
        
        let stopButtonConfig = AlertButtonConfig(text: .ok, type: .blue, isBold: false) { [weak self] view in
            guard let self = self else { return }
            deviceOperator.stopScreenShare()
            view.dismiss()
        }
        
        let config = AlertViewConfig(title: .stopScreenShare,
                                     content: .stopScreenShareConfirm,
                                     cancelButton: cancelButtonConfig,
                                     confirmButton: stopButtonConfig)
        AtomicAlertView(config: config).show()
    }
}

fileprivate extension String {
    static let ok = "roomkit_ok".localized
    static let cancel = "roomkit_cancel".localized
    static let stop = "roomkit_btn_stop".localized
    static let members = "roomkit_member_count"
    static let mute = "roomkit_mute".localized
    static let unmute = "roomkit_unmute".localized
    static let stopVideo = "roomkit_stop_video".localized
    static let startVideo = "roomkit_start_video".localized
    static let member = "roomkit_member".localized
    static let aiTools = "roomkit_transcription_ai_tools".localized
    static let startScreenShare = "roomkit_start_screen_share".localized
    static let startScreenShareMessage = "roomkit_screen_share_start_message".localized
    static let stopScreenShare = "roomkit_stop_screen_share".localized
    static let stopScreenShareConfirm = "roomkit_stop_screen_share_confirm".localized
    static let anotherIsSharing = "roomkit_another_is_sharing_the_screen".localized
    static let tips = "roomkit_tips".localized
    static let unableToSharedScreen = "roomkit_unable_to_shared_screen".localized
    static let contactUs = "roomkit_contact_us".localized
    static let privacyScreenShareTipTitle = "roomkit_privacy_screen_share_tip_title".localized
    static let privacyScreenShareTipContent = "roomkit_privacy_screen_share_tip_content".localized
    static let privacyScreenShareTipContinue = "roomkit_privacy_screen_share_tip_continue".localized
    static let notAllowedToScreenShare = "roomkit_not_allowed_to_screen_share".localized
}
