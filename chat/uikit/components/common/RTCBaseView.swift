import UIKit

open class RTCBaseView: UIView {
    private var isViewReady = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable, message: "Loading this view from a nib is unsupported")

    public required init?(coder aDecoder: NSCoder) {
        fatalError("Loading this view from a nib is unsupported")
    }

    open override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupViewStyle()
        isViewReady = true
    }

    open func constructViewHierarchy() {
        assertionFailure("RTCBaseView constructViewHierarchy function can not be called")
    }

    open func activateConstraints() {
        assertionFailure("RTCBaseView activateConstraints function can not be called")
    }

    open func bindInteraction() {}

    open func setupViewStyle() {}
}
