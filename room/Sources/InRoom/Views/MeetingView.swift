import UIKit
import SnapKit
import AtomicXCore

public enum RoomBehavior {
    case create(roomName: String)
    case join
}

public struct RoomConnectConfig {
    public let autoEnableMicrophone: Bool
    public let autoEnableCamera: Bool
    public let autoEnableSpeaker: Bool

    public init(autoEnableMicrophone: Bool, autoEnableCamera: Bool, autoEnableSpeaker: Bool) {
        self.autoEnableMicrophone = autoEnableMicrophone
        self.autoEnableCamera = autoEnableCamera
        self.autoEnableSpeaker = autoEnableSpeaker
    }
}

public final class MeetingView: UIView {

    public weak var routerContext: RouterContext? {
        didSet {
            topBar.routerContext = routerContext
            toolBar.routerContext = routerContext
            eventHandler.routerContext = routerContext
        }
    }

    private let roomID: String
    private let behavior: RoomBehavior
    private let connectConfig: RoomConnectConfig
    private let eventHandler: RoomEventHandler

    private let topBar: MeetingTopBar
    private let roomView: RoomView
    private let toolBar: MeetingToolBar

    private let sharingPlaceholder: RoomScreenSharingPlaceholderView
    private let enteringView = RoomLoadingView()

    public init(roomID: String, behavior: RoomBehavior, config: RoomConnectConfig) {
        self.roomID = roomID
        self.behavior = behavior
        self.connectConfig = config
        self.topBar = MeetingTopBar(roomID: roomID)
        self.roomView = RoomView(roomID: roomID)
        self.toolBar = MeetingToolBar(roomID: roomID)
        self.eventHandler = RoomEventHandler(roomID: roomID)
        self.sharingPlaceholder = RoomScreenSharingPlaceholderView(roomID: roomID)
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        enterRoom()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        addSubview(topBar)
        addSubview(roomView)
        addSubview(sharingPlaceholder)
        addSubview(toolBar)
        addSubview(enteringView)
    }

    private func setupConstraints() {
        topBar.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide.snp.top)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(44)
        }
        
        roomView.snp.makeConstraints {
            $0.top.equalTo(topBar.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(toolBar.snp.top)
        }
        
        sharingPlaceholder.snp.makeConstraints {
            $0.edges.equalTo(roomView)
        }
        
        toolBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
            $0.height.equalTo(64)
        }

        enteringView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
    
    private func setupStyles() {
        backgroundColor = UIColor.roomKitBgSurface
        topBar.backgroundColor = .clear
        toolBar.backgroundColor = .clear
    }

    private func setupBindings() {
        topBar.popoverHost = self
        eventHandler.start()
    }

    private func enterRoom() {
        enteringView.setShown(true)
        switch behavior {
        case .create(let roomName):
            createRoom(named: roomName)
        case .join:
            joinRoom()
        }
    }

    private func createRoom(named roomName: String) {
        var options = CreateRoomOptions()
        options.roomName = roomName
        RoomStore.shared.createAndJoinRoom(roomID: roomID, roomType: .standard, options: options) { [weak self] result in
            guard let self else { return }
            handleEnterResult(result)
        }
    }

    private func joinRoom(password: String? = nil) {
        RoomStore.shared.joinRoom(roomID: roomID,
                                  roomType: .standard,
                                  password: password) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error) where ErrorLocalized.rule(code: error.code) == .passwordRequired ||
                                           ErrorLocalized.rule(code: error.code) == .wrongPassword:
                enteringView.setShown(false)
                presentPassword(wrongPassword: ErrorLocalized.rule(code: error.code) == .wrongPassword)
            default:
                handleEnterResult(result)
            }
        }
    }

    private func handleEnterResult<T>(_ result: Result<T, ErrorInfo>) {
        switch result {
        case .success:
            finishEnter()
        case .failure(let error):
            enteringView.setShown(false)
            ErrorLocalized.showError(code: error.code, message: error.message)
            leaveFromRoom()
        }
    }

    private func finishEnter() {
        enteringView.setShown(false)
        applyConnectConfig()
        RoomParticipantStore.create(roomID: roomID).getParticipantList(cursor: nil, completion: nil)
    }

    private func applyConnectConfig() {
        DeviceStore.shared.setAudioRoute(connectConfig.autoEnableSpeaker ? .speakerphone : .earpiece)

        if connectConfig.autoEnableMicrophone && canOpenMicrophone() {
            RoomDevicePermission.requestMicrophonePermission { granted in
                guard granted else {
                    RoomToast.show(RoomKitResources.localizedString("roomkit.device.mic_no_permission"))
                    return
                }
                DeviceStore.shared.openLocalMicrophone { result in
                    switch result {
                    case .success:
                        RoomParticipantStore.create(roomID: self.roomID).unmuteMicrophone { result in
                            if case .failure(let error) = result {
                                ErrorLocalized.showError(code: error.code, message: error.message)
                            }
                        }
                    case .failure(let error):
                        ErrorLocalized.showError(code: error.code, message: error.message)
                    }
                }
            }
        }

        if connectConfig.autoEnableCamera && canOpenCamera() {
            RoomDevicePermission.requestCameraPermission { granted in
                guard granted else {
                    RoomToast.show(RoomKitResources.localizedString("roomkit.device.camera_no_permission"))
                    return
                }
                DeviceStore.shared.openLocalCamera(isFront: DeviceStore.shared.state.value.isFrontCamera) { result in
                    if case .failure(let error) = result {
                        ErrorLocalized.showError(code: error.code, message: error.message)
                    }
                }
            }
        }
    }

    private func isLocalPrivileged() -> Bool {
        let room = RoomStore.shared.state.value.currentRoom
        let localUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        let isOwner = !localUserID.isEmpty && localUserID == room?.roomOwner.userID
        let isAdmin = RoomParticipantStore.create(roomID: roomID).state.value.localParticipant?.role == .admin
        return isOwner || isAdmin
    }

    private func canOpenMicrophone() -> Bool {
        isLocalPrivileged() || RoomStore.shared.state.value.currentRoom?.isAllMicrophoneDisabled != true
    }

    private func canOpenCamera() -> Bool {
        isLocalPrivileged() || RoomStore.shared.state.value.currentRoom?.isAllCameraDisabled != true
    }

    private func presentPassword(wrongPassword: Bool) {
        RoomPasswordDialog.present(
            in: self,
            wrongPassword: wrongPassword,
            onSubmit: { [weak self] password in
                self?.enteringView.setShown(true)
                self?.joinRoom(password: password)
            },
            onCancel: { [weak self] in self?.leaveFromRoom() }
        )
    }

    private func leaveFromRoom(toast: String? = nil) {
        eventHandler.stop()
        if let toast { RoomToast.show(toast) }
        if let coordinator = routerContext?.navigationController?.transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                self?.popToRootSkippingIntermediateTransition()
            }
        } else {
            popToRootSkippingIntermediateTransition()
        }
    }

    /// Fixed overlapping navigation push/pop animations on iOS 26 and later versions.
    private func popToRootSkippingIntermediateTransition() {
        guard let navigationController = routerContext?.navigationController else {
            routerContext?.popToRoot(animated: true)
            return
        }
        let stack = navigationController.viewControllers
        guard stack.count > 2, let root = stack.first, let top = stack.last else {
            navigationController.popToRootViewController(animated: true)
            return
        }
        navigationController.setViewControllers([root, top], animated: false)
        navigationController.popViewController(animated: true)
    }
}
