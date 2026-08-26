import UIKit
import SnapKit

final class ConversationPopupMenuController: UIViewController {
    struct MenuItem {
        let title: String
        let isDangerous: Bool
        let action: () -> Void
    }

    private static let menuCornerRadius: CGFloat = CGFloat(RadiusScheme.smallRadius)

    private static let menuItemHorizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let menuItemVerticalPadding: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)

    private static let dividerHeight: CGFloat = 0.5

    private static let dividerHorizontalInset: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let hostMargin: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)

    private static let anchorHorizontalInset: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let aboveOverlap: CGFloat = 8

    private static let minBelowOverlap: CGFloat = 24

    private static let showDuration: TimeInterval = 0.18

    private static let dismissDuration: TimeInterval = 0.16

    private static let animationScale: CGFloat = 0.92

    private static let showTranslation: CGFloat = 8

    private static let dismissTranslation: CGFloat = 6

    private static let shadowOpacity: Float = 0.15

    private static let shadowRadius: CGFloat = 8

    private static let itemHighlightAlpha: CGFloat = 0.08

    private static let belowOverlapNumerator: CGFloat = 3

    private static let belowOverlapDenominator: CGFloat = 5

    private let items: [MenuItem]

    private let anchorFrameInHost: CGRect

    private let onDismiss: () -> Void

    private var showBelow = true

    private var isDismissing = false

    private let menuContainer = UIView()

    private let menuStack = UIStackView()

    // MARK: - Init

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func show(
        items: [MenuItem],
        anchorFrameInHost: CGRect,
        from hostViewController: UIViewController,
        onDismiss: @escaping () -> Void
    ) {
        guard !items.isEmpty else { return }
        let controller = ConversationPopupMenuController(
            items: items,
            anchorFrameInHost: anchorFrameInHost,
            onDismiss: onDismiss
        )
        hostViewController.present(controller, animated: false)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        layoutMenu()
        prepareShowAnimationState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateShow()
    }

    // MARK: - Actions

    private init(items: [MenuItem], anchorFrameInHost: CGRect, onDismiss: @escaping () -> Void) {
        self.items = items
        self.anchorFrameInHost = anchorFrameInHost
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    private func constructViewHierarchy() {
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleBackdropTap))
        tapRecognizer.delegate = self
        view.addGestureRecognizer(tapRecognizer)

        menuStack.axis = .vertical
        menuStack.spacing = 0
        for (index, item) in items.enumerated() {
            menuStack.addArrangedSubview(makeMenuItemView(item: item))
            if index < items.count - 1 {
                menuStack.addArrangedSubview(makeDivider())
            }
        }
        menuContainer.addSubview(menuStack)
        view.addSubview(menuContainer)
    }

    private func activateConstraints() {
        menuStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupViewStyle() {
        let colors = ChatUIKitTheme.colors
        view.backgroundColor = .clear
        menuContainer.backgroundColor = colors.bgColorOperate
        menuContainer.layer.cornerRadius = Self.menuCornerRadius
        menuContainer.layer.masksToBounds = false
        menuContainer.layer.shadowColor = UIColor.black.cgColor
        menuContainer.layer.shadowOpacity = Self.shadowOpacity
        menuContainer.layer.shadowRadius = Self.shadowRadius
        menuContainer.layer.shadowOffset = .zero
    }

    private func makeMenuItemView(item: MenuItem) -> UIView {
        let colors = ChatUIKitTheme.colors
        let control = UIControl()
        let label = UILabel()
        label.text = item.title
        label.font = FontScheme.caption1Regular
        label.textColor = item.isDangerous ? colors.textColorError : colors.textColorPrimary
        control.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.menuItemHorizontalPadding)
            make.trailing.equalToSuperview().offset(-Self.menuItemHorizontalPadding)
            make.top.equalToSuperview().offset(Self.menuItemVerticalPadding)
            make.bottom.equalToSuperview().offset(-Self.menuItemVerticalPadding)
        }
        control.addAction(UIAction { [weak self] _ in
            self?.dismissMenu(afterDismiss: item.action)
        }, for: .touchUpInside)
        control.addAction(UIAction { [weak control] _ in
            control?.backgroundColor = ChatUIKitTheme.colors.textColorPrimary.withAlphaComponent(Self.itemHighlightAlpha)
        }, for: .touchDown)
        let clearHighlight = UIAction { [weak control] _ in
            control?.backgroundColor = .clear
        }
        control.addAction(clearHighlight, for: .touchUpOutside)
        control.addAction(clearHighlight, for: .touchCancel)
        return control
    }

    private func makeDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = ChatUIKitTheme.colors.strokeColorSecondary
        divider.snp.makeConstraints { make in
            make.height.equalTo(Self.dividerHeight)
        }
        let insetContainer = UIView()
        insetContainer.isUserInteractionEnabled = false
        insetContainer.addSubview(divider)
        divider.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Self.dividerHorizontalInset)
            make.trailing.equalToSuperview().offset(-Self.dividerHorizontalInset)
            make.top.bottom.equalToSuperview()
        }
        return insetContainer
    }

    private func layoutMenu() {
        view.layoutIfNeeded()
        menuContainer.layoutIfNeeded()
        let popupSize = menuStack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let hostSize = view.bounds.size

        let isRtl = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let preferredX: CGFloat
        if isRtl {
            preferredX = anchorFrameInHost.minX + Self.anchorHorizontalInset
        } else {
            preferredX = anchorFrameInHost.maxX - popupSize.width - Self.anchorHorizontalInset
        }
        let maxX = max(hostSize.width - popupSize.width - Self.hostMargin, Self.hostMargin)
        let xOffset = min(max(preferredX, Self.hostMargin), maxX)

        let belowOverlap = max(anchorFrameInHost.height * Self.belowOverlapNumerator / Self.belowOverlapDenominator, Self.minBelowOverlap)
        let belowY = anchorFrameInHost.maxY - belowOverlap
        let aboveY = anchorFrameInHost.minY - popupSize.height + Self.aboveOverlap
        showBelow = belowY + popupSize.height <= hostSize.height - Self.hostMargin || aboveY < Self.hostMargin
        let yOffset: CGFloat
        if showBelow {
            yOffset = min(belowY, hostSize.height - popupSize.height - Self.hostMargin)
        } else {
            yOffset = max(aboveY, Self.hostMargin)
        }

        menuContainer.frame = CGRect(origin: CGPoint(x: xOffset, y: yOffset), size: popupSize)
    }

    private func prepareShowAnimationState() {
        let isRtl = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        menuContainer.layer.anchorPoint = CGPoint(
            x: isRtl ? 0 : 1,
            y: showBelow ? 0 : 1
        )

        menuContainer.frame.origin = CGPoint(
            x: menuContainer.frame.origin.x + (isRtl ? -menuContainer.frame.width / 2 : menuContainer.frame.width / 2),
            y: menuContainer.frame.origin.y + (showBelow ? -menuContainer.frame.height / 2 : menuContainer.frame.height / 2)
        )
        let translation: CGFloat = showBelow ? -Self.showTranslation : Self.showTranslation
        menuContainer.alpha = 0
        menuContainer.transform = CGAffineTransform(scaleX: Self.animationScale, y: Self.animationScale)
            .translatedBy(x: 0, y: translation)
    }

    private func animateShow() {
        UIView.animate(withDuration: Self.showDuration) {
            self.menuContainer.alpha = 1
            self.menuContainer.transform = .identity
        }
    }

    private func dismissMenu(afterDismiss: (() -> Void)? = nil) {
        guard !isDismissing else { return }
        isDismissing = true
        let translation: CGFloat = showBelow ? -Self.dismissTranslation : Self.dismissTranslation
        UIView.animate(withDuration: Self.dismissDuration, animations: {
            self.menuContainer.alpha = 0
            self.menuContainer.transform = CGAffineTransform(scaleX: Self.animationScale, y: Self.animationScale)
                .translatedBy(x: 0, y: translation)
        }, completion: { _ in
            self.dismiss(animated: false) {
                self.onDismiss()
                afterDismiss?()
            }
        })
    }

    @objc private func handleBackdropTap() {
        dismissMenu()
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ConversationPopupMenuController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let touchView = touch.view else { return true }
        return !touchView.isDescendant(of: menuContainer)
    }
}
