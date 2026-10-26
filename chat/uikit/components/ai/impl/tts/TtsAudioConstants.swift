import Foundation

enum TtsAudioConstants {
    static let sampleRate: Int32 = 16000
    static let channels: UInt32 = 1
}

func TtsPlaybackLog(_ message: String) {
    NSLog("[TTS] %@", message)
}
