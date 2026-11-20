import AtomicXCore
import SnapKit
import UIKit

final class VoiceLoungeAudienceEndView: UIView {
    var onBack: (() -> Void)?
    var onSwipeUp: (() -> Void)?

    private let summaryView = SummaryView()
    private let backButton = UIButton(type: .custom)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = LiveTheme.Color.canvasBackground
        addSubview(summaryView)
        addSubview(backButton)
        summaryView.snp.makeConstraints { $0.edges.equalToSuperview() }

        backButton.setImage(LiveKitResources.image(named: "livekit_summary_back"), for: .normal)
        backButton.imageView?.contentMode = .scaleAspectFit
        backButton.accessibilityLabel = LiveKitResources.localizedString("tuilivekit.pusher.summary.back")
        backButton.addTarget(self, action: #selector(tapBack), for: .touchUpInside)
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalTo(safeAreaLayoutGuide.snp.top).offset(14)
            make.size.equalTo(44)
        }

        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swipeUp))
        swipe.direction = .up
        addGestureRecognizer(swipe)
        isHidden = true
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(liveInfo: LiveInfo, reason: String? = nil) {
        summaryView.bind(liveInfo, reason: reason)
        isHidden = false
        superview?.bringSubviewToFront(self)
    }

    @objc private func tapBack() { onBack?() }
    @objc private func swipeUp() { onSwipeUp?() }
}
