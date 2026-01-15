//
//  KaraokeManager.swift
//  Pods
//
//  Created by ssc on 2025/8/19.
//

import Foundation
#if canImport(TXLiteAVSDK_TRTC)
import TXLiteAVSDK_TRTC
#elseif canImport(TXLiteAVSDK_Professional)
import TXLiteAVSDK_Professional
#endif
import RTCRoomEngine
import Combine
import RTCCommon
import TUICore
import AtomicXCore

public class KaraokeManager: NSObject {

    private(set) var state: ObservableState<KaraokeState>
    let kickedOutSubject = PassthroughSubject<Void, Never>()
    public let errorSubject = PassthroughSubject<String, Never>()
    var karaokeState: KaraokeState { state.state }

    private let roomId: String
    private let trtcCloud = TRTCCloud.sharedInstance()
    private let roomEngine = TUIRoomEngine.sharedInstance()
    private let config: KaraokeConfig = KaraokeConfig.shared
    private let service = MusicCatalogServiceManager.shared.getService()

    private lazy var audioEffectManager: TXAudioEffectManager = trtcCloud.getAudioEffectManager()
    private lazy var chorusMusicPlayer: TXChorusMusicPlayer = {
        let player = TXChorusMusicPlayer.createPlayer(with: trtcCloud, roomId: roomId, delegate: self) ?? TXChorusMusicPlayer()
        return player
    }()

    private lazy var songListManager: TUISongListManager? = {
        let manager = TUIRoomEngine.sharedInstance().getExtension(extensionType: .songListManager) as? TUISongListManager
        manager?.addObserver(self)
        return manager
    }()

    private var scorePanelTimer: Timer?
    private var isNaturalEnd: Bool = true
    private var isLoadingMusic: Bool = false

    private var lastSentJsonData: String?
    private var sendCounter: Int = 0
    private let userIdKey = "u"
    private let pitchKey = "p"
    private let scoreKey = "s"
    private let avgScoreKey = "a"
    private var ownerId: String = LiveListStore.shared.state.value.currentLive.liveOwner.userID
    private var userId: String = TUIRoomEngine.getSelfInfo().userId

