//
//  RoomSingleStreamView.swift
//  TUIRoomKit
//
//  Refactored from SingleStreamView.swift to use AtomicXCore
//  RoomParticipantStore / RoomParticipantView.
//

import UIKit
import SnapKit
import AtomicXCore
import Kingfisher
import Combine

// MARK: - Delegate

protocol RoomSingleStreamViewDelegate: AnyObject {
    func singleStreamViewDidTap(_ view: RoomSingleStreamView, participant: RoomParticipant?)
}

// MARK: - RoomSingleStreamView

class RoomSingleStreamView: UIView {

    // MARK: - Properties

    weak var delegate: RoomSingleStreamViewDelegate?

    private(set) var participant: RoomParticipant?

    private var isDraggable: Bool = false

    private var isBorderHighlighted = false

    private var lastVolumeUpdateTime: TimeInterval = 0

    private(set) var originalX: CGFloat = 0

    var onVideoStatusChanged: (() -> Void)?

    private var lastIsVideoOn: Bool?

    var cancellableSet = Set<AnyCancellable>()

    private lazy var participantStore: RoomParticipantStore = {
        RoomParticipantStore.create(roomID: roomID)
    }()

    private let roomID: String

    private var localUserID: String {
        LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
    }

    // MARK: - Init

    init(roomID: String, isDraggable: Bool = false) {
        self.roomID = roomID
        self.isDraggable = isDraggable
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Components

    let participantView: RoomParticipantView = {
        let view = RoomParticipantView()
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()

    private lazy var speakingBorderView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.clear.cgColor
        return view
    }()

    private lazy var backgroundMaskView: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g2
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()

    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.layer.masksToBounds = true
        return imageView
    }()

