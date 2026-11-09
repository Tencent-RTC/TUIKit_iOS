import UIKit
import SnapKit
import Combine
import AtomicXCore

final class RoomRecordingButton: UIControl, RoomToolBarTitleDisplaying {

    var onRequestDismiss: (() -> Void)?

    weak var routerContext: RouterContext?

    var showsTitle = false {
        didSet {
            guard oldValue != showsTitle else { return }
            applyTitleVisibility()
        }
    }

    private let roomID: String
    private var isRecording = false
    private var cancellableSet = Set<AnyCancellable>()

    private let container = UIStackView()
    private let iconBox = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    var isAvailable: Bool {
        let role = RoomParticipantStore.create(roomID: roomID).state.value.localParticipant?.role
        return role == .owner || role == .admin
    }

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
        applyState(isRecording: false)
        applyTheme()
    }

    private func setupBindings() {
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        observeRecordingStatus()
    }
}

extension RoomRecordingButton {

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

    private func applyState(isRecording: Bool) {
        iconView.image = RoomKitResources.image(
            named: isRecording ? "roomkit_icon_recording" : "roomkit_icon_record"
        )
        iconView.tintColor = isRecording ? UIColor.roomKitDanger : UIColor.roomKitFgPrimary
        titleLabel.text = isRecording ? .recordingStop : .recordingStart
        accessibilityLabel = titleLabel.text
    }

    private func observeRecordingStatus() {
        RoomStore.shared.state
            .subscribe(StatePublisherSelector(projector: { $0.currentRoom?.recordingInfo.status == .recording }))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] recording in
                guard let self else { return }
                self.isRecording = recording
                self.applyState(isRecording: recording)
            }
            .store(in: &cancellableSet)
    }
}

extension RoomRecordingButton {

    @objc private func handleTap() {
        onRequestDismiss?()
        guard let presenter = routerContext as? UIViewController else { return }
        if isRecording {
            CloudRecordingConfirm.showStopDialog(in: presenter)
        } else {
            CloudRecordingConfirm.showStartDialog(in: presenter)
        }
    }
}

extension String {
    fileprivate static var recordingStart: String { RoomKitResources.localizedString("roomkit.cloud_recording.record_label") }
    fileprivate static var recordingStop: String { RoomKitResources.localizedString("roomkit.cloud_recording.stop_confirm") }
}

private extension RoomRecordingButton {
    static let buttonSize: CGFloat = 44
    static let iconSize: CGFloat = 20
    static let menuIconBoxSize: CGFloat = 46
    static let menuIconSize: CGFloat = 21
    static let titleSpacing: CGFloat = 7
}
