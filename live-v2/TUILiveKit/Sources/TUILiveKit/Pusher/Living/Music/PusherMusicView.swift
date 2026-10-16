import UIKit
import AtomicXCore
import Combine
import SnapKit

@MainActor
final class PusherMusicView: BottomSheetView {
    private struct Track: Equatable {
        let id: Int
        let name: String
        let url: String
        let duration: String
    }

    private enum PlayStatus: Equatable {
        case idle
        case loading
        case playing
        case paused
    }

    private struct State: Equatable {
        var tracks = [
            Track(
                id: 1,
                name: LiveKitResources.localizedString("tuilivekit.pusher.music.happy"),
                url: "https://dldir1.qq.com/hudongzhibo/TUIKit/resource/music/PositiveHappyAdvertising.mp3",
                duration: "05:45"
            ),
            Track(
                id: 2,
                name: LiveKitResources.localizedString("tuilivekit.pusher.music.sad"),
                url: "https://dldir1.qq.com/hudongzhibo/TUIKit/resource/music/SadCinematicPiano.mp3",
                duration: "06:06"
            ),
            Track(
                id: 3,
                name: LiveKitResources.localizedString("tuilivekit.pusher.music.wonder_world"),
                url: "https://dldir1.qq.com/hudongzhibo/TUIKit/resource/music/WonderWorld.mp3",
                duration: "02:05"
            ),
        ]
        var currentURL: String?
        var playStatus: PlayStatus = .idle

        func isPlaying(_ track: Track) -> Bool {
            currentURL == track.url && (playStatus == .playing || playStatus == .loading)
        }

        func isCurrent(_ track: Track) -> Bool {
            currentURL == track.url && playStatus != .idle
        }
    }

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let musicStore: MusicStore
    private var state = State()
    private var cancellables = Set<AnyCancellable>()
    private var isActive = false
    private var isSuspended = false
    private var resumeURL: String?

    override var sheetHeight: CGFloat { 370 }

    init(liveID: String) {
        musicStore = MusicStore.create(liveID: liveID)
        super.init(frame: .zero)
        configureUI()
    }

    func activate() {
        guard !isActive else { return }
        isActive = true
        updateState(musicStore.state.value)
        musicStore.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] musicState in
                self?.updateState(musicState)
            }
            .store(in: &cancellables)
    }

    func deactivate() {
        isSuspended = false
        resumeURL = nil
        guard isActive else { return }
        isActive = false
        cancellables.removeAll()
        musicStore.stopPlay()
        state.currentURL = nil
        state.playStatus = .idle
        tableView.reloadData()
    }

    func setSuspended(_ suspended: Bool) {
        guard isSuspended != suspended else { return }
        isSuspended = suspended
        guard isActive else { return }
        let current = musicStore.state.value
        if suspended {
            resumeURL = current.playStatus == .playing || current.playStatus == .loading
                ? current.playURL : nil
            if resumeURL != nil { musicStore.pausePlay() }
        } else {
            let shouldResume = resumeURL != nil && resumeURL == current.playURL && current.playStatus == .paused
            resumeURL = nil
            if shouldResume { musicStore.resumePlay() }
        }
    }

    func show() {
        present()
    }

    private func toggle(_ track: Track) {
        guard isActive, !isSuspended else { return }
        if state.currentURL == track.url {
            switch state.playStatus {
            case .playing, .loading:
                musicStore.pausePlay()
                return
            case .paused:
                musicStore.resumePlay()
                return
            case .idle:
                break
            }
        }
        if let currentURL = state.currentURL, currentURL != track.url {
            musicStore.stopPlay()
        }
        musicStore.setPitch(0)
        musicStore.startPlay(url: track.url, completion: nil)
    }

    private func updateState(_ musicState: MusicState) {
        guard isActive else { return }
        let playStatus: PlayStatus
        switch musicState.playStatus {
        case .idle: playStatus = .idle
        case .loading: playStatus = .loading
        case .playing: playStatus = .playing
        case .paused: playStatus = .paused
        @unknown default: playStatus = .idle
        }
        guard state.currentURL != musicState.playURL || state.playStatus != playStatus else { return }
        state.currentURL = musicState.playURL
        state.playStatus = playStatus
        tableView.reloadData()
        // Loading may complete after the live was paused.
        if isSuspended, playStatus == .playing {
            musicStore.pausePlay()
        }
    }

    private func configureUI() {
        sheetTitle = LiveKitResources.localizedString("tuilivekit.pusher.living.music")

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = 72
        tableView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 16, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(PusherMusicCell.self, forCellReuseIdentifier: PusherMusicCell.reuseIdentifier)
        contentView.addSubview(tableView)

        tableView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalToSuperview().offset(60)
        }
    }
}

