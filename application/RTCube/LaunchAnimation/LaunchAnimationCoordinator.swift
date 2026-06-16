//
//  LaunchAnimationCoordinator.swift
//  RTCube / TencentRTC / RTCubeLab
//

import Foundation
import UIKit

enum LaunchAnimationCoordinator {
    private static let videoBaseName = "69babfea7b12a1a7d89502bc918f480b"
    private static let videoExtension = "mov"

    private static var isScheduledForCurrentLaunch = false

    static func shouldPlayOnEnterHome() -> Bool {
        #if RTCUBE_LAB
        return false
        #else
        return videoURL() != nil && !LaunchAnimationPlaybackRecord.hasPlayedForCurrentVersion
        #endif
    }

    static func tryAcquirePlaybackForCurrentLaunch() -> Bool {
        guard shouldPlayOnEnterHome() else { return false }
        guard !isScheduledForCurrentLaunch else { return false }
        isScheduledForCurrentLaunch = true
        return true
    }

    static func videoURL() -> URL? {
        return Bundle.main.url(forResource: videoBaseName, withExtension: videoExtension)
    }

    static func markPlayedForCurrentVersion() {
        LaunchAnimationPlaybackRecord.markPlayedForCurrentVersion()
    }

    static func resetForReLogin() {
        LaunchAnimationPlaybackRecord.clear()
        isScheduledForCurrentLaunch = false
    }
}
