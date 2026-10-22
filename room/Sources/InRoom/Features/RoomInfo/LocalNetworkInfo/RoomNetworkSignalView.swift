import UIKit
import SnapKit
import AtomicXCore

final class RoomNetworkSignalView: UIControl {

    private static let barHeights: [CGFloat] = [4, 8, 12]
    private static let barWidth: CGFloat = 3
    private static let barGap: CGFloat = 2
    private static let barCornerRadius: CGFloat = 1
    private static let alphaLit: CGFloat = 1
    private static let alphaDim: CGFloat = 0.28
    private static let alphaDown: CGFloat = 0.18

    private let bars: [UIView]
    private var quality: NetworkQuality = .excellent

    override init(frame: CGRect) {
        bars = Self.barHeights.map { _ in UIView() }
        super.init(frame: frame)
        layer.cornerRadius = 8

        let stack = UIStackView(arrangedSubviews: bars)
        stack.axis = .horizontal
        stack.alignment = .bottom
        stack.spacing = Self.barGap
        stack.isUserInteractionEnabled = false
        addSubview(stack)
        stack.snp.makeConstraints { $0.center.equalToSuperview() }

        for (index, bar) in bars.enumerated() {
            bar.isUserInteractionEnabled = false
            bar.layer.cornerRadius = Self.barCornerRadius
            bar.snp.makeConstraints {
                $0.width.equalTo(Self.barWidth)
                $0.height.equalTo(Self.barHeights[index])
            }
        }
        applyTheme()
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
            bar.alpha = index < level ? Self.alphaLit : (level == 0 ? Self.alphaDown : Self.alphaDim)
        }
    }
}

// MARK: - public methods

extension RoomNetworkSignalView {

    func update(quality: NetworkQuality) {
        guard self.quality != quality else { return }
        self.quality = quality
        applyTheme()
    }
}
