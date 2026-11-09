import UIKit
import SnapKit
import Combine
import AtomicXCore

final class RoomScreenShareButton: UIControl, RoomToolBarTitleDisplaying {

    var onRequestDismiss: (() -> Void)?

    weak var routerContext: RouterContext?

    var showsTitle = false {
        didSet {
            guard oldValue != showsTitle else { return }
            applyTitleVisibility()
        }
    }

    private let roomID: String
    private var isSharing = false
    private var isShareRestricted = false {
        didSet {
            guard oldValue != isShareRestricted else { return }
            alpha = isShareRestricted ? RoomScreenShareButton.shareRestrictedAlpha : 1
        }
    }
    private var cancellableSet = Set<AnyCancellable>()

    private let container = UIStackView()
    private let iconBox = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    override var intrinsicContentSize: CGSize {
        let box = showsTitle ? Self.menuIconBoxSize : Self.buttonSize
        return CGSize(
            width: box,
            height: showsTitle ? box + Self.titleSpacing + titleLabel.intrinsicContentSize.height : box
        )
    }

    init(roomID: String) {
        self.roomID = roomID
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            transform = isHighlighted ? CGAffineTransform(scaleX: 0.92, y: 0.92) : .identity
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { applyTheme() }
    }

    private func setupViews() {
        container.isUserInteractionEnabled = false
        iconBox.addSubview(iconView)
        container.addArrangedSubview(iconBox)
        container.addArrangedSubview(titleLabel)
        addSubview(container)
    }

    private func setupConstraints() {
        container.snp.makeConstraints { $0.edges.equalToSuperview() }
        iconBox.snp.makeConstraints { $0.size.equalTo(Self.buttonSize) }
        iconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(20)
        }
    }

    private func setupStyles() {
        iconBox.layer.cornerRadius = Self.buttonSize / 2
        container.axis = .vertical
        container.alignment = .center
        container.spacing = Self.titleSpacing
        iconView.contentMode = .scaleAspectFit
        titleLabel.font = .systemFont(ofSize: 11)
        titleLabel.textColor = UIColor.roomKitFgSecondary
        titleLabel.textAlignment = .center
        titleLabel.isHidden = !showsTitle
        applyState(isSharing: false)
        applyTheme()
    }

    private func setupBindings() {
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        observeSharingStatus()
        observeShareRestriction()
    }
}

extension RoomScreenShareButton {

    private var presenter: UIViewController? {
        routerContext as? UIViewController
    }

    private var screenSharerName: String? {
        RoomParticipantStore.create(roomID: roomID).state.value.participantWithScreen?.displayName
    }

    private func applyTheme() {
        iconBox.backgroundColor = UIColor.roomKitBgHover
    }

