import UIKit
import SnapKit

final class BubbleMenuViewController: UIViewController {
    struct Item {
        let icon: UIImage?
        let title: String
        let action: () -> Void
    }

    private static let bubbleCornerRadius: CGFloat = CGFloat(RadiusScheme.smallRadius)

    private static let arrowWidth: CGFloat = 12

    private static let arrowHeight: CGFloat = 6

    private static let shadowOpacity: Float = 0.2

    private static let rowHorizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let rowVerticalPadding: CGFloat = 10

    private static let iconSize: CGFloat = 20

    private static let iconTextSpacing: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let dividerHorizontalMargin: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let dividerHeight: CGFloat = 1

    private static let minContentWidth: CGFloat = 72

    private static let maxWidthScreenInset: CGFloat = CGFloat(SpacingScheme.titleSpacing)

    private static let screenMargin: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    private static let anchorGap: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)

    private static let titleFontSize: CGFloat = 16

    private static let appearDuration: TimeInterval = 0.15

    private static let rowHeight: CGFloat = titleFontSize * 1.2 + rowVerticalPadding * 2

    private let anchorView: UIView

    private let items: [Item]

    private let bubbleView = BubbleMenuBubbleView()

    private let stackView = UIStackView()

    init(anchorView: UIView, items: [Item]) {
        self.anchorView = anchorView
        self.items = items
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: Self.appearDuration) {
            self.view.alpha = 1
        }
    }

    private func constructViewHierarchy() {
        view.alpha = 0
        view.addSubview(bubbleView)
        stackView.axis = .vertical
        stackView.spacing = 0
        for (index, item) in items.enumerated() {
            stackView.addArrangedSubview(makeRow(item: item))
            if index < items.count - 1 {
                stackView.addArrangedSubview(makeDivider())
            }
        }
        bubbleView.contentView.addSubview(stackView)
    }

    private func activateConstraints() {
        let contentWidth = Self.contentWidth(for: items)
        let contentHeight = Self.contentHeight(for: items)
        let anchorFrame = anchorView.convert(anchorView.bounds, to: nil)
        let screenWidth = UIScreen.main.bounds.width

        let isRTL = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let preferredX = isRTL ? Self.screenMargin : screenWidth - contentWidth - Self.screenMargin
        let maxX = screenWidth - contentWidth - Self.screenMargin
        let bubbleX = max(Self.screenMargin, min(preferredX, maxX))
        let bubbleY = anchorFrame.maxY + Self.anchorGap
        let arrowCenterX = (anchorFrame.midX - bubbleX)
            .clamped(to: Self.bubbleCornerRadius ... contentWidth - Self.bubbleCornerRadius)

        bubbleView.arrowCenterX = arrowCenterX
        bubbleView.frame = CGRect(
            x: bubbleX,
            y: bubbleY,
            width: contentWidth,
            height: Self.arrowHeight + contentHeight
        )
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(contentWidth)
            make.height.equalTo(contentHeight)
        }
    }

    private func bindInteraction() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackdropTap(_:)))
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    private static func contentWidth(for items: [Item]) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: titleFontSize)]
        let maxTextWidth = items
            .map { ceil(($0.title as NSString).size(withAttributes: attributes).width) }
            .max() ?? 0
        let hasAnyIcon = items.contains { $0.icon != nil }
        let iconSpace = hasAnyIcon ? iconSize + iconTextSpacing : 0
        let raw = maxTextWidth + iconSpace + rowHorizontalPadding * 2
        let maxWidth = UIScreen.main.bounds.width - maxWidthScreenInset
        return min(max(raw, minContentWidth), maxWidth)
    }

    private static func contentHeight(for items: [Item]) -> CGFloat {
        let dividers = CGFloat(max(items.count - 1, 0)) * dividerHeight
        return CGFloat(items.count) * rowHeight + dividers
    }

    private func makeRow(item: Item) -> UIControl {
        let colors = ChatUIKitTheme.colors
        let control = MenuItemControl { [weak self] in
            self?.dismiss(animated: false, completion: {
                item.action()
            })
        }
        let iconView = UIImageView(image: item.icon)
        iconView.tintColor = colors.textColorPrimary
        iconView.contentMode = .scaleAspectFit
        let titleLabel = UILabel()
        titleLabel.text = item.title
        titleLabel.font = .systemFont(ofSize: Self.titleFontSize)
        titleLabel.textColor = colors.textColorPrimary
        control.addSubview(iconView)
        control.addSubview(titleLabel)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.rowHorizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(Self.iconSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(Self.iconTextSpacing)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.rowHorizontalPadding)
            make.centerY.equalToSuperview()
        }

        control.snp.makeConstraints { make in
            make.height.equalTo(Self.rowHeight)
        }
        return control
    }

    private func makeDivider() -> UIView {
        let wrapper = UIView()
        let divider = UIView()
        divider.backgroundColor = ChatUIKitTheme.colors.strokeColorSecondary
        wrapper.addSubview(divider)
        divider.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview().offset(Self.dividerHorizontalMargin)
            make.trailing.equalToSuperview().offset(-Self.dividerHorizontalMargin)
            make.height.equalTo(Self.dividerHeight)
        }
        return wrapper
    }

    @objc private func handleBackdropTap(_ gesture: UITapGestureRecognizer) {
        dismiss(animated: false)
    }
}

