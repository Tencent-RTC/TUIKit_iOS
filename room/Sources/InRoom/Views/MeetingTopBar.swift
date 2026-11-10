import UIKit
import SnapKit

final class MeetingTopBar: UIView {

    weak var popoverHost: UIView? {
        didSet { leaveButton.popoverHost = popoverHost }
    }

    weak var routerContext: RouterContext? {
        didSet { leaveButton.routerContext = routerContext }
    }

    private let roomInfoView: RoomInfoView
    private let networkView = RoomNetworkSignalView()
    private let recordingStatus = CloudRecordingStatus()
    private let recordingSlot = UIView()
    private let leaveButton: RoomLeaveRoomButton
    private let leadingStack = UIStackView()

    init(roomID: String) {
        self.roomInfoView = RoomInfoView(roomID: roomID)
        self.leaveButton = RoomLeaveRoomButton(roomID: roomID)
        super.init(frame: .zero)
        backgroundColor = .clear
        setupViews()
        setupConstraints()
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
        leadingStack.addArrangedSubview(recordingSlot)
        leadingStack.setCustomSpacing(4, after: roomInfoView)
        leadingStack.setCustomSpacing(2, after: networkView)
        leadingStack.setContentHuggingPriority(.required, for: .horizontal)
        addSubview(leadingStack)
        addSubview(leaveButton)

        recordingSlot.addSubview(recordingStatus)
    }

    private func setupConstraints() {
        leadingStack.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16 - 6)
            $0.centerY.equalToSuperview()
            $0.trailing.lessThanOrEqualTo(leaveButton.snp.leading).offset(-15)
        }
        roomInfoView.snp.makeConstraints {
            $0.width.lessThanOrEqualTo(Self.roomInfoMaxWidth)
        }
        networkView.snp.makeConstraints {
            $0.size.equalTo(24)
        }
        recordingSlot.snp.makeConstraints {
            $0.width.equalTo(recordingStatus.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width)
            $0.height.equalTo(22)
        }
        recordingStatus.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        leaveButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-16 + 4)
            $0.centerY.equalToSuperview()
            $0.height.equalTo(28)
            $0.width.greaterThanOrEqualTo(54)
        }
    }
}

private extension MeetingTopBar {
    static let roomInfoMaxWidth: CGFloat = 220
}
