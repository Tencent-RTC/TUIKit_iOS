import UIKit
import SnapKit

final class RoomLeavePopoverView {

    var onSelect: ((RoomLeaveRoomButton.Kind) -> Void)?
    var onDismiss: (() -> Void)?

    private let popover: RoomPopover
    private let endItem = UIButton(type: .system)
    private let leaveItem = UIButton(type: .system)

    init(anchor: UIView) {
        popover = RoomPopover(anchor: anchor)
        popover.placement = .bottom
        popover.align = .end
        popover.showsArrow = false
        popover.gap = 8
        popover.minWidth = 176

        Self.configure(
            endItem, title: RoomKitResources.localizedString("roomkit.main.leave_end"),
            background: .roomKitDanger, pressed: .roomKitDangerPressed, titleColor: .roomKitFgOnDanger
        )
        Self.configure(
            leaveItem, title: RoomKitResources.localizedString("roomkit.main.leave_self"),
            background: .roomKitBgHover, pressed: .roomKitBgPress, titleColor: .roomKitFgPrimary
        )

        let stack = UIStackView(arrangedSubviews: [endItem, leaveItem])
        stack.axis = .vertical
        stack.spacing = 6
        popover.contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        popover.onClose = { [weak self] in self?.onDismiss?() }
        endItem.addAction(UIAction { [weak self] _ in self?.onSelect?(.endAll) }, for: .touchUpInside)
        leaveItem.addAction(UIAction { [weak self] _ in self?.onSelect?(.leaveSelf) }, for: .touchUpInside)
    }

    static func makeAnimator() -> UIViewPropertyAnimator {
        RoomPopover.makeAnimator()
    }

    private static func configure(
        _ button: UIButton, title: String, background: UIColor, pressed: UIColor, titleColor: UIColor
    ) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(titleColor, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        button.layer.cornerRadius = 12
        button.clipsToBounds = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.setBackgroundImage(.solid(background), for: .normal)
        button.setBackgroundImage(.solid(pressed), for: .highlighted)
    }
}

// MARK: - public methods

extension RoomLeavePopoverView {

    func show(in host: UIView) {
        popover.show(in: host)
    }

    func close(animated: Bool = true, completion: (() -> Void)? = nil) {
        popover.close(animated: animated, completion: completion)
    }
}
