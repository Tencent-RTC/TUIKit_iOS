import UIKit
import SnapKit
import Combine
import AtomicXCore

public final class RoomConferenceView: UIView {

    public weak var routerContext: RouterContext?

    public var onRoomLeft: (() -> Void)?

    private let roomID: String
    private var cancellableSet = Set<AnyCancellable>()
    private var pendingSettingsKinds = Set<RoomDeviceKind>()
    private var wasSharing = false
    private var hasSeenLocalInRoom = false
    private let screenShare = RoomScreenShareController.shared
    private let eventHandler: RoomEventHandler

    private var hasLeftRoom = false

    private let topBar = RoomTopBar()
    private let roomView: RoomView
    private let toolBar = RoomToolBar()

    private let sharingPlaceholder = RoomScreenSharingPlaceholderView()
    private var faultSheet: RoomDeviceFaultSheet?
    private var audioRouteSheet: RoomAudioRouteSheet?
    private var moreSheet: RoomMoreMenuSheet?
    private var infoSheet: RoomInfoSheet?
    private var networkSheet: RoomNetworkInfoSheet?
    private var participantsListView: RoomParticipantListView?

    public init(roomID: String) {
        self.roomID = roomID
        self.roomView = RoomView(roomID: roomID)
        self.eventHandler = RoomEventHandler(roomID: roomID)
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        setupEventHandling()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyTheme()
        }
    }

    private func setupViews() {
        addSubview(topBar)
        addSubview(roomView)
        addSubview(sharingPlaceholder)
        addSubview(toolBar)
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
    }

    private func setupStyles() {
        applyTheme()
    }

    private func setupBindings() {
        screenShare.bind(roomID: roomID)
        sharingPlaceholder.onStop = { [weak self] in self?.stopScreenShare() }
        screenShare.$isSharing
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.updateScreenSharing($0) }
            .store(in: &cancellableSet)

        topBar.popoverHost = self
        topBar.onLeave = { [weak self] kind in self?.leave(kind) }
        topBar.onRoomInfoTap = { [weak self] in self?.handleRoomInfoTap() }
        topBar.onNetworkTap = { [weak self] in self?.handleNetworkTap() }
        toolBar.bind(roomID: roomID)
        toolBar.onRequestOpenDevice = { [weak self] kind in self?.openDevice(kind) }
        toolBar.onBlocked = { [weak self] kind in
            RoomToast.show(kind == .camera ? .deviceAllCamDisabled : .deviceAllMicDisabled)
        }
        toolBar.onSpeakerTap = { [weak self] in self?.handleSpeakerTap() }
        toolBar.onChatTap = { [weak self] in self?.handleChatTap() }
        toolBar.onParticipantTap = { [weak self] in self?.handlePartTap() }
        toolBar.onMoreTap = { [weak self] in self?.handleMoreTap() }

        RoomStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \RoomState.currentRoom))
            .receive(on: RunLoop.main)
            .sink { [weak self] room in
                guard let self, let room, !room.isEmpty else { return }
                let localUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
                self.topBar.isOwner = !localUserID.isEmpty && room.roomOwner.userID == localUserID
                self.toolBar.participantCount = room.participantCount
            }
            .store(in: &cancellableSet)

        Publishers.Merge(
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification),
            NotificationCenter.default.publisher(for: RoomLocalMediaUtils.deviceOpenDidFinishNotification)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in self?.refreshDeviceFault() }
        .store(in: &cancellableSet)
        refreshDeviceFault()

        RoomParticipantStore.create(roomID: roomID).state
            .subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.localParticipant))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] local in
                guard let self else { return }
                if local != nil {
                    self.hasSeenLocalInRoom = true
                } else if self.hasSeenLocalInRoom {
                    self.hasSeenLocalInRoom = false
                    self.leaveFromRoom()
                }
            }
            .store(in: &cancellableSet)
    }

    private func setupEventHandling() {
        eventHandler.onLeave = { [weak self] message in
            self?.leaveFromRoom(toast: message)
        }
        eventHandler.start()
    }

    private func applyTheme() {
        backgroundColor = UIColor.roomKitBgSurface
        topBar.backgroundColor = .clear
        toolBar.backgroundColor = .clear
    }

    private func leaveFromRoom(toast: String? = nil) {
        guard !hasLeftRoom else { return }
        hasLeftRoom = true
        eventHandler.stop()
        if let toast { RoomToast.show(toast) }
        onRoomLeft?()
    }
}