extension BubbleMenuViewController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let touchedView = touch.view, touchedView.isDescendant(of: bubbleView) {
            return false
        }
        return true
    }
}

private final class MenuItemControl: UIControl {
    private static let highlightAlpha: CGFloat = 0.1

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted
                ? ChatUIKitTheme.colors.textColorPrimary.withAlphaComponent(Self.highlightAlpha)
                : .clear
        }
    }

    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        handler()
    }
}

final class BubbleMenuBubbleView: UIView {
    var arrowCenterX: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }

    let contentView = UIView()

    private static let cornerRadius: CGFloat = CGFloat(RadiusScheme.smallRadius)

    private static let arrowWidth: CGFloat = 12

    private static let arrowHeight: CGFloat = 6

    private static let shadowOpacity: Float = 0.2

    private static let shadowRadius: CGFloat = 8

    private static let shadowOffset = CGSize(width: 0, height: 2)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.backgroundColor = ChatUIKitTheme.colors.bgColorDialog
        contentView.layer.cornerRadius = Self.cornerRadius
        contentView.layer.masksToBounds = true
        addSubview(contentView)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = Self.shadowOpacity
        layer.shadowRadius = Self.shadowRadius
        layer.shadowOffset = Self.shadowOffset
        layer.masksToBounds = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.frame = CGRect(
            x: 0,
            y: Self.arrowHeight,
            width: bounds.width,
            height: bounds.height - Self.arrowHeight
        )
        layer.shadowPath = bubblePath().cgPath
    }

    override func draw(_ rect: CGRect) {
        ChatUIKitTheme.colors.bgColorDialog.setFill()
        bubblePath().fill()
    }

    private func bubblePath() -> UIBezierPath {
        let arrowHalfWidth = Self.arrowWidth / 2
        let bodyRect = CGRect(
            x: 0,
            y: Self.arrowHeight,
            width: bounds.width,
            height: bounds.height - Self.arrowHeight
        )
        let clampedCenterX = min(
            max(arrowCenterX, Self.cornerRadius),
            bodyRect.width - Self.cornerRadius
        )
        let path = UIBezierPath()
        path.move(to: CGPoint(x: clampedCenterX - arrowHalfWidth, y: bodyRect.minY))
        path.addLine(to: CGPoint(x: clampedCenterX, y: 0))
        path.addLine(to: CGPoint(x: clampedCenterX + arrowHalfWidth, y: bodyRect.minY))
        path.close()
        path.append(UIBezierPath(roundedRect: bodyRect, cornerRadius: Self.cornerRadius))
        return path
    }
}

private extension Comparable {

    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
