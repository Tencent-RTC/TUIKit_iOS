import AtomicXCore
import Kingfisher
import SnapKit
import UIKit

final class PlayerVideoView: UIView {
    let coreView = AtomicLiveView(viewType: AtomicLiveViewType.playView)
    private let backgroundView = UIImageView()
    private var liveInfo = LiveInfo()
    private let unitAdapter = LiveVideoViewAdapter()

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        backgroundView.contentMode = .scaleAspectFill
        backgroundView.clipsToBounds = true
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in make.edges.equalToSuperview() }
        coreView.setViewChangeAdapter(unitAdapter)
        addSubview(coreView)
        coreView.snp.makeConstraints { make in make.edges.equalToSuperview() }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var onGeometryChanged: (() -> Void)? {
        get { unitAdapter.onGeometryChanged }
        set { unitAdapter.onGeometryChanged = newValue }
    }

    func visibleSeatRegions(in view: UIView) -> [CGRect] { unitAdapter.visibleSeatRegions(in: view) }

    func setLiveInfo(_ liveInfo: LiveInfo) {
        self.liveInfo = liveInfo
        unitAdapter.liveInfo = liveInfo
        setBackground(liveInfo)
        guard !liveInfo.liveID.isEmpty else { return }
        coreView.setLiveID(liveInfo.liveID)
    }

    func setPlayerStatus(_ status: PlayerStatus) { unitAdapter.setStatus(status) }

    private func setBackground(_ liveInfo: LiveInfo) {
        let url =
            liveInfo.backgroundURL.isEmpty
            ? (liveInfo.coverURL.isEmpty ? LiveKitResources.defaultBackgroundURL : liveInfo.coverURL)
            : liveInfo.backgroundURL
        let placeholder = LiveKitResources.image(named: "livekit_livelist_default_cover")
        backgroundView.kf.setImage(
            with: URL(string: url), placeholder: placeholder, options: [.processor(BlurImageProcessor(blurRadius: 80))])
    }
}

private final class LiveVideoViewAdapter: AtomicLiveViewChangeAdapter {
    var onGeometryChanged: (() -> Void)?
    var liveInfo = LiveInfo() {
        didSet {
            guard liveInfo.liveID != oldValue.liveID else { return }
            geometrySession = UUID()
            geometryNotificationPending = false
            activeUnits.removeAllObjects()
        }
    }
    private var geometrySession = UUID()
    private var geometryNotificationPending = false
    private var currentStatus: PlayerStatus = .idle
    private let activeUnits = NSHashTable<PlayerUnitView>.weakObjects()

    func setStatus(_ status: PlayerStatus) {
        guard currentStatus != status else { return }
        currentStatus = status
        activeUnits.allObjects.forEach { $0.setPlayerStatus(status) }
        notifyGeometryChanged()
    }

    func onCreateUnitView(unitInfo: UnitInfo?) -> UIView? {
        guard let unitInfo, unitInfo.liveID.isEmpty || unitInfo.liveID == liveInfo.liveID else { return nil }
        let view = PlayerUnitView(unitInfo: unitInfo, liveInfo: liveInfo, playerStatus: currentStatus)
        track(view)
        return view
    }

    func onUpdateUnitView(unitInfo: UnitInfo?, view: UIView?) {
        guard let view = view as? PlayerUnitView, unitInfo != nil || view.representedLiveID == liveInfo.liveID,
            unitInfo == nil || unitInfo?.liveID.isEmpty == true || unitInfo?.liveID == liveInfo.liveID
        else { return }
        view.setUnitInfo(unitInfo ?? UnitInfo(), liveInfo: liveInfo)
        view.setPlayerStatus(currentStatus)
        track(view)
    }
    func onVolumeChanged(unitInfo: UnitInfo?, volume: Int, view: UIView?) {
        (view as? PlayerUnitView)?.updateVolume(volume)
    }

    func onVideoViewFrameChanged(left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat) {
        notifyGeometryChanged()
    }

    func visibleSeatRegions(in target: UIView) -> [CGRect] {
        guard currentStatus == .inRoom || currentStatus == .coGuest else { return [] }
        return activeUnits.allObjects.compactMap { view in
            guard view.representedLiveID == liveInfo.liveID, view.window != nil, view.window === target.window,
                !view.bounds.isEmpty
            else { return nil }
            var ancestor: UIView? = view
            while let current = ancestor {
                guard !current.isHidden, current.alpha > 0.01 else { return nil }
                ancestor = current.superview
            }
            return view.convert(view.bounds, to: target)
        }
    }

    private func track(_ view: PlayerUnitView) {
        activeUnits.add(view)
        view.onGeometryChanged = { [weak self, weak view] in
            guard let self, let view, view.representedLiveID == self.liveInfo.liveID else { return }
            self.notifyGeometryChanged()
        }
        notifyGeometryChanged()
    }

    private func notifyGeometryChanged() {
        guard !geometryNotificationPending else { return }
        geometryNotificationPending = true
        let session = geometrySession
        DispatchQueue.main.async { [weak self] in
            guard let self, self.geometrySession == session else { return }
            self.geometryNotificationPending = false
            self.onGeometryChanged?()
        }
    }
}
