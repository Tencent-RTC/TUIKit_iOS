//
//  KaraokeState.swift
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

enum PlaybackState {
    case idel
    case start
    case pause
    case resume
    case stop
}

class KaraokeState {
    var currentMusicId: String = ""
    var currentMusicTotalDuration: TimeInterval = 0
    var chorusRole: TXChorusRole = .leadSinger
    var songLibrary: [MusicInfo] = availableSongs1
    var selectedSongs: [TUISongInfo] = []

    var musicTrackType: TXChorusMusicTrack = .originalSong
    var playProgress: TimeInterval = 0
    var playbackState: PlaybackState = .stop

    var standardPitchSequence: [TXReferencePitch] = []
    var pitch: Int32 = 0
    var progressMs: Int64 = 0
    var currentScore: Int32 = 0
    var averageScore: Int32 = 0

    var EarMonitor: Bool = false
    var enableScore: Bool = true
    var publishVolume: Int = 60
    var playoutVolume: Int = 95
    var musicPitch: Float = 0.0
    var reverbType: MusicReverbType = .none
    var enableRequestMusic: Bool = true

    var currentLyricList: [TXLyricLine] = []
    var currentPitchList: [TXReferencePitch] = []
    var isLocalMusic: Bool = true

    func isSongSelected(_ musicId: String) -> Bool {
        return selectedSongs.contains { $0.songId == musicId }
    }
}

public struct MusicInfo: Equatable, Codable {
    let musicId: String
    let musicName: String
    let artist: String
    let duration: TimeInterval
    let coverUrl: String
    let accompanyUrl: String
    let originalUrl: String
    let lyricUrl: String
    let isOriginal: Bool
    let hasRating: Bool
    var singers: [String] {
        return artist.components(separatedBy: ";").filter { !$0.isEmpty }
    }

    public init(
        musicId: String,
        musicName: String,
        artist: String,
        duration: TimeInterval,
        coverUrl: String,
        accompanyUrl: String,
        originalUrl: String,
        lyricUrl: String,
        isOriginal: Bool,
        hasRating: Bool
    ) {
        self.musicId = musicId
        self.musicName = musicName
        self.artist = artist
        self.duration = duration
        self.coverUrl = coverUrl
        self.accompanyUrl = accompanyUrl
        self.originalUrl = originalUrl
        self.lyricUrl = lyricUrl
        self.isOriginal = isOriginal
        self.hasRating = hasRating
    }

    static func fromJSON(_ json: [String: String]) -> MusicInfo? {
        guard let musicId = json["musicId"],
              let musicName = json["musicName"] else {
            return nil
        }

        let artist = json["singer"] ?? ""
        let coverUrl = json["coverUrl"] ?? ""
        let musicUrl = json["musicUrl"] ?? ""
        let lrcUrl = json["lrcUrl"] ?? ""

        return MusicInfo(
            musicId: musicId,
            musicName: musicName,
            artist: artist,
            duration: 0,
            coverUrl: coverUrl,
            accompanyUrl: "",
            originalUrl: musicUrl,
            lyricUrl: lrcUrl,
            isOriginal: true,
            hasRating: false
        )
    }

    public func toJSON() -> [String: String] {
        var json: [String: String] = [
            "musicId": musicId,
            "musicName": musicName,
            "singer": artist,
            "coverUrl": coverUrl,
            "musicUrl": originalUrl,
            "lrcUrl": lyricUrl
        ]

        return json
    }
}

enum MusicReverbType: Int {
    case none = 0
    case KTV = 1
    case smallRoom = 2
    case auditorium = 3
    case deep = 4
    case loud = 5
    case metallic = 6
    case magnetic = 7
}

let availableSongs1: [MusicInfo] = []

