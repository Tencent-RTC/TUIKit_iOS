import UIKit
import SnapKit
import Combine
import AtomicXCore

final class RoomTopBar: UIView {
    var onRoomInfoTap: (() -> Void)?
    var onNetworkTap: (() -> Void)?
    var onLeave: ((RoomLeaveRoomButton.Kind) -> Void)?

    weak var popoverHost: UIView? {
        didSet { leaveButton.popoverHost = popoverHost }
    }

    var isDetailOpen: Bool {
        get { roomInfoView.isDetailOpen }
        set { roomInfoView.isDetailOpen = newValue }
    }

    var isOwner: Bool {
        get { leaveButton.isOwner }
        set { leaveButton.isOwner = newValue }
    }

    private let roomInfoView = RoomInfoView()
    private let networkView = RoomNetworkSignalView()
    private let recordingStatus = CloudRecordingStatus()
    private let leaveButton = RoomLeaveRoomButton()
    private let leadingStack = UIStackView()
    private var cancellableSet = Set<AnyCancellable>()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupViews()
        setupConstraints()
        setupBindings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        leadingStack.axis = .horizontal
        leadingStack.alignment = .center
        leadingStack.addArrangedSubview(roomInfoView)
        leadingStack.addArrangedSubview(networkView)
        leadingStack.addArrangedSubview(recordingStatus)
        leadingStack.setCustomSpacing(Self.networkGap, after: roomInfoView)
        leadingStack.setCustomSpacing(Self.recordingGap, after: networkView)
        addSubview(leadingStack)
        addSubview(leaveButton)
    }

    private func setupConstraints() {
        leadingStack.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16 - 6)
            $0.centerY.equalToSuperview()
            $0.trailing.lessThanOrEqualTo(leaveButton.snp.leading).offset(-Self.tailGap)
        }
        networkView.snp.makeConstraints {
            $0.size.equalTo(24)
        }
        leaveButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-16 + 4)
            $0.centerY.equalToSuperview()
            $0.height.equalTo(28)
            $0.width.greaterThanOrEqualTo(54)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard leaveButton.frame.width > 0 else { return }
        var used = Self.networkSize + Self.networkGap
        if !recordingStatus.isHidden {
            used += recordingStatus.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width
                + Self.recordingGap
        }
        let available = leaveButton.frame.minX - Self.tailGap - leadingStack.frame.minX - used
        roomInfoView.availableWidth = max(0, available)
    }

    private static let networkSize: CGFloat = 24
    private static let networkGap: CGFloat = 4
    private static let recordingGap: CGFloat = 2
    private static let tailGap: CGFloat = 4

    private func setupBindings() {
        roomInfoView.addTarget(self, action: #selector(handleRoomInfoTap), for: .touchUpInside)
        networkView.addTarget(self, action: #selector(handleNetworkTap), for: .touchUpInside)
        leaveButton.onLeave = { [weak self] kind in self?.onLeave?(kind) }

        let updateNetwork: (DeviceState) -> Void = { [weak self] state in
            self?.networkView.update(quality: state.networkInfo.quality)
        }
        updateNetwork(DeviceStore.shared.state.value)
        DeviceStore.shared.state.subscribe()
            .receive(on: RunLoop.main)
            .sink(receiveValue: updateNetwork)
            .store(in: &cancellableSet)

        RoomStore.shared.state
            .subscribe(StatePublisherSelector(projector: { $0.currentRoom?.recordingInfo.status == .recording }))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.setNeedsLayout()
            }
            .store(in: &cancellableSet)
    }

    @objc private func handleRoomInfoTap() {
        onRoomInfoTap?()
    }

    @objc private func handleNetworkTap() {
        onNetworkTap?()
    }
}

// MARK: - public methods


