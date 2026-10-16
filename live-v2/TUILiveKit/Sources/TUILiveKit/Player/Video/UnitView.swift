import AtomicXCore
import UIKit

final class UnitView: LiveSeat {
    private let liveInfo: LiveInfo?

    init(unitInfo: UnitInfo, liveInfo: LiveInfo? = nil) {
        self.liveInfo = liveInfo
        super.init(emptyTitle: LiveKitResources.localizedString("tuilivekit.player.coguest.apply"))
        setUnitInfo(unitInfo)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setUnitInfo(_ unitInfo: UnitInfo) {
        let ownerID = liveInfo?.liveOwner.userID ?? ""
        let isOwner = !ownerID.isEmpty && ownerID == unitInfo.userID
        updateContent(
            name: unitInfo.userName.isEmpty ? unitInfo.userID : unitInfo.userName,
            avatarURL: unitInfo.avatarURL,
            microphoneOn: unitInfo.microphoneStatus == .on
        )
        updateVisibility(
            isEmpty: unitInfo.userID.isEmpty,
            showsNoVideo: unitInfo.cameraStatus != .on || unitInfo.userSuspendStatus == .inBackground,
            showsOverlay: !isOwner
        )
    }
}