    public init(roomId: String) {
        self.roomId = roomId
        self.state = ObservableState(initialState: KaraokeState())
        super.init()
        
        setupObservers()
        setupAudioEffect()
        loadMusicCatalog()

        getWaitingList(cursor: "")
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Setup & Cleanup
    
    private func setupObservers() {
        roomEngine.addObserver(self)
        trtcCloud.setAudioFrameDelegate(self)
    }
    
    private func setupAudioEffect() {
        setAudioEffect()
    }
    
    private func loadMusicCatalog() {
        service.getSongList { [weak self] songList in
            self?.state.update { state in
                state.songLibrary = songList
            }
        }
    }
    
    private func cleanup() {
        releaseScorePanelTimer()
        roomEngine.removeObserver(self)
        songListManager?.removeObserver(self)
        trtcCloud.setAudioFrameDelegate(nil)
    }

    // MARK: - Chorus Role Management
    
    func setChorusRole(chorusRole: TXChorusRole) {
        let bgmParams = createBGMParams()
        chorusMusicPlayer.setChorusRole(chorusRole, trtcParamsForPlayer: bgmParams)
        
        state.update { state in
            state.chorusRole = chorusRole
        }
    }
    
    private func createBGMParams() -> TRTCParams {
        let bgmParams = TRTCParams()
        bgmParams.sdkAppId = UInt32(config.SDKAPPID)
        bgmParams.userId = "\(roomId)_bgm"
        bgmParams.userSig = GenerateTestUserSig.genTestUserSig(
            SDKAPPID: config.SDKAPPID,
            SECRETKEY: config.SECRETKEY,
            identifier: bgmParams.userId
        )
        bgmParams.roomId = 0
        bgmParams.strRoomId = roomId
        bgmParams.role = .anchor
        return bgmParams
    }

    // MARK: - Music Loading

    func loadLocalMusic() {
        if let musicInfo = self.karaokeState.songLibrary.first(where: { $0.musicId == self.karaokeState.selectedSongs[0].songId }) {
            loadLocalDemoMusic(
                musicId: musicInfo.musicId,
                musicUrl: musicInfo.originalUrl,
                accompanyUrl: musicInfo.accompanyUrl
            )
        }
    }

    func loadNetWorkMusic(musicId: String) {
        loadCopyrightedMusic(musicId: musicId)
    }

    private func loadCopyrightedMusic(musicId: String) {
        service.queryPlayToken(musicId: musicId, liveID: roomId, callback: ClosureQueryPlayTokenCallback(
            onSuccess: { [weak self] musicId, playToken, licenseKey, licenseUrl in
                guard let self = self else { return }
                self.loadCopyrightedMusicWithToken(
                    musicId: musicId,
                    playToken: playToken,
                    copyrightedLicenseKey: licenseKey ?? "",
                    copyrightedLicenseUrl: licenseUrl ?? ""
                )
            },
            onFailure: { [weak self] code, desc in
                self?.errorSubject.send(.loadFailedText)
            }
        ))
    }
    
    private func loadCopyrightedMusicWithToken(musicId: String, playToken: String, copyrightedLicenseKey: String, copyrightedLicenseUrl: String) {
        let params = TXChorusCopyrightedMusicParams()
        params.musicId = musicId
        params.playToken = playToken
        params.copyrightedLicenseKey = copyrightedLicenseKey
        params.copyrightedLicenseUrl = copyrightedLicenseUrl
        chorusMusicPlayer.loadMusic(params)
    }
    
    private func loadLocalDemoMusic(musicId: String, musicUrl: String, accompanyUrl: String) {
        let params = TXChorusExternalMusicParams()
        params.musicId = musicId
        params.musicUrl = musicUrl
        params.accompanyUrl = accompanyUrl
        params.isEncrypted = 0
        params.encryptBlockLength = 0
        
        chorusMusicPlayer.loadExternalMusic(params)
    }

    // MARK: - Music Playback Contro

    func start() {
        let musicTrackType: TXChorusMusicTrack
        if isTrackAvailable(karaokeState.musicTrackType) {
            musicTrackType = karaokeState.musicTrackType
        } else {
            musicTrackType = .accompaniment
            state.update { state in
                state.musicTrackType = .accompaniment
            }
        }
        
        switchMusicTrack(trackType: musicTrackType)
        chorusMusicPlayer.start()
        
        state.update { state in
            state.playbackState = .start
        }
    }
    
    func stopPlayback() {
        chorusMusicPlayer.stop()
        state.update { state in
            state.playbackState = .stop
            state.playProgress = 0
        }
    }
    
    func pausePlayback() {
        chorusMusicPlayer.pause()
        state.update { state in
            state.playbackState = .pause
        }
    }
    
    func resumePlayback() {
        chorusMusicPlayer.resume()
        state.update { state in
            state.playbackState = .resume
        }
    }
    
    func seek(positionMs: TimeInterval) {
        chorusMusicPlayer.seek(Int64(positionMs) / 1000)
        state.update { state in
            state.playProgress = positionMs
        }
    }
    
    func switchMusicTrack(trackType: TXChorusMusicTrack) {
        guard isTrackAvailable(trackType) else {
            state.update { state in
                state.musicTrackType = state.musicTrackType
            }
            if karaokeState.chorusRole == .leadSinger {
                errorSubject.send(.trackSwitchNotSupportedText)
            }
            return
        }

        state.update { state in
            state.musicTrackType = trackType
        }
        chorusMusicPlayer.switch(trackType)
    }

    func isTrackAvailable(_ trackType: TXChorusMusicTrack) -> Bool {
        guard let currentSong = karaokeState.selectedSongs.first else {
            return false
        }
        
        let musicId = currentSong.songId

        if musicId.hasPrefix("local_demo") {
            guard let musicInfo = karaokeState.songLibrary.first(where: { $0.musicId == musicId }) else {
                return false
            }
            
            switch trackType {
                case .originalSong:
                    return !musicInfo.originalUrl.isEmpty
                case .accompaniment:
                    return !musicInfo.accompanyUrl.isEmpty
                @unknown default:
                    return false
            }
        }

        guard let media = TXCopyrightedMedia.instance() else {
            return true
        }
        
        let bgmType: Int = (trackType == .originalSong) ? 0 : 1
        let trackPath = media.genMusicURI(musicId, bgmType: Int32(bgmType), bitrateDefinition: "audio/hi")

        return (trackPath?.count ?? 0) > 0
    }
    
    func setPlayoutVolume(volume: Int) {
        state.update { state in
            state.playoutVolume = volume
        }
        chorusMusicPlayer.setPlayoutVolume(Int32(volume))
    }
    
    func setPublishVolume(volume: Int) {
        state.update { state in
            state.publishVolume = volume
        }
        chorusMusicPlayer.setPublishVolume(Int32(volume))
    }
    
    func setMusicPitch(pitch: Float) {
        state.update { state in
            state.musicPitch = pitch
        }
        chorusMusicPlayer.setMusicPitch(pitch)
    }
    
    func setVoiceEarMonitorEnable(_ enable: Bool) {
        audioEffectManager.enableVoiceEarMonitor(enable)
        state.update { state in
            state.EarMonitor = enable
        }
    }
    
    func setReverbType(_ type: MusicReverbType) {
        audioEffectManager.setVoiceReverbType(TXVoiceReverbType(rawValue: type.rawValue) ?? ._0)
        state.update { state in
            state.reverbType = type
        }
    }

    // MARK: - Song List Management

    func addSong(songInfo: TUISongInfo) {
        songListManager?.addSong(songList: [songInfo], onSuccess: {
        }, onError: { [weak self] code, message in
            if code == .freqLimit {
                self?.errorSubject.send(.freqLimitText)
            }
        })
    }
    
    func eraseMusic(musicId: String) {
        songListManager?.removeSong(songIdList: [musicId], onSuccess: {
        }, onError: { [weak self] code, message in
            if code == .freqLimit {
                self?.errorSubject.send(.freqLimitText)
            }
        })
    }
    
    func setNextSong(musicId: String) {
        songListManager?.setNextSong(targetSongId: musicId, onSuccess: {
        }, onError: { [weak self] code, message in
            if code == .freqLimit {
                self?.errorSubject.send(.freqLimitText)
            }
        })
    }

    func playNextSong() {
        songListManager?.playNextSong(onSuccess: {
        }, onError: { [weak self] code, message in
            if code == .freqLimit {
                self?.errorSubject.send(.freqLimitText)
            }
        })
    }
    
    func playNextMusic() {
        guard !isLoadingMusic else {
            return
        }

        releaseScorePanelTimer()
        isNaturalEnd = false
        
        if karaokeState.playbackState == .idel {
            playNextSong()
        } else {
            songListManager?.playNextSong(onSuccess: { [weak self] in
                guard let self = self else {return}
                stopPlayback()
            }, onError: { [weak self] code, message in
                if code == .freqLimit {
                    self?.errorSubject.send(.freqLimitText)
                }
            })
        }
    }

    func eraseAllMusic() {
        let allMusicIds = karaokeState.selectedSongs.map { $0.songId }
        guard !allMusicIds.isEmpty else { return }

        songListManager?.removeSong(songIdList: allMusicIds, onSuccess: {
        }, onError: { [weak self] code, message in
            if code == .freqLimit {
                self?.errorSubject.send(.freqLimitText)
            }
        })
    }

    private func getWaitingList(cursor: String) {
        songListManager?.getWaitingList(cursor: cursor, count: 20, onSuccess: { [weak self] result in
            guard let self = self else { return }
            self.updateWaitingListState(with: result.songList, cursor: cursor)

            if result.cursor != "" {
                self.getWaitingList(cursor: result.cursor)
            }
        }, onError: { code, message in
        })
    }
    
    private func updateWaitingListState(with songList: [TUISongInfo], cursor: String) {
        state.update { state in
            let wasEmpty = state.selectedSongs.isEmpty

            if cursor.isEmpty {
                state.selectedSongs = songList
            } else {
                state.selectedSongs.append(contentsOf: songList)
            }

            if wasEmpty && !state.selectedSongs.isEmpty {
                guard let firstSong = state.selectedSongs.first else { return }

                if firstSong.songId.hasPrefix("local_demo") {
                    loadLocalMusic()
                } else {
                    loadNetWorkMusic(musicId: firstSong.songId)
                }
            }
        }
    }


    // MARK: - Score & Metadata Management
    
    func enableScore(enable: Bool) {
        guard let data = try? JSONEncoder().encode(enable),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        
        let metadata: [String: String] = ["EnableScore": jsonString]
        roomEngine.setRoomMetadataByAdmin(metadata, onSuccess: {
        }, onError: { _,_ in
        })
    }

    // MARK: - Room Management
    
    public func synchronizeMetadata(isOwner: Bool) {
        if !isOwner {
            getMetadata()
            getWaitingList(cursor: "")
        } else {
            enableScore(enable: true)
        }
    }
    
    public func show() {
        guard karaokeState.chorusRole == .leadSinger else {
            return
        }
        
        state.update { state in
            state.enableRequestMusic = true
        }
        
        enableRequestMusic(enable: true)
    }
    
    public func exit() {
        eraseAllMusic()
        stopPlayback()
        state.update { state in
            state.enableRequestMusic = false
            state.selectedSongs = []
        }
        
        guard karaokeState.chorusRole == .leadSinger else {
            return
        }
        
        enableRequestMusic(enable: false)
        enableScore(enable: false)
    }
    
    private func enableRequestMusic(enable: Bool) {
        guard let data = try? JSONEncoder().encode(enable),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        
        let metadata: [String: String] = ["EnableRequestMusic": jsonString]
        roomEngine.setRoomMetadataByAdmin(metadata, onSuccess: {
        }, onError: { _, _ in
        })

    }

    // MARK: - Private Helper Methods
    
    private func performPlayNextMusic() {
        state.update { state in
            state.playbackState = .stop
            state.currentScore = -1001
            isNaturalEnd = true
        }
        
        guard !karaokeState.selectedSongs.isEmpty else {
            return
        }
        
        songListManager?.playNextSong { [weak self] in
            guard let self = self else { return }
        } onError: { [weak self] code, message in
            if code == .freqLimit {
                self?.errorSubject.send(.freqLimitText)
            }
        }
    }

    private func getMetadata() {
        roomEngine.getRoomMetadata(["EnableScore"], onSuccess: { [weak self] response in
            guard let self = self, let value = response["EnableScore"] else { return }
            self.parseEnableScoreJson(value)
        }, onError: {error, message in
        })

        roomEngine.getRoomMetadata(["EnableRequestMusic"], onSuccess: { [weak self] response in
            guard let self = self, let value = response["EnableRequestMusic"] else { return }
            self.parseEnableRequestMusicJson(value)
        }, onError: { error, message in
        })
    }
    
    private func releaseScorePanelTimer() {
        scorePanelTimer?.invalidate()
        scorePanelTimer = nil
    }
    
    private func parseEnableScoreJson(_ jsonString: String) {
        guard !jsonString.isEmpty,
              let data = jsonString.data(using: .utf8),
              let isEnabled = try? JSONDecoder().decode(Bool.self, from: data) else {
            return
        }
        
        state.update { state in
            state.enableScore = isEnabled
        }
    }
    
    private func parseEnableRequestMusicJson(_ jsonString: String) {
        guard !jsonString.isEmpty,
              let data = jsonString.data(using: .utf8),
              let isEnabled = try? JSONDecoder().decode(Bool.self, from: data) else {
            return
        }
        
        state.update { state in
            state.enableRequestMusic = isEnabled
        }
    }

    func subscribe<Value>(_ selector: StateSelector<KaraokeState, Value>) -> AnyPublisher<Value, Never> {
        return state.subscribe(selector)
    }
}

// MARK: - Audio Effects Extension
extension KaraokeManager {
    func setAudioEffect() {
        let dspConfig: [String: Any] = [
            "api": "setPrivateConfig",
            "params": [
                "configs": [
                    [
                        "key": "Liteav.Audio.common.dsp.version",
                        "value": "2",
                        "default": "1"
                    ]
                ]
            ]
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: dspConfig),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            trtcCloud.callExperimentalAPI(jsonString)
        }

