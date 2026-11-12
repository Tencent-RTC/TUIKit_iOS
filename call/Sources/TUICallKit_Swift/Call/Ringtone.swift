import AVFoundation
import Foundation

final class Ringtone {

    static let shared = Ringtone()

    private var player: AVAudioPlayer?

    private init() {}

    func startDialTone() {
        play(resource: CallKitResources.audioPath("phone_dialing.m4a"))
    }

    func startRinging() {
        guard !CallKitConfig.shared.enableMuteMode else { return }
        let customPath = CallKitConfig.shared.callingBellPath
        if !customPath.isEmpty {
            if play(resource: customPath) { return }
            CallKitLog.warning("custom calling bell unavailable, fallback to built-in: \(customPath)")
        }
        play(resource: CallKitResources.audioPath("phone_ringing.mp3"))
    }

    func stopAll() {
        player?.stop()
        player = nil
    }

    @discardableResult
    private func play(resource path: String?) -> Bool {
        guard player == nil, let path else { return false }
        guard let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path)) else {
            CallKitLog.error("ringtone play failed: \(path)")
            return false
        }
        player.numberOfLoops = -1
        player.prepareToPlay()
        player.play()
        self.player = player
        return true
    }
}
