import Foundation
import ImSDK_Plus

final class RealtimeASRSessionImpl {
    static let errStartTimeout: Int32 = -1001

    private static let baseUploadBatchFrames = 5
    private static let baseFrameDurationMs = 20
    private static let flushLogThreshold = 3
    private static let flushLogInterval = 50

    weak var owner: RealtimeASRSession?
    var language = "zh"
    var startTimeoutMs = 5000
    var uploadBatchFrames = RealtimeASRSessionImpl.baseUploadBatchFrames
    var uploadMaxFramesPerCall = 100
    var onLog: ((String) -> Void)?
    var onError: ((Int32, String) -> Void)?

    private var pendingPackets: [Data] = []
    private var currentSessionID: String?
    private var starting = false
    private var startTimeoutWork: DispatchWorkItem?
    private var drainingSessionID: String?
    private var generation = 0
    private var flushCount = 0

    init() {}

    var sessionID: String? { currentSessionID }
    var isStarting: Bool { starting }
    var drainSessionID: String? { drainingSessionID }
    var isLive: Bool { currentSessionID != nil || starting }

    func start() {
        drainingSessionID = nil
        guard !starting, currentSessionID == nil else { return }
        starting = true
        generation += 1
        let gen = generation
        pendingPackets.removeAll()
        scheduleStartTimeout(gen: gen)

        log("startASR request language=\(language)")
        V2TIMManager.sharedInstance().callExperimentalAPI(
            api: "startRealtimeTranscriber",
            param: ["language": language] as NSDictionary,
            succ: { [weak self] result in
                let id = (result as? String) ?? ""
                DispatchQueue.main.async { [weak self] in
                    guard let self, let owner = self.owner else {
                        if !id.isEmpty { Self.stopASR(sessionID: id, completion: nil) }
                        return
                    }
                    defer { withExtendedLifetime(owner) {} }
                    self.log("startASR success sessionID=\(id) genMatch=\(gen == self.generation)")
                    if gen != self.generation {
                        if !id.isEmpty { Self.stopASR(sessionID: id, completion: nil) }
                        return
                    }
                    self.cancelStartTimeout()
                    self.generation += 1
                    self.starting = false
                    self.currentSessionID = id
                    owner.listener?.asrSessionDidStart(owner)
                }
            },
            fail: { [weak self] code, desc in
                DispatchQueue.main.async { [weak self] in
                    guard let self, let owner = self.owner else { return }
                    defer { withExtendedLifetime(owner) {} }
                    self.log("startASR FAILED code=\(code) desc=\(desc ?? "")")
                    if gen != self.generation { return }
                    self.cancelStartTimeout()
                    self.generation += 1
                    self.starting = false
                    owner.listener?.asrSession(owner, didFailToStart: code, desc: desc ?? "")
                }
            }
        )
    }

    func pushPacket(_ packet: Data) {
        guard let id = currentSessionID else { return }
        pendingPackets.append(packet)
        if pendingPackets.count >= uploadBatchFrames {
            flush(sessionID: id)
        }
    }

    func applyOpusFrameDuration(_ frameDurationMs: Int) {
        guard frameDurationMs > 0 else { return }
        uploadBatchFrames = max(1, Self.baseUploadBatchFrames * Self.baseFrameDurationMs / frameDurationMs)
    }

    func stop(onStopped: (() -> Void)? = nil) {
        cancelStartTimeout()
        generation += 1
        starting = false
        let id = currentSessionID
        currentSessionID = nil
        guard let id else {
            pendingPackets.removeAll()
            onStopped?()
            return
        }
        if !pendingPackets.isEmpty {
            flush(sessionID: id)
        }
        drainingSessionID = id
        Self.stopASR(sessionID: id, completion: onStopped, onError: onError)
    }

    func stopFlushingTail(tailTimeoutMs: Int, onStopped: @escaping () -> Void) {
        cancelStartTimeout()
        generation += 1
        starting = false
        let id = currentSessionID
        currentSessionID = nil
        guard let id else {
            pendingPackets.removeAll()
            onStopped()
            return
        }
        drainingSessionID = id
        flushTailThenStop(sessionID: id, timeoutMs: tailTimeoutMs, onStopped: onStopped)
    }

