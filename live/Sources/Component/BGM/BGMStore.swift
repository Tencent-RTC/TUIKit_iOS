//
//  BGMStore.swift
//  TUILiveKit
//
//  BGM playback store using AtomicXCore MusicStore.
//

import Foundation
import Combine
import AtomicXCore

struct BGMItem: Equatable {
    let id: Int32
    let name: String
    let path: String
    let pitch: Double

    static func == (lhs: BGMItem, rhs: BGMItem) -> Bool {
        return lhs.id == rhs.id
    }

    static func defaultList() -> [BGMItem] {
        return [
            BGMItem(id: 1,
                    name: internalLocalized("common_music_cheerful"),
                    path: "https://dldir1.qq.com/hudongzhibo/TUIKit/resource/music/PositiveHappyAdvertising.mp3",
                    pitch: 0),
            BGMItem(id: 2,
                    name: internalLocalized("common_music_melancholy"),
                    path: "https://dldir1.qq.com/hudongzhibo/TUIKit/resource/music/SadCinematicPiano.mp3",
                    pitch: 0),
            BGMItem(id: 3,
                    name: internalLocalized("common_music_wonder_world"),
                    path: "https://dldir1.qq.com/hudongzhibo/TUIKit/resource/music/WonderWorld.mp3",
                    pitch: 0),
        ]
    }
}

private let defaultMusicVolume = 60

class BGMStore {
    static weak var current: BGMStore?

    private let musicStore: MusicStore
    private(set) var musicList: [BGMItem] = BGMItem.defaultList()
    @Published private(set) var volume: Int = defaultMusicVolume

    private var cancellables = Set<AnyCancellable>()
    var onStateChanged: (() -> Void)?

    init(liveID: String) {
        self.musicStore = MusicStore.create(liveID: liveID)
        subscribeState()
        BGMStore.current = self
    }

    // MARK: - Query

    func isPlaying(_ item: BGMItem) -> Bool {
        let state = musicStore.state.value
        return state.playURL == item.path && state.playStatus == .playing
    }

    // MARK: - Playback Control

    func startPlay(_ item: BGMItem) {
        if musicStore.state.value.playStatus != .idle {
            musicStore.stopPlay()
        }
        musicStore.startPlay(url: item.path, completion: nil)
    }

    func stopPlay(_ item: BGMItem) {
        guard musicStore.state.value.playURL == item.path else { return }
        musicStore.stopPlay()
    }

    // MARK: - Volume

    func setVolume(_ vol: Int) {
        musicStore.setMusicVolume(vol)
    }

    // MARK: - Private

    private func subscribeState() {
        musicStore.state
            .subscribe(StatePublisherSelector(keyPath: \MusicState.musicVolume))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] vol in
                guard let self = self else { return }
                self.volume = vol
            }
            .store(in: &cancellables)

        musicStore.state
            .subscribe(StatePublisherSelector(keyPath: \MusicState.playStatus))
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.onStateChanged?()
            }
            .store(in: &cancellables)
    }
}
