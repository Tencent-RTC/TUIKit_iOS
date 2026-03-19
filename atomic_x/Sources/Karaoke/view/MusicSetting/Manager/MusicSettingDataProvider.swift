//
//  MusicSettingDataProvider.swift
//  TUILiveKit
//
//  Created by aby on 2024/4/3.
//
import Combine
#if canImport(TXLiteAVSDK_TRTC)
import TXLiteAVSDK_TRTC
#elseif canImport(TXLiteAVSDK_Professional)
import TXLiteAVSDK_Professional
#endif
import AtomicXCore

protocol MusicSettingMenuDateGenerator {
    typealias Section = Int
    var MusicSettingMenus: [Section: [MusicSettingItem]] { get }
    var MusicSettingSectionTitles: [Section: String] { get }
}

class MusicSettingDataProvider {
    
    private weak var manager: KaraokeManager?
    init(manager: KaraokeManager) {
        self.manager = manager
    }
}

extension MusicSettingDataProvider: MusicSettingMenuDateGenerator {
    
    var MusicSettingMenus: [Section : [MusicSettingItem]] {
        return generateMusicSettingData()
    }
    
    var MusicSettingSectionTitles: [Section : String] {
        return [
            0: "",
            1: .audioSetting,
        ]
    }
    
    func generateMusicSettingData() -> [Section : [MusicSettingItem]] {
        var menus: [Int:[MusicSettingItem]] = [:]
        menus[0] = firstSectionMenus()
        menus[1] = secondSectionMenus()
        return menus
    }
    
    private func firstSectionMenus() -> [MusicSettingItem] {
        guard let manager = manager else { return [] }
        var firstSection: [MusicSettingItem] = []

        var original = MusicSwitchItem(
            title: .Original,
            isOn: manager.karaokeState.musicTrackType == .originalSong,
            isEnabled: manager
                .isTrackAvailable(
                    manager.karaokeState.musicTrackType == .originalSong ? .accompaniment
                    : .originalSong)
        )
        original.action = { [weak self] isOpened in
            guard let self = self, let manager = self.manager else { return }
            
            let targetTrack: TXChorusMusicTrack = isOpened ? .originalSong : .accompaniment
            if !manager.isTrackAvailable(targetTrack) {
                manager.errorSubject.send(.trackSwitchNotSupportedText)
                return
            }

            manager.switchMusicTrack(trackType: targetTrack)
        }

        original.subscribeState = { [weak self] cell, cancellableSet in
            guard let self = self, let manager = self.manager else { return }

            manager.subscribe(StatePublisherSelector(keyPath: \.musicTrackType))
                .receive(on: DispatchQueue.main)
                .sink { [weak cell] musicTrackType in
                    if musicTrackType == .accompaniment {
                        cell?.isSelected = false
                    } else {
                        cell?.isSelected = true
                    }
                }
                .store(in: &cancellableSet)
        }
        firstSection.append(original)

        var enableScore = MusicSwitchItem(
            title: .score,
            isOn: manager.karaokeState.enableScore
        )
        enableScore.action = { [weak self] isOpened in
            guard let self = self else { return }
            self.manager?.enableScore(enable: isOpened)
        }
        enableScore.subscribeState = { [weak self] cell, cancellableSet in
            guard let self = self else { return }
            self.manager?.subscribe(StatePublisherSelector(keyPath: \.enableScore))
                .receive(on: DispatchQueue.main)
                .sink { [weak cell] enableScore in
                    if !enableScore {
                        cell?.isSelected = false
                    } else {
                        cell?.isSelected = true
                    }
                }
                .store(in: &cancellableSet)
        }
        firstSection.append(enableScore)
        return firstSection
    }
    
