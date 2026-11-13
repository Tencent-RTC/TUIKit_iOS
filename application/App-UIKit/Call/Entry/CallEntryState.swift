import AtomicXCore
import Foundation
import TUICallKit_Swift

final class CallEntryState {

    static let shared = CallEntryState()

    enum Media: String {
        case video
        case audio
    }

    enum Resolution: String, CaseIterable {
        case sd = "540P"
        case hd = "720P"
        case fhd = "1080P"
        case premium2K = "2K"

        var displayName: String {
            switch self {
            case .sd: CallAccessText.resolutionSD
            case .hd: CallAccessText.resolutionHD
            case .fhd: CallAccessText.resolutionFHD
            case .premium2K: CallAccessText.resolution2K
            }
        }

        var videoQuality: VideoQuality? {
            switch self {
            case .sd: .quality540P
            case .hd: .quality720P
            case .fhd: .quality1080P
            case .premium2K: nil
            }
        }
    }

    var userIDs: [String] = []
    var media: Media = .video
    var resolution: Resolution = .sd

    var ringtone = ""

    var ringtoneLabel: String {
        ringtone.isEmpty ? CallAccessText.settingsRingtoneDefault : ringtone
    }

    static let builtinRingtoneName = "phone_ringing.mp3"
    var bannerOn = true
    var showFloatButton = true
    var blurBackgroundOn = true
    var proBeautyOn = true
    var captionOn = true

    var muteModeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.muteMode) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.muteMode) }
    }

    private enum Keys {
        static let muteMode = "callkit.access.muteMode"
    }

    var roomID = ""
    var timeoutSeconds = 60
    var extendedInfo = ""

    var userIDsText: String {
        userIDs.joined(separator: ",")
    }

    static func parseIDs(_ raw: String) -> [String] {
        let parts = raw.components(separatedBy: CharacterSet(charactersIn: " \t\n,，;；、"))
        var seen = Set<String>()
        var list: [String] = []
        for part in parts {
            let id = part.trimmingCharacters(in: .whitespaces)
            guard !id.isEmpty else { continue }
            guard !seen.contains(id.lowercased()) else { continue }
            seen.insert(id.lowercased())
            list.append(id)
        }
        return list
    }

    static func containsSeparator(_ text: String) -> Bool {
        text.rangeOfCharacter(from: CharacterSet(charactersIn: " \t\n,，;；、")) != nil
    }

    static let maxCalleeIDs = 8
}
