import AtomicXCore
import UIKit

/// A single custom unit replaces the old background/foreground delegates. Its
/// no-video cover also hides a guest's video while the guest is in the background.
final class PusherUnitView: LiveSeat {
    private(set) var unitInfo: UnitInfo
    var onGeometryChanged: (() -> Void)?
    private var isLiving = false
    private var showsEmptySeats = false
    private var hasGuests = false
    private var showsHostOverlay = false
    private var localCameraStatus: DeviceStatus?

    var isHost: Bool {
        !unitInfo.userID.isEmpty && unitInfo.userID == LoginStore.shared.state.value.loginUserInfo?.userID
    }
    var isGuest: Bool { !unitInfo.userID.isEmpty && !isHost }

    init(unitInfo: UnitInfo) {
        self.unitInfo = unitInfo
        super.init(emptyTitle: LiveKitResources.localizedString("tuilivekit.pusher.coguest.invite_to_seat"))
        setUnitInfo(unitInfo)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setUnitInfo(_ unitInfo: UnitInfo) {
        if self.unitInfo.userID != unitInfo.userID || unitInfo.microphoneStatus != .on { super.updateVolume(0) }
        self.unitInfo = unitInfo
        updateContent(
            name: unitInfo.userName.isEmpty ? unitInfo.userID : unitInfo.userName, avatarURL: unitInfo.avatarURL,
            microphoneOn: unitInfo.microphoneStatus == .on)
        refreshVisibility()
    }

    func setPresentation(
        isLiving: Bool, showsEmptySeats: Bool, hasGuests: Bool, showsHostOverlay: Bool, localCameraStatus: DeviceStatus?
    ) {
        self.isLiving = isLiving
        self.showsEmptySeats = showsEmptySeats
        self.hasGuests = hasGuests
        self.showsHostOverlay = showsHostOverlay
        self.localCameraStatus = localCameraStatus
        refreshVisibility()
    }

    override func updateVolume(_ volume: Int) {
        let canSpeak = isLiving && !unitInfo.userID.isEmpty && unitInfo.microphoneStatus == .on
        super.updateVolume(canSpeak ? max(0, volume) : 0)
    }

    private func refreshVisibility() {
        if !isLiving { super.updateVolume(0) }
        let isEmpty = unitInfo.userID.isEmpty
        // The host's seat snapshot can lag behind an already active local preview.
        let cameraStatus = isHost ? localCameraStatus : unitInfo.cameraStatus
        let isGuestInBackground = isGuest && unitInfo.userSuspendStatus == .inBackground
        isHidden = !isLiving || (isEmpty && !showsEmptySeats)
        updateVisibility(
            isEmpty: isEmpty, showsNoVideo: isGuestInBackground || (cameraStatus != nil && cameraStatus != .on),
            showsOverlay: (isGuest && hasGuests) || (isHost && showsHostOverlay))
    }

    override var frame: CGRect { didSet { if oldValue != frame { onGeometryChanged?() } } }
    override var center: CGPoint { didSet { if oldValue != center { onGeometryChanged?() } } }
    override var isHidden: Bool { didSet { if oldValue != isHidden { onGeometryChanged?() } } }
    override func didMoveToWindow() {
        super.didMoveToWindow();
        onGeometryChanged?()
    }
    override func didMoveToSuperview() {
        super.didMoveToSuperview();
        onGeometryChanged?()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        onGeometryChanged?()
    }
}
