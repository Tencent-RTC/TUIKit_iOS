import AtomicXCore
import SnapKit
import UIKit

final class PusherVideoView: UIView {
    let coreView = AtomicLiveView(viewType: AtomicLiveViewType.pushView)
    private let coGuestSeatViewProvider = PusherCoGuestSeatViewProvider()

    init(liveID: String) {
        super.init(frame: .zero)
        backgroundColor = PusherVideoStyle.idleBackground
        coreView.setViewChangeAdapter(coGuestSeatViewProvider)
        coreView.backgroundColor = .clear
        coreView.setLiveID(liveID)
        addSubview(coreView)
        coreView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func updateCoGuestVideoState(
        isLiving: Bool,
        layout: PusherCoGuestStore.Layout,
        connectedGuestCount: Int
    ) {
        coGuestSeatViewProvider.update(
            isLiving: isLiving,
            layout: layout,
            connectedGuestCount: connectedGuestCount
        )
        let isCoGuestStageVisible = isLiving && (connectedGuestCount > 0 || layout != .floating)
        backgroundColor = isCoGuestStageVisible ? .clear : PusherVideoStyle.idleBackground
    }

    func updateLocalCameraStatus(_ status: DeviceStatus) {
        coGuestSeatViewProvider.updateLocalCameraStatus(status)
    }

    var onCoGuestGeometryChanged: (() -> Void)? {
        get { coGuestSeatViewProvider.onGeometryChanged }
        set { coGuestSeatViewProvider.onGeometryChanged = newValue }
    }

    func coGuestSmallWindowRegions(in view: UIView) -> [CGRect] {
        coGuestSeatViewProvider.smallWindowRegions(in: view)
    }

    func coGuestUserID(at point: CGPoint) -> String? {
        coGuestSeatViewProvider.guestUserID(at: point, in: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum PusherVideoStyle {
    static let idleBackground: UIColor = UIColor(white: 0.12, alpha: 1)
}