        let hifiConfig: [String: Any] = [
            "api": "setPrivateConfig",
            "params": [
                "configs": [
                    [
                        "key": "Liteav.Audio.common.smart.3a.strategy.flag",
                        "value": "16",
                        "default": "1"
                    ]
                ]
            ]
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: hifiConfig),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            trtcCloud.callExperimentalAPI(jsonString)
        }

        let aiecModelConfig: [String: Any] = [
            "api": "setPrivateConfig",
            "params": [
                "configs": [
                    [
                        "key": "Liteav.Audio.common.ai.ec.model.type",
                        "value": "2",
                        "default": "2"
                    ]
                ]
            ]
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: aiecModelConfig),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            trtcCloud.callExperimentalAPI(jsonString)
        }

        let enableAiecConfig: [String: Any] = [
            "api": "setPrivateConfig",
            "params": [
                "configs": [
                    [
                        "key": "Liteav.Audio.common.enable.ai.ec.module",
                        "value": "1",
                        "default": "1"
                    ]
                ]
            ]
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: enableAiecConfig),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            trtcCloud.callExperimentalAPI(jsonString)
        }

        let enableAiModuleConfig: [String: Any] = [
            "api": "setPrivateConfig",
            "params": [
                "configs": [
                    [
                        "key": "Liteav.Audio.common.ai.module.enabled",
                        "value": "1",
                        "default": "1"
                    ]
                ]
            ]
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: enableAiModuleConfig),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            trtcCloud.callExperimentalAPI(jsonString)
        }
    }

    func setReverb(enable: Bool) {
        let customReverbParams: [String: Any] = [
            "enable": enable,
            "RoomSize": 60,
            "PreDelay": 20,
            "Reverberance": 40,
            "Damping": 50,
            "ToneLow": 30,
            "ToneHigh": 100,
            "WetGain": -3,
            "DryGain": 0,
            "StereoWidth": 40,
            "WetOnly": false
        ]
        let customReverbConfig: [String: Any] = [
            "api": "setCustomReverbParams",
            "params": customReverbParams
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: customReverbConfig),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            trtcCloud.callExperimentalAPI(jsonString)
        }
    }
}

