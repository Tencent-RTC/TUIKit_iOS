import AVFoundation
import Foundation

final class TtsAudioPlayback {
    private static let fadeInSamples = 160
    private static let levelFullScale: Double = 6000
    private static let playbackGain: Float = 1.8

    private let onFinished: () -> Void
    private let externalEngine: AVAudioEngine?
    private lazy var ownedEngine = AVAudioEngine()
    private var engine: AVAudioEngine { externalEngine ?? ownedEngine }
    private let playerNode = AVAudioPlayerNode()
    private let lock = NSLock()
    private let format: AVAudioFormat?

    private var pendingBufferCount = 0
    private var endOfStream = false
    private var flushEpoch = 0
    private var fadeInPending = true
    private var running = false
    private var levelValue: Float = 0
    private var playedSampleCount = 0

    var currentLevel: Float {
        lock.lock()
        defer { lock.unlock() }
        return levelValue
    }

    var playedMilliseconds: Int {
        lock.lock()
        defer { lock.unlock() }
        return playedSampleCount * 1000 / Int(TtsAudioConstants.sampleRate)
    }

    init(engine: AVAudioEngine? = nil, onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
        externalEngine = engine
        format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(TtsAudioConstants.sampleRate),
            channels: TtsAudioConstants.channels,
            interleaved: false
        )
    }

    @discardableResult
    func start() -> Bool {
        lock.lock()
        let alreadyRunning = running
        lock.unlock()
        if alreadyRunning { return true }
        guard let format else { return false }
        if playerNode.engine == nil {
            engine.attach(playerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        }
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                TtsPlaybackLog("playback engine start failed: \(error.localizedDescription)")
                return false
            }
        }
        lock.lock()
        running = true
        endOfStream = false
        fadeInPending = true
        lock.unlock()
        return true
    }

    @discardableResult
    func enqueue(_ pcm: [Int16]) -> Bool {
        guard !pcm.isEmpty else { return true }
        lock.lock()
        guard running, let format else {
            lock.unlock()
            return false
        }
        let epoch = flushEpoch
        let faded = applyFadeInIfNeeded(pcm)
        levelValue = level(of: faded)
        pendingBufferCount += 1
        lock.unlock()

        guard let buffer = makeBuffer(from: faded, format: format) else {
            finishOneBuffer(epoch: epoch, sampleCount: 0)
            return false
        }
        let sampleCount = faded.count
        playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            self?.finishOneBuffer(epoch: epoch, sampleCount: sampleCount)
        }
        if !playerNode.isPlaying {
            playerNode.play()
        }
        return true
    }

    func markEndOfStream() {
        var shouldNotify = false
        lock.lock()
        endOfStream = true
        if pendingBufferCount == 0 {
            endOfStream = false
            levelValue = 0
            shouldNotify = true
        }
        lock.unlock()
        if shouldNotify {
            onFinished()
        }
    }

    func flush() {
        lock.lock()
        flushEpoch += 1
        pendingBufferCount = 0
        playedSampleCount = 0
        endOfStream = false
        levelValue = 0
        fadeInPending = true
        lock.unlock()
        playerNode.stop()
    }

    func stop() {
        lock.lock()
        running = false
        flushEpoch += 1
        pendingBufferCount = 0
        playedSampleCount = 0
        endOfStream = false
        levelValue = 0
        lock.unlock()
        playerNode.stop()
        if externalEngine == nil {
            engine.stop()
        }
    }

    private func finishOneBuffer(epoch: Int, sampleCount: Int) {
        var shouldNotify = false
        lock.lock()
        if epoch == flushEpoch, pendingBufferCount > 0 {
            pendingBufferCount -= 1
            playedSampleCount += sampleCount
            if pendingBufferCount == 0, endOfStream {
                endOfStream = false
                levelValue = 0
                shouldNotify = true
            }
        }
        lock.unlock()
        if shouldNotify {
            onFinished()
        }
    }

    private func applyFadeInIfNeeded(_ pcm: [Int16]) -> [Int16] {
        guard fadeInPending else { return pcm }
        fadeInPending = false
        let count = min(pcm.count, Self.fadeInSamples)
        guard count > 1 else { return pcm }
        var result = pcm
        for index in 0..<count {
            result[index] = Int16((Double(pcm[index]) * Double(index) / Double(count)).rounded())
        }
        return result
    }

    private func level(of pcm: [Int16]) -> Float {
        var sum = 0.0
        for sample in pcm {
            let value = Double(sample)
            sum += value * value
        }
        let rms = (sum / Double(pcm.count)).squareRoot()
        return Float(min(max(rms / Self.levelFullScale, 0.0), 1.0))
    }

    private func makeBuffer(from pcm: [Int16], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(pcm.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        for index in 0..<pcm.count {
            let gained = Float(pcm[index]) / 32768.0 * Self.playbackGain
            channel[index] = min(1.0, max(-1.0, gained))
        }
        buffer.frameLength = AVAudioFrameCount(pcm.count)
        return buffer
    }
}
