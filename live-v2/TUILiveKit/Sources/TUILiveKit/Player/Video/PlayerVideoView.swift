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

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setLiveInfo(_ liveInfo: LiveInfo) {
        self.liveInfo = liveInfo
        unitAdapter.liveInfo = liveInfo
        setBackground(liveInfo)
        guard !liveInfo.liveID.isEmpty else { return }
        coreView.setLiveID(liveInfo.liveID)
    }

    private func setBackground(_ liveInfo: LiveInfo) {
        let url = liveInfo.backgroundURL.isEmpty
        ? (liveInfo.coverURL.isEmpty ? LiveKitResources.defaultBackgroundURL : liveInfo.coverURL)
            : liveInfo.backgroundURL
        let placeholder = LiveKitResources.image(named: "livekit_livelist_default_cover")
        backgroundView.kf.setImage(
            with: URL(string: url),
            placeholder: placeholder,
            options: [.processor(BlurImageProcessor(blurRadius: 80))]
        )
    }
}

private final class LiveVideoViewAdapter: AtomicLiveViewChangeAdapter {
    var liveInfo = LiveInfo()

    func onCreateUnitView(unitInfo: UnitInfo?) -> UIView? {
        guard let unitInfo else { return nil }
        return UnitView(unitInfo: unitInfo, liveInfo: liveInfo)
    }

    func onUpdateUnitView(unitInfo: UnitInfo?, view: UIView?) {
        (view as? UnitView)?.setUnitInfo(unitInfo ?? UnitInfo())
    }

    func onVideoViewFrameChanged(left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat) {}
}
