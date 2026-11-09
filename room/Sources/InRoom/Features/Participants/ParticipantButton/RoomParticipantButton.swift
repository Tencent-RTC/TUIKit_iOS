import UIKit
import SnapKit
import Combine
import AtomicXCore

final class RoomParticipantButton: UIControl {

    var isActive = false {
        didSet {
            guard oldValue != isActive else { return }
            applyTheme()
        }
    }

    private let roomID: String
    private let iconView = UIImageView()
    private let badgeLabel = UILabel()
    private var listView: RoomParticipantListView?
    private var cancellableSet = Set<AnyCancellable>()

    private var count: Int? {
        didSet {
            guard oldValue != count else { return }
            applyBadge()
        }
    }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            transform = isHighlighted ? CGAffineTransform(scaleX: 0.92, y: 0.92) : .identity
        }
    }

    init(roomID: String) {
        self.roomID = roomID
        super.init(frame: .zero)
        iconView.image = RoomKitResources.image(named: "roomkit_icon_members")
        iconView.isUserInteractionEnabled = false
        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)

        badgeLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        badgeLabel.textAlignment = .left
        badgeLabel.isHidden = true
        badgeLabel.isUserInteractionEnabled = false
        addSubview(badgeLabel)

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        observeParticipants()
        applyTheme()
        applyBadge()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { applyTheme() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
        iconView.frame = CGRect(
            x: (bounds.width - 20) / 2,
            y: (bounds.height - 20) / 2,
            width: 20,
            height: 20
        )
        badgeLabel.sizeToFit()
        badgeLabel.frame = CGRect(
            x: bounds.midX + 8,
            y: bounds.midY - 6 - 12,
            width: max(badgeLabel.bounds.width, 6),
            height: 12
        )
    }

    private func observeParticipants() {
        RoomParticipantStore.create(roomID: roomID).state
            .subscribe(StatePublisherSelector(projector: { $0.participantList.count }))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.count = $0 }
            .store(in: &cancellableSet)
    }

    @objc private func handleTap() {
        guard listView == nil else { return }
        let view = RoomParticipantListView(roomID: roomID)
        view.onDismiss = { [weak self] in self?.listView = nil }
        listView = view
        view.show(in: self)
    }

    private func applyTheme() {
        backgroundColor = isActive ? UIColor.roomKitBgHoverStrong : UIColor.roomKitBgHover
        badgeLabel.textColor = UIColor.roomKitFgPrimary
    }

    private func applyBadge() {
        guard let count, count > 0 else {
            badgeLabel.isHidden = true
            return
        }
        badgeLabel.isHidden = false
        badgeLabel.text = count > 99 ? "99+" : "\(count)"
        setNeedsLayout()
    }
}
