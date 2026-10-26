import UIKit
import SnapKit

public typealias SearchResultHandler = (Any) -> Void

public final class SearchBarView: UIView {
    private let implementation: SearchEntryBarViewImpl

    public init(onTapItem: @escaping SearchResultHandler) {
        implementation = SearchEntryBarViewImpl(onTapItem: onTapItem)
        super.init(frame: .zero)
        addSubview(implementation)
        implementation.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