extension PusherMusicView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        state.tracks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: PusherMusicCell.reuseIdentifier,
            for: indexPath
        ) as? PusherMusicCell else {
            return UITableViewCell()
        }
        let track = state.tracks[indexPath.row]
        cell.bind(
            name: track.name,
            duration: track.duration,
            isCurrent: state.isCurrent(track),
            isPlaying: state.isPlaying(track)
        )
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        toggle(state.tracks[indexPath.row])
    }
}

private final class PusherMusicCell: UITableViewCell {
    static let reuseIdentifier = "PusherMusicCell"

    private let coverView = UIView()
    private let coverIcon = UIImageView()
    private let playingOverlay = UIView()
    private let waveView = MusicWaveView()
    private let nameLabel = LiveText(.body)
    private let durationLabel = LiveText(.caption, tone: .tertiary)
    private let playbackControl = MusicPlaybackControlView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        waveView.setPlaying(false)
    }

    func bind(name: String, duration: String, isCurrent: Bool, isPlaying: Bool) {
        nameLabel.text = name
        durationLabel.text = duration
        playingOverlay.isHidden = !isCurrent
        playbackControl.bind(isCurrent: isCurrent, isPlaying: isPlaying)
        waveView.setPlaying(isPlaying)
    }

    private func configureUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        coverView.backgroundColor = PusherMusicStyle.coverBackground
        coverView.layer.cornerRadius = 9
        coverView.layer.masksToBounds = true
        contentView.addSubview(coverView)

        coverIcon.image = LiveKitResources.image(named: "livekit_living_setting_music")
        coverIcon.contentMode = .scaleAspectFit
        coverView.addSubview(coverIcon)

        playingOverlay.backgroundColor = PusherMusicStyle.playingOverlay
        playingOverlay.isHidden = true
        coverView.addSubview(playingOverlay)

        playingOverlay.addSubview(waveView)

        contentView.addSubview(nameLabel)

        contentView.addSubview(durationLabel)

        contentView.addSubview(playbackControl)

        coverView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(50)
        }
        coverIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 18, height: 21))
        }
        playingOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        waveView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 25, height: 18))
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverView.snp.trailing).offset(12)
            make.trailing.lessThanOrEqualTo(playbackControl.snp.leading).offset(-12)
            make.top.equalToSuperview().offset(17)
        }
        durationLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(7)
        }
        playbackControl.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(28)
        }
    }
}

private final class MusicPlaybackControlView: UIView {
    private let shapeLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        shapeLayer.fillColor = UIColor.white.withAlphaComponent(0.92).cgColor
        layer.addSublayer(shapeLayer)
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(isCurrent: Bool, isPlaying: Bool) {
        isHidden = !isCurrent
        shapeLayer.path = isPlaying ? makePausePath().cgPath : makePlayPath().cgPath
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = CGRect(x: 4.5, y: 4.5, width: 19, height: 19)
    }

