//
//  LaunchAnimationPlaybackRecord.swift
//  RTCube / TencentRTC / RTCubeLab
//

import Foundation

enum LaunchAnimationPlaybackRecord {
    private static let lastPlayedVersionKey = "RTCube.LaunchAnimation.lastPlayedAppVersion"

    static var currentAppVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        guard !short.isEmpty, !build.isEmpty else { return "" }
        return "\(short).\(build)"
    }

    static var lastPlayedAppVersion: String? {
        return UserDefaults.standard.string(forKey: lastPlayedVersionKey)
    }

    static var hasPlayedForCurrentVersion: Bool {
        guard let last = lastPlayedAppVersion, !last.isEmpty else { return false }
        return last == currentAppVersion
    }

    static func markPlayedForCurrentVersion() {
        UserDefaults.standard.set(currentAppVersion, forKey: lastPlayedVersionKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: lastPlayedVersionKey)
    }
}
