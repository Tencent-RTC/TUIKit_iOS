import UIKit
import SnapKit
import Combine
import AtomicXCore

final class RoomLeaveRoomButton: UIControl {

    enum Kind {
        case leaveSelf
        case endAll
    }

    weak var popoverHost: UIView?
    weak var routerContext: RouterContext?

    private let roomID: String
    private var cancellableSet = Set<AnyCancellable>()

    private var isOwner = false {
        didSet {
            guard oldValue != isOwner, isOpen else { return }
            close(animated: false)
        }
    }

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

    init(roomID: String) {
        self.roomID = roomID
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
            observeRole()
        } else {
            if isOpen { close(animated: false) }
            cancellableSet.removeAll()
        }
    }

    private func observeRole() {
        guard cancellableSet.isEmpty else { return }
        RoomParticipantStore.create(roomID: roomID).state
            .subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.localParticipant))
            .receive(on: RunLoop.main)
            .sink { [weak self] local in
                self?.isOwner = local?.role == .owner
            }
            .store(in: &cancellableSet)
    }

    private func leave(_ kind: Kind) {
        let completion: CompletionClosure = { [weak self] _ in
            DispatchQueue.main.async {
                RoomToast.show(kind == .endAll ? .mainEnded : .mainLeft)
                self?.routerContext?.popToRoot(animated: true)
            }
        }
        switch kind {
        case .endAll: RoomStore.shared.endRoom(completion: completion)
        case .leaveSelf: RoomStore.shared.leaveRoom(completion: completion)
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

extension RoomLeaveRoomButton {

    @objc private func handleTap() {
        guard isOwner else {
            leave(.leaveSelf)
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
            self?.leave(kind)
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

private extension String {
    static var mainLeft: String { RoomKitResources.localizedString("roomkit.main.left") }
    static var mainEnded: String { RoomKitResources.localizedString("roomkit.main.ended") }
}
