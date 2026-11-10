import Foundation

struct PusherSettingsState: Equatable {
    var isMirrorEnabled = true
    var isMuted = false
    var captureVolume = 100
}

@MainActor protocol PusherSettingsActionHandling: AnyObject {
    func toggleMirror()
    func setCaptureVolume(_ volume: Int)
}