    private func secondSectionMenus() -> [MusicSettingItem] {
        guard let manager = manager else { return [] }
        var secondSection:[MusicSettingItem] = []
        var microphoneVolume = MusicSliderItem(title: .captureVolume)
        microphoneVolume.min = 0
        microphoneVolume.max = 100
        microphoneVolume.currentValue = Float(manager.karaokeState.publishVolume)
        microphoneVolume.valueChanged = { [weak self] value in
            guard let self = self else { return }
            self.manager?.setPublishVolume(volume: Int(value))
        }
        microphoneVolume.subscribeState = { [weak self] cell, cancellableSet in
            guard let self = self else { return }
            self.manager?.subscribe(StatePublisherSelector(keyPath: \.publishVolume))
                .receive(on: DispatchQueue.main)
                .sink { [weak cell] value in
                    guard let sliderCell = cell else { return }
                    sliderCell.valueLabel.text = "\(value)"
                    sliderCell.configSlider.value = Float(value)
                }
                .store(in: &cancellableSet)
        }
        secondSection.append(microphoneVolume)

        var musicVolume = MusicSliderItem(title: .playoutVolume)
        musicVolume.min = 0
        musicVolume.max = 100
        musicVolume.currentValue = Float(manager.karaokeState.playoutVolume)
        musicVolume.valueChanged = { [weak self] value in
            self?.manager?.setPlayoutVolume(volume: Int(value))
        }
        musicVolume.subscribeState = { [weak self] cell, cancellableSet in
            guard let self = self else { return }
            self.manager?.subscribe(StatePublisherSelector(keyPath: \.playoutVolume))
                .receive(on: DispatchQueue.main)
                .sink { [weak cell] value in
                    guard let sliderCell = cell else { return }
                    sliderCell.valueLabel.text = "\(value)"
                    sliderCell.configSlider.value = Float(value)
                }
                .store(in: &cancellableSet)
        }
        secondSection.append(musicVolume)

        var pitchAdjustment = MusicSliderItem(title: .pitchSetting)
        pitchAdjustment.min = -1.0
        pitchAdjustment.max = 1.0
        pitchAdjustment.currentValue = manager.karaokeState.musicPitch
        pitchAdjustment.valueChanged = { [weak self] value in
            self?.manager?.setMusicPitch(pitch: value)
        }

        pitchAdjustment.subscribeState = { [weak self] cell, cancellableSet in
            guard let self = self else { return }
            self.manager?.subscribe(StatePublisherSelector(keyPath: \.musicPitch))
                .receive(on: DispatchQueue.main)
                .sink { [weak cell] value in
                    cell?.valueLabel.text = String(format: "%.1f", value)
                    cell?.configSlider.value = Float(value)
                }
                .store(in: &cancellableSet)
        }
        secondSection.append(pitchAdjustment)

        return secondSection
    }
}

fileprivate extension String {
    static var voiceEarMonitor: String = ("karaoke_setting_ear_return").atomicLocalized

    static var audioSetting: String = ("karaoke_setting_audio").atomicLocalized

    static var captureVolume: String = ("karaoke_setting_capture_volume").atomicLocalized

    static var playoutVolume: String = ("karaoke_setting_playback_volume").atomicLocalized

    static var voicePitch: String = ("karaoke_setting_music_pitch").atomicLocalized

    static var reverb: String = ("karaoke_change_reverb").atomicLocalized

    static var Original: String = ("karaoke_original").atomicLocalized

    static var child: String = ("karaoke_voice_child").atomicLocalized

    static var girl: String = ("karaoke_voice_girl").atomicLocalized

    static var uncle: String = ("karaoke_voice_uncle").atomicLocalized

    static var ethereal: String = ("karaoke_voice_ethereal").atomicLocalized

    static var withoutEffect: String = ("karaoke_reverb_none").atomicLocalized

    static var karaoke: String = ("karaoke_reverb_ktv").atomicLocalized

    static var metal: String = ("karaoke_reverb_metallic").atomicLocalized

    static var low: String = ("karaoke_reverb_low").atomicLocalized

    static var loud: String = ("karaoke_reverb_loud").atomicLocalized

    static var done: String = ("karaoke_setting_done").atomicLocalized

    static var score: String = ("karaoke_score").atomicLocalized

    static var pitchSetting: String = ("karaoke_setting_pitch_shift").atomicLocalized

    static var trackSwitchNotSupportedText = ("karaoke_cant_switch_tracks").atomicLocalized
}
