import Foundation

enum PusherVideoQualitySetting: Equatable {
    case fhd
    case hd
    case sd

    var title: String {
        switch self {
        case .fhd: return LiveKitResources.localizedString("tuilivekit.pusher.quality.fhd")
        case .hd: return LiveKitResources.localizedString("tuilivekit.pusher.quality.hd")
        case .sd: return LiveKitResources.localizedString("tuilivekit.pusher.quality.sd")
        }
    }
}

struct PusherSettingsState: Equatable {
    var videoQuality: PusherVideoQualitySetting = .hd
    var isMirrorEnabled = true
    var isMuted = false
    var captureVolume = 100
}

@MainActor
protocol PusherSettingsActionHandling: AnyObject {
    func toggleMirror()
    func setCaptureVolume(_ volume: Int)
}