    private(set) lazy var participantInfoContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.g2.withAlphaComponent(0.8)
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        return view
    }()

    private(set) lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 12, weight: .regular)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private(set) lazy var roleIconImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.layer.cornerRadius = 12
        imageView.layer.masksToBounds = true
        return imageView
    }()

    private(set) lazy var micStatusImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()

    // MARK: - Lifecycle

    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        backgroundColor = .clear
        if let participant = participant {
            updateParticipant(participant)
        }
    }

    // MARK: - View Hierarchy

    private func constructViewHierarchy() {
        addSubview(participantView)
        addSubview(backgroundMaskView)
        addSubview(avatarImageView)
        addSubview(participantInfoContainerView)
        participantInfoContainerView.addSubview(roleIconImageView)
        participantInfoContainerView.addSubview(micStatusImageView)
        participantInfoContainerView.addSubview(nameLabel)
        addSubview(speakingBorderView)
    }

    private func activateConstraints() {
        participantView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(2)
        }
        backgroundMaskView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(2)
        }
        speakingBorderView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(2)
        }
        participantInfoContainerView.snp.makeConstraints { make in
            make.height.equalTo(24)
            make.bottom.equalToSuperview().offset(-5)
            make.leading.equalToSuperview().offset(5)
            make.width.lessThanOrEqualTo(self).multipliedBy(0.9)
        }
        roleIconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(24)
            make.width.equalTo(24)
        }
        micStatusImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(roleIconImageView.snp.right).offset(6)
            make.width.equalTo(14)
            make.height.equalTo(14)
        }
        nameLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(micStatusImageView.snp.right).offset(2)
            make.right.equalToSuperview().offset(-8)
        }
    }

    private func bindInteraction() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(singleViewDidTapped))
        addGestureRecognizer(tapGesture)
        if isDraggable {
            addGesture()
        }
    }

    // MARK: - Public

    func updateParticipant(_ participant: RoomParticipant?) {
        cancellableSet.removeAll()
        if let old = self.participant, old.userID != participant?.userID {
            participantView.setActive(isActive: false)
            resetBorderColor()
            lastIsVideoOn = nil
        }
        self.participant = participant
        guard let participant = participant else {
            avatarImageView.isHidden = true
            backgroundMaskView.isHidden = true
            resetBorderColor()
            lastIsVideoOn = nil
            return
        }
        updateUI(with: participant)
        bindParticipantState(with: participant)
        ensureRenderActive()
    }

    func releaseRender() {
        participantView.setActive(isActive: false)
    }

    func ensureRenderActive() {
        guard isViewReady, !isHidden, alpha > 0, let current = participant else { return }
        let latest = latestParticipant(for: current.userID) ?? current
        handleInfoUpdate(participant: latest)
    }

    private func latestParticipant(for userID: String) -> RoomParticipant? {
        return participantStore.state.value.participantList.first { $0.userID == userID }
    }

    func reset() {
        cancellableSet.removeAll()
        participantView.setActive(isActive: false)
        resetBorderColor()
        participant = nil
        avatarImageView.isHidden = true
        backgroundMaskView.isHidden = true
    }

    func updateVolume(hasAudio: Bool, volume: Int) {
        lastVolumeUpdateTime = Date().timeIntervalSince1970
        if volume > 0 && hasAudio {
            if !isBorderHighlighted {
                speakingBorderView.layer.borderColor = RoomColors.b2d.cgColor
                isBorderHighlighted = true
            }
            scheduleBorderReset()
        } else {
            resetBorderColor()
        }
    }

    func updateSize(size: CGSize) {
        var frame = self.frame
        frame.size = size
        self.frame = frame
        center = adsorption(centerPoint: center)
    }

    func setupFrame(_ frame: CGRect) {
        self.frame = frame
        self.originalX = frame.origin.x
    }

    // MARK: - State Binding

    private func bindParticipantState(with participant: RoomParticipant) {
        let publisher = createParticipantPublisher(for: participant.userID, isScreen: false)
        publisher
            .removeDuplicates { oldItem, newItem in
                oldItem.microphoneStatus == newItem.microphoneStatus
            }
            .sink { [weak self] participant in
                guard let self = self else { return }
                self.updateMicStatus(with: participant)
            }
            .store(in: &cancellableSet)

        publisher
            .removeDuplicates { oldItem, newItem in
                oldItem.name == newItem.name &&
                oldItem.role == newItem.role &&
                oldItem.cameraStatus == newItem.cameraStatus &&
                oldItem.screenShareStatus == newItem.screenShareStatus &&
                oldItem.avatarURL == newItem.avatarURL
            }
            .sink { [weak self] participant in
                guard let self = self else { return }
                self.handleInfoUpdate(participant: participant)
            }
            .store(in: &cancellableSet)
    }

    private func createParticipantPublisher(for userID: String, isScreen: Bool) -> AnyPublisher<RoomParticipant, Never> {
        if isScreen {
            return participantStore.state
                .subscribe(StatePublisherSelector(keyPath: \.participantWithScreen))
                .compactMap { $0 }
                .filter { $0.userID == userID }
                .receive(on: DispatchQueue.main)
                .share()
                .eraseToAnyPublisher()
        } else {
            return participantStore.state
                .subscribe(StatePublisherSelector(keyPath: \.participantList))
                .compactMap { $0.first { $0.userID == userID } }
                .receive(on: DispatchQueue.main)
                .share()
                .eraseToAnyPublisher()
        }
    }

    // MARK: - Render

    private func handleInfoUpdate(participant: RoomParticipant) {
        guard !self.isHidden, self.alpha > 0 else { return }
        self.participant = participant
        updateUI(with: participant)
        if participant.cameraStatus == .on {
            participantView.setFillMode(fillMode: .fill)
            participantView.updateStreamType(streamType: .camera)
            participantView.updateParticipant(participant: participant)
            participantView.setActive(isActive: true)
        } else {
            participantView.setActive(isActive: false)
        }
        notifyVideoStatusIfNeeded(participant)
    }

    private func notifyVideoStatusIfNeeded(_ participant: RoomParticipant) {
        let isVideoOn = participant.hasCameraVideoForSingleStream
        guard lastIsVideoOn != isVideoOn else { return }
        lastIsVideoOn = isVideoOn
        onVideoStatusChanged?()
    }

    // MARK: - UI Update

    private func updateUI(with participant: RoomParticipant) {
        self.participant = participant
        avatarImageView.kf.setImage(
            with: URL(string: participant.avatarURL),
            placeholder: ResourceLoader.loadImage("avatar_placeholder")
        )
        let isVideoOn = participant.hasCameraVideoForSingleStream
        avatarImageView.isHidden = isVideoOn
        backgroundMaskView.isHidden = isVideoOn
        updateNameLabel(with: participant)
        updateRoleIcon(with: participant)
        updateMicStatus(with: participant)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            let width = min(self.bounds.width / 2, 72)
            self.avatarImageView.layer.cornerRadius = width * 0.5
            self.avatarImageView.snp.remakeConstraints { make in
                make.height.width.equalTo(width)
                make.center.equalToSuperview()
            }
        }
    }

    private func updateNameLabel(with participant: RoomParticipant) {
        nameLabel.text = participant.name
    }

    private func updateRoleIcon(with participant: RoomParticipant) {
        let roleImageName: String?
        switch participant.role {
        case .admin:
            roleImageName = "room_administrator"
        case .owner:
            roleImageName = "room_homeowner"
        default:
            roleImageName = nil
        }
        if let imageName = roleImageName {
            roleIconImageView.isHidden = false
            roleIconImageView.image = ResourceLoader.loadImage(imageName)
            micStatusImageView.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.left.equalTo(roleIconImageView.snp.right).offset(6)
                make.width.equalTo(14)
                make.height.equalTo(14)
            }
        } else {
            roleIconImageView.isHidden = true
            micStatusImageView.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.left.equalToSuperview().offset(6)
                make.width.equalTo(14)
                make.height.equalTo(14)
            }
        }
    }

    private func updateMicStatus(with participant: RoomParticipant) {
        let imageName = participant.microphoneStatus == .off ? "room_mic_off_red" : "room_mic_on_big"
        micStatusImageView.image = ResourceLoader.loadImage(imageName)
    }

    // MARK: - Border

    private func scheduleBorderReset() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            let now = Date().timeIntervalSince1970
            if now - self.lastVolumeUpdateTime >= 2 {
                self.resetBorderColor()
            }
        }
    }

    private func resetBorderColor() {
        speakingBorderView.layer.borderColor = UIColor.clear.cgColor
        isBorderHighlighted = false
    }

    // MARK: - Actions

    @objc private func singleViewDidTapped() {
        delegate?.singleStreamViewDidTap(self, participant: participant)
    }

    deinit {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        debugPrint("deinit \(self)")
    }
}

