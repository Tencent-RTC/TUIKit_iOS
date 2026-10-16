import UIKit
import SnapKit

/// Shared presentation shell for every bottom sheet.
///
/// Subclasses only own their content: add subviews to `contentView`, override
/// `sheetHeight`, and call `present()` / `dismiss()`. The dimming layer, sheet
/// background, height constraint and slide animations belong to this class and
/// must not be reimplemented by subclasses.
class BottomSheetView: UIView {
    /// Subclasses add their content here, never to `self`.
    let contentView = BottomSheetBackgroundView()

    /// Optional standard title. A nil value keeps the title hidden without
    /// reserving any additional content space.
    var sheetTitle: String? {
        didSet {
            titleLabel.text = sheetTitle
            titleLabel.isHidden = sheetTitle?.isEmpty != false
        }
    }

    private static let presentedPanels = NSHashTable<BottomSheetView>.weakObjects()

    private let dimmingControl = UIControl()
    private let titleLabel = LiveText(.sheetTitle, alignment: .center)
    private var sheetHeightConstraint: Constraint?
    private var appliedSheetHeight: CGFloat = 0

    // MARK: - Subclass overrides

    /// Height the sheet should occupy for its current state. Read after attachment,
    /// on `present()` and `updateSheetHeight(animated:)`, never in the base initializer.
    var sheetHeight: CGFloat { 0 }

    var isDismissibleByTappingOutside: Bool { true }

    /// Called before the present animation starts, after the height is applied.
    /// Override to update constraints that must animate together with the sheet.
    func sheetWillPresent() {}
    func sheetWillDismiss() {}
    /// Called after the dismiss animation completes. Override to reset content.
    func sheetDidDismiss() {}

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureBottomSheet()
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard superview != nil else { return }
        // Hidden views still participate in Auto Layout. Subclass initialization
        // is complete now, so replace the placeholder before the first layout.
        updateSheetHeight(animated: false)
    }

    private func configureBottomSheet() {
        dimmingControl.backgroundColor = LiveTheme.Color.sheetScrim
        dimmingControl.addTarget(self, action: #selector(handleDimmingTap), for: .touchUpInside)
        addSubview(dimmingControl)
        addSubview(contentView)

        titleLabel.isHidden = true
        contentView.addSubview(titleLabel)

        dimmingControl.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        // `sheetHeight` is intentionally not read here: subclass stored
        // properties are not initialized yet at this point.
        contentView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            sheetHeightConstraint = make.height.equalTo(0).constraint
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(SheetTitleStyle.horizontalInset)
            make.top.equalToSuperview().offset(SheetTitleStyle.topInset)
            make.height.equalTo(SheetTitleStyle.height)
        }
    }

    // MARK: - Presentation

    private enum Animation {
        static let presentDuration: TimeInterval = 0.25
        static let dismissDuration: TimeInterval = 0.2
        static let heightDuration: TimeInterval = 0.22
        static let present: UIView.AnimationOptions = [
            .curveEaseOut, .beginFromCurrentState, .allowUserInteraction,
        ]
        static let dismiss: UIView.AnimationOptions = [
            .curveEaseIn, .beginFromCurrentState, .allowUserInteraction,
        ]
    }

    static func dismissAll() {
        presentedPanels.allObjects.forEach { panel in
            if panel.isHidden || panel.window == nil {
                presentedPanels.remove(panel)
            } else {
                panel.dismiss()
            }
        }
    }

    func present() {
        BottomSheetView.presentedPanels.add(self)
        let height = sheetHeight
        appliedSheetHeight = height
        sheetHeightConstraint?.update(offset: height)
        sheetWillPresent()
        // Resolve the sheet's outer size before laying out its constrained content.
        superview?.layoutIfNeeded()
        isHidden = false
        layoutIfNeeded()
        dimmingControl.alpha = 0
        contentView.transform = CGAffineTransform(translationX: 0, y: height)
        UIView.animate(
            withDuration: Animation.presentDuration,
            delay: 0,
            options: Animation.present
        ) {
            self.dimmingControl.alpha = 1
            self.contentView.transform = .identity
        }
    }

    @objc func dismiss() {
        guard !isHidden else { return }
        BottomSheetView.presentedPanels.remove(self)
        sheetWillDismiss()
        UIView.animate(
            withDuration: Animation.dismissDuration,
            delay: 0,
            options: Animation.dismiss
        ) {
            self.dimmingControl.alpha = 0
            self.contentView.transform = CGAffineTransform(
                translationX: 0,
                y: self.contentView.bounds.height
            )
        } completion: { [weak self] _ in
            guard let self else { return }
            self.contentView.transform = .identity
            self.isHidden = true
            self.sheetDidDismiss()
        }
    }

    /// Applies the current `sheetHeight`. Use when the sheet switches pages
    /// while visible.
    func updateSheetHeight(animated: Bool) {
        let height = sheetHeight
        guard height != appliedSheetHeight else { return }
        appliedSheetHeight = height
        sheetHeightConstraint?.update(offset: height)
        setNeedsLayout()
        // Subclasses select their initial page before being attached or sized.
        guard window != nil, !isHidden, bounds.width > 0 else { return }
        guard animated else {
            layoutIfNeeded()
            return
        }
        UIView.animate(
            withDuration: Animation.heightDuration,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState]
        ) {
            self.layoutIfNeeded()
        }
    }

    @objc private func handleDimmingTap() {
        guard isDismissibleByTappingOutside else { return }
        dismiss()
    }
}

private enum SheetTitleStyle {
    static let horizontalInset: CGFloat = 16
    static let topInset: CGFloat = 30
    static let height: CGFloat = 18
}