    private func applyTitleVisibility() {
        titleLabel.isHidden = !showsTitle
        let box = showsTitle ? Self.menuIconBoxSize : Self.buttonSize
        iconBox.snp.remakeConstraints { $0.size.equalTo(box) }
        iconBox.layer.cornerRadius = box / 2
        iconView.snp.remakeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(showsTitle ? Self.menuIconSize : Self.iconSize)
        }
        invalidateIntrinsicContentSize()
    }

    private func applyState(isSharing: Bool) {
        iconView.image = RoomKitResources.image(
            named: isSharing ? "roomkit_icon_screen_share_stop" : "roomkit_icon_screen_share_start"
        )
        iconView.tintColor = isSharing ? UIColor.roomKitDanger : UIColor.roomKitFgPrimary
        titleLabel.text = isSharing ? .screenShareStop : .screenShareStart
        accessibilityLabel = titleLabel.text
    }

    private func observeSharingStatus() {
        RoomParticipantStore.create(roomID: roomID).state
            .subscribe(StatePublisherSelector(projector: { $0.localParticipant?.screenShareStatus == .on }))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] sharing in
                guard let self else { return }
                self.isSharing = sharing
                self.applyState(isSharing: sharing)
            }
            .store(in: &cancellableSet)
    }

    private func observeShareRestriction() {
        let shareDisabledPublisher = RoomStore.shared.state
            .subscribe(StatePublisherSelector(projector: { $0.currentRoom?.isAllScreenShareDisabled == true }))
        let privilegedPublisher = RoomParticipantStore.create(roomID: roomID).state
            .subscribe(StatePublisherSelector(projector: { state in
                let role = state.localParticipant?.role
                return role == .owner || role == .admin
            }))
        Publishers.CombineLatest(shareDisabledPublisher, privilegedPublisher)
            .removeDuplicates { $0.0 == $1.0 && $0.1 == $1.1 }
            .receive(on: RunLoop.main)
            .sink { [weak self] shareDisabled, privileged in
                self?.isShareRestricted = shareDisabled && !privileged
            }
            .store(in: &cancellableSet)
    }

    private func requestStartSharing() {
        if isShareRestricted {
            RoomToast.show(.screenShareOwnerAdminOnly)
            return
        }
        guard screenSharerName == nil else {
            RoomToast.show(.screenShareRemoteSharing)
            return
        }
        guard let presenter else { return }
        var dialog: RoomDialog?
        dialog = RoomDialog.Builder(in: presenter)
            .title(.screenShareAlertTitle)
            .message(.screenShareAlertMessage)
            .secondaryAction(.commonCancel) {}
            .primaryAction(.screenShareAlertContinue) { [weak self] in
                dialog?.dismiss(animated: true)
                self?.onRequestDismiss?()
                do {
                    try RoomScreenShareLauncher.shared.start()
                } catch {
                    NSLog("[ScreenShare] start failed: \(error)")
                }
            }
            .show()
    }

    private func confirmStopSharing() {
        onRequestDismiss?()
        guard let presenter else { return }
        var dialog: RoomDialog?
        dialog = RoomDialog.Builder(in: presenter)
            .title(.screenShareStopTitle)
            .message(.screenShareStopMessage)
            .secondaryAction(.commonCancel) {}
            .primaryAction(.screenShareStopConfirm, variant: .danger) {
                dialog?.dismiss(animated: true)
                RoomScreenShareLauncher.shared.stop()
            }
            .show()
    }
}

extension RoomScreenShareButton {

    @objc private func handleTap() {
        if isSharing {
            confirmStopSharing()
        } else {
            requestStartSharing()
        }
    }
}

extension String {
    fileprivate static var screenShareOwnerAdminOnly: String { RoomKitResources.localizedString("roomkit.main.screen_share_owner_admin_only") }
    fileprivate static var screenShareStart: String { RoomKitResources.localizedString("roomkit.main.screen_share") }
    fileprivate static var screenShareStop: String { RoomKitResources.localizedString("roomkit.main.screen_share_stop") }
    fileprivate static var screenShareRemoteSharing: String { RoomKitResources.localizedString("roomkit.main.screen_share_remote_sharing") }
    fileprivate static var screenShareAlertTitle: String { RoomKitResources.localizedString("roomkit.main.screen_share_alert_title") }
    fileprivate static var screenShareAlertMessage: String { RoomKitResources.localizedString("roomkit.main.screen_share_alert_message") }
    fileprivate static var screenShareAlertContinue: String { RoomKitResources.localizedString("roomkit.main.screen_share_alert_continue") }
    fileprivate static var screenShareStopTitle: String { RoomKitResources.localizedString("roomkit.main.screen_share_stop_title") }
    fileprivate static var screenShareStopMessage: String { RoomKitResources.localizedString("roomkit.main.screen_share_stop_message") }
    fileprivate static var screenShareStopConfirm: String { RoomKitResources.localizedString("roomkit.main.screen_share_stop_confirm") }
    fileprivate static var commonCancel: String { RoomKitResources.localizedString("roomkit.common.cancel") }
}

private extension RoomScreenShareButton {
    static let buttonSize: CGFloat = 44
    static let iconSize: CGFloat = 20
    static let menuIconBoxSize: CGFloat = 46
    static let menuIconSize: CGFloat = 21
    static let titleSpacing: CGFloat = 7
    static let shareRestrictedAlpha: CGFloat = 0.45
}
