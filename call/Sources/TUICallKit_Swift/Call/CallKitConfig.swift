import Combine
import Foundation

final class CallKitConfig {

    static let shared = CallKitConfig()

    private enum Keys {
        static let muteMode = "com.tencent.callkit.config.muteMode"
        static let transcriptionEnabled = "com.tencent.callkit.config.transcriptionEnabled"
        static let showOriginalTranscript = "com.tencent.callkit.config.showOriginalTranscript"
        static let transcriptFontSize = "com.tencent.callkit.config.transcriptFontSize"
        static let transcriptionTargetLanguage = "com.tencent.callkit.config.transcriptionTargetLanguage"
        static let ccPresetEnabled = "com.tencent.callkit.config.ccPresetEnabled"
    }

    private enum PresetFlag {
        static let on = "1"
        static let off = "0"
    }

    enum TranscriptFontSize: String, CaseIterable {
        case sm
        case md
        case lg

        var textFontSize: CGFloat {
            switch self {
            case .sm: return 11
            case .md: return 12
            case .lg: return 14
            }
        }
    }

    let transcriptionChanged = PassthroughSubject<Void, Never>()

    private let defaults = UserDefaults.standard

    private init() {
        enableMuteMode = defaults.bool(forKey: Keys.muteMode)
        enableAITranscriber = defaults.object(forKey: Keys.transcriptionEnabled) as? Bool ?? true
        let flag = defaults.string(forKey: Keys.ccPresetEnabled)
        switch flag {
        case nil, PresetFlag.on:
            ccPresetEnabled = true
            showOriginalTranscript = defaults.bool(forKey: Keys.showOriginalTranscript)
            transcriptFontSize = TranscriptFontSize(rawValue: defaults.string(forKey: Keys.transcriptFontSize) ?? "") ?? .md
            if let storedTarget = defaults.string(forKey: Keys.transcriptionTargetLanguage), !storedTarget.isEmpty {
                transcriptionTargetLanguage = storedTarget
            } else {
                transcriptionTargetLanguage = Self.factoryTargetLanguage
            }
        default:
            ccPresetEnabled = false
            showOriginalTranscript = false
            transcriptFontSize = .md
            transcriptionTargetLanguage = Self.factoryTargetLanguage
        }
    }

    private static var factoryTargetLanguage: String {
        Locale.current.languageCode == "zh" ? "zh" : "en"
    }

    var callingBellPath: String = ""
    var enableFloatWindow: Bool = true
    var enableIncomingBanner: Bool = true
    var enableVirtualBackground: Bool = false
    var screenOrientation: Int = 0

    private(set) var enableAITranscriber: Bool
    private(set) var enableMuteMode: Bool
    private(set) var showOriginalTranscript: Bool
    private(set) var transcriptFontSize: TranscriptFontSize
    private(set) var transcriptionTargetLanguage: String
    private(set) var ccPresetEnabled: Bool

    func updateMuteMode(_ enable: Bool) {
        enableMuteMode = enable
        defaults.set(enable, forKey: Keys.muteMode)
    }

    func updateAITranscriber(_ enable: Bool) {
        guard enableAITranscriber != enable else { return }
        enableAITranscriber = enable
        defaults.set(enable, forKey: Keys.transcriptionEnabled)
        transcriptionChanged.send()
    }

    func updateShowOriginalTranscript(_ show: Bool) {
        showOriginalTranscript = show
        if ccPresetEnabled {
            defaults.set(show, forKey: Keys.showOriginalTranscript)
        }
        transcriptionChanged.send()
    }

    func updateTranscriptFontSize(_ size: TranscriptFontSize) {
        transcriptFontSize = size
        if ccPresetEnabled {
            defaults.set(size.rawValue, forKey: Keys.transcriptFontSize)
        }
        transcriptionChanged.send()
    }

    func updateTranscriptionTargetLanguage(_ target: String) {
        transcriptionTargetLanguage = target
        if ccPresetEnabled {
            defaults.set(target, forKey: Keys.transcriptionTargetLanguage)
        }
        transcriptionChanged.send()
    }

    func updateCcPresetEnabled(_ enabled: Bool) {
        guard ccPresetEnabled != enabled else { return }
        ccPresetEnabled = enabled
        defaults.set(enabled ? PresetFlag.on : PresetFlag.off, forKey: Keys.ccPresetEnabled)
        if enabled {
            defaults.set(showOriginalTranscript, forKey: Keys.showOriginalTranscript)
            defaults.set(transcriptFontSize.rawValue, forKey: Keys.transcriptFontSize)
            defaults.set(transcriptionTargetLanguage, forKey: Keys.transcriptionTargetLanguage)
        } else {
            defaults.removeObject(forKey: Keys.showOriginalTranscript)
            defaults.removeObject(forKey: Keys.transcriptFontSize)
            defaults.removeObject(forKey: Keys.transcriptionTargetLanguage)
        }
        transcriptionChanged.send()
    }
}
