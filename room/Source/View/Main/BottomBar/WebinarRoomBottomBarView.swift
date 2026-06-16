//
//  WebinarRoomBottomBarView.swift
//  Pods
//
//  Created by adamsfliu on 2026/4/1.
//

import AtomicXCore
import Combine
import AtomicX

public protocol WebinarRoomBottomBarViewDelegate: AnyObject {
    func onMembersButtonTapped(bottomBar: WebinarRoomBottomBarView)
    func onHandsUpManagerButtonTapped(bottomBar: WebinarRoomBottomBarView)
    func onShowToast(message: String , style: ToastStyle)
}

public class WebinarRoomBottomBarView: UIView, BaseView {
    // MARK: - BaseView Properties
    public weak var routerContext: RouterContext?
    
    // MARK: - Properties
    public weak var delegate: WebinarRoomBottomBarViewDelegate?
    
    private let roomStore: RoomStore = RoomStore.shared
    private lazy var participantStore: RoomParticipantStore = {
        RoomParticipantStore.create(roomID: roomID)
    }()
    
    private var isHandsUpPending = CurrentValueSubject<Bool, Never>(false)
    private let roomID: String
    private let loginUserID: String = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
    private let deviceOperator = DeviceOperator()
    private var cancellableSet = Set<AnyCancellable>()
    private let errorCodeRequestPending = 100100
    
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
    