// MARK: - private methods

extension RoomConferenceView {

    private func handleSpeakerTap() {
        guard audioRouteSheet == nil else { return }
        let sheet = RoomAudioRouteSheet(current: currentAudioOutput)
        sheet.onSelect = { [weak self] output in
            self?.audioRouteSheet = nil
            RoomLocalMediaUtils.setAudioOutput(output)
        }
        sheet.onDismiss = { [weak self] in self?.audioRouteSheet = nil }
        audioRouteSheet = sheet
        sheet.show(in: self)
    }

    private var currentAudioOutput: RoomAudioOutput {
        DeviceStore.shared.state.value.currentAudioRoute == .speakerphone ? .speaker : .earpiece
    }

    private func handleChatTap() {
        RoomToast.show(.mainFeatureComing)
    }

    private func handlePartTap() {
        guard participantsListView == nil else { return }
        let view = RoomParticipantListView(roomID: roomID)
        view.onDismiss = { [weak self] in self?.participantsListView = nil }
        participantsListView = view
        view.show(in: self)
    }

    private func handleMoreTap() {
        guard moreSheet == nil else { return }
        let sheet = RoomMoreMenuSheet(items: moreItems)
        sheet.onDismiss = { [weak self] in self?.moreSheet = nil }
        moreSheet = sheet
        sheet.show(in: self)
    }

    private var moreItems: [RoomMoreMenuSheet.Item] {
        let pushSettings: () -> Void = { [weak self] in
            guard let self else { return }
            self.moreSheet?.dismiss()
            self.moreSheet = nil
            self.routerContext?.push(RoomSettingsViewController(), animated: true)
        }
        var items: [RoomMoreMenuSheet.Item] = [
            screenShareItem,
            .init(iconName: "roomkit_icon_caption", title: .mainCaptions) { RoomToast.show(.mainFeatureComing) },
        ]
        if let recordItem { items.append(recordItem) }
        items.append(.init(iconName: "roomkit_icon_settings", title: .mainSettings, action: pushSettings))
        return items
    }

    private var recordItem: RoomMoreMenuSheet.Item? {
        let role = RoomParticipantStore.create(roomID: roomID).state.value.localParticipant?.role
        guard role == .owner || role == .admin else { return nil }
        let recording = RoomStore.shared.state.value.currentRoom?.recordingInfo.status == .recording
        return .init(
            iconName: recording ? "roomkit_icon_recording_primary" : "roomkit_icon_record_primary",
            title: recording ? .cloudRecordingStopConfirm : .cloudRecordingRecordLabel
        ) { [weak self] in
            self?.closeMoreSheet()
            guard let presenter = self?.presenter else { return }
            if recording {
                CloudRecordingConfirm.stop(in: presenter)
            } else {
                CloudRecordingConfirm.start(in: presenter)
            }
        }
    }

    private var screenShareItem: RoomMoreMenuSheet.Item {
        if screenShare.isSharing {
            return .init(iconName: "roomkit_icon_screen_share_stop", title: .mainScreenShareStop, isDanger: true) { [weak self] in
                self?.closeMoreSheet()
                self?.confirmStopScreenShare()
            }
        }
        return .init(iconName: "roomkit_icon_screen_share_start", title: .mainScreenShare) { [weak self] in
            self?.requestScreenShare()
        }
    }

    private func closeMoreSheet() {
        moreSheet?.dismiss()
        moreSheet = nil
    }