    private func makePlayPath() -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 6.49, y: 4.12))
        path.addCurve(
            to: CGPoint(x: 8.06, y: 3.25),
            controlPoint1: CGPoint(x: 6.49, y: 3.31),
            controlPoint2: CGPoint(x: 7.38, y: 2.81)
        )
        path.addLine(to: CGPoint(x: 16.14, y: 8.33))
        path.addCurve(
            to: CGPoint(x: 16.14, y: 10.07),
            controlPoint1: CGPoint(x: 17.02, y: 8.88),
            controlPoint2: CGPoint(x: 17.02, y: 9.52)
        )
        path.addLine(to: CGPoint(x: 8.06, y: 15.15))
        path.addCurve(
            to: CGPoint(x: 6.49, y: 14.28),
            controlPoint1: CGPoint(x: 7.38, y: 15.59),
            controlPoint2: CGPoint(x: 6.49, y: 15.09)
        )
        path.close()
        return path
    }

    private func makePausePath() -> UIBezierPath {
        let path = UIBezierPath()
        path.append(UIBezierPath(roundedRect: CGRect(x: 5.54, y: 3.96, width: 2.85, height: 11.08), cornerRadius: 1.19))
        path.append(UIBezierPath(roundedRect: CGRect(x: 10.61, y: 3.96, width: 2.85, height: 11.08), cornerRadius: 1.19))
        return path
    }
}

private final class MusicWaveView: UIView {
    private struct AnimationParameters {
        let duration: CFTimeInterval
        let delay: CFTimeInterval
        let low: CGFloat
        let high: CGFloat
    }

    private let dots: [UIView] = (0 ..< 4).map { _ in UIView() }
    private let parameters = [
        AnimationParameters(duration: 0.620, delay: -0.180, low: 3, high: -4),
        AnimationParameters(duration: 0.790, delay: -0.510, low: 2, high: -5),
        AnimationParameters(duration: 0.530, delay: -0.340, low: 4, high: -3),
        AnimationParameters(duration: 0.710, delay: -0.620, low: 2, high: -4),
    ]
    private var isPlaying = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: dots)
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalSpacing
        addSubview(stack)
        dots.forEach {
            $0.backgroundColor = LiveTheme.Color.brandCyan
            $0.layer.cornerRadius = 2
            $0.layer.shadowColor = LiveTheme.Color.brandCyan.withAlphaComponent(0.95).cgColor
            $0.layer.shadowOpacity = 1
            $0.layer.shadowRadius = 5
            $0.layer.shadowOffset = .zero
            $0.snp.makeConstraints { make in
                make.size.equalTo(4)
            }
        }
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setPlaying(_ playing: Bool) {
        guard isPlaying != playing else { return }
        isPlaying = playing
        zip(dots, parameters).forEach { dot, parameters in
            dot.layer.removeAllAnimations()
            guard playing else {
                dot.layer.transform = CATransform3DIdentity
                dot.layer.opacity = 0.9
                return
            }

            dot.layer.transform = CATransform3DMakeAffineTransform(
                CGAffineTransform(translationX: 0, y: parameters.low).scaledBy(x: 0.82, y: 0.82)
            )
            dot.layer.opacity = 0.64

            let transform = CABasicAnimation(keyPath: "transform")
            transform.fromValue = CATransform3DMakeAffineTransform(
                CGAffineTransform(translationX: 0, y: parameters.low).scaledBy(x: 0.82, y: 0.82)
            )
            transform.toValue = CATransform3DMakeAffineTransform(
                CGAffineTransform(translationX: 0, y: parameters.high).scaledBy(x: 1.08, y: 1.08)
            )

            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = 0.64
            opacity.toValue = 1

            let group = CAAnimationGroup()
            group.animations = [transform, opacity]
            group.duration = parameters.duration
            group.beginTime = CACurrentMediaTime() + parameters.delay
            group.autoreverses = true
            group.repeatCount = .infinity
            group.timingFunction = CAMediaTimingFunction(controlPoints: 0.37, 0, 0.63, 1)
            group.isRemovedOnCompletion = false
            dot.layer.add(group, forKey: "backgroundMusicWave")
        }
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum PusherMusicStyle {
    static let coverBackground: UIColor = UIColor.white.withAlphaComponent(0.06)
    static let playingOverlay: UIColor = UIColor(red: 5 / 255, green: 7 / 255, blue: 12 / 255, alpha: 0.56)
}
