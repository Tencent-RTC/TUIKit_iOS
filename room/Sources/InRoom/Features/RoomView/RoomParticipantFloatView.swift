import UIKit
import SnapKit
import AtomicXCore

final class RoomParticipantFloatView: UIView {

    private var participant: RoomParticipant?
    private var isLocal = false
    private var volume = 0
    private var networkQuality: NetworkQuality?
    private var isPlaying = false
    private var renderer: RoomParticipantView?

    private let videoContainer = UIView()
    private let overlayView = RoomParticipantOverlayView()
    private let panGesture = UIPanGestureRecognizer()

    var onFloatingPan: ((UIGestureRecognizer.State, CGPoint) -> Void)?

    init() {
        super.init(frame: .zero)
        backgroundColor = UIColor.roomKitBgCanvas
        clipsToBounds = true
        layer.cornerRadius = 12
        panGesture.addTarget(self, action: #selector(handlePan(_:)))
        panGesture.maximumNumberOfTouches = 1
        addGestureRecognizer(panGesture)
        addSubview(videoContainer)
        addSubview(overlayView)
        videoContainer.snp.makeConstraints { $0.edges.equalToSuperview() }
        overlayView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        renderer?.setActive(isActive: false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePlayback()
    }
}

extension RoomParticipantFloatView {

    func bind(participant: RoomParticipant,
              localParticipantID: String?,
              volume: Int,
              networkQuality: NetworkQuality?) {
        let nextIsLocal = participant.userID == localParticipantID
        let nextVolume = participant.microphoneStatus == .on ? volume : 0
        let networkChanged = self.networkQuality != networkQuality

        if let old = self.participant,
           old.userID == participant.userID,
           !networkChanged,
           old.displayName == participant.displayName,
           old.avatarURL == participant.avatarURL,
           old.role == participant.role,
           old.microphoneStatus == participant.microphoneStatus,
           old.cameraStatus == participant.cameraStatus,
           old.screenShareStatus == participant.screenShareStatus,
           isLocal == nextIsLocal,
           self.volume == nextVolume {
            self.participant = participant
            return
        }

        let identityChanged = self.participant?.userID != participant.userID || isLocal != nextIsLocal
        let hadVideo = self.participant.map(hasVideoStream) ?? false
        if identityChanged { releaseRenderer() }

        self.participant = participant
        isLocal = nextIsLocal
        self.volume = nextVolume
        self.networkQuality = networkQuality

        let hasVideo = hasVideoStream(participant)
        overlayView.bind(participant: participant,
                         streamType: .camera,
                         isLocal: isLocal,
                         volume: volume,
                         hasVideoStream: hasVideo,
                         networkQuality: networkQuality)
        if identityChanged || hadVideo != hasVideo { updatePlayback() }
    }

    func setPlaying(_ value: Bool) {
        guard isPlaying != value else { return }
        isPlaying = value
        updatePlayback()
    }

    func release() {
        isPlaying = false
        releaseRenderer()
        participant = nil
        isLocal = false
        volume = 0
        overlayView.reset()
        transform = .identity
    }
}

private extension RoomParticipantFloatView {

    func hasVideoStream(_ participant: RoomParticipant) -> Bool {
        participant.cameraStatus == .on
    }

    func updatePlayback() {
        guard let participant, bounds.width > 0, bounds.height > 0, hasVideoStream(participant) else {
            releaseRenderer()
            return
        }
        if renderer == nil { createRenderer(participant) }
        renderer?.setActive(isActive: isPlaying)
    }

    func createRenderer(_ participant: RoomParticipant) {
        let videoView = RoomParticipantView(streamType: .camera, participant: participant)
        renderer = videoView
        videoContainer.addSubview(videoView)
        videoView.snp.makeConstraints { $0.edges.equalToSuperview() }
        videoView.setActive(isActive: false)
        videoView.setFillMode(fillMode: .fill)
        videoView.updateStreamType(streamType: .camera)
        videoView.updateParticipant(participant: participant)
    }

    func releaseRenderer() {
        renderer?.setActive(isActive: false)
        renderer?.removeFromSuperview()
        renderer = nil
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        onFloatingPan?(gesture.state, gesture.translation(in: superview))
    }
}
