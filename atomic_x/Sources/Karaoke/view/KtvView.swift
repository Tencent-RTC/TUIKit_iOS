//
//  KtvView.swift
//  Pods
//
//  Created by ssc on 2025/8/18.
//

import UIKit
import Combine
import RTCCommon
#if canImport(TXLiteAVSDK_TRTC)
import TXLiteAVSDK_TRTC
#elseif canImport(TXLiteAVSDK_Professional)
import TXLiteAVSDK_Professional
#endif

public class KtvView: UIView {
    private var initialCenter = CGPoint.zero
    private var isOwner: Bool
    private var isKTV: Bool
    private var isFirstEnterRoom: Bool = true
    private let karaokeManager: KaraokeManager
    private weak var popupViewController: UIViewController?
    private var averageScore: Int32 = -1

    private lazy var musicControlView: MusicControlView = {
        let view = MusicControlView(isOwner: isOwner,isKTV: isKTV)
        view.karaokeManager = self.karaokeManager
        view.onSongListButtonTapped = { [weak self] in
            guard let self = self else {return }
            self.onSongListButtonTapped()
        }
        return view
    }()

    private lazy var pitchView: PitchView = {
        let view = PitchView(manager: self.karaokeManager,isKTV: isKTV)
        view.isHidden = true
        return view
    }()

    private lazy var LyricsView: LyricsView = {
        let view = AtomicX.LyricsView(isKTV: isKTV)
        return view
    }()

    private lazy var scoreBoardView: ScoreBoardView = {
        let view =  ScoreBoardView()
        view.isHidden = true
        return view
    }()

    private lazy var songListButton: SongListButton = {
        let btn = SongListButton()
        btn.isHidden = true
        return btn
    }()

    private let tipsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Regular", size: 14)
        label.text = .waitingTipsText
        label.textColor = UIColor.white.withAlphaComponent(0.9)
        return label
    }()

    private var cancellables = Set<AnyCancellable>()

    public init(karaokeManager: KaraokeManager, isOwner: Bool, isKTV: Bool) {
        self.karaokeManager = karaokeManager
        self.isOwner = isOwner
        self.isKTV = isKTV
        super.init(frame: .zero)
    }

    deinit{
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        popupViewController = nil
    }

    private var isViewReady = false
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        setupPitchView()
        bindInteraction()
        setupStateSubscriptions()
        isViewReady = true
        setChorusRole()
    }


    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setChorusRole() {
        let role: TXChorusRole = isOwner ? .leadSinger : .audience
        karaokeManager.setChorusRole(chorusRole: role)
    }

    private func loadCurrentSongResources(musicId: String) {
        let isLocalMusic = musicId.hasPrefix("local_demo")

        if isLocalMusic {
            guard let song = karaokeManager.karaokeState.songLibrary.first(where: { $0.musicId == musicId }) else {
                return
            }
            let fileURL = URL(fileURLWithPath: song.lyricUrl)
            let lyricsInfo = LyricParser.parserLocalLyricFile(fileURL: fileURL)
            generateStandardPitchModels(lyricsInfo)
            LyricsView.loadLyrics(fileURL: fileURL)
        } else {
            let state = karaokeManager.karaokeState
            generateStandardPitchModelsFromOnline(state.currentPitchList)
            LyricsView.loadOnlineLyrics(lyricList: state.currentLyricList)
        }
    }

    private func updateLyricsAndPitch(progress: Int) {
        LyricsView.updateLyrics(progress: progress)
        pitchView.isHidden = false
        pitchView.setCurrentSongProgress(progress: progress)
    }

    private func handlePlaybackStateChange(_ state: PlaybackState) {
        switch state {
            case .stop:
                LyricsView.isHidden = true
                scoreBoardView.isHidden = true
                pitchView.hidden()
                pitchView.stopButterflyEffect()
                pitchView.clear()

            case .pause:
                pitchView.stopButterflyEffect()
                tipsLabel.isHidden = true
            case .resume:
                return

            case .idel:
                pitchView.hidden()
                pitchView.stopButterflyEffect()
                tipsLabel.isHidden = true
                LyricsView.isHidden = true
                showScoreBoard()
            default:
                LyricsView.isHidden = false
                tipsLabel.isHidden = true
                scoreBoardView.isHidden = true
                pitchView.show()
        }
    }

    private func updatePitch(pitch: Int, progress: Int) {
        pitchView.setCurrentPitch(pitch: pitch)
        pitchView.setCurrentSongProgress(progress: progress)
    }

    private func generateStandardPitchModels(_ info: LyricsInfo?) {
        var newModels: [PitchModel] = []

        if let info = info {
            for lineInfo in info.LyricLineInfos {
                let lineStartTime = lineInfo.startTime
                let linePitch = Int.random(in: 20...80)

                for charStr in lineInfo.charStrArray {
                    let model = PitchModel(
                        startTime: charStr.startTime + Int(lineStartTime * 1000),
                        duration: charStr.duration,
                        pitch: linePitch + Int.random(in: -5...5)
                    )
                    newModels.append(model)
                }
            }
        }
        pitchView.setStandardPitchModels(standardPitchModels: newModels)
    }

    private func generateStandardPitchModelsFromOnline(_ pitchList: [TXReferencePitch]) {
        var newModels: [PitchModel] = []

        for pitch in pitchList {
            let model = PitchModel(
                startTime: Int(pitch.startTimeMs),
                duration: Int(pitch.durationMs),
                pitch: Int(pitch.referencePitch)
            )
            newModels.append(model)
        }

        pitchView.setStandardPitchModels(standardPitchModels: newModels)
    }

    private func showScoreBoard() {
        guard let songs = karaokeManager.karaokeState.selectedSongs.first else { return }
        let imageURL = songs.requester.avatarUrl
        let username = songs.requester.userName == "" ? songs.requester.userId : songs.requester.userName
        if karaokeManager.karaokeState.enableScore && isKTV{
            scoreBoardView.isHidden = false
            scoreBoardView.showScoreBoard(imageURl: imageURL,username: username,
                                          score: self.averageScore == -1 ? Int32.random(in: 95...100) : self.averageScore)
        } else {
            scoreBoardView.isHidden = true
        }
    }

    private func setupPitchView() {
        let config = PitchViewConfig()
        config.timeElapsedOnScreen = 2000
        config.timeToPlayOnScreen = 3000
        pitchView.setConfig(config: config)
    }

    private func bindInteraction() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)

        songListButton.addTarget(self, action: #selector(onSongListButtonTapped), for: .touchUpInside)
    }
}