// MARK: - TUISongListManagerObserver
extension KaraokeManager: TUISongListManagerObserver {
    public func onWaitingListChanged(reason: TUISongListChangeReason, changedSongs: [TUISongInfo]) {
        state.update { state in
            switch reason {
                case .add:
                    for song in changedSongs {
                        if !state.selectedSongs.contains(where: { $0.songId == song.songId }) {
                            state.selectedSongs.append(song)
                        }
                        if self.karaokeState.selectedSongs.count == 1 {
                            guard let firstSong = state.selectedSongs.first else { return }

                            if firstSong.songId.hasPrefix("local_demo") {
                                loadLocalMusic()
                            } else {
                                loadNetWorkMusic(musicId: firstSong.songId)
                            }
                        }
                    }
                    break
                case .remove:
                    let removedSongIds = Set(changedSongs.map { $0.songId })
                    let isPlayingSongRemoved = !state.selectedSongs.isEmpty && removedSongIds.contains(state.selectedSongs[0].songId)

                    state.selectedSongs.removeAll { removedSongIds.contains($0.songId) }

                    if isPlayingSongRemoved && state.chorusRole == .leadSinger {
                        if let firstSong = state.selectedSongs.first {
                            if firstSong.songId.hasPrefix("local_demo") {
                                loadLocalMusic()
                            } else {
                                loadNetWorkMusic(musicId: firstSong.songId)
                            }
                        }
                    }

                    if state.selectedSongs.isEmpty {
                        if state.playbackState != .stop && state.playbackState != .idel {
                            self.stopPlayback()
                        }
                        state.currentMusicId = ""
                        state.currentLyricList = []
                        state.currentPitchList = []
                        state.currentScore = -1001
                    }
                    break
                case .orderChanged:
                    for song in changedSongs {
                        if let index = state.selectedSongs.firstIndex(where: { $0.songId == song.songId }) {
                            let selectedMusic = state.selectedSongs.remove(at: index)
                            let insertIndex = min(1, state.selectedSongs.count)
                            state.selectedSongs.insert(selectedMusic, at: insertIndex)
                        }
                    }
                case .unknown:
                    let removedSongIds = Set(changedSongs.map { $0.songId })
                    state.selectedSongs.removeAll { removedSongIds.contains($0.songId) }

                    if state.selectedSongs.isEmpty {
                        if state.playbackState != .stop && state.playbackState != .idel {
                            self.stopPlayback()
                        }
                        state.currentMusicId = ""
                        state.currentScore = -1001
                    }
                    break
                default:
                    break
            }
        }
    }