    func endDrain() {
        drainingSessionID = nil
    }

    func noteRemoteFinished(sessionID: String) {
        guard currentSessionID == sessionID else { return }
        generation += 1
        starting = false
        currentSessionID = nil
        pendingPackets.removeAll()
    }

    private func flushTailThenStop(sessionID: String, timeoutMs: Int, onStopped: @escaping () -> Void) {
        let tail = pendingPackets
        pendingPackets.removeAll()
        let chunks = tail.chunked(into: uploadMaxFramesPerCall)
        if chunks.isEmpty {
            Self.stopASR(sessionID: sessionID, completion: onStopped, onError: onError)
            return
        }
        var stopped = false
        var remaining = chunks.count
        let errorCallback = onError
        let stopOnce = {
            guard !stopped else { return }
            stopped = true
            Self.stopASR(sessionID: sessionID, completion: onStopped, onError: errorCallback)
        }
        let guardWork = DispatchWorkItem {
            stopOnce()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(timeoutMs), execute: guardWork)
        for chunk in chunks {
            V2TIMManager.sharedInstance().callExperimentalAPI(
                api: "feedRealtimeAudioData",
                param: ["sessionID": sessionID, "dataList": chunk] as NSDictionary,
                succ: { _ in
                    DispatchQueue.main.async {
                        remaining -= 1
                        if remaining == 0 {
                            guardWork.cancel()
                            stopOnce()
                        }
                    }
                },
                fail: { [weak self] code, desc in
                    DispatchQueue.main.async {
                        self?.onError?(code, desc ?? "")
                        remaining -= 1
                        if remaining == 0 {
                            guardWork.cancel()
                            stopOnce()
                        }
                    }
                }
            )
        }
    }

    private func scheduleStartTimeout(gen: Int) {
        let work = DispatchWorkItem { [weak self] in
            guard let self, let owner = self.owner, gen == self.generation else { return }
            defer { withExtendedLifetime(owner) {} }
            self.generation += 1
            self.starting = false
            if let owner = self.owner {
                owner.listener?.asrSession(owner, didFailToStart: Self.errStartTimeout, desc: "startASR timeout")
            }
        }
        startTimeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(startTimeoutMs), execute: work)
    }

    private func cancelStartTimeout() {
        startTimeoutWork?.cancel()
        startTimeoutWork = nil
    }

    private func flush(sessionID: String) {
        let batch = pendingPackets
        pendingPackets.removeAll()
        flushCount += 1
        if flushCount <= Self.flushLogThreshold || flushCount % Self.flushLogInterval == 0 {
            log("feedAudio #\(flushCount) packets=\(batch.count) session=\(sessionID)")
        }
        V2TIMManager.sharedInstance().callExperimentalAPI(
            api: "feedRealtimeAudioData",
            param: ["sessionID": sessionID, "dataList": batch] as NSDictionary,
            succ: nil,
            fail: { [weak self] code, desc in
                self?.log("feedAudio FAILED code=\(code) desc=\(desc ?? "")")
                self?.onError?(code, desc ?? "")
            }
        )
    }

    private static func stopASR(sessionID: String, completion: (() -> Void)?, onError: ((Int32, String) -> Void)? = nil) {
        V2TIMManager.sharedInstance().callExperimentalAPI(
            api: "stopRealtimeTranscriber",
            param: ["sessionID": sessionID] as NSDictionary,
            succ: { _ in completion?() },
            fail: { code, desc in
                onError?(code, desc ?? "")
                completion?()
            }
        )
    }

    private func log(_ message: String) {
        onLog?(message)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var result: [[Element]] = []
        var index = 0
        while index < count {
            let end = Swift.min(index + size, count)
            result.append(Array(self[index ..< end]))
            index = end
        }
        return result
    }
}
