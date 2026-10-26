extension AICallConfig {
    private static let minimumTTSSpeed: Float = 0.5
    private static let maximumTTSSpeed: Float = 2.0
    private static let maximumAccumulatedMilliseconds = 60000
    private static let maximumTimeoutMilliseconds = Int(Int32.max)

    internal func validated() -> AICallConfig {
        var result = self
        let defaults = AICallConfig()
        if !ttsSpeed.isFinite || !(Self.minimumTTSSpeed ... Self.maximumTTSSpeed).contains(ttsSpeed) {
            result.ttsSpeed = defaults.ttsSpeed
        }
        if silenceHoldMs <= 0 || silenceHoldMs > Self.maximumAccumulatedMilliseconds {
            result.silenceHoldMs = defaults.silenceHoldMs
        }
        if thinkingTimeoutMs < 0 || thinkingTimeoutMs > Self.maximumTimeoutMilliseconds {
            result.thinkingTimeoutMs = defaults.thinkingTimeoutMs
        }
        return result
    }
}
