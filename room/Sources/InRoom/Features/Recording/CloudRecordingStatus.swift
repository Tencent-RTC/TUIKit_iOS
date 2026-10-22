import AtomicXCore
import Combine
import SnapKit
import UIKit

final class CloudRecordingStatus: UIView {

    private let dot = UIView()
    private let label = UILabel()
    private var cancellableSet = Set<AnyCancellable>()

    override init(frame: CGRect) {
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

    private func setupViews() {
        isHidden = true
        addSubview(dot)
        addSubview(label)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    private func setupConstraints() {
        snp.makeConstraints { $0.height.equalTo(Self.CHIP_HEIGHT) }
        dot.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Self.CHIP_PADDING)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(Self.DOT_SIZE)
        }
        label.snp.makeConstraints {
            $0.leading.equalTo(dot.snp.trailing).offset(Self.CHIP_GAP)
            $0.trailing.equalToSuperview().offset(-Self.CHIP_PADDING)
            $0.centerY.equalToSuperview()
        }
    }

    private func setupStyles() {
        layer.cornerRadius = Self.CHIP_HEIGHT / 2
        backgroundColor = UIColor.roomKitDangerSoft
        dot.layer.cornerRadius = Self.DOT_SIZE / 2
        dot.backgroundColor = UIColor.roomKitDanger
        label.text = .cloudRecordingRecordingLabel
        label.font = .systemFont(ofSize: Self.LABEL_FONT_SIZE, weight: .medium)
        label.textColor = UIColor.roomKitDanger
    }

    private func setupBindings() {
        RoomStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \RoomState.currentRoom))
            .receive(on: RunLoop.main)
            .sink { [weak self] room in self?.render(room) }
            .store(in: &cancellableSet)
    }

    private func render(_ room: RoomInfo?) {
        let recording = room?.recordingInfo.status == .recording
        isHidden = !recording
        if recording { startPulse() } else { stopPulse() }
    }

    @objc private func handleTap() {
        let roomID = RoomStore.shared.state.value.currentRoom?.roomID ?? ""
        let role = RoomParticipantStore.create(roomID: roomID).state.value.localParticipant?.role
        guard role == .owner || role == .admin, let presenter = Self.viewController(from: self) else { return }
        CloudRecordingConfirm.stop(in: presenter)
    }

    private func startPulse() {
        guard dot.layer.animation(forKey: Self.PULSE_KEY) == nil else { return }
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 0.35
        animation.duration = Self.PULSE_DURATION
        animation.autoreverses = true
        animation.repeatCount = .infinity
        dot.layer.add(animation, forKey: Self.PULSE_KEY)
    }

    private func stopPulse() {
        dot.layer.removeAnimation(forKey: Self.PULSE_KEY)
    }

    private static func viewController(from view: UIView) -> UIViewController? {
        var responder: UIResponder? = view
        while let next = responder?.next {
            if let viewController = next as? UIViewController { return viewController }
            responder = next
        }
        return nil
    }

    private static let CHIP_HEIGHT: CGFloat = 22
    private static let CHIP_PADDING: CGFloat = 8
    private static let CHIP_GAP: CGFloat = 6
    private static let DOT_SIZE: CGFloat = 6
    private static let LABEL_FONT_SIZE: CGFloat = 11
    private static let PULSE_DURATION: CFTimeInterval = 1.2
    private static let PULSE_KEY = "cloudRecordingPulse"
}

private extension String {
    static let cloudRecordingRecordingLabel = RoomKitResources.localizedString("roomkit.cloud_recording.recording_label")
}
