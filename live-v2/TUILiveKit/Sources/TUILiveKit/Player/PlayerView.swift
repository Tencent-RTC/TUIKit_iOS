import AtomicXCore
import Combine
import SnapKit
import UIKit

public enum PlayerStatus {
    case idle
    case playing
    case inRoom
    case coGuest
    case end
}

public final class PlayerView: UIView {
    private let impl = PlayerViewImpl()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(impl)
        impl.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public var liveID: String? {
        impl.liveID
    }

    public var status: AnyPublisher<PlayerStatus, Never> {
        impl.statusPublisher.eraseToAnyPublisher()
    }

    public func setLiveInfo(_ liveInfo: LiveInfo) {
        impl.setLiveInfo(liveInfo)
    }

    public func startPlay() {
        impl.startPlay()
    }

    public func stopPlay() {
        impl.stopPlay()
    }

    public func joinChannel(completion: ((Result<LiveInfo, Error>) -> Void)? = nil) {
        impl.joinChannel(completion: completion)
    }

    public func leaveChannel(completion: ((Result<Void, Error>) -> Void)? = nil) {
        impl.leaveChannel(completion: completion)
    }

    public func setVolume(_ volume: Int) {
        impl.setVolume(volume)
    }

    public var contentSafeAreaInsets: UIEdgeInsets {
        get { impl.contentSafeAreaInsets }
        set { impl.contentSafeAreaInsets = newValue }
    }

    public var joinLiveEntranceEnabled: Bool {
        get { impl.joinLiveEntranceEnabled }
        set { impl.joinLiveEntranceEnabled = newValue }
    }

    public static let eventKeyPlayerView = "PlayerView"
    public static let eventSubKeyOnJoinChannelResult = "onJoinChannelResult"
    public static let eventSubKeyOnJoinChannelParamsKey = "liveID"

    public var onCloseClicked: (() -> Void)? {
        get { impl.onCloseClicked }
        set { impl.onCloseClicked = newValue }
    }

    public var onJoinLiveClicked: (() -> Void)? {
        get { impl.onJoinLiveClicked }
        set { impl.onJoinLiveClicked = newValue }
    }
}
