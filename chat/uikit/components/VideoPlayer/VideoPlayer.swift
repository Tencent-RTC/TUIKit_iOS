import AVKit
import Combine
import UIKit

struct VideoData {
    let uri: String
    let localPath: String?
    public let width: Int
    public let height: Int
    let duration: TimeInterval?
    let snapshotUrl: String?
    let snapshotLocalPath: String?
    init(
        uri: String,
        localPath: String? = nil,
        width: Int = 0,
        height: Int = 0,
        duration: TimeInterval? = nil,
        snapshotUrl: String? = nil,
        snapshotLocalPath: String? = nil
    ) {
        self.uri = uri
        self.localPath = localPath
        self.width = width
        self.height = height
        self.duration = duration
        self.snapshotUrl = snapshotUrl
        self.snapshotLocalPath = snapshotLocalPath
    }
}

class VideoPlayer: ObservableObject {
    public static let shared = VideoPlayer()

    @Published public var isPresented = false
    @Published public var currentVideoData: VideoData?
    @Published public var player: AVPlayer?

    func play(videoData: VideoData) {
        currentVideoData = videoData
        setupPlayer(with: videoData)
        isPresented = true
    }

    func playWithUIKit(videoData: VideoData, onPresented: (() -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        currentVideoData = videoData

        let videoURL: URL
        if let localPath = videoData.localPath, !localPath.isEmpty {
            videoURL = URL(fileURLWithPath: localPath)
        } else {
            videoURL = URL(string: videoData.uri) ?? URL(fileURLWithPath: videoData.uri)
        }

        let player = AVPlayer(url: videoURL)
        let playerVC = AVPlayerViewController()
        playerVC.player = player

        let containerVC = VideoPlayerContainerViewController(playerViewController: playerVC)
        containerVC.onDismiss = onDismiss
        containerVC.modalPresentationStyle = .fullScreen
        containerVC.modalTransitionStyle = .crossDissolve

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(containerVC, animated: true) {
                player.play()
                onPresented?()
            }
        }
    }

    public func dismiss() {
        player?.pause()
        player = nil
        currentVideoData = nil
        isPresented = false
    }

    private init() {}

    private func setupPlayer(with videoData: VideoData) {
        let videoURL: URL
        if let localPath = videoData.localPath, !localPath.isEmpty {
            videoURL = URL(fileURLWithPath: localPath)
        } else {
            videoURL = URL(string: videoData.uri) ?? URL(fileURLWithPath: videoData.uri)
        }

        let asset = AVURLAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: playerItem)

        newPlayer.automaticallyWaitsToMinimizeStalling = false

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.dismiss()
        }

        newPlayer.play()
        player = newPlayer
    }
}

class VideoPlayerContainerViewController: UIViewController {
    var onDismiss: (() -> Void)?

    override var prefersStatusBarHidden: Bool {
        return true
    }

    private let playerViewController: AVPlayerViewController

    init(playerViewController: AVPlayerViewController) {
        self.playerViewController = playerViewController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        addChild(playerViewController)
        view.addSubview(playerViewController.view)
        playerViewController.view.frame = view.bounds
        playerViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerViewController.didMove(toParent: self)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isBeingDismissed || presentingViewController == nil else { return }
        playerViewController.player?.pause()
        onDismiss?()
        onDismiss = nil
    }
}
