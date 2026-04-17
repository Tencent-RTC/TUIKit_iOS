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
        
        // 订阅 participantCount
        roomStore.state.subscribe(StatePublisherSelector(keyPath: \.currentRoom))
            .map { room in (room?.participantCount ?? 0) + (room?.audienceCount ?? 0) }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                guard let self = self else { return }
                updateParticipantCount(count: count)
            }
            .store(in: &cancellableSet)
        
        // 订阅 microphoneStatus (每个订阅使用独立数据源，避免 share() 丢失初始值)
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
        
        // 订阅 cameraStatus
        Publishers.CombineLatest4(
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.participantList))
                .map { list in list.contains { $0.userID == localUserID } }
                .removeDuplicates(),
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.localParticipant))
                .map { $0?.cameraStatus }
                .removeDuplicates(),
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.localParticipant))
                .map { $0?.screenShareStatus ?? .off }
                .removeDuplicates(),
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.localParticipant))
                .map { $0?.role }
                .removeDuplicates()
        )
        .combineLatest(
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.participantListWithVideo))
                .map { list in list.first { $0.userID != localUserID }?.role }
                .removeDuplicates()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] combined, sharingRole in
            guard let self = self else { return }
            let (isLocalInList, camStatus, screenStatus, localRole) = combined
            updateCameraStatus(isLocalInParticipantList: isLocalInList, cameraStatus: camStatus, screenStatus: screenStatus, localRole: localRole, sharingUserRole: sharingRole)
        }
        .store(in: &cancellableSet)
        
        // 订阅 screenShareStatus
        Publishers.CombineLatest4(
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.participantList))
                .map { list in list.contains { $0.userID == localUserID } }
                .removeDuplicates(),
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.localParticipant))
                .map { $0?.screenShareStatus ?? .off }
                .removeDuplicates(),
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.localParticipant))
                .map { $0?.cameraStatus }
                .removeDuplicates(),
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.localParticipant))
                .map { $0?.role }
                .removeDuplicates()
        )
        .combineLatest(
            participantStore.state.subscribe(StatePublisherSelector(keyPath: \.participantListWithVideo))
                .map { list in list.first { $0.userID != localUserID }?.role }
                .removeDuplicates()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] combined, sharingRole in
            guard let self = self else { return }
            let (isLocalInList, screenStatus, camStatus, localRole) = combined
            updateScreenShareStatus(isLocalInParticipantList: isLocalInList, screenStatus: screenStatus, cameraStatus: camStatus, localRole: localRole, sharingUserRole: sharingRole)
        }
        .store(in: &cancellableSet)
        
        // 订阅 handsUpButton
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
        
        // 订阅 handsUpManageButton
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
        RoomKitLog.info("updateParticipantCount count:$count")
        membersButton.setTitle(.members.localizedReplace("\(count)"))
    }
    
    private func updateHandsUpManageButton(role: ParticipantRole?, pendingCount: Int) {
        RoomKitLog.info("updateHandsUpManageButton role:\(role) pendingCount:\(pendingCount)")
        if role == .generalUser {
            handsUpManagerButton.isHidden = true
            return
        }
        handsUpManagerButton.isHidden = false
        handsUpManagerButton.setBadgeCount(pendingCount)
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
    }
    
    private func updateMicrophoneStatus(
        isLocalInParticipantList: Bool,
        microphoneStatus: DeviceStatus?,
        role: ParticipantRole?,
        isAllMicrophoneDisabled: Bool) {
            RoomKitLog.info("updateMicrophoneStatus isLocalInParticipantList:\(isLocalInParticipantList) microphoneStatus:\(microphoneStatus) role:\(role) isAllMicrophoneDisabled:\(isAllMicrophoneDisabled)")
            
            
            if !isLocalInParticipantList {
                microphoneButton.isHidden = true
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
        }
    
    private func updateCameraStatus(
        isLocalInParticipantList: Bool,
        cameraStatus: DeviceStatus?,
        screenStatus: DeviceStatus,
        localRole: ParticipantRole?,
        sharingUserRole: ParticipantRole?) {
            RoomKitLog.info("updateCameraStatus isLocalInParticipantList:\(isLocalInParticipantList) cameraStatus:\(cameraStatus) screenStatus:\(screenStatus) localRole:\(localRole) sharingUserRole:\(sharingUserRole)")
            
            if localRole != .owner {
                cameraButton.isHidden = true
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
            
            let isBlockedByScreenShare = screenStatus == .on
            let localRankHigherThanSharing: Bool = {
                if let localRole = localRole, let sharingUserRole = sharingUserRole {
                    return localRole.rawValue < sharingUserRole.rawValue
                }
                return false
            }()
            let isBlockedByOtherSharing = sharingUserRole != nil && !localRankHigherThanSharing && cameraStatus != .on
            let isButtonDisabled = isBlockedByScreenShare || isBlockedByOtherSharing
            cameraButton.alpha = isButtonDisabled ? 0.5 : 1.0
        }
    
    private func updateScreenShareStatus(
        isLocalInParticipantList: Bool,
        screenStatus: DeviceStatus,
        cameraStatus: DeviceStatus?,
        localRole: ParticipantRole?,
        sharingUserRole: ParticipantRole?) {
            screenShareButton.isHidden = true
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
            showAtomicToast(text: .cameraBlockedByScreenShare, style: .warning)
            return
        }
        
        if participantStore.state.value.participantListWithVideo.allSatisfy({ $0.userID == loginUserID }) {
            RoomKitLog.info("cameraButtonTapped: no other sharing, open camera directly")
            openLocalCamera()
            return
        }
        
        if isSharingUserHigherRank() {
            RoomKitLog.info("cameraButtonTapped: sharing user has higher or equal rank, blocked")
            showAtomicToast(text: .videoShareOccupied, style: .warning)
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
            showAtomicToast(text: .screenShareBlockedByCamera, style: .warning)
            return
        }
        
        if participantStore.state.value.participantListWithVideo.allSatisfy({ $0.userID == loginUserID }) {
            RoomKitLog.info("screenShareButtonTapped: no other sharing, start screen share directly")
            deviceOperator.launchScreenShareBroadcast()
            return
        }
        
        if isSharingUserHigherRank() {
            RoomKitLog.info("screenShareButtonTapped: sharing user has higher or equal rank, blocked")
            showAtomicToast(text: .videoShareOccupied, style:.warning)
            return
        }
        
        showStartVideoConfirmAlert(title: .startScreenShare, message: .startScreenShareMessage) { [weak self] in
            guard let self = self else { return }
            deviceOperator.launchScreenShareBroadcast()
        }
    }
    
    @objc private func handsUpButtonTapped() {
        RoomKitLog.info("handsUpButtonTapped")
        if isHandsUpPending.value {
            participantStore.cancelOpenDeviceRequest(device: .microphone) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success:
                    break
                case .failure(let err):
                    RoomKitLog.error("cancelOpenDeviceRequest failed: code=\(err.code), message=\(err.message)")
                    showAtomicToast(text: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
                }
            }
            isHandsUpPending.send(false)
        } else {
            participantStore.requestToOpenDevice(device: .microphone, timeout: 60) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success:
                    break
                case .failure(let err):
                    RoomKitLog.error("hands up requestToOpenDevice failed: code=\(err.code), message=\(err.message)")
                    showAtomicToast(text: InternalError(code: err.code, message: err.message).localizedMessage, style: .error)
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
                    showAtomicToast(text: InternalError(code: error.code, message: error.message).localizedMessage, style: .warning)
                } else {
                    showAtomicToast(text: InternalError(code: error.code, message: error.message).localizedMessage, style: .error)
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
                    showAtomicToast(text: InternalError(code: error.code, message: error.message).localizedMessage, style: .warning)
                } else {
                    showAtomicToast(text: InternalError(code: error.code, message: error.message).localizedMessage, style: .error)
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
        
        let stopButtonConfig = AlertButtonConfig(text: .stop, type: .blue, isBold: false) { [weak self] view in
            guard let self = self else { return }
            deviceOperator.stopScreenShare()
            view.dismiss()
        }
        
        let config = AlertViewConfig(content: .stopScreenShare, iconUrl: nil, cancelButton: cancelButtonConfig, confirmButton: stopButtonConfig)
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
    static let handsUp = "roomkit_hands_up".localized
    static let handsDown = "roomkit_hands_down".localized
    static let handsUpList = "roomkit_hands_up_list".localized
    static let stop = "roomkit_btn_stop".localized
    static let screenShareBlockedByCamera = "roomkit_screen_share_blocked_by_camera".localized
    static let videoShareOccupied = "roomkit_video_share_occupied".localized
    static let cameraBlockedByScreenShare = "roomkit_camera_blocked_by_screen_share".localized
}
