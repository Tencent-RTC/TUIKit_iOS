//
//  LaunchAnimationPlaybackRecord.swift
//  RTCube / TencentRTC / RTCubeLab
//
//  开屏动画播放记录的持久化存储（单一职责：读 / 写 / 清除「上次播放时的 App 版本号」）。
//
//  设计动机：
//  - 动画展示规则需要识别「升级 / 全新安装 / token 过期重登」三种"应播放"场景，
//    但不希望日常自动登录冷启动反复播放。
//  - 用「上次播放时的版本号」与「当前版本号」对比，自然覆盖前两种；
//    token 过期场景由调用方在过期时刻显式 `clear()` 来重置触发条件。
//

import Foundation

enum LaunchAnimationPlaybackRecord {
    /// UserDefaults 中保存「上次成功播放完开屏动画时的 App 版本号」。
    private static let lastPlayedVersionKey = "RTCube.LaunchAnimation.lastPlayedAppVersion"

    /// 当前 App 完整版本标识（`CFBundleShortVersionString` + `CFBundleVersion`）。
    /// 同时包含市场版本号和构建号，确保同版本不同构建的覆盖安装也能触发动画。
    /// - Returns: 格式如 "13.1.0.8010"；任一字段取不到时返回空串，倾向于"播放"
    static var currentAppVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        guard !short.isEmpty, !build.isEmpty else { return "" }
        return "\(short).\(build)"
    }

    /// 上次播放完成时记录的 App 版本号；从未播放过则为 nil。
    static var lastPlayedAppVersion: String? {
        return UserDefaults.standard.string(forKey: lastPlayedVersionKey)
    }

    /// 当前版本是否已经播放过开屏动画。
    static var hasPlayedForCurrentVersion: Bool {
        guard let last = lastPlayedAppVersion, !last.isEmpty else { return false }
        return last == currentAppVersion
    }

    /// 记录「当前版本已成功播放完开屏动画」。
    /// 在动画播放完成（含被中断后的 onFinished 回调）后调用。
    static func markPlayedForCurrentVersion() {
        UserDefaults.standard.set(currentAppVersion, forKey: lastPlayedVersionKey)
    }

    /// 清除播放记录，使下一次登录成功进入首页时重新播放。
    /// 调用时机：token 过期 / 被动登出，让「过期重登」满足"应播放"语义。
    static func clear() {
        UserDefaults.standard.removeObject(forKey: lastPlayedVersionKey)
    }
}
