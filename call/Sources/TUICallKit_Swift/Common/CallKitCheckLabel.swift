import UIKit

final class CallKitCheckLabel: UILabel {

    init(tint: UIColor) {
        super.init(frame: .zero)
        text = "✓"
        font = .systemFont(ofSize: 15, weight: .bold)
        textColor = tint
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