extension KtvView: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let touchPoint = touch.location(in: self)

        let rightCircleFrame = musicControlView.convert(musicControlView.getSongListButtonFrame(), to: self)
        return rightCircleFrame.contains(touchPoint)
    }
}
// MARK: Layout
extension KtvView {
    private func constructViewHierarchy() {
        addSubview(pitchView)
        addSubview(LyricsView)
        addSubview(musicControlView)
        addSubview(songListButton)
        addSubview(scoreBoardView)
        addSubview(tipsLabel)
    }

    private func activateConstraints() {
        if isKTV {
            if isOwner {
                scoreBoardView.snp.makeConstraints { make in
                    make.width.equalTo(88.scale375())
                    make.height.equalTo(32.scale375())
                    make.left.equalToSuperview().offset(127.scale375())
                    make.top.equalTo(musicControlView.snp.bottom).offset(29.scale375())
                }
                songListButton.snp.makeConstraints { make in
                    make.height.equalTo(32.scale375())
                    make.width.equalTo(88.scale375())
                    make.centerX.equalToSuperview()
                    make.top.equalTo(musicControlView.snp.bottom).offset(12.scale375())
                }
            }

            tipsLabel.snp.makeConstraints { make in
                make.centerY.centerX.equalToSuperview()
                make.height.equalTo(22.scale375())
            }

            scoreBoardView.snp.makeConstraints { make in
                make.width.equalTo(88.scale375())
                make.height.equalTo(32.scale375())
                make.centerX.equalToSuperview()
                make.top.equalTo(musicControlView.snp.bottom).offset(29.scale375())
            }

            musicControlView.snp.makeConstraints { make in
                make.top.equalToSuperview()
                make.height.equalTo(40.scale375())
                make.left.right.equalToSuperview()
            }

            LyricsView.snp.makeConstraints { make in
                make.height.equalTo(50.scale375())
                make.bottom.equalToSuperview()
                make.left.right.equalToSuperview()
            }

            pitchView.snp.makeConstraints { make in
                make.height.equalTo(56.scale375())
                make.top.equalTo(musicControlView.snp.bottom).offset(5.scale375())
                make.left.equalToSuperview()
                make.right.equalToSuperview()
                make.centerX.equalToSuperview()
            }
        } else {
            pitchView.snp.makeConstraints { make in
                make.top.equalToSuperview()
                make.height.equalTo(40.scale375())
                make.left.right.equalToSuperview()
            }

            LyricsView.snp.makeConstraints { make in
                make.height.equalTo(40.scale375())
                make.top.equalTo(pitchView.snp.bottom).offset(5.scale375())
                make.left.right.equalToSuperview()
            }

            musicControlView.snp.makeConstraints { make in
                make.height.equalTo(40.scale375())
                make.top.equalTo(LyricsView.snp.bottom).offset(5.scale375())
                make.left.right.equalToSuperview()
            }
        }
    }
}

// MARK: Action
extension KtvView {

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view, let superview = superview else { return }

