import UIKit
import SnapKit

final class RoomLeaveRoomButton: UIControl {

    enum Kind {
        case leaveSelf
        case endAll
    }

    var onLeave: ((Kind) -> Void)?

    var isOwner = false {
        didSet {
            guard oldValue != isOwner, isOpen else { return }
            close(animated: false)
        }
    }

    weak var popoverHost: UIView?

    private(set) var isOpen = false

    private let iconView = UIImageView()
    private let cancelLabel = UILabel()
    private var popover: RoomLeavePopoverView?

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            applyTheme()
            UIView.animate(withDuration: 0.08) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }

    init() {
        super.init(frame: .zero)

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = RoomKitResources.localizedString("roomkit.main.leave_self")

        iconView.image = RoomKitResources.image(named: "roomkit_icon_end_call")
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(15)
            $0.leading.greaterThanOrEqualToSuperview().offset(14)
            $0.trailing.lessThanOrEqualToSuperview().offset(-14)
        }

        cancelLabel.text = RoomKitResources.localizedString("roomkit.common.cancel")
        cancelLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        cancelLabel.textAlignment = .center
        cancelLabel.alpha = 0
        cancelLabel.isUserInteractionEnabled = false
        addSubview(cancelLabel)
        cancelLabel.snp.makeConstraints { $0.edges.equalToSuperview() }

        layer.cornerRadius = 14
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        applyTheme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 54, height: 28)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyTheme()
        } else {
            if isOpen { close(animated: false) }
        }
    }

    private func applyTheme() {
        if isOpen {
            backgroundColor = UIColor.roomKitBgPress
            cancelLabel.textColor = UIColor.roomKitFgPrimary
        } else {
            backgroundColor = isHighlighted ? UIColor.roomKitDangerPressed : UIColor.roomKitDanger
        }
    }
}

// MARK: - public methods

extension RoomLeaveRoomButton {

    func close(animated: Bool = true) {
        guard isOpen else { return }
        isOpen = false
        accessibilityValue = nil
        let popover = self.popover
        self.popover = nil
        popover?.close(animated: animated)
        setOpenAppearance(animated: animated)
    }
}

// MARK: - private methods

extension RoomLeaveRoomButton {

    @objc private func handleTap() {
        guard isOwner else {
            onLeave?(.leaveSelf)
            return
        }
        isOpen ? close() : open()
    }

    private func open() {
        guard let host = popoverHost, isDescendant(of: host) else { return }
        isOpen = true
        accessibilityValue = RoomKitResources.localizedString("roomkit.common.cancel")

        let popover = RoomLeavePopoverView(anchor: self)
        popover.onDismiss = { [weak self] in self?.close() }
        popover.onSelect = { [weak self] kind in
            self?.close()
            self?.onLeave?(kind)
        }
        self.popover = popover
        popover.show(in: host)
        setOpenAppearance(animated: true)
    }

    private func setOpenAppearance(animated: Bool) {
        let apply = {
            self.applyTheme()
            self.iconView.alpha = self.isOpen ? 0 : 1
            self.cancelLabel.alpha = self.isOpen ? 1 : 0
        }
        guard animated else {
            apply()
            return
        }
        let animator = RoomLeavePopoverView.makeAnimator()
        animator.addAnimations(apply)
        animator.startAnimation()
    }
}
