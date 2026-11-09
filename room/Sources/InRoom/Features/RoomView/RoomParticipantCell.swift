import UIKit
import SnapKit
import AtomicXCore

class RoomParticipantCell: UICollectionViewCell {

    var streamType: VideoStreamType { fatalError("Subclasses must provide streamType") }
    var cellBackgroundColor: UIColor { fatalError("Subclasses must provide cellBackgroundColor") }

    private var participant: RoomParticipant?
    private(set) var isLocal = false
    private var volume = 0
    private var networkQuality: NetworkQuality?
    private var isPlaying = false
    private var renderer: RoomParticipantView?

    private let videoContainer = UIView()
    private let overlayView = RoomParticipantOverlayView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.clipsToBounds = true
        contentView.layer.cornerRadius = 12
        contentView.backgroundColor = cellBackgroundColor
        contentView.addSubview(videoContainer)
        contentView.addSubview(overlayView)
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

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { contentView.backgroundColor = cellBackgroundColor }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePlayback()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        release()
    }

    func hasVideoStream(_ participant: RoomParticipant) -> Bool {
        fatalError("Subclasses must implement hasVideoStream")
    }

    func configureRenderer(_ renderer: RoomParticipantView) {
        fatalError("Subclasses must implement configureRenderer")
    }
}

extension RoomParticipantCell {

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
                         streamType: streamType,
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

    private func release() {
        isPlaying = false
        releaseRenderer()
        participant = nil
        isLocal = false
        volume = 0
        overlayView.reset()
    }
}

private extension RoomParticipantCell {

    func updatePlayback() {
        guard let participant, bounds.width > 0, bounds.height > 0, hasVideoStream(participant) else {
            releaseRenderer()
            return
        }
        if renderer == nil { createRenderer(participant) }
        renderer?.setActive(isActive: isPlaying)
    }

    func createRenderer(_ participant: RoomParticipant) {
        let videoView = RoomParticipantView(streamType: streamType, participant: participant)
        renderer = videoView
        videoContainer.addSubview(videoView)
        videoView.snp.makeConstraints { $0.edges.equalToSuperview() }
        videoView.setActive(isActive: false)
        configureRenderer(videoView)
        videoView.updateStreamType(streamType: streamType)
        videoView.updateParticipant(participant: participant)
    }

    func releaseRenderer() {
        renderer?.setActive(isActive: false)
        renderer?.removeFromSuperview()
        renderer = nil
    }
}

final class RoomParticipantCameraCell: RoomParticipantCell {

    override var streamType: VideoStreamType { .camera }
    override var cellBackgroundColor: UIColor { UIColor.roomKitBgCanvas }

    override func hasVideoStream(_ participant: RoomParticipant) -> Bool {
        participant.cameraStatus == .on
    }

    override func configureRenderer(_ renderer: RoomParticipantView) {
        renderer.setFillMode(fillMode: .fill)
    }
}

final class RoomParticipantScreenShareCell: RoomParticipantCell {

    override var streamType: VideoStreamType { .screen }
    override var cellBackgroundColor: UIColor { UIColor.roomKitBgInverse }

    override func hasVideoStream(_ participant: RoomParticipant) -> Bool {
        !isLocal && participant.screenShareStatus == .on
    }

    override func configureRenderer(_ renderer: RoomParticipantView) {
        renderer.setFillMode(fillMode: .fit)
    }
}