        switch gesture.state {
            case .began:
                initialCenter = view.center
            case .changed:
                let translation = gesture.translation(in: superview)
                let newCenter = CGPoint(x: initialCenter.x,
                                        y: initialCenter.y + translation.y)

                let safeFrame = superview.bounds.inset(by: superview.safeAreaInsets)
                let topMargin = safeFrame.height / 4
                let bottomMargin = safeFrame.height / 4
                
                let minY = topMargin + view.bounds.height / 2
                let maxY = safeFrame.maxY - bottomMargin - view.bounds.height / 2

                let clampedY = min(max(newCenter.y, minY), maxY)

                view.center = CGPoint(x: initialCenter.x, y: clampedY)
            case .ended, .cancelled:
                let safeFrame = superview.bounds.inset(by: superview.safeAreaInsets)
                let topMargin = safeFrame.height / 4
                let bottomMargin = safeFrame.height / 4
                
                var newCenter = view.center
                newCenter.y = min(max(newCenter.y,
                                      topMargin + view.bounds.height / 2),
                                  safeFrame.maxY - bottomMargin - view.bounds.height / 2)

                UIView.animate(withDuration: 0.3) {
                    view.center = newCenter
                }
            default:
                break
        }
    }

    @objc private func onSongListButtonTapped() {
        if let vc = WindowUtils.getCurrentWindowViewController() {
            popupViewController = vc
            let songListView = SongListViewController(
                karaokeManager: self.karaokeManager,
                isOwner: isOwner,
                isKTV: isKTV
            )
            popupViewController?.present(songListView, animated: true)
        }
    }
}

// MARK: subscribe
extension KtvView {
    private func setupStateSubscriptions() {
        karaokeManager.subscribe(StateSelector(keyPath: \.playbackState))
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else {return}
                self.handlePlaybackStateChange(state)
            }
            .store(in: &cancellables)

        karaokeManager.subscribe(StateSelector(keyPath: \.currentMusicId))
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] musicId in
                guard let self = self else {return}
                if musicId != "" {
                    self.loadCurrentSongResources(musicId: musicId)
                }
            }
            .store(in: &cancellables)

        karaokeManager.subscribe(StateSelector(keyPath: \.currentPitchList))
            .removeDuplicates { $0.count == $1.count }
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pitchList in
                guard let self = self else { return }
                if !pitchList.isEmpty {
                    let musicId = self.karaokeManager.karaokeState.currentMusicId
                    if musicId != "" {
                        self.loadCurrentSongResources(musicId: musicId)
                    }
                }
            }
            .store(in: &cancellables)

        karaokeManager.subscribe(StateSelector(keyPath: \.playProgress))
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] progress in
                guard let self = self else {return}
                let progressMs = Int(progress * 1000)
                self.updateLyricsAndPitch(progress: progressMs)
            }
            .store(in: &cancellables)

        karaokeManager.subscribe(StateSelector(keyPath: \.pitch))
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] pitch in
                guard let self = self else {return}
                self.updatePitch(pitch: Int(pitch), progress: Int(karaokeManager.karaokeState.progressMs))
            }
            .store(in: &cancellables)

        karaokeManager.subscribe(StateSelector(keyPath: \.selectedSongs))
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selectedSongs in
                guard let self = self else {return}
                if selectedSongs.count == 0 && isKTV && isOwner{
                    self.songListButton.isHidden = false
                    self.tipsLabel.text = .waitingTipsText
                } else {
                    self.songListButton.isHidden = true
                }

                if selectedSongs.count == 0 && isKTV && !isOwner{
                    self.tipsLabel.isHidden = false
                    self.tipsLabel.text = .waitingTipsText
                } else {
                    self.tipsLabel.isHidden = true
                }

                let state = karaokeManager.karaokeState
                let hasSelectedSong = !state.selectedSongs.isEmpty
                let isSongMismatch = state.currentMusicId != state.selectedSongs.first?.songId && selectedSongs.count != 0

                if isKTV && !isOwner &&
                    hasSelectedSong &&
                    state.playbackState == .stop &&
                    isSongMismatch && isFirstEnterRoom{
                    tipsLabel.isHidden = false
                    tipsLabel.text = .pauseText
                    isFirstEnterRoom = false
                }
            }
            .store(in: &cancellables)

        karaokeManager.subscribe(StateSelector(keyPath: \.enableRequestMusic))
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enableRequestMusic in
                guard let self = self else {return}
                if enableRequestMusic{
                    self.isHidden = false
                } else {
                    self.isHidden = true
                }
            }
            .store(in: &cancellables)

        karaokeManager.subscribe(StateSelector(keyPath: \.currentScore))
            .removeDuplicates()
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] currentScore in
                guard let self = self else {return}
                pitchView.setScore("\(currentScore)")
            }
            .store(in: &cancellables)

        karaokeManager.subscribe(StateSelector(keyPath: \.averageScore))
            .removeDuplicates()
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] averageScore in
                guard let self = self else {return}
                self.averageScore = averageScore
            }
            .store(in: &cancellables)

    }
}

fileprivate extension String {
    static let waitingTipsText = ("Waiting for song selection…").localized
    static let pauseText = ("Song paused...").localized
}

