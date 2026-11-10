import AtomicXCore
import SnapKit
import UIKit

final class PusherVideoView: UIView {
    let coreView = AtomicLiveView(viewType: AtomicLiveViewType.pushView)
    private let unitAdapter = LiveVideoViewAdapter()

    init(liveID: String) {
        super.init(frame: .zero)
        backgroundColor = PusherVideoStyle.idleBackground
        coreView.setViewChangeAdapter(unitAdapter)
        coreView.backgroundColor = .clear
        coreView.setLiveID(liveID)
        addSubview(coreView)
        coreView.snp.makeConstraints { make in make.edges.equalToSuperview() }
    }

    func updateCoGuestVideoState(isLiving: Bool, layout: CoGuestLayoutTemplate, connectedGuestCount: Int) {
        unitAdapter.update(isLiving: isLiving, layout: layout, connectedGuestCount: connectedGuestCount)
        let isCoGuestStageVisible = isLiving && (connectedGuestCount > 0 || layout != .floatLayout)
        backgroundColor = isCoGuestStageVisible ? .clear : PusherVideoStyle.idleBackground
    }

    func updateLocalCameraStatus(_ status: DeviceStatus) { unitAdapter.updateLocalCameraStatus(status) }

    var onCoGuestGeometryChanged: (() -> Void)? {
        get { unitAdapter.onGeometryChanged }
        set { unitAdapter.onGeometryChanged = newValue }
    }

    func coGuestSmallWindowRegions(in view: UIView) -> [CGRect] { unitAdapter.smallWindowRegions(in: view) }

    func coGuestGridRegions(in view: UIView) -> [CGRect] { unitAdapter.gridRegions(in: view) }

    func coGuestUserID(at point: CGPoint) -> String? { unitAdapter.guestUserID(at: point, in: self) }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum PusherVideoStyle { static let idleBackground: UIColor = UIColor(white: 0.12, alpha: 1) }

/// The SDK owns seat geometry. This adapter updates the widgets of each reusable
/// unit, including empty seats, and exposes their actual frames to the host UI.
private final class LiveVideoViewAdapter: AtomicLiveViewChangeAdapter {
    private struct ManagedView { weak var view: PusherUnitView? }

    var onGeometryChanged: (() -> Void)?
    private var geometryNotificationPending = false
    private var managedViews: [ManagedView] = []
    private var usesSmallWindows = false
    private var usesGrid = false
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

    func update(isLiving: Bool, layout: CoGuestLayoutTemplate, connectedGuestCount: Int) {
        self.isLiving = isLiving
        self.connectedGuestCount = connectedGuestCount
        showsEmptySeats = layout.pusherShowsEmptySeats
        showsHostOverlay = layout == .gridLayout || (layout == .dynamicLayout && connectedGuestCount > 0)
        usesSmallWindows = layout == .floatLayout || layout == .columnLayout
        usesGrid = layout == .gridLayout || (layout == .dynamicLayout && connectedGuestCount > 0)
        managedViews.removeAll { $0.view == nil }
        managedViews.forEach { if let view = $0.view { updatePresentation(view) } }
        notifyGeometryChanged()
    }

    func onCreateUnitView(unitInfo: UnitInfo?) -> UIView? {
        guard let unitInfo else { return nil }
        let view = PusherUnitView(unitInfo: unitInfo)
        view.onGeometryChanged = { [weak self] in self?.notifyGeometryChanged() }
        managedViews.removeAll { $0.view == nil }
        managedViews.append(ManagedView(view: view))
        updatePresentation(view)
        return view
    }

    func onUpdateUnitView(unitInfo: UnitInfo?, view: UIView?) {
        guard let view = view as? PusherUnitView else { return }
        // A nil update clears the reusable unit rather than retaining its old user.
        view.setUnitInfo(unitInfo ?? UnitInfo())
        notifyGeometryChanged()
    }
    func onVolumeChanged(unitInfo: UnitInfo?, volume: Int, view: UIView?) {
        guard let view = view as? PusherUnitView, unitInfo == nil || unitInfo?.userID == view.unitInfo.userID else {
            return
        }
        view.updateVolume(volume)
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

    func gridRegions(in targetView: UIView) -> [CGRect] {
        guard isLiving, usesGrid else { return [] }
        // Include the host and visible empty seats, not only connected guests.
        return managedViews.compactMap(\.view).compactMap { view in
            guard isVisible(view, in: targetView) else { return nil }
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

    private func updatePresentation(_ view: PusherUnitView) {
        view.setPresentation(
            isLiving: isLiving, showsEmptySeats: showsEmptySeats, hasGuests: connectedGuestCount > 0,
            showsHostOverlay: showsHostOverlay, localCameraStatus: localCameraStatus)
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