    public func onPlayedListChanged(addedSongs: [TUISongInfo]) {

    }
}

// MARK: - ITXChorusMusicPlayerDelegate
extension KaraokeManager: ITXChorusPlayerDelegate {
    public func onChorusMusicLoadSucceed(_ musicId: String,
                                         lyricList: [TXLyricLine],
                                         pitchList: [TXReferencePitch]) {
        let isLocalMusic = musicId.hasPrefix("local_demo")

        isLoadingMusic = false

        start()
        state.update { state in
            state.currentMusicId = musicId
            state.currentLyricList = lyricList
            state.currentPitchList = pitchList
            state.isLocalMusic = isLocalMusic
        }
    }

    public func onVoicePitchUpdated(_ pitch: Int32, hasVoice: Bool, progressMs: Int64) {
        state.update { state in
            state.pitch = pitch
        }
    }

    public func onChorusRequireLoadMusic(_ musicId: String) {
        releaseScorePanelTimer()
        isLoadingMusic = true

        if musicId.hasPrefix("local_demo") {
            loadLocalDemoMusic(
                musicId: musicId,
                musicUrl: karaokeState.songLibrary
                    .first{$0.musicId == musicId}?.originalUrl ?? "",
                accompanyUrl: karaokeState.songLibrary
                    .first{$0.musicId == musicId}?.accompanyUrl ?? ""
            )
        } else {
            loadNetWorkMusic(musicId: musicId)
        }

    }

