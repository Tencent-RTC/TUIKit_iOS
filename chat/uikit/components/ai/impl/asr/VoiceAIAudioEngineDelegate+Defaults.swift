import Foundation

extension VoiceAIAudioEngineDelegate {
    func voiceAIAudioEngine(_ engine: VoiceAIAudioEngine, didOutputPCM pcm: [Int16]) {}
    func voiceAIAudioEngine(_ engine: VoiceAIAudioEngine, didDetectOpusFormat frameDurationMs: Int, sampleRate: Int, channels: Int) {}
}