    private lazy var handsUpManagerButton: RoomIconButton = {
        return makeIconButton(title: .handsUpList, imageName: "room_hands_up_manager")
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
    
    private lazy var handsUpButton: RoomIconButton = {
        return makeIconButton(title: .handsUp, imageName: "room_hands_up")
    }()
    
    private lazy var buttons: [RoomIconButton] = [membersButton, handsUpManagerButton, microphoneButton, cameraButton, screenShareButton, handsUpButton]
    
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
        handsUpManagerButton.addTarget(self, action: #selector(handsUpManagerButtonTapped), for: .touchUpInside)
        screenShareButton.addTarget(self, action: #selector(screenShareButtonTapped), for: .touchUpInside)
        handsUpButton.addTarget(self, action: #selector(handsUpButtonTapped), for: .touchUpInside)
        
        participantStore.participantEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onDeviceRequestApproved, .onDeviceRequestRejected, .onDeviceRequestTimeout:
                    isHandsUpPending.send(false)
                default: break
                }
            }
            .store(in: &cancellableSet)
        
        let localUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        
        roomStore.state.subscribe(StatePublisherSelector(keyPath: \.currentRoom))
            .map { room in (room?.participantCount ?? 0) + (room?.audienceCount ?? 0) }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                guard let self = self else { return }
                updateParticipantCount(count: count)
            }
            .store(in: &cancellableSet)
        
        Publishers.CombineLatest4(
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.participantList))
                .map { list in list.contains { $0.userID == localUserID } }
                .removeDuplicates(),
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.localParticipant))
                .map { $0?.microphoneStatus }
                .removeDuplicates(),
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.localParticipant))
                .map { $0?.role }
                .removeDuplicates(),
            roomStore.state.subscribe(StatePublisherSelector(keyPath: \.currentRoom))
                .map { $0?.isAllMicrophoneDisabled ?? false }
                .removeDuplicates()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] isLocalInList, micStatus, role, isAllMuted in
            guard let self = self else { return }
            updateMicrophoneStatus(isLocalInParticipantList: isLocalInList, microphoneStatus: micStatus, role: role, isAllMicrophoneDisabled: isAllMuted)
        }
        .store(in: &cancellableSet)
        
        Publishers.CombineLatest(
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.participantList))
                .map { list in list.contains { $0.userID == localUserID } }
                .removeDuplicates(),
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.localParticipant))
                .map { $0?.cameraStatus }
                .removeDuplicates()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] isLocalInList, camStatus in
            guard let self = self else { return }
            updateCameraStatus(isLocalInParticipantList: isLocalInList, cameraStatus: camStatus)
        }
        .store(in: &cancellableSet)
        
        Publishers.CombineLatest(
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.participantList))
                .map { list in list.contains { $0.userID == localUserID } }
                .removeDuplicates(),
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.localParticipant))
                .map { $0?.screenShareStatus ?? .off }
                .removeDuplicates()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] isLocalInList, screenStatus in
            guard let self = self else { return }
            updateScreenShareStatus(isLocalInParticipantList: isLocalInList, screenStatus: screenStatus)
        }
        .store(in: &cancellableSet)
        
        Publishers.CombineLatest3(
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.participantList))
                .map { list in list.contains { $0.userID == localUserID } }
                .removeDuplicates(),
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.localParticipant))
                .map { $0?.role }
                .removeDuplicates(),
            isHandsUpPending.removeDuplicates()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] isLocalInList, role, pending in
            guard let self = self else { return }
            updateHandsUpButton(isLocalInParticipantList: isLocalInList, role: role, isPending: pending)
        }
        .store(in: &cancellableSet)
        
        Publishers.CombineLatest(
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.localParticipant))
                .map { $0?.role }
                .removeDuplicates(),
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.pendingDeviceApplications))
                .map { list in list.filter { $0.device == .microphone }.count }
                .removeDuplicates()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] role, pendingCount in
            guard let self = self else { return }
            updateHandsUpManageButton(role: role, pendingCount: pendingCount)
        }
        .store(in: &cancellableSet)
        
    }
    
    private func updateParticipantCount(count: Int) {
        RoomKitLog.info("updateParticipantCount count:\(count)")
        membersButton.setTitle(.members.localizedReplace("\(count)"))
    }
    
    private func updateStackViewSpacing() {
        let visibleCount = buttons.filter { !$0.isHidden }.count
        let spacing: CGFloat
        switch visibleCount {
        case 0, 1:
            spacing = 0
        case 2:
            spacing = 120
        case 3:
            spacing = 40
        case 4:
            spacing = 30
        case 5:
            spacing = 25
        default:
            spacing = 20
        }
        buttonStackView.spacing = spacing
    }
    
    private func updateHandsUpManageButton(role: ParticipantRole?, pendingCount: Int) {
        RoomKitLog.info("updateHandsUpManageButton role:\(role) pendingCount:\(pendingCount)")
        if role == .generalUser {
            handsUpManagerButton.isHidden = true
            updateStackViewSpacing()
            return
        }
        handsUpManagerButton.isHidden = false
        handsUpManagerButton.setBadgeCount(pendingCount)
        updateStackViewSpacing()
    }
    
    private func updateHandsUpButton(isLocalInParticipantList: Bool, role: ParticipantRole?, isPending: Bool) {
        RoomKitLog.info("updateHandsUpButton isLocalInParticipantList:\(isLocalInParticipantList) role:\(role) isPending:\(isPending)")
        
        if role == .generalUser && !isLocalInParticipantList {
            handsUpButton.isHidden = false
            if isPending {
                handsUpButton.setIcon(ResourceLoader.loadImage("room_hands_down"))
                handsUpButton.setTitle(.handsDown)
            } else {
                handsUpButton.setIcon(ResourceLoader.loadImage("room_hands_up"))
                handsUpButton.setTitle(.handsUp)
            }
        } else {
            handsUpButton.isHidden = true
            isHandsUpPending.send(false)
        }
        updateStackViewSpacing()
    }
    
    private func updateMicrophoneStatus(
        isLocalInParticipantList: Bool,
        microphoneStatus: DeviceStatus?,
        role: ParticipantRole?,
        isAllMicrophoneDisabled: Bool) {
            RoomKitLog.info("updateMicrophoneStatus isLocalInParticipantList:\(isLocalInParticipantList) microphoneStatus:\(microphoneStatus) role:\(role) isAllMicrophoneDisabled:\(isAllMicrophoneDisabled)")
            
            
            if !isLocalInParticipantList {
                microphoneButton.isHidden = true
                updateStackViewSpacing()
                return
            }
            microphoneButton.isHidden = false
            
            switch microphoneStatus {
            case .on:
                microphoneButton.setIcon(ResourceLoader.loadImage("room_mic_on_big"))
                microphoneButton.setTitle(.mute)
            default:
                microphoneButton.setIcon(ResourceLoader.loadImage("room_mic_off_red"))
                microphoneButton.setTitle(.unmute)
            }
            
            let isButtonDisabled = microphoneStatus == .off && isAllMicrophoneDisabled && role == .generalUser
            microphoneButton.alpha = isButtonDisabled ? 0.5 : 1.0
            updateStackViewSpacing()
        }
    
    private func updateCameraStatus(
        isLocalInParticipantList: Bool,
        cameraStatus: DeviceStatus?) {
            RoomKitLog.info("updateCameraStatus isLocalInParticipantList:\(isLocalInParticipantList) cameraStatus:\(cameraStatus)")
            
            if !isLocalInParticipantList {
                cameraButton.isHidden = true
                updateStackViewSpacing()
                return
            }
            cameraButton.isHidden = false
            
            switch cameraStatus {
            case .on:
                cameraButton.setIcon(ResourceLoader.loadImage("camera_open"))
                cameraButton.setTitle(.stopVideo)
            default:
                cameraButton.setIcon(ResourceLoader.loadImage("camera_close"))
                cameraButton.setTitle(.startVideo)
            }
            updateStackViewSpacing()
        }
    
    private func updateScreenShareStatus(
        isLocalInParticipantList: Bool,
        screenStatus: DeviceStatus) {
            RoomKitLog.info("updateScreenShareStatus isLocalInParticipantList:\(isLocalInParticipantList) screenStatus:\(screenStatus)")
            if !isLocalInParticipantList {
                screenShareButton.isHidden = true
                updateStackViewSpacing()
                return
            }
            
            screenShareButton.isHidden = false
            switch screenStatus {
            case .on:
                screenShareButton.setIcon(ResourceLoader.loadImage("room_stop_screen_share"))
            case .off:
                screenShareButton.setIcon(ResourceLoader.loadImage("room_start_screen_share"))
            }
            updateStackViewSpacing()
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
extension WebinarRoomBottomBarView {
    @objc private func membersButtonTapped() {
        delegate?.onMembersButtonTapped(bottomBar: self)
    }
    
    @objc private func microphoneButtonTapped() {
        RoomKitLog.info("microphoneButtonTapped")
        guard let localParticipant = participantStore.state.value.localParticipant else { return }
        if localParticipant.microphoneStatus == .on {
            deviceOperator.muteMicrophone(participantStore: participantStore)
        } else {
            let isAllMuted = roomStore.state.value.currentRoom?.isAllMicrophoneDisabled ?? false
            let role = participantStore.state.value.localParticipant?.role ?? .generalUser
            
            if isAllMuted && role == .generalUser {
                RoomKitLog.info("microphoneButtonTapped: All participants are muted, cannot unmute")
                delegate?.onShowToast(message: .cannotUnmute, style: .warning)
                return
            }
            unmuteMicrophone()
        }
    }
    
    @objc private func cameraButtonTapped() {
        guard let localParticipant = participantStore.state.value.localParticipant else { return }
        RoomKitLog.info("cameraButtonTapped cameraStatus:\(localParticipant.cameraStatus) screenStatus:\(localParticipant.screenShareStatus)")
        if localParticipant.cameraStatus == .on {
            RoomKitLog.info("cameraButtonTapped: camera is ON, closing camera")
            deviceOperator.closeLocalCamera()
            return
        }
        
        if localParticipant.screenShareStatus == .on {
            RoomKitLog.info("cameraButtonTapped: blocked by screen share")
            delegate?.onShowToast(message: .cameraBlockedByScreenShare, style: .warning)
            return
        }
        
        if participantStore.state.value.participantListWithVideo.allSatisfy({ $0.userID == loginUserID }) {
            RoomKitLog.info("cameraButtonTapped: no other sharing, open camera directly")
            openLocalCamera()
            return
        }
        
        if isSharingUserHigherRank() {
            RoomKitLog.info("cameraButtonTapped: sharing user has higher or equal rank, blocked")
            delegate?.onShowToast(message: .videoShareOccupied, style: .warning)
            return
        }
        
        showStartVideoConfirmAlert(title: .startVideo, message: .startVideoMessage) { [weak self] in
            guard let self = self else { return }
            openLocalCamera()
        }
    }
    
    @objc private func handsUpManagerButtonTapped() {
        delegate?.onHandsUpManagerButtonTapped(bottomBar: self)
    }
    
    @objc private func screenShareButtonTapped() {
        guard let localParticipant = participantStore.state.value.localParticipant else { return }
        RoomKitLog.info("screenShareButtonTapped screenStatus:\(localParticipant.screenShareStatus)")
        
        if localParticipant.screenShareStatus == .on {
            RoomKitLog.info("screenShareButtonTapped: screen share is ON, show stop alert")
            showStopScreenShareAlert()
            return
        }
        
        if localParticipant.cameraStatus == .on {
            RoomKitLog.info("screenShareButtonTapped: blocked by camera")
            delegate?.onShowToast(message: .screenShareBlockedByCamera, style: .warning)
            return
        }
        
        if participantStore.state.value.participantListWithVideo.allSatisfy({ $0.userID == loginUserID }) {
            RoomKitLog.info("screenShareButtonTapped: no other sharing, start screen share directly")
            requestScreenShareTip { [weak self] in
                guard let self = self else { return }
                deviceOperator.launchScreenShareBroadcast()
            }
            return
        }
        
        if isSharingUserHigherRank() {
            RoomKitLog.info("screenShareButtonTapped: sharing user has higher or equal rank, blocked")
            delegate?.onShowToast(message: .screenShareOccupied, style: .warning)
            return
        }
        
        showStartVideoConfirmAlert(title: .startScreenShare, message: .startScreenShareMessage) { [weak self] in
            guard let self = self else { return }
            requestScreenShareTip { [weak self] in
                guard let self = self else { return }
                deviceOperator.launchScreenShareBroadcast()
            }
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
    
    @objc private func handsUpButtonTapped() {
        RoomKitLog.info("handsUpButtonTapped")
        if isHandsUpPending.value {
            participantStore.cancelOpenDeviceRequest(device: .microphone, completion: nil)
            isHandsUpPending.send(false)
        } else {
            participantStore.requestToOpenDevice(device: .microphone, timeout: 30) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success:
                    break
                case .failure(let err):
                    RoomKitLog.error("hands up requestToOpenDevice failed: code=\(err.code), message=\(err.message)")
                    if err.code == errorCodeRequestPending {
                        return
                    }
                    delegate?.onShowToast(message: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
                }
            }
            isHandsUpPending.send(true)
        }
    }
    
}

extension WebinarRoomBottomBarView {
    private func unmuteMicrophone() {
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
    
    private func openLocalCamera() {
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

extension WebinarRoomBottomBarView {
    private func isSharingUserHigherRank() -> Bool {
        guard let localParticipant = participantStore.state.value.localParticipant else { return false }
        guard let sharingUser = participantStore.state.value.participantListWithVideo.first(where: { $0.userID != loginUserID }) else {
            return false
        }
        return sharingUser.role.rawValue <= localParticipant.role.rawValue
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
    
    private func showStartVideoConfirmAlert(title: String, message: String, onStart: @escaping () -> Void) {
        let cancelButtonConfig = AlertButtonConfig(text: .cancel) { view in
            view.dismiss()
        }
        let confirmButtonConfig = AlertButtonConfig(text: .ok) { view in
            onStart()
            view.dismiss()
        }
        let alertConfig = AlertViewConfig(title: title, content: message, cancelButton: cancelButtonConfig, confirmButton: confirmButtonConfig)
        AtomicAlertView(config: alertConfig).show()
    }
}

fileprivate extension String {
    static let cancel = "roomkit_cancel".localized
    static let ok = "roomkit_ok".localized
    static let members = "roomkit_member_count"
    static let mute = "roomkit_mute".localized
    static let unmute = "roomkit_unmute".localized
    static let stopVideo = "roomkit_stop_video".localized
    static let startVideo = "roomkit_start_video".localized
    static let startVideoMessage = "roomkit_video_start_message".localized
    static let member = "roomkit_member".localized
    static let startScreenShare = "roomkit_start_screen_share".localized
    static let startScreenShareMessage = "roomkit_screen_share_start_message".localized
    static let stopScreenShare = "roomkit_stop_screen_share".localized
    static let stopScreenShareConfirm = "roomkit_stop_screen_share_confirm".localized
    static let handsUp = "roomkit_hands_up".localized
    static let handsDown = "roomkit_hands_down".localized
    static let handsUpList = "roomkit_hands_up_list".localized
    static let stop = "roomkit_btn_stop".localized
    static let screenShareBlockedByCamera = "roomkit_screen_share_blocked_by_camera".localized
    static let videoShareOccupied = "roomkit_video_share_occupied".localized
    static let screenShareOccupied = "roomkit_screen_share_occupied".localized
    static let cameraBlockedByScreenShare = "roomkit_camera_blocked_by_screen_share".localized
    static let cannotUnmute = "roomkit_tip_all_muted_cannot_unmute".localized
    static let tips = "roomkit_tips".localized
    static let unableToSharedScreen = "roomkit_unable_to_shared_screen".localized
    static let contactUs = "roomkit_contact_us".localized
    static let privacyScreenShareTipTitle = "roomkit_privacy_screen_share_tip_title".localized
    static let privacyScreenShareTipContent = "roomkit_privacy_screen_share_tip_content".localized
    static let privacyScreenShareTipContinue = "roomkit_privacy_screen_share_tip_continue".localized
}