    public func onMusicProgressUpdated(_ progressMs: Int64, durationMs: Int64) {
        state.update { state in
            state.playProgress = TimeInterval(progressMs) / 1000.0
            state.currentMusicTotalDuration = TimeInterval(durationMs) / 1000.0
            if state.currentMusicTotalDuration - state.playProgress <= 1 || state.playProgress > state.currentMusicTotalDuration {
                isNaturalEnd = true
            } else {
                isNaturalEnd = false
            }
        }
    }

    public func onChorusError(_ errCode: TXChorusError, errMsg: String) {
        if errCode == TXChorusError.musicLoadFailed {
            state.update { state in
                if !state.selectedSongs.isEmpty { self.eraseMusic(musicId: state.selectedSongs.first?.songId ?? "")}
                state.currentMusicId = ""
                state.currentMusicTotalDuration = 0
                state.currentLyricList = []
                state.currentPitchList = []
            }
            errorSubject.send(.loadFailedText)
        }
    }

    public func onChorusMusicLoadProgress(_ musicId: String, progress: Float) {
    }

    public func onVoiceScoreUpdated(_ currentScore: Int32, averageScore: Int32, currentLine: Int32) {
        state.update { state in
            state.currentScore = currentScore
            state.averageScore = averageScore
        }
    }

    public func onChorusStopped() {
        if self.karaokeState.chorusRole == .leadSinger {
            setReverb(enable: false)
        }
        guard isNaturalEnd else {
            state.update { state in
                state.playbackState = .stop
                state.currentScore = -1001
            }
            return
        }

        if karaokeState.enableScore {
            state.update { state in
                state.playbackState = .idel
            }
            scorePanelTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                guard let self = self else {return}
                if self.karaokeState.chorusRole == .leadSinger {
                    self.performPlayNextMusic()
                } else {
                    state.update { state in
                        state.playbackState = .stop
                        state.currentScore = -1001
                    }
                }
            }
        } else {
            if karaokeState.chorusRole == .leadSinger {
                self.performPlayNextMusic()
            } else {
                state.update { state in
                    state.playbackState = .stop
                    state.currentScore = -1001
                }
            }
        }
    }

    public func onChorusStarted() {
        if self.karaokeState.chorusRole == .leadSinger {
            setReverb(enable: true)
        }
        state.update { state in
            state.playbackState = .start
        }
        getMetadata()
    }

    public func onChorusPaused() {
        state.update { state in
            state.playbackState = .pause
        }
    }

    public func onChorusResumed() {
        state.update { state in
            state.playbackState = .resume
        }
    }
}

