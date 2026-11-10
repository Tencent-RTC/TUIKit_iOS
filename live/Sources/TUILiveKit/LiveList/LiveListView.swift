import AtomicXCore
import SnapKit
import UIKit

public final class LiveListView: UIView {
    public var onLoadMore: (() -> Void)?

    private let pagerView: PagerView

    public init(liveID: String = "") {
        pagerView = PagerView(initialLiveID: liveID)
        super.init(frame: .zero)

        pagerView.onLoadMore = { [weak self] in self?.onLoadMore?() }
        addSubview(pagerView)
        pagerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    public func setData(_ list: [LiveInfo]) {
        pagerView.setData(list)
    }

    public func appendData(_ list: [LiveInfo]) {
        pagerView.appendData(list)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
