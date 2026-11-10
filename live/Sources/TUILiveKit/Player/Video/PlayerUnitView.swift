import AtomicXCore
import UIKit

final class PlayerUnitView: LiveSeat {
    var onGeometryChanged: (() -> Void)?
    var representedLiveID: String { liveInfo?.liveID ?? "" }
    private var liveInfo: LiveInfo?
    private var currentUnitInfo: UnitInfo
    private var currentStatus: PlayerStatus

    init(unitInfo: UnitInfo, liveInfo: LiveInfo? = nil, playerStatus: PlayerStatus = .idle) {
        self.liveInfo = liveInfo
        self.currentUnitInfo = unitInfo
        self.currentStatus = playerStatus
        super.init(emptyTitle: LiveKitResources.localizedString("tuilivekit.player.coguest.apply"))
        apply()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setUnitInfo(_ unitInfo: UnitInfo, liveInfo: LiveInfo) {
        self.liveInfo = liveInfo
        currentUnitInfo = unitInfo
        apply()
    }

    func setPlayerStatus(_ status: PlayerStatus) {
        guard currentStatus != status else { return }
        currentStatus = status
        apply()
    }

    override var frame: CGRect { didSet { if frame != oldValue { onGeometryChanged?() } } }
    override var center: CGPoint { didSet { if center != oldValue { onGeometryChanged?() } } }
    override var isHidden: Bool { didSet { if isHidden != oldValue { onGeometryChanged?() } } }
    override func didMoveToSuperview() {
        super.didMoveToSuperview();
        onGeometryChanged?()
    }
    override func didMoveToWindow() {
        super.didMoveToWindow();
        onGeometryChanged?()
    }
    override func layoutSubviews() {
        super.layoutSubviews();
        onGeometryChanged?()
    }

    private func apply() {
        let info = currentUnitInfo
        let ownerID = liveInfo?.liveOwner.userID ?? ""
        let isOwner = !ownerID.isEmpty && ownerID == info.userID
        let roomActive = currentStatus == .inRoom || currentStatus == .coGuest
        updateContent(
            name: info.userName.isEmpty ? info.userID : info.userName, avatarURL: info.avatarURL,
            microphoneOn: info.microphoneStatus == .on)
        updateVisibility(
            isEmpty: info.userID.isEmpty,
            showsNoVideo: info.cameraStatus != .on || info.userSuspendStatus == .inBackground,
            showsOverlay: !isOwner && roomActive)
    }
}
