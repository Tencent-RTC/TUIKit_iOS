import UIKit
import SnapKit
import AtomicXCore

final class RoomParticipantTileView: UIView {

    let streamType: VideoStreamType

    private var participant: RoomParticipant?
    private var isLocal = false
    private var volume = 0
    private var networkQuality: NetworkQuality?
    private var isPlaying = false
    private var renderer: RoomParticipantView?

    private let videoContainer = UIView()
    private let overlayView = RoomParticipantOverlayView()

    init(streamType: VideoStreamType) {
        self.streamType = streamType
        super.init(frame: .zero)
        backgroundColor = .clear
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

// MARK: - public methods

extension RoomParticipantTileView {

    func bind(participant: RoomParticipant,
              localParticipantID: String?,
              volume: Int,
              networkQuality: NetworkQuality? = nil) {
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

        if identityChanged || hadVideo != hasVideo {
            updatePlayback()
        }
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
    }
}

// MARK: - private methods

extension RoomParticipantTileView {

    private func hasVideoStream(_ participant: RoomParticipant) -> Bool {
        switch streamType {
        case .screen: return !isLocal && participant.screenShareStatus == .on
        case .camera: return participant.cameraStatus == .on
        }
    }

    private func updatePlayback() {
        guard let participant else {
            releaseRenderer()
            return
        }
        let hasLayoutSize = bounds.width > 0 && bounds.height > 0
        let canRender = isPlaying && hasLayoutSize && hasVideoStream(participant)
        if canRender {
            bindRenderer(participant)
        } else {
            releaseRenderer()
        }
    }

    private func bindRenderer(_ participant: RoomParticipant) {
        guard renderer == nil else { return }
        let videoView = RoomParticipantView(streamType: streamType, participant: participant)
        renderer = videoView
        videoContainer.addSubview(videoView)
        videoView.snp.makeConstraints { $0.edges.equalToSuperview() }

        videoView.setActive(isActive: false)
        videoView.setFillMode(fillMode: streamType == .screen ? .fit : .fill)
        videoView.updateStreamType(streamType: streamType)
        videoView.updateParticipant(participant: participant)
        videoView.setActive(isActive: true)
    }

    private func releaseRenderer() {
        renderer?.setActive(isActive: false)
        renderer?.removeFromSuperview()
        renderer = nil
    }
}