    private func updateScreenSharing(_ isSharing: Bool) {
        sharingPlaceholder.isHidden = !isSharing
        guard isSharing != wasSharing else { return }
        wasSharing = isSharing
        RoomToast.show(isSharing ? .mainScreenShareStarted : .mainScreenShareStopped)
    }

    private func stopScreenShare() {
        RoomScreenShareController.shared.stop()
    }

    private func confirmStopScreenShare() {
        guard let presenter else { return }
        var dialog: RoomDialog?
        dialog = RoomDialog.Builder(in: presenter)
            .title(.mainScreenShareStopTitle)
            .message(.mainScreenShareStopMessage)
            .secondaryAction(.commonCancel) {}
            .primaryAction(.mainScreenShareStopConfirm, variant: .danger) { [weak self] in
                dialog?.dismiss(animated: true)
                self?.stopScreenShare()
            }
            .show()
    }

    private func requestScreenShare() {
        if screenShare.sharerName != nil {
            RoomToast.show(RoomKitResources.localizedString("roomkit.main.screen_share_remote_sharing"))
            return
        }
        guard let presenter else { return }
        var dialog: RoomDialog?
        dialog = RoomDialog.Builder(in: presenter)
            .title(.mainScreenShareAlertTitle)
            .message(.mainScreenShareAlertMessage)
            .closable(false)
            .cancelable(false)
            .secondaryAction(.commonCancel) {}
            .primaryAction(.mainScreenShareAlertContinue) { [weak self] in
                dialog?.dismiss(animated: true)
                self?.moreSheet?.dismiss()
                self?.moreSheet = nil
                RoomScreenShareController.shared.start()
            }
            .show()
    }

    private var presenter: UIViewController? {
        if let controller = routerContext as? UIViewController { return controller }
        var responder: UIResponder? = next
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }

    private func handleRoomInfoTap() {
        guard infoSheet == nil else { return }
        let sheet = RoomInfoSheet(roomID: roomID)
        sheet.onDismiss = { [weak self] in
            self?.infoSheet = nil
            self?.topBar.isDetailOpen = false
        }
        infoSheet = sheet
        topBar.isDetailOpen = true
        sheet.show(in: self)
    }

    private func handleNetworkTap() {
        guard networkSheet == nil else { return }
        let sheet = RoomNetworkInfoSheet()
        sheet.onDismiss = { [weak self] in self?.networkSheet = nil }
        networkSheet = sheet
        sheet.show(in: self)
    }

    private func leave(_ kind: RoomLeaveRoomButton.Kind) {
        let completion: CompletionClosure = { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                if case .failure(let error) = result {
                    ErrorLocalized.showError(code: error.code, message: error.message)
                    self.leaveFromRoom()
                    return
                }
                self.leaveFromRoom(toast: kind == .endAll ? .mainEnded : .mainLeft)
            }
        }
        switch kind {
        case .endAll: RoomStore.shared.endRoom(completion: completion)
        case .leaveSelf: RoomStore.shared.leaveRoom(completion: completion)
        }
    }
}

extension RoomConferenceView {
    fileprivate func openDevice(_ kind: RoomDeviceKind, onOpened: (() -> Void)? = nil) {
        guard !RoomLocalMediaUtils.isPermissionDenied(kind) else {
            showFaultSheet(kind)
            return
        }
        let completion: (RoomDeviceOpenResult) -> Void = { result in
            if case .opened = result { onOpened?() }
        }
        switch kind {
        case .microphone: RoomLocalMediaUtils.openMicrophone(roomID: roomID, completion: completion)
        case .camera: RoomLocalMediaUtils.openCamera(completion: completion)
        }
    }

