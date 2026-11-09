//
//  SampleHandler.swift
//  RoomKitScreenShare
//
//  Created by adamsfliu on 2026/10/19.
//

import ReplayKit
import TXLiteAVSDK_ReplayKitExt

private let appGroup = "group.com.tencent.liveadapter.demo"

class SampleHandler: RPBroadcastSampleHandler, TXReplayKitExtDelegate {

    private var frameCount: UInt64 = 0

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        NSLog("[ScreenShareExt] broadcastStarted appGroup=%@", appGroup)
        TXReplayKitExt.sharedInstance().setup(withAppGroup: appGroup, delegate: self)
    }

    override func broadcastPaused() {}

    override func broadcastResumed() {}

    override func broadcastFinished() {
        TXReplayKitExt.sharedInstance().broadcastFinished()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        if frameCount == 0 { NSLog("[ScreenShareExt] first sampleBuffer type=%d", sampleBufferType.rawValue) }
        frameCount += 1
        if frameCount % 600 == 0 { NSLog("[ScreenShareExt] sampleBuffer count=%d", frameCount) }
        TXReplayKitExt.sharedInstance().send(sampleBuffer, with: sampleBufferType)
    }

    // MARK: - TXReplayKitExtDelegate

    func broadcastFinished(_ broadcast: TXReplayKitExt, reason: TXReplayKitExtReason) {
        NSLog("[ScreenShareExt] delegate broadcastFinished reason=%d(%@) frames=%llu",
              reason.rawValue, Self.description(of: reason), frameCount)
        _ = perform(#selector(RPBroadcastSampleHandler.finishBroadcastWithError(_:)), with: nil)
    }

    private static func description(of reason: TXReplayKitExtReason) -> String {
        switch reason {
        case .requestedByMain: return "requestedByMain"
        case .disconnected: return "disconnected"
        case .versionMismatch: return "versionMismatch"
        @unknown default: return "unknown"
        }
    }
}
