import AtomicXCore
import SnapKit
import UIKit

@MainActor
final class PageCell: UIView {
    let playerView = PlayerView()

    var liveID: String { liveInfo.liveID }

    private var liveInfo: LiveInfo
    private let getSwipeBehavior: () -> SwipeBehavior
    private let onCloseClicked: () -> Void
    private let onJoinClicked: () -> Void
    private let onDidSlideIn: (PageCell) -> Void
    private let onDidSlideOut: (PageCell) -> Void
    private let onJoinChannelStart: () -> Void
    private let onJoinChannelResult: (PageCell, Result<LiveInfo, Error>) -> Void

    init(
        liveInfo: LiveInfo,
        getSwipeBehavior: @escaping () -> SwipeBehavior,
        onCloseClicked: @escaping () -> Void,
        onJoinClicked: @escaping () -> Void,
        onDidSlideIn: @escaping (PageCell) -> Void,
        onDidSlideOut: @escaping (PageCell) -> Void,
        onJoinChannelStart: @escaping () -> Void,
        onJoinChannelResult: @escaping (PageCell, Result<LiveInfo, Error>) -> Void
    ) {
        self.liveInfo = liveInfo
        self.getSwipeBehavior = getSwipeBehavior
        self.onCloseClicked = onCloseClicked
        self.onJoinClicked = onJoinClicked
        self.onDidSlideIn = onDidSlideIn
        self.onDidSlideOut = onDidSlideOut
        self.onJoinChannelStart = onJoinChannelStart
        self.onJoinChannelResult = onJoinChannelResult
        super.init(frame: .zero)

        playerView.setLiveInfo(liveInfo)
        playerView.joinLiveEntranceEnabled = getSwipeBehavior() == .previewOnly
        playerView.onCloseClicked = { [weak self] in self?.onCloseClicked() }
        playerView.onJoinLiveClicked = { [weak self] in self?.onJoinClicked() }

        addSubview(playerView)
        playerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func updateData(_ liveInfo: LiveInfo) {
        self.liveInfo = liveInfo
        playerView.setLiveInfo(liveInfo)
    }

    func startPreview() {
        playerView.setVolume(0)
        playerView.startPlay()
    }

    func stopPreview() {
        playerView.stopPlay()
    }

    func joinChannel() {
        playerView.setVolume(100)
        onDidSlideIn(self)
        guard getSwipeBehavior() == .autoEnterRoom else { return }
        onJoinChannelStart()
        playerView.joinChannel { [weak self] result in
            guard let self else { return }
            self.onJoinChannelResult(self, result)
        }
    }

    func leaveChannel() {
        playerView.stopPlay()
        if getSwipeBehavior() == .autoEnterRoom {
            playerView.leaveChannel(completion: nil)
        }
        onDidSlideOut(self)
    }

    func stopAndLeaveChannel() {
        playerView.stopPlay()
        playerView.leaveChannel(completion: nil)
    }

    func setJoinLiveEntranceEnabled(_ enabled: Bool) {
        playerView.joinLiveEntranceEnabled = enabled
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
