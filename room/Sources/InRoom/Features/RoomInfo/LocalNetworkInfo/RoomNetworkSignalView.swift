import UIKit
import SnapKit
import Combine
import AtomicXCore

final class RoomNetworkSignalView: UIControl {

    private static let barHeights: [CGFloat] = [4, 8, 12]

    private let bars: [UIView]
    private var quality: NetworkQuality = .excellent
    private var popup: RoomNetworkInfoPopup?
    private var cancellableSet = Set<AnyCancellable>()

    override init(frame: CGRect) {
        bars = Self.barHeights.map { _ in UIView() }
        super.init(frame: frame)
        layer.cornerRadius = 8

        let stack = UIStackView(arrangedSubviews: bars)
        stack.axis = .horizontal
        stack.alignment = .bottom
        stack.spacing = 2
        stack.isUserInteractionEnabled = false
        addSubview(stack)
        stack.snp.makeConstraints { $0.center.equalToSuperview() }

        for (index, bar) in bars.enumerated() {
            bar.isUserInteractionEnabled = false
            bar.layer.cornerRadius = 1
            bar.snp.makeConstraints {
                $0.width.equalTo(3)
                $0.height.equalTo(Self.barHeights[index])
            }
        }
        applyTheme()
        setupBindings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyTheme()
        }
    }

    private func setupBindings() {
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        DeviceStore.shared.state
            .subscribe(StatePublisherSelector(projector: { $0.networkInfo.quality }))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.update(quality: $0) }
            .store(in: &cancellableSet)
    }

    @objc private func handleTap() {
        guard popup == nil else { return }
        let popup = RoomNetworkInfoPopup()
        popup.onDismiss = { [weak self] in self?.popup = nil }
        self.popup = popup
        popup.show(in: self)
    }

    private func applyTheme() {
        let level: Int
        let color: UIColor
        switch quality {
        case .excellent, .good:
            level = 3
            color = UIColor.roomKitSuccess
        case .poor:
            level = 2
            color = UIColor.roomKitWarning
        case .bad, .veryBad:
            level = 1
            color = UIColor.roomKitDanger
        case .down, .unknown:
            level = 0
            color = UIColor.roomKitDanger
        }
        backgroundColor = level <= 1 ? UIColor.roomKitDangerFaint : .clear

        for (index, bar) in bars.enumerated() {
            bar.backgroundColor = color
            bar.alpha = index < level ? 1 : (level == 0 ? 0.18 : 0.28)
        }
    }
}

extension RoomNetworkSignalView {

    func update(quality: NetworkQuality) {
        guard self.quality != quality else { return }
        self.quality = quality
        applyTheme()
    }
}