    fileprivate func refreshDeviceFault() {
        toolBar.setFault(RoomLocalMediaUtils.isPermissionDenied(.microphone), for: .microphone)
        toolBar.setFault(RoomLocalMediaUtils.isPermissionDenied(.camera), for: .camera)

        if let sheet = faultSheet, !RoomLocalMediaUtils.isPermissionDenied(sheet.kind) {
            sheet.dismiss()
            faultSheet = nil
        }
        for kind in pendingSettingsKinds where !RoomLocalMediaUtils.isPermissionDenied(kind) {
            pendingSettingsKinds.remove(kind)
            openDevice(kind) {
                RoomToast.show(RoomKitResources.localizedFormat("roomkit.main.device_enabled_format", kind.localizedName))
            }
        }
    }

    private func showFaultSheet(_ kind: RoomDeviceKind) {
        guard faultSheet == nil else { return }
        let sheet = RoomDeviceFaultSheet(kind: kind)
        sheet.onPrimary = { [weak self] in
            self?.faultSheet = nil
            self?.pendingSettingsKinds.insert(kind)
            RoomToast.show(.mainDeviceOpenSettingsToast)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
        sheet.onDismiss = { [weak self] in self?.faultSheet = nil }
        faultSheet = sheet
        sheet.show(in: self)
    }
}

// MARK: - localized strings

extension String {
    fileprivate static var mainDeviceOpenSettingsToast: String { RoomKitResources.localizedString("roomkit.main.device_open_settings_toast") }
    fileprivate static var mainLeft: String { RoomKitResources.localizedString("roomkit.main.left") }
    fileprivate static var mainEnded: String { RoomKitResources.localizedString("roomkit.main.ended") }
    fileprivate static var mainFeatureComing: String { RoomKitResources.localizedString("roomkit.main.feature_coming") }
    fileprivate static var cloudRecordingRecordLabel: String { RoomKitResources.localizedString("roomkit.cloud_recording.record_label") }
    fileprivate static var cloudRecordingStopConfirm: String { RoomKitResources.localizedString("roomkit.cloud_recording.stop_confirm") }
    fileprivate static var deviceAllMicDisabled: String { RoomKitResources.localizedString("roomkit.device.all_mic_disabled") }
    fileprivate static var deviceAllCamDisabled: String { RoomKitResources.localizedString("roomkit.device.all_cam_disabled") }
    fileprivate static var mainScreenShare: String { RoomKitResources.localizedString("roomkit.main.screen_share") }
    fileprivate static var mainScreenShareStop: String { RoomKitResources.localizedString("roomkit.main.screen_share_stop") }
    fileprivate static var mainScreenShareAlertTitle: String { RoomKitResources.localizedString("roomkit.main.screen_share_alert_title") }
    fileprivate static var mainScreenShareAlertMessage: String { RoomKitResources.localizedString("roomkit.main.screen_share_alert_message") }
    fileprivate static var mainScreenShareAlertContinue: String { RoomKitResources.localizedString("roomkit.main.screen_share_alert_continue") }
    fileprivate static var mainScreenShareStarted: String { RoomKitResources.localizedString("roomkit.main.screen_share_started") }
    fileprivate static var mainScreenShareStopped: String { RoomKitResources.localizedString("roomkit.main.screen_share_stopped") }
    fileprivate static var mainScreenShareStopTitle: String { RoomKitResources.localizedString("roomkit.main.screen_share_stop_title") }
    fileprivate static var mainScreenShareStopMessage: String { RoomKitResources.localizedString("roomkit.main.screen_share_stop_message") }
    fileprivate static var mainScreenShareStopConfirm: String { RoomKitResources.localizedString("roomkit.main.screen_share_stop_confirm") }
    fileprivate static var commonCancel: String { RoomKitResources.localizedString("roomkit.common.cancel") }
    fileprivate static var mainCaptions: String { RoomKitResources.localizedString("roomkit.main.captions") }
    fileprivate static var mainRecord: String { RoomKitResources.localizedString("roomkit.main.record") }
    fileprivate static var mainSettings: String { RoomKitResources.localizedString("roomkit.settings.title") }
}