// MARK: - TUIRoomObserver
extension KaraokeManager: TUIRoomObserver {
    public func onRoomMetadataChanged(key: String, value: String) {
        if key == "EnableScore" && !value.isEmpty {
            parseEnableScoreJson(value)
        } else if key == "EnableRequestMusic" && !value.isEmpty {
            parseEnableRequestMusicJson(value)
        }
    }

    public func onRoomDismissed(roomId: String, reason: TUIRoomDismissedReason) {
        kickedOutSubject.send()
    }

    public func onKickedOutOfRoom(roomId: String, reason: TUIKickedOutOfRoomReason, message: String) {
        kickedOutSubject.send()
    }
}

// MARK: - TRTCAudioFrameDelegate
extension KaraokeManager: TRTCAudioFrameDelegate {

    public func onCapturedAudioFrame(_ frame: TRTCAudioFrame) {
    }
    
    public func onLocalProcessedAudioFrame(_ frame: TRTCAudioFrame) {
        guard karaokeState.chorusRole == .leadSinger,
              karaokeState.playbackState == .start || karaokeState.playbackState == .resume else {
            lastSentJsonData = nil
            sendCounter = 0
            return
        }
        
        var dataMap: [String: Any] = [:]
        dataMap[userIdKey] = userId

        if karaokeState.pitch != 0 {
            dataMap[pitchKey] = karaokeState.pitch
        }

        if karaokeState.currentScore != 0 {
            dataMap[scoreKey] = karaokeState.currentScore
        }

        if karaokeState.averageScore != 0 {
            dataMap[avgScoreKey] = karaokeState.averageScore
        }

        if dataMap.count > 1 {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: dataMap)
                let currentJsonString = String(data: jsonData, encoding: .utf8)
                
                if currentJsonString != lastSentJsonData {
                    lastSentJsonData = currentJsonString
                    sendCounter = 5
                }
            } catch {
            }
        }

        if sendCounter > 0, let jsonString = lastSentJsonData {
            if let dataBytes = jsonString.data(using: .utf8) {
                frame.extraData = dataBytes
                sendCounter -= 1
            }
        }
    }
    
    public func onRemoteUserAudioFrame(_ frame: TRTCAudioFrame, userId: String) {
        guard let extraData = frame.extraData else {
            return
        }

        do {
            let dataMap = try JSONSerialization.jsonObject(with: extraData) as? [String: Any]

            guard let dataMap = dataMap,
                  let itemUserId = dataMap[userIdKey] as? String,
                  itemUserId == ownerId else {
                return
            }

            if let pitch = dataMap[pitchKey] as? NSNumber {
                let pitchValue = pitch.int32Value
                if karaokeState.pitch != pitchValue {
                    state.update { state in
                        state.pitch = pitchValue
                    }
                }
            }

            if let score = dataMap[scoreKey] as? NSNumber {
                let scoreValue = score.int32Value
                if karaokeState.currentScore != scoreValue {
                    state.update { state in
                        state.currentScore = scoreValue
                    }
                }
            }

            if let avgScore = dataMap[avgScoreKey] as? NSNumber {
                let avgScoreValue = avgScore.int32Value
                if karaokeState.averageScore != avgScoreValue {
                    state.update { state in
                        state.averageScore = avgScoreValue
                    }
                }
            }
            
        } catch {
        }
    }
    
    public func onMixedPlay(_ frame: TRTCAudioFrame) {

    }
    
    public func onMixedAllAudioFrame(_ frame: TRTCAudioFrame) {

    }
}

// MARK: - String Localization
fileprivate extension String {
    static let loadFailedText = ("karaoke_music_loading_error").localized
    static let trackSwitchNotSupportedText = ("karaoke_cant_switch_tracks").localized
    static let freqLimitText = ("common_client_error_freq_limit").localized}

