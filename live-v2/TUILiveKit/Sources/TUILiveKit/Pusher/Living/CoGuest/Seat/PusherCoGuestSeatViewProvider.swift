import AtomicXCore
import UIKit

/// The SDK owns seat geometry. This adapter updates the widgets of each reusable
/// unit, including empty seats, and exposes their actual frames to the host UI.
final class PusherCoGuestSeatViewProvider: AtomicLiveViewChangeAdapter {
    private struct ManagedView {
        weak var view: PusherCoGuestUnitView?
    }

    var onGeometryChanged: (() -> Void)?
    private var geometryNotificationPending = false
    private var managedViews: [ManagedView] = []
    private var usesSmallWindows = false
    private var isLiving = false
    private var connectedGuestCount = 0
    private var showsEmptySeats = false
    private var showsHostOverlay = false
    private var localCameraStatus: DeviceStatus?

    func updateLocalCameraStatus(_ status: DeviceStatus) {
        guard localCameraStatus != status else { return }
        localCameraStatus = status
        managedViews.removeAll { $0.view == nil }
        // Reused seats may later represent the host, so keep every presentation current.
        managedViews.compactMap(\.view).forEach(updatePresentation)
    }

    func update(isLiving: Bool, layout: PusherCoGuestStore.Layout, connectedGuestCount: Int) {
        self.isLiving = isLiving
        self.connectedGuestCount = connectedGuestCount
        showsEmptySeats = layout.showsEmptySeats
        showsHostOverlay = layout == .grid9 || (layout == .grid2 && connectedGuestCount > 0)
        usesSmallWindows = layout == .floating || layout == .fixed
        managedViews.removeAll { $0.view == nil }
        managedViews.forEach { if let view = $0.view { updatePresentation(view) } }
        notifyGeometryChanged()
    }

    func onCreateUnitView(unitInfo: UnitInfo?) -> UIView? {
        guard let unitInfo else { return nil }
        let view = PusherCoGuestUnitView(unitInfo: unitInfo)
        view.onGeometryChanged = { [weak self] in self?.notifyGeometryChanged() }
        managedViews.removeAll { $0.view == nil }
        managedViews.append(ManagedView(view: view))
        updatePresentation(view)
        return view
    }

    func onUpdateUnitView(unitInfo: UnitInfo?, view: UIView?) {
        guard let view = view as? PusherCoGuestUnitView else { return }
        // A nil update clears the reusable unit rather than retaining its old user.
        view.setUnitInfo(unitInfo ?? UnitInfo())
        notifyGeometryChanged()
    }

    func onVideoViewFrameChanged(left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat) {
        notifyGeometryChanged()
    }

    func guestUserID(at point: CGPoint, in sourceView: UIView) -> String? {
        guard isLiving, connectedGuestCount > 0 else { return nil }
        return managedViews.reversed().compactMap(\.view).first { view in
            view.isGuest && isVisible(view, in: sourceView)
                && view.bounds.contains(view.convert(point, from: sourceView))
        }?.unitInfo.userID
    }

    func smallWindowRegions(in targetView: UIView) -> [CGRect] {
        guard isLiving, usesSmallWindows else { return [] }
        return managedViews.compactMap(\.view).compactMap { view in
            guard !view.isHost, isVisible(view, in: targetView) else { return nil }
            return view.convert(view.bounds, to: targetView)
        }
    }

    private func isVisible(_ view: UIView, in target: UIView) -> Bool {
        guard view.window != nil, view.window === target.window, !view.bounds.isEmpty else { return false }
        var ancestor: UIView? = view
        while let current = ancestor {
            guard !current.isHidden, current.alpha > 0.01 else { return false }
            ancestor = current.superview
        }
        return true
    }

    private func updatePresentation(_ view: PusherCoGuestUnitView) {
        view.setPresentation(isLiving: isLiving, showsEmptySeats: showsEmptySeats,
                    hasGuests: connectedGuestCount > 0, showsHostOverlay: showsHostOverlay,
                    localCameraStatus: localCameraStatus)
    }

    private func notifyGeometryChanged() {
        guard !geometryNotificationPending else { return }
        geometryNotificationPending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.geometryNotificationPending = false
            self.onGeometryChanged?()
        }
    }
}

/// A single custom unit replaces the old background/foreground delegates. Its
/// no-video cover also hides a guest's video while the guest is in the background.
private final class PusherCoGuestUnitView: LiveSeat {
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

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setUnitInfo(_ unitInfo: UnitInfo) {
        self.unitInfo = unitInfo
        updateContent(
            name: unitInfo.userName.isEmpty ? unitInfo.userID : unitInfo.userName,
            avatarURL: unitInfo.avatarURL,
            microphoneOn: unitInfo.microphoneStatus == .on
        )
        refreshVisibility()
    }

    func setPresentation(isLiving: Bool, showsEmptySeats: Bool, hasGuests: Bool, showsHostOverlay: Bool, localCameraStatus: DeviceStatus?) {
        self.isLiving = isLiving
        self.showsEmptySeats = showsEmptySeats
        self.hasGuests = hasGuests
        self.showsHostOverlay = showsHostOverlay
        self.localCameraStatus = localCameraStatus
        refreshVisibility()
    }

    private func refreshVisibility() {
        let isEmpty = unitInfo.userID.isEmpty
        // The host's seat snapshot can lag behind an already active local preview.
        let cameraStatus = isHost ? localCameraStatus : unitInfo.cameraStatus
        let isGuestInBackground = isGuest && unitInfo.userSuspendStatus == .inBackground
        isHidden = !isLiving || (isEmpty && !showsEmptySeats)
        updateVisibility(
            isEmpty: isEmpty,
            showsNoVideo: isGuestInBackground || (cameraStatus != nil && cameraStatus != .on),
            showsOverlay: (isGuest && hasGuests) || (isHost && showsHostOverlay)
        )
    }

    override var frame: CGRect { didSet { if oldValue != frame { onGeometryChanged?() } } }
    override var center: CGPoint { didSet { if oldValue != center { onGeometryChanged?() } } }
    override var isHidden: Bool { didSet { if oldValue != isHidden { onGeometryChanged?() } } }
    override func didMoveToWindow() { super.didMoveToWindow(); onGeometryChanged?() }
    override func didMoveToSuperview() { super.didMoveToSuperview(); onGeometryChanged?() }
    override func layoutSubviews() {
        super.layoutSubviews()
        onGeometryChanged?()
    }
}