// MARK: - Video Status Helper

extension RoomParticipant {
    var hasCameraVideoForSingleStream: Bool {
        return cameraStatus == .on
    }
}

// MARK: - Drag Gesture (floating window mode)

extension RoomSingleStreamView {
    private func addGesture() {
        let dragGesture = UIPanGestureRecognizer(target: self, action: #selector(dragViewDidDrag(gesture:)))
        addGestureRecognizer(dragGesture)
    }

    @objc private func dragViewDidDrag(gesture: UIPanGestureRecognizer) {
        guard let viewSuperview = superview else { return }
        let moveState = gesture.state
        let viewCenter = center
        switch moveState {
        case .changed:
            let point = gesture.translation(in: viewSuperview)
            center = CGPoint(x: viewCenter.x + point.x, y: viewCenter.y + point.y)
        case .ended:
            let point = gesture.translation(in: viewSuperview)
            let newPoint = CGPoint(x: viewCenter.x + point.x, y: viewCenter.y + point.y)
            UIView.animate(withDuration: 0.2) {
                self.center = self.adsorption(centerPoint: newPoint)
            } completion: { _ in
                self.originalX = self.frame.origin.x
            }
        default:
            break
        }
        gesture.setTranslation(.zero, in: viewSuperview)
    }

    private func adsorption(centerPoint: CGPoint) -> CGPoint {
        guard let viewSuperview = superview else { return centerPoint }
        let limitMargin: CGFloat = 5
        let frame = self.frame
        let point = CGPoint(x: centerPoint.x - frame.width / 2, y: centerPoint.y - frame.height / 2)
        var newPoint = point
        if centerPoint.x < (viewSuperview.frame.width / 2) {
            newPoint.x = limitMargin
        } else {
            newPoint.x = viewSuperview.frame.width - frame.width - limitMargin
        }
        if point.y <= limitMargin {
            newPoint.y = limitMargin
        } else if (point.y + frame.height) > (viewSuperview.frame.height - limitMargin) {
            newPoint.y = viewSuperview.frame.height - frame.height - limitMargin
        }
        return CGPoint(x: newPoint.x + frame.width / 2, y: newPoint.y + frame.height / 2)
    }
}
